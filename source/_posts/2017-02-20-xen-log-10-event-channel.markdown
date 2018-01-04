---
layout: post
title: "Xen Log 10-Event Channel Implementation"
date: 2017-02-20 13:55:43 +0800
comments: true
tags: virtualization
keywords: xen, event channel, io
description: "Event channel of Xen"
---

[I/O Ring][9]能够让我们通过共享内存传输数据，但是在准备好数据后又该如何告知远端的Dom呢？因此类似中断，这里就要用到Event\_Channel来进行异步通知。Event Channel是Xen提供的一套
等价于硬件中断的通信机制，其融合了Physical Interrupt, Virtual Interrupt和Inter/Intradomain Communication. 

本篇博文分为两部分，这篇介绍Event Channel的实现机制，[另一篇][12]介绍Event Channel如何在Guest中使用。

<!-- more -->

1. [Grant Table][8]
2. [I/O Ring Structure][9]
3. **Event Channel Implementation(本篇)**
4. [Event Channel Usage][12]
5. [XenStore Usage][13]
6. [Write a PV Driver][14]
7. [Connect to XenBus][15]

# Event Channel Model

Event Channel是Xen提供的通信机制，Xen允许Guest将以下四种中断映射成为Event Channel。

1. 利用Pass-through的方式将硬件直接交给某个Guest，或使用支持SR-IOV的硬件时是可以直接使用这个中断的。
2. 但是Guest有的时候需要一些中断(e.g. 时钟中断)来完成某个功能，因此Xen提供了虚拟中断(VIRQ)，Hypervisor设置某个bit使得Guest以为有了中断。
3. Interdomain communication, Domain之间的通信需要依赖某个机制。
4. Intradomain communication, Domainn内部通信，属于Interdomain Communication的一种特殊情况, (DomID相同，cpuID不同)

在Event Channel部分, remote port往往与evtchn互换使用，而local port则与irq互换使用。

一个Guest会通过Event Channel绑定到一个时间源上，并设置对应的handler.

Event Source可以是另一个dom的port(Case 3, 4), 真实的物理中断(Case 1)或者一个虚拟中断(Case 2)。当Event Channel建好后，事件源就可以通过这个Channel发通知给接收端。

```c Event Channel Model
domM irq_handler<--- bound --->local_irq <--- bound --->
port/evtchn<---(bound)--->Event Source
```

# PV Guest (No CPU Hardware Virtualization)

PV Guest由于可以对Kernel进行修改，因此Event是通过callback来完成的。Guest在初始化的时候会利用Hypercall注册好callback的handler, 每次Xen调用callback时直接跳转到handler中

### PV Register Callback

```c Boot_Code
/* $DIR/arch/x86/kernel/setup.c: 851: */
void __init setup_arch(char **cmdline_p) :
-> x86_init.oem.arch_setup(); 
/* ↑ This function pointer is initialized in $DIR/arch/x86/xen/enlignted.c: 
  
  http://lxr.free-electrons.com/source/arch/x86/xen/enlighten.c
	1576: x86_init.oem.arch_setup = xen_arch_setup;
*/

/* $DIR/arch/x86/xen/setup.c */
1032: void __init xen_arch_setup(void) :
-> if (!xen_feature(XENFEAT_auto_translated_physmap)) xen_pvmmu_arch_setup();

1015: void __init xen_pvmmu_arch_setup(void)
{
  ...

	if (register_callback(CALLBACKTYPE_event, xen_hypervisor_callback) ||
	    register_callback(CALLBACKTYPE_failsafe, xen_failsafe_callback))
		BUG();

	xen_enable_sysenter();
	xen_enable_syscall();
}

964: static int register_callback(unsigned type, const void *func)
{
	struct callback_register callback = {
		.type = type,
		.address = XEN_CALLBACK(__KERNEL_CS, func),
		.flags = CALLBACKF_mask_events,
	};

	return HYPERVISOR_callback_op(CALLBACKOP_register, &callback);
}
```

