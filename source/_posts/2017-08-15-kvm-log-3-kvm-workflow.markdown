---
layout: post
title: "KVM Log 3-KVM Workflow (ARM64)"
date: 2017-08-15 15:58:12 +0800
comments: true
tags: virtualization
keywords: QEMU, kvm, workflow, arm64 
description: "kvm workflow"
---

本篇介绍kvm自身的执行流程，以及与qemu的交互。kvm的代码本身分为两部分，kernel态代码作为kernel module虚拟出一个字符设备，qemu通过对`/dev/kvm`发送`ioctl`来实现与kvm的交互。

<!-- more -->

# KVM IOCTL

在[上一篇][2]中提到过kvm作为加速器的初始化，不过没有详细说，那么首先我们先看看kvm的初始化。

```c $QEMU/accel/kvm/kvm-all.c
2607 static void kvm_accel_class_init(ObjectClass *oc, void *data)
2608 {
2609     AccelClass *ac = ACCEL_CLASS(oc);
2610     ac->name = "KVM";
2611     ac->init_machine = kvm_init;
2612     ac->allowed = &kvm_allowed;
2613 }
2614
2622 static void kvm_type_init(void)
2623 {
2624     type_register_static(&kvm_accel_type);
2625 }
2626
2627 type_init(kvm_type_init);
```

在[QOM的介绍][1]里我提到过kvm通过`type_init`将初始化的函数指针加入了QOM的`Module_Init_Type`队列中，QEMU在初始化的时候则会通过这个链表调用`kvm_init`

```c $QEMU/accel/kvm/kvm-all.c
1558 static int kvm_init(MachineState *ms) {
...
1596     s->fd = qemu_open("/dev/kvm", O_RDWR);
...
1603     ret = kvm_ioctl(s, KVM_GET_API_VERSION, 0);
...
1745     ret = kvm_arch_init(ms, s);
}
```

可以发现QEMU最终会通过`kvm_ioctl`让kernel态的kvm来完成实际的工作。

# Initialization of vCPU

vcpu的初始化方式和kvm类似，以arm为例: 

```c $QEMU/target/arm/cpu.c
645 static void arm_cpu_realizefn(DeviceState *dev, Error **errp)
646 {
...
853     qemu_init_vcpu(cs);
...
    }

1648 static void arm_cpu_class_init(ObjectClass *oc, void *data)
1649 {
...
1655     dc->realize = arm_cpu_realizefn;
...
1691 }

1708 static const TypeInfo arm_cpu_type_info = {
...
1717     .class_init = arm_cpu_class_init,
1718 };

1732 type_init(arm_cpu_register_types)
```

```c $QEMU/cpus.c
1101 static void *qemu_kvm_cpu_thread_fn(void *arg)
1102 {
1114     r = kvm_init_vcpu(cpu);
1120     kvm_init_cpu_signals(cpu);

1122     /* signal CPU creation */
1123     cpu->created = true;
1124     qemu_cond_signal(&qemu_cpu_cond);
1125
1126     do {
1127         if (cpu_can_run(cpu)) {
1128             r = kvm_cpu_exec(cpu);
...

1725 static void qemu_kvm_start_vcpu(CPUState *cpu)
1726 {
1729     cpu->thread = g_malloc0(sizeof(QemuThread));
1730     cpu->halt_cond = g_malloc0(sizeof(QemuCond));
1731     qemu_cond_init(cpu->halt_cond);
1732     snprintf(thread_name, VCPU_THREAD_NAME_SIZE, "CPU %d/KVM",
1733              cpu->cpu_index);
1734     qemu_thread_create(cpu->thread, thread_name, qemu_kvm_cpu_thread_fn,
1735                        cpu, QEMU_THREAD_JOINABLE);
1739 }

1757 void qemu_init_vcpu(CPUState *cpu)
1758 {
1774         qemu_kvm_start_vcpu(cpu);
1782 }
```

从上面的代码可以发现，从vcpu初始化开始，一步步最后调到`qemu_kvm_start_vcpu`, 在这里QEMU会为每一个vcpu创建一个thread, thread的入口函数中则会调用`kvm_init_vcpu`和`kvm_cpu_exec`
所以在qemu的`vm_start`中resemu所有的vcpu后，这些会以线程的形式开始执行虚拟机的代码；

在Linux调度的头文件中我们可以发现Thread的属性有一个就是vcpu↓: 

```c $LINUX/include/linux/sched.h
2301 /*
2302  * Per process flags
2303  */
2304 #define PF_IDLE     0x00000002  /* I am an IDLE thread */
2305 #define PF_EXITING  0x00000004  /* getting shut down */
2306 #define PF_EXITPIDONE   0x00000008  /* pi exit done on shut down */
2307 #define PF_VCPU     0x00000010  /* I'm a virtual CPU */
```

所以与Xen不同的是, kvm复用了Linux自身的调度器，自己只负责处理这些ioctl

# Execution and Context Switch

上面调用了ioctl, 那么处理就是由kvm kernel module来完成的，续上，qemu调用了`kvm_cpu_exec`后，里面会调用ioctl:

```c $LINUX/virt/kvm/kvm_main.c
2524 static long kvm_vcpu_ioctl(struct file *filp, unsigned int ioctl, unsigned long arg)
2526 {
2567         r = kvm_arch_vcpu_ioctl_run(vcpu, vcpu->run);
```

```c $LINUX/arch/arm/kvm/arm.c
589 int kvm_arch_vcpu_ioctl_run(struct kvm_vcpu *vcpu, struct kvm_run *run)
590 {
659         guest_enter_irqoff();
660         vcpu->mode = IN_GUEST_MODE;
661
662         ret = kvm_call_hyp(__kvm_vcpu_run, vcpu);
663
664         vcpu->mode = OUTSIDE_GUEST_MODE;
/* Handle vmexit */
...
```
module中的代码负责处理`kvm_cpu_exec`的就是上面这个函数，module在初始化的时候会创建一个`/dev/kvm`设备，同时会注册相应的ioctl的handler, 代码同样在这个文件中，比较简单就不放了。

