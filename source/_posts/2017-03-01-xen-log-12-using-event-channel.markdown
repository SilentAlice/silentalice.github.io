---
layout: post
title: "Xen Log 12-Event Channel Usage"
date: 2017-03-01 18:41:40 +0800
comments: true
tags: virtualization
keywords: xen, event channel, linux, irq, interrupt
description: "Using xen event channel in linux"
---

[前一篇][1]我们已经了解了Event Channel是如何被注册和被Hypervisor实现的，本篇将利用kernel module，使用Event Channel进行Guest间的通信。

<!-- more -->

1. [Grant Table][8]
2. [I/O Ring Structure][9]
3. [Event Channel Implementation][10]
4. **Event Channel Usage(本篇)**
5. [XenStore Usage][13]
6. [Write a PV Driver][14]
7. [Connect to XenBus][15]

# Event Channel OPs

```c $XENDIR/xen/include/public/event_channel.h https://xenbits.xen.org/gitweb/?p=xen.git;a=blob;f=xen/include/public/event_channel.h;h=05e531da2c1f4752a9cb1ad830d34e81e34f45f0;hb=refs/heads/stable-4.5
/* ` enum event_channel_op { // EVTCHNOP_* => struct evtchn_* */
#define EVTCHNOP_bind_interdomain 0
#define EVTCHNOP_bind_virq        1
#define EVTCHNOP_bind_pirq        2
#define EVTCHNOP_close            3
#define EVTCHNOP_send             4
#define EVTCHNOP_status           5
#define EVTCHNOP_alloc_unbound    6
#define EVTCHNOP_bind_ipi         7
#define EVTCHNOP_bind_vcpu        8
#define EVTCHNOP_unmask           9
#define EVTCHNOP_reset           10
#define EVTCHNOP_init_control    11
#define EVTCHNOP_expand_array    12
#define EVTCHNOP_set_priority    13
```

* 0-2 分别是绑定到不同类型的Evtchn上
* 3用来关闭Evtchn
* 4用来发送一个Event
* 5用来查询当前Evtchn的状态
* 6用于申请一个空闲的未被绑定的evtchn用于Interdomain的通信
* 7用于不同cpu间的通信
* 8用于evt到来时通知哪一个vcpu, ipi通知相关vcpu, per-vcpu virq通知相关vcpu, 但是其他的默认都是通知vcpu0的。
* 9用于启动某个evtchn (unmask用于启用)
* 10用于关闭和一个domid相关的所有evtchn
* 11-13 FIFO实现的Evtchn的相关操作

如果想要完成不同dom间通信，需要dom1申请一个未绑定的evtchn, 接受者绑定这个evtchn，而后将本地的中断绑定到这个evtchn，之后就和普通的中断处理一样了。

我的demo中会由domU申请，dom0绑定并通知domU, domU收到通知后在handler中再通知dom0, 而后dom0退出。

# DomU Module

### Alloc Event channel

```c alice_domU.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_12/domU/alice_domU.c
struct evtchn_alloc_unbound alloc_unbound;
int err;

alloc_unbound.dom = DOMID_SELF;
alloc_unbound.remote_dom = DOM0_ID;

/* Get a unbound evtchn */
err = HYPERVISOR_event_channel_op(EVTCHNOP_alloc_unbound, &alloc_unbound);
```

通过Hypercall来申请一个evtchn, Hypervisor会将值填入`evtchn_alloc_unbound`中

### Alloc IRQ and Bind to Evtchn

```c alice_domU.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_12/domU/alice_domU.c
irq = bind_evtchn_to_irq(global_info.evtchn);
```

`bind_evtchn_to_irq`是linux封装的函数，其实现如↓

```c $DIR/drivers/xen/events/events_base.c http://lxr.free-electrons.com/source/drivers/xen/events/events_base.c
int bind_evtchn_to_irq(unsigned int evtchn)
{
  ...

	irq = get_evtchn_to_irq(evtchn);
	if (irq == -1) {
		irq = xen_allocate_irq_dynamic();
		irq_set_chip_and_handler_name(irq, &xen_dynamic_chip,
					      handle_edge_irq, "event");

		ret = xen_irq_info_evtchn_setup(irq, evtchn);

		/* New interdomain events are bound to VCPU 0. */
		bind_evtchn_to_cpu(evtchn, 0);
	} 

	return irq;
}
```

在首次绑定的时候，linux会动态申请一个中断号，并配置好相应的描述符，并默认绑到vcpu0上

### Bound IRQ Handler to IRQ

```c alice_domU.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_12/domU/alice_domU.c
static irqreturn_t domU_handler(int irq, void *dev_id) { ... }

err = request_irq(global_info.irq, domU_handler, 0, "alice_dev", &global_info);
```

这里定义好Handler函数后调用`request_irq`将Handler进行注册; `request_irq`实现如↓

```c $DIR/kernel/irq/manage.c http://lxr.free-electrons.com/source/kernel/irq/manage.c
1634: int request_threaded_irq(unsigned int irq, irq_handler_t handler,
			 irq_handler_t thread_fn, unsigned long irqflags,
			 const char *devname, void *dev_id)
{
    ...
    desc = irq_to_desc(irq);
    action = kzalloc(sizeof(struct irqaction), GFP_KERNEL);
    action->handler = handler;
    action->thread_fn = thread_fn;
    action->flags = irqflags;
    action->name = devname;
    action->dev_id = dev_id;

    retval = irq_chip_pm_get(&desc->irq_data);
    retval = __setup_irq(irq, desc, action);

    return retval;
}
```

可以发现， 函数将handler填入中断的描述符中后调用`__setup_irq`完成对中断的配置，这样Handler就与IRQ绑定了起来。

### Notify via IRQ

```c alice_domU.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_12/domU/alice_domU.c
static irqreturn_t domU_handler(int irq, void *dev_id)
{
    ...
    pr_info("DomU: Handled! irq: %d, evtchn:%d\n", irq, info->evtchn);
    notify_remote_via_irq(irq);
    return IRQ_HANDLED;
}
```

这样domU就可以通过irq来通知远端，`notify_remote_via_irq`则是直接调用`HYPERVISOR_event_channel_op(EVTCHNOP_send, &send)` 让Hypervisor帮忙去set相应的pending bit.

# Dom0 Module

dom0的Module原理上和domU类似，不同的是dom0不需要自己申请空闲的evtchn, 只需要直接绑定到domU的evtchn即可，并且linux中已经把上述过程都封装好了..

```c alice_dom0.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_12/dom0/alice_dom0.c
err = bind_interdomain_evtchn_to_irqhandler(global_info.remoteDomID,
            global_info.evtchn, dom0_handler, 0, "alice_dev", &global_info);
```

这个函数的执行过程和上面的过程类似，就不展开了。

# Running Demo

```sh
/* In domU, sudo insmod alice_domU.ko; dmesg */
[   81.340632] DomU: Get new evtchn: 32
[   81.340670] DomU: Bound local irq: 69 to evtchn:32
[  114.224679] DomU: Handled! irq: 69, evtchn:32

/* IN dom0, sudo insmod alice_dom0.ko domid=id port=port; dmesg */
[79383.358635] Dom0: init info with remoteDomID:6, port:32
[79383.363885] Dom0: Handled, domid: 6, port: 32, local_irq:95
[79383.363902] Dom0: bound local irq:95 to evtchn:32
[79383.374352] Dom0: Handled, domid: 6, port: 32, local_irq:95
```

刚启动dom0的module后，dom0会立即处理一次中断，可能是之前的bit没有清掉导致的... 第二次的Handle则是domU通知的。

[1]: http://silentming.net/blog/2017/02/20/xen-log-10-event-channel/
[8]: http://silentming.net/blog/2016/12/26/xen-log-8-grant-table/
[9]: http://silentming.net/blog/2016/12/28/xen-log-9-io-ring/
[10]: http://silentming.net/blog/2017/02/20/xen-log-10-event-channel/
[12]: http://silentming.net/blog/2017/03/01/xen-log-12-using-event-channel/
[13]: http://silentming.net/blog/2017/03/02/xen-log-13-xenstore/
[14]: http://silentming.net/blog/2017/03/20/xen-log-14-pv-driver/
[15]: http://silentming.net/blog/2017/03/21/xen-log-15-xenbus/

