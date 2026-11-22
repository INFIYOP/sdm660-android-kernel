#!/vendor/bin/sh
# Start every remoteproc that is still offline (modem, adsp, ...). The mainline drivers can probe before
# /vendor/firmware is mounted and do not always retry, so init runs this after the vendor partition is up.
# Not index-based: remoteproc numbering depends on probe order.
for r in /sys/class/remoteproc/remoteproc*; do
  [ -d "$r" ] || continue
  name="$(cat "$r/name" 2>/dev/null)"
  state="$(cat "$r/state" 2>/dev/null)"
  if [ "$state" = "offline" ]; then
    echo start > "$r/state" 2>/dev/null && log -t remoteproc "started $name ($r)" || log -t remoteproc "FAILED to start $name ($r)"
  else
    log -t remoteproc "$name ($r) is $state"
  fi
done