可以发现，Linux最终通过调用`HYPERVISOR_callback_op(callback_register, &callback)`将`xen_hypervisor_callback()`与`xen_failsafe_callback()`注册成为Upcall的Handler和失败处理。

每当有一个Event时，Xen会set shared\_info中对应vcpu的event map的对应bit, 再通过这个upcall来通知Guest, 控制流会直接跳转到`xen_hypervisor_callback()`中，
这个函数定义在[`arch/x86/entry/entry_64.S or entry_32.S`][6]中, 处理逻辑与中断类似，保存当前状态并跳到实际的处理函数`xen_evtchn_do_upcall`。在实际的处理函数中会去查event map中的bit并调用相应的函数进行处理。

```c 过程如下
Hypervisor --- Callback ---> Guest Callback Handler
---> Save state ---> Event Handler 
---> xen_evtchn_do_upcall 
```

# HVM Guest (CPU Hardware Virtualization)

在引入HVM后，根据不同程度虚拟化可以将Guest分为下述几类

{% img https://farm3.staticflickr.com/2547/32205809304_32bfd8b119_o_d.png spectrum %}

关于上面这幅图的详细介绍以及如何确定自己的Guest运行在哪个模式下，在[下一篇博文][2]中我会详述。

这里为了提高性能，我之后主要使用的是PVHVM, 充分利用CPU和内存/MMU的硬件虚拟化，同时利用PV Driver (Split drivers in Xen)和Interrupt与Timer。与PV不同的是HVM使用了CPU的硬件虚拟化，拥有**root**和**non-root**模式
Hypervisor不可能单单使用Callback跳转到ring3, 必须使用VMENTER/VMRUN进入non-root。 
HVM中CPU虚拟化提供了VMCS(Intel)/VMCB(AMD), 在VMENTER/VMRUN之前设置里面的对应bit，就可以在回到Non-root模式的时候引起Guest的中断处理。 
因此，Hypervisor所需要做的就是设置引起中断的bit即可。

### Guest Register Callback

```c Boot_Code 
/* $DIR/arch/x86/xen/enlighten.c */
1864: static void __init xen_hvm_guest_init(void) :
-> 1880: x86_init.irqs.intr_init = xen_init_IRQ;

/* $DIR/drivers/xen/events/events_base.c */
1678: void __init xen_init_IRQ(void):
-> 1703: xen_callback_vector();

1649: void xen_callback_vector(void): 
-> rc = xen_set_callback_via(callback_via);
/* callback_via is HYPERVISOR_CALLBACK_VECTOR: 0xf3 */

int xen_set_callback_via(uint64_t via)
{
	struct xen_hvm_param a;
	a.domid = DOMID_SELF;
	a.index = HVM_PARAM_CALLBACK_IRQ;
	a.value = via;
	return HYPERVISOR_hvm_op(HVMOP_set_param, &a);
}

-> alloc_intr_gate(HYPERVISOR_CALLBACK_VECTOR, xen_hvm_callback_vector);
```

可以发现，Guest 通过调用`HYPERVISOR_hvm_op`Hypercall 告诉Xen有一个`HVM_PARAM_CALLBACK_IRQ`, 在Xen Hypervisor中，会根据via传来的参数创建一个新的irq。via是callback的vector号。

而后Guest会为这个vector分配一个中断。

```c $DIR/arch/x86/entry/entry_64.S http://lxr.free-electrons.com/source/arch/x86/entry/entry_64.S?v=4.8 
914:  apicinterrupt3 HYPERVISOR_CALLBACK_VECTOR \
      xen_hvm_callback_vector xen_evtchn_do_upcall
```

最终`xen_hvm_callback_vector`会由`xen_evtchn_do_upcall`来处理，

### Hypervisor Set VMCB According to Pending Bit

而在Hypervisor中，每次 VMRUN/VMENTER会查询之前注册的号，如果发现有被set的就会在VMCB/VMCS里面set中断位，在VMRUN/VMENTER后Guest就会去处理相应的逻辑。

```c Hypervisor_check
/* $XENDIR/xen/arch/x86/hvm/svm/intr.c */
135: void svm_intr_assist(void) 
-> 146: intack = hvm_vcpu_has_pending_irq(v); /* Check pending bit */
-> 197: if ( unlikely(vmcb->eventinj.fields.v) || intblk ) /* Set VMCB */

/* $XENDIR/xen/arch/x86/vhm/irq.c */
in hvm_vcpu_has_pending_irq(v) {
...
/* Check evtchn_upcall_pending */
    if ( (plat->irq.callback_via_type == HVMIRQ_callback_vector)
         && vcpu_info(v, evtchn_upcall_pending) )
...
}

/* $XENDIR/xen/arch/x86/hvm/svm/entry.S */
ENTRY(svm_asm_do_resume)
-> 37: call svm_intr_assist
...
VMRUN
...
```

因此每次VMExit处理完后，Hypervisor都会检查pending的中断并设置VMCB中相应的bit，在VMRUN的时候Guest会进入中断处理来处理Event。

```c 过程如下
Hypervisor --- Check Pending bit ---> Set VMCB/VMCS
---> VMRUN/VMENTER 

Guest --- Interrupt ---> Callback
---> Callback handler ---> xen_evtchn_do_upcall
```

# Real Handler: xen\_evtchn\_do\_upcall

无论是PV还是HVM, 最终Event都会交由`xen_evtchn_do_upcall`来处理:

```c $DIR/drivers/xen/events/events_base.c http://lxr.free-electrons.com/source/drivers/xen/events/events_base.c
1253: void xen_evtchn_do_upcall(struct pt_regs *regs)
1263: -> __xen_evtchn_do_upcall();

1228: static void __xen_evtchn_do_upcall(void)
1240: xen_evtchn_handle_events(cpu);
```

之后`xen_evtchn_handle_events`会根据event的实现采用2l/fifo的event\_channel来处理，(以fifo为例),

```c $DIR/drivers/xen/events/events_fifo.c http://lxr.free-electrons.com/source/drivers/xen/events/events_fifo.c
327: static void __evtchn_fifo_handle_events(unsigned cpu, bool drop)
339: -> consume_one_event(cpu, control_block, q, &ready, drop);

282: static void consume_one_event(unsigned cpu, ...)
321: -> handle_irq_for_port(port);

273: static void handle_irq_for_port(unsigned port)
279: -> generic_handle_irq(irq);
```

之后就和普通处理irq的逻辑一样了, 查找对应的描述符并调用相应的处理函数，Event Channel至此就再次被转换为上层的IPI、VIRQ或IRQ.

在2-level ABI(2l)的中是通过查找shared\_info中的bitmap来处理event的，但是最终也会调用`generic_handle_irq`回到统一的处理逻辑上。


# Summary

Xen提供的Event Channel是Hypervisor中的一种机制，对于上层Guest来说其目的是将IRQ、VIRQ、IPI借助Event Channel这一统一形式进行传递。从而实现异步通信。

在发升IRQ的时候Guest都会进行下陷，由Hypervisor去set相应的bit, 不过一种新技术[Post-Interrupt](4)可以在不下陷的情况下完成这一要求, 有机会再详细介绍。


[2]: http://silentming.net/blog/2017/02/28/xen-log-11-what-color-is-your-guest/
[4]: http://events.linuxfoundation.org/sites/events/files/slides/VT-d%20Posted%20Interrupts-final%20.pdf
[6]: http://lxr.free-electrons.com/source/arch/x86/entry/entry_64.S

[8]: http://silentming.net/blog/2016/12/26/xen-log-8-grant-table/
[9]: http://silentming.net/blog/2016/12/28/xen-log-9-io-ring/
[10]: http://silentming.net/blog/2017/02/20/xen-log-10-event-channel/
[12]: http://silentming.net/blog/2017/03/01/xen-log-12-using-event-channel/
[13]: http://silentming.net/blog/2017/03/02/xen-log-13-xenstore/
[14]: http://silentming.net/blog/2017/03/20/xen-log-14-pv-driver/
[15]: http://silentming.net/blog/2017/03/21/xen-log-15-xenbus/


