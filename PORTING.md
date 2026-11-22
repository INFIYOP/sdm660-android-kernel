# Android-required features missing from mainline 7.2: decision for each
Rule used: (1) find an alternative; (2) if none, find an existing port; (3) if none that fits, port it ourselves.

| Feature | Decision | Result |
|---|---|---|
| xt_quota2 (+ _LOG) | PORTED (existing 4.19 source, adapted to 7.2) | 0001 patch. Compiles clean with LOG enabled. Not runtime-tested. |
| uid_sys_stats | PORTED (existing 4.19 source, adapted) | 0002 patch. Compiles clean. Not runtime-tested. |
| fsync counter in task_io_accounting (needed by uid_sys_stats) | WRITTEN by us (tiny) | 0003 patch. Compiles clean. |
| ashmem | ALTERNATIVE: memfd | AOSP libcutils uses memfd_create with seals when /dev/ashmem is absent; CONFIG_MEMFD_CREATE=y here. Needs verifying on a booted system (sys.use_memfd property). |
| cpufreq_times | ALTERNATIVE: eBPF | Android's time-in-state is eBPF on tracepoints. BPF_SYSCALL, BPF_EVENTS, TRACEPOINTS are all =y. Needs verifying in userspace. |
| dm-default-key (metadata encryption) | ALTERNATIVE: plain FBE (fscrypt) | FS_ENCRYPTION + inline crypt =y; Adiantum/HCTR2/XTS/CTS added. No metadata encryption. Fine for a custom ROM on an old phone; not for passing certification. |
| NF_CT_PROTO_DCCP / UDPLITE, SCHED_DEBUG | NOT NEEDED | Removed or made unconditional upstream. |
| LD_IS_LLD | N/A | Compiler detection; true only if you build with LLD. |

## What changed in the port from 4.19 to 7.2
- xt_quota2: PDE_DATA -> pde_data, file_operations -> proc_ops, strlcpy -> strscpy, <asm/atomic.h> -> <linux/atomic.h>,
  uapi header now uses __u8/__aligned_u64, zero-length array -> flexible array, module_param types fixed. Struct layout unchanged (iptables userspace ABI).
- uid_sys_stats: same proc_ops conversion; do_each_thread/while_each_thread -> for_each_process_thread;
  profile_event_register(PROFILE_TASK_EXIT) no longer exists -> sched_process_exit tracepoint (same point in do_exit(), after io accounting is collected);
  dropped the cpufreq_times hook; depends on TRACEPOINTS instead of PROFILING.
- Not verified: behaviour at runtime. These only compile-tested against 7.2.3.
