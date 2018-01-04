---
layout: post
title: "KVM Log 2-QEMU-kvm Startup"
date: 2017-08-14 16:20:36 +0800
comments: true
tags: virtualization
keywords: QEMU, kvm, module
description: "QEMU-kvm startup"
---

[上一篇](http://silentming.net/blog/2017/08/14/kvm-log-1-qemu-module-intro/)简单说明了QEMU Object Module的注册实现，本篇简单介绍Qemu的启动整个流程。QEMU版本是2.10-rc2 (2017-08-14的版本master分支), 函数的深入细节不涉及~

<!-- more -->

# Startup

QEMU是从`vl.c`中的`main()`开始执行的↓:

* `main()`:

```c vl.c
2994 int main(int argc, char **argv, char **envp)
2995 {
2996     int i;
...
3039     module_call_init(MODULE_INIT_TRACE);

3041     qemu_init_cpu_list();
3042     qemu_init_cpu_loop();
3043     qemu_mutex_lock_iothread();
3044
3045     atexit(qemu_run_exit_notifiers);
3046     error_set_progname(argv[0]);
3047     qemu_init_exec_dir(argv[0]);
3048
3049     module_call_init(MODULE_INIT_QOM);
3050     monitor_init_qmp_commands();
3051
3052     qemu_add_opts(&qemu_drive_opts);
...
```

* `module_call_init()` :实现如下↓

```c util/module.c
90 void module_call_init(module_init_type type)
91 {
92     ModuleTypeList *l;
93     ModuleEntry *e;
94
95     l = find_type(type);
96
97     QTAILQ_FOREACH(e, l, node) {
98         e->init();
99     }
100 }
```

在[前一篇](http://silentming.net/blog/2017/08/14/kvm-log-1-qemu-module-intro/)中已经说明了`ModuleTypeList`已经在`main()`执行前初始化过了，所以这里`QTAILQ_FOREACH`就是在遍历所有的entry并调用真正的init初始化函数。

* `qemu_init_cpu_list()`, 初始化完Trace后，紧接着初始化`cpu_list`, 这个主要是初始化一些锁和同步机制的相关变量。

* `qemu_init_cpu_loop()`:

这个函数我们主要需要注意其中的`qemu_init_sigbus`, 其他就是初始化锁之类的

```c cpus.c
#if CONFIG_LINUX
988 static void sigbus_handler(int n, siginfo_t *siginfo, void *ctx)
989 {
990     if (siginfo->si_code != BUS_MCEERR_AO && siginfo->si_code != BUS_MCEERR_AR) {
991         sigbus_reraise();
992     }
993
994     if (current_cpu) {
995         /* Called asynchronously in VCPU thread.  */
996         if (kvm_on_sigbus_vcpu(current_cpu, siginfo->si_code, siginfo->si_addr)) {
997             sigbus_reraise();
998         }
999     } else {
1000         /* Called synchronously (via signalfd) in main thread.  */
1001         if (kvm_on_sigbus(siginfo->si_code, siginfo->si_addr)) {
1002             sigbus_reraise();
1003         }
1004     }
1005 }

1007 static void qemu_init_sigbus(void)
1008 {
1009     struct sigaction action;
1010
1011     memset(&action, 0, sizeof(action));
1012     action.sa_flags = SA_SIGINFO;
1013     action.sa_sigaction = sigbus_handler;
1014     sigaction(SIGBUS, &action, NULL);
1015
1016     prctl(PR_MCE_KILL, PR_MCE_KILL_SET, PR_MCE_KILL_EARLY, 0, 0);
1017 }
```

在函数里面初始化了sigbus, 这里sigbus会建立一个`sigaction`, `sigaction`是vcpu对signal的动作，当config为Linux时，`sigbus_handler`会调用kvm的相关函数.

接下来都是些比较简单的初始化，初始化QOM和OPT类型的Module, 

之后就是冗长的参数解析和处理过程...

```c vl.c
3746             case QEMU_OPTION_enable_kvm:
3747                 olist = qemu_find_opts("machine");
3748                 qemu_opts_parse_noisily(olist, "accel=kvm", false);
3749                 break;
...
4121     machine_class = select_machine();
```

其中有一项就是判断是否开启了kvm, 如果开启了kvm则将accelerator设置为KVM. 

当参数这些弄完后，就会开始选择target的machine类型, (机器支持的类型可以通过`qemu -machine help`查看到):

```sh
# For example, arm64:
% qemu-system-aarch64 -machine help
Supported machines are:
lm3s811evb           Stellaris LM3S811EVB
canon-a1100          Canon PowerShot A1100 IS
vexpress-a15         ARM Versatile Express for Cortex-A15
vexpress-a9          ARM Versatile Express for Cortex-A9
xilinx-zynq-a9       Xilinx Zynq Platform Baseboard for Cortex-A9
connex               Gumstix Connex (PXA255)
n800                 Nokia N800 tablet aka. RX-34 (OMAP2420)
lm3s6965evb          Stellaris LM3S6965EVB
versatileab          ARM Versatile/AB (ARM926EJ-S)
borzoi               Borzoi PDA (PXA270)
tosa                 Tosa PDA (PXA255)
cheetah              Palm Tungsten|E aka. Cheetah PDA (OMAP310)
midway               Calxeda Midway (ECX-2000)
...
```
继续就是设置虚拟机的内存大小。

```c vl.c
4123     set_memory_options(&ram_slots, &maxram_size, machine_class);
...
4177     cpu_exec_init_all();
```

再往下就是实际为虚拟机分配内存:

* `cpu_exec_init_all()` ↓

```c exec.c
2760 static void memory_map_init(void)
2761 {
2762     system_memory = g_malloc(sizeof(*system_memory));
2763
2764     memory_region_init(system_memory, NULL, "system", UINT64_MAX);
2765     address_space_init(&address_space_memory, system_memory, "memory");
2766
2767     system_io = g_malloc(sizeof(*system_io));
2768     memory_region_init_io(system_io, NULL, &unassigned_io_ops, NULL, "io",
2769                           65536);
2770     address_space_init(&address_space_io, system_io, "I/O");
2771 }

3215 void cpu_exec_init_all(void)
3216 {
3217     qemu_mutex_init(&ram_list.mutex);
3225     finalize_target_page_bits();
3226     io_mem_init();
3227     memory_map_init();
3228     qemu_mutex_init(&map_client_list_lock);
3229 }
```

往下就是初始化smp、默认的显示器、log、Page页大小、socket, 之后就是和kvm非常相关的配置accelerator了，
与kvm的交互我们放下一篇细说，这里不深入了。

```c vl.c
4424     configure_accelerator(current_machine);
4425
4430     register_global_properties(current_machine);
...
4442     machine_opts = qemu_get_machine_opts();
4443     kernel_filename = qemu_opt_get(machine_opts, "kernel");
4444     initrd_filename = qemu_opt_get(machine_opts, "initrd");
4445     kernel_cmdline = qemu_opt_get(machine_opts, "append");
4446     bios_name = qemu_opt_get(machine_opts, "firmware");
...
4577     default_drive(default_cdrom, snapshot, machine_class->block_default_type, 2,
4578                   CDROM_OPTS);
...
4741     qdev_machine_creation_done();
4746     qemu_run_machine_init_done_notifiers();
```

之后就是读取kernel镜像位置等和启动参数等，然后初始化console、设置默认的启动介质、设置watchdog、其他设备相关的初始化。

最终qemu就会初始化完成虚拟机machine, 

```c vl.c
4786         vm_start();
4787     }
4788
4789     os_setup_post();
4790
4791     main_loop();
```

之后QEMU会调用`vm_start()` 所有的vcpu开始被调度，QEMU自身进入`main_loop()`, 当我们停止虚拟机的时候，`main_loop()`会跳出并回收资源.

```c cpus.c
1845 void vm_start(void)
1846 {
1847     if (!vm_prepare_start()) {
1848         resume_all_vcpus();
1849     }
1850 }
```

这就是整个QEMU的执行过程。