这里需要注意的是`ret = kvm_call_hyp(__kvm_vcpu_run, vcpu);`, arm中的Hypercall调用方式与x86不太一样，虚拟机的运行模式也不太一样，这里的意思就是进入Hypervisor(hyp)模式，并开始执行`__kvm_vcpu_run`, 这个函数最终会进入guest mode:

```asm $LINUX/arch/arm64/kvm/hyp/entry.S
 52 /*
 53  * u64 __guest_enter(struct kvm_vcpu *vcpu,
 54  *           struct kvm_cpu_context *host_ctxt);
 55  */
 56 ENTRY(__guest_enter)
 57     // x0: vcpu
 58     // x1: host context
 59     // x2-x17: clobbered by macros
 60     // x18: guest context
 /* Context switch */
 eret
```

在存储host状态并恢复guest状态后, 调用`eret`, 根据手册中描述:

> In a processor that implements the Virtualization Extensions, you can use ERET to perform a return from an exception taken to Hyp mode.

> When executed in Hyp mode, ERET loads the PC from `ELR_hyp` and loads the `CPSR` from `SPSR_hyp`. When executed in any other mode, apart from User or System, it behaves as:<br>
> MOVS PC, LR in the ARM instruction set<br>
> SUBS PC, LR, #0 in the Thumb instruction set.

```asm $LINUX/arch/arm64/kernel/entry.S
311 /*
312  * Exception vectors.
313  */
315
316     .align  11
317 ENTRY(vectors)
318     ventry  el1_sync_invalid        // Synchronous EL1t
319     ventry  el1_irq_invalid         // IRQ EL1t
...
324     ventry  el1_irq             // IRQ EL1h
...
```

```asm $LINUX/arch/arm64/kvm/hyp/hyp-entry.S
124 el1_irq:
125     stp     x0, x1, [sp, #-16]!
126     mrs x1, tpidr_el2
127     mov x0, #ARM_EXCEPTION_IRQ
128     b   __guest_exit
```
```asm $LINUX/arch/arm64/kvm/hyp/entry.S
91 ENTRY(__guest_exit)
 92     // x0: return code
 93     // x1: vcpu
 94     // x2-x29,lr: vcpu regs
 95     // vcpu x0-x1 on the stack
...
/* context switch and to handler */
```

加载了PC后就会执行guest代码了，则会由Exception向量表跳到对应的入口，最后借由`__guest_exit`返回重新加载host的context, 那么就会回到进入guest mode前的下一条指令开始处理exit。
关于exit处理在之后的文章里再说.

# Hypercall

上面也提了，`ret = kvm_call_hyp(__kvm_vcpu_run, vcpu);`这个是借助Hypercall完成的，那么我们看看`kvm_call_hyp`:

```asm $LINUX/arch/arm64/kvm/hyp.S
25 /* u64 __kvm_call_hyp(void *hypfn, ...); */
43 ENTRY(__kvm_call_hyp)
44 alternative_if_not ARM64_HAS_VIRT_HOST_EXTN
45     str     lr, [sp, #-16]!
46     hvc #0
47     ldr     lr, [sp], #16
48     ret
```

实际上就是调用了hvc指令，这个指令根据arm手册，x0里面存的是下一条要在hyp mode中执行的代码。

这样就可以完成hypercall的调用，需要注意的是arm里进入hyp mode会切换页表，所以必须保证之后要执行的代码在hyp mode里面有映射

# Initialization of Hyp mode

```c $LINUX/virt/kvm/kvm_main.c
3909 int kvm_init(void *opaque, unsigned vcpu_size, unsigned vcpu_align,
3910           struct module *module)
3911 {
3914
3915     r = kvm_arch_init(opaque);
```

```c $LINUX/arch/arm/kvm/arm.c
1410 /**
1411  * Initialize Hyp-mode and memory mappings on all CPUs.
1412  */
1413 int kvm_arch_init(void *opaque) {
1438         err = init_hyp_mode();
```

```c $LINUX/arch/arm/kvm/arm.c
1299 static int init_hyp_mode(void) {
1332     /*
1333      * Map the Hyp-code called directly from the host
1334      */
1335     err = create_hyp_mappings(kvm_ksym_ref(__hyp_text_start),
1336                   kvm_ksym_ref(__hyp_text_end), PAGE_HYP_EXEC);
...
```

在kvm module被加载初始化的时候，就会初始化hyp mode, 并映射相应的代码，(stage2 page table)也是在这个时候初始化的。

# Note

1. 到这里应该比较清楚kvm module初始化做了什么(初始化hyp mode, 虚拟一个`/dev/kvm`设备等等), 以及如何进入guest, 如何与qemu进行交互了。
2. 与x86的独立于ring0和ring3的non-root (guest mode)不同，arm的hyp mode是在EL1之下的权限级(EL2)，而Hypercall的调用则更像一个jump而非x86中向量表的方式。
3. x86中Non-root下执行的代码会由VMCS/VMCB来配置下陷，而arm中则是直接跑在上面的EL0和EL1, 然后再根据情况一级级下陷，所以ARM的虚拟化方式更像没有硬件虚拟化支持之前的x86的虚拟化;
(kernel跑在ring1, hypervisor跑在ring0的样子)




[1]: http://silentming.net/blog/2017/08/14/kvm-log-1-qemu-module-intro/
[2]: http://silentming.net/blog/2017/08/14/kvm-log-2-qemu-kvm-startup/
