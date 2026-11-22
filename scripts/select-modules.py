#!/usr/bin/env python3
"""Pick kernel modules a device tree needs, from a modules_install tree. Source tool, no kernel build.

usage: select-modules.py --modroot <.../lib/modules/X> --dtb <file.dtb> [--out outdir]
Needs: dtc, zstd (if modules are .ko.zst), modinfo (kmod).
Matches 'of:' module aliases against compatible strings of ENABLED dts nodes, then adds dependencies from modules.dep.
Writes: needed-modules.txt (names), needed-modules-sizes.txt, unmatched-dt-compatibles.txt
"""
import argparse, os, re, subprocess, sys, tempfile, collections

ap = argparse.ArgumentParser()
ap.add_argument('--modroot', required=True)
ap.add_argument('--dtb', required=True)
ap.add_argument('--out', default='.')
ap.add_argument('--extra', default='', help='comma separated extra module names to force-include')
a = ap.parse_args()

# ---- 1. enabled compatibles from the dtb
dts = subprocess.run(['dtc', '-I', 'dtb', '-O', 'dts', a.dtb], capture_output=True, text=True).stdout
stack, props = [], []          # props: (path, compat_list, enabled)
node_info = {}
cur = []
for line in dts.splitlines():
    s = line.strip()
    m = re.match(r'^([\w@,.+\-/]*)\s*\{$', s)
    if m:
        cur.append({'name': m.group(1) or '/', 'compat': [], 'status': None})
        continue
    if s == '};':
        n = cur.pop()
        path = '/'.join(c['name'] for c in cur + [n])
        if 'symbols' in path or '__' in path:
            continue
        enabled = all(c['status'] in (None, 'okay', 'ok') for c in cur + [n])
        if n['compat']:
            props.append((path, n['compat'], enabled))
        continue
    if cur:
        m = re.match(r'compatible = (.*);', s)
        if m:
            cur[-1]['compat'] = [x for q in re.findall(r'"([^"]+)"', m.group(1)) for x in q.split('\\0')]
        m = re.match(r'status = "([^"]+)";', s)
        if m:
            cur[-1]['status'] = m.group(1)
enabled_compat = collections.OrderedDict()
for path, comp, en in props:
    if en:
        for c in comp:
            enabled_compat.setdefault(c, path)

# ---- 2. module -> of aliases
mods = {}
for root, _, files in os.walk(a.modroot):
    for f in files:
        if f.endswith('.ko') or f.endswith('.ko.zst') or f.endswith('.ko.xz') or f.endswith('.ko.gz'):
            rel = os.path.relpath(os.path.join(root, f), a.modroot)
            name = re.sub(r'\.ko(\.\w+)?$', '', f).replace('-', '_')
            mods[name] = rel
def aliases(rel):
    p = os.path.join(a.modroot, rel)
    tmp = None
    if p.endswith('.zst'):
        tmp = tempfile.NamedTemporaryFile(suffix='.ko', delete=False); tmp.close()
        subprocess.run(['zstd', '-dqf', p, '-o', tmp.name], check=True); p = tmp.name
    out = subprocess.run(['modinfo', '-F', 'alias', p], capture_output=True, text=True).stdout.split()
    if tmp: os.unlink(tmp.name)
    return out
mod_compat = {}
for name, rel in mods.items():
    cs = set()
    for al in aliases(rel):
        if al.startswith('of:'):
            c = re.sub(r'^of:N\*T\*C', '', al); c = re.sub(r'(C\*|\*)$', '', c); cs.add(c)
    mod_compat[name] = cs

# ---- 3. match
need = collections.OrderedDict()
matched = set()
for c, path in enabled_compat.items():
    for name, cs in mod_compat.items():
        if c in cs:
            need.setdefault(name, []).append((c, path)); matched.add(c)
for e in [x for x in a.extra.split(',') if x]:
    need.setdefault(e.replace('-', '_'), []).append(('(extra)', ''))

# ---- 4. dependency closure via modules.dep
dep = {}
dp = os.path.join(a.modroot, 'modules.dep')
for line in open(dp):
    k, _, v = line.partition(':')
    dep[re.sub(r'\.ko(\.\w+)?$', '', os.path.basename(k)).replace('-', '_')] = [re.sub(r'\.ko(\.\w+)?$', '', os.path.basename(x)).replace('-', '_') for x in v.split()]
closure = collections.OrderedDict()
def add(n):
    if n in closure: return
    closure[n] = True
    for d in dep.get(n, []): add(d)
for n in need: add(n)

# ---- 5. built-in drivers (modules.builtin.modinfo) -> real gaps
bi = {}
bp = os.path.join(a.modroot, 'modules.builtin.modinfo')
if os.path.exists(bp):
    for d in open(bp, 'rb').read().split(b'\0'):
        d = d.decode(errors='ignore')
        m = re.match(r'([\w\-]+)\.alias=of:N\*T\*C(.*?)(C\*|\*)?$', d)
        if m: bi.setdefault(m.group(2), m.group(1))
os.makedirs(a.out, exist_ok=True)
IGNORE = ('arm,psci', 'arm,armv8-pmuv3', 'arm,armv8-timer', 'arm,armv7-timer-mem', 'arm,gic-v3', 'arm,idle-state',
          'cache', 'fixed-clock', 'operating-points-v2', 'shared-dma-pool', 'simple-battery', 'qcom,kryo260',
          'ramoops', 'simple-framebuffer', 'regulator-fixed', 'gpio-keys', 'pwm-vibrator')
with open(os.path.join(a.out, 'dt-gaps.txt'), 'w') as f:
    f.write('# Enabled DT nodes where NO compatible string maps to a module or a built-in OF alias.\n')
    f.write('# Often fine (arch/core code, platform drivers matched by name, non-OF aliases). Review the rest.\n')
    for path, comp, en in props:
        if not en: continue
        if any(c in matched or c in bi for c in comp): continue
        if any(c.startswith(IGNORE) or c in IGNORE for c in comp): continue
        f.write(f'{" | ".join(comp)}\t{path}\n')
tot = 0
with open(os.path.join(a.out, 'needed-modules.txt'), 'w') as f1, open(os.path.join(a.out, 'needed-modules-sizes.txt'), 'w') as f2:
    for n in closure:
        rel = mods.get(n)
        sz = os.path.getsize(os.path.join(a.modroot, rel)) if rel else 0
        tot += sz
        f1.write((re.sub(r'\.ko(\.\w+)?$', '', os.path.basename(rel)) if rel else n) + '\n')
        why = ', '.join(c for c, _ in need.get(n, [])) or '(dependency)'
        f2.write(f'{sz:>10}  {n:<32} {why}\n')
print(f'enabled compatibles: {len(enabled_compat)}, matched to a module: {len(matched)}')
print(f'direct modules: {len(need)}, with dependencies: {len(closure)}, total compressed size: {tot/1e6:.1f} MB')
