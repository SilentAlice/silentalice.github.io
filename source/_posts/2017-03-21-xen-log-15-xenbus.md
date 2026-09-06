---
layout: post
title: "Xen Log 15-Connect to Xenbus"
date: 2017-03-21 10:56:10 +0800
comments: true
tags: virtualization
keywords: xen, xenbus, linux, driver
---

XenBus是通过XenStore协商的一套协议，前端和后端通过XenBus进行协商最终建立起通信，
前端和后端都是状态机，而状态转换的条件就是由XenBus来完成的，本篇将介绍XenBus.
[源码][3]可以从Github上得到。

<!-- more -->
1. [Grant Table][8]
2. [I/O Ring Structure][9]
3. [Event Channel Implementation][10]
4. [Event Channel Usage][12]
5. [XenStore Usage][13]
6. [Write a PV Driver][14]
7. **Connect to XenBus(本篇)**

# XenBus

> The XenBus, in the context of device drivers, is **an informal protocol built on top of the XenStore**, which provides a way of enumerating the (virtual) devices available to a given domain, and connecting to them. Implementing the XenBus interface is not required when porting a kernel to Xen. It is predominantly used in Linux to isolate the Xen-specific code behind a relatively abstract interface.(from chapter 6.4<sup>[[1](#ref1)]</sup>)

XenBus由于是一个通信协议，因此不是必须要实现的(e.g.XenStore & Console). 使用XenBus能够和Dom0上的Backend进行协商，不过我们同样可以实现自己的协议。

XenStore与Console也属于设备的一种，而这两者就是直接从`start_info`获取的，其余的外设则是通过XenStore进行交流.

# State Machine

```c xenbus.h http://lxr.free-electrons.com/source/include/xen/interface/io/xenbus.h
enum xenbus_state
{
	XenbusStateUnknown      = 0,
	XenbusStateInitialising = 1,
	XenbusStateInitWait     = 2,  /* Finished early initialisation, but waiting
					 for information from the peer or hotplug scripts. */
	XenbusStateInitialised  = 3,  /* Initialised and waiting for a
					 connection from the peer. */
	XenbusStateConnected    = 4,
	XenbusStateClosing      = 5,  /* The device is being closed
					 due to an error or an unplug event. */
	XenbusStateClosed       = 6,

	/*
	* Reconfiguring: The device is being reconfigured.
	*/
	XenbusStateReconfiguring = 7,
	XenbusStateReconfigured  = 8
};
```

使用XenBus协议的设备状态有以上这些，其中Reconfigure我们暂不讨论，一般设备不重新配置的话是不需要这个状态的，状态的转换一般如↓:

{% img https://farm4.staticflickr.com/3937/33197130430_7b037f76a0_o_d.png xenbus_state %}

```c xenbus_client.c http://lxr.free-electrons.com/source/drivers/xen/xenbus/xenbus_client.c
183: static int __xenbus_switch_state(struct xenbus_device *dev,
		      enum xenbus_state state, int depth)
{
	struct xenbus_transaction xbt;
	int current_state;
	int err, abort;

	if (state == dev->state)
		return 0;

	xenbus_transaction_start(&xbt);
	xenbus_scanf(xbt, dev->nodename, "state", "%d", &current_state);
	xenbus_printf(xbt, dev->nodename, "state", "%d", state);
	err = xenbus_transaction_end(xbt, abort);

  dev->state = state;
	return 0;
}

 * xenbus_watch_path - register a watch
 * @dev: xenbus device
 * @path: path to watch
 * @watch: watch to register
 * @callback: callback to register
115: int xenbus_watch_path(struct xenbus_device *dev, const char *path,
		      struct xenbus_watch *watch, void (*callback)(struct xenbus_watch *,
				       const char **, unsigned int))
```

在`xenbus.h`中有所有状态的声明, 由`switch_state`进行状态的迁移，`switch_state`会通过XenStore接口(Linux中即XenBus接口)向XenStore实时写入目前设备的状态
由此另一端就能通过状态来判断是否是否应该读取某些值，通过这个协议前后端就可以进行协商(告知对方shared page的grant reference等)

而两端也都会在对方Xenstore的key上注册watch来监控变动，这样当一方状态改变时另一方就能迅速做出相应。

一般来说我们会把尽可能多的工作交给back来完成, 这样Guest的driver就可以尽可能简化, 而共享页等分配则交由Guest来做, 当然自己的Driver也可以不这么做..而前后端的状态会互相影响:

{% img https://farm3.staticflickr.com/2921/33197130490_014acb268b_o_d.png split driver state %}

一般Back初始化后front才开始初始化, (front可能会从xenstore读一些关于back的信息)，back的初始化会用到front的一些数据(grant ref等), 因此在front初始化完成前back会进入Initwait等待front向xenstore中写入信息。之后当guest连接到bus后back也会连接到bus上，此时driver就可以正常工作了。

当任何一方断开时另一方也会断开。

# Add State to Driver

我们现在给前一篇完成的Driver中加入XenBus的状态:

```c alice_dom0.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_15/dom0/alice_dom0.c
/* We set up the callback functions */
static struct xenbus_driver alice_back_driver = {
	.ids  = alice_back_ids,
	.probe = alice_back_probe,
	.otherend_changed = alice_back_otherend_changed,
};

/* The function is called on a state change of the frontend driver */
static void alice_back_otherend_changed(struct xenbus_device *dev, enum xenbus_state frontend_state)
{
	switch (frontend_state) {
		case XenbusStateInitialising:
			set_backend_state(dev, XenbusStateInitWait);
			break;

		case XenbusStateConnected:
			set_backend_state(dev, XenbusStateConnected);
			break;
    ...

		default:
			xenbus_dev_fatal(dev, -EINVAL, "saw state %s (%d) at frontend",
					xenbus_strstate(frontend_state), frontend_state);
			break;
	}
}
```

主要内容就是加入`otherend_changed`函数并在里面根据另一端的状态切换本端的状态。顺便提一下`activate.sh`需要给domU和dom0的Key加入读写权限:

```sh Manual of config ----> http://manpages.ubuntu.com/manpages/trusty/man1/xenstore-chmod.1.html
# Make sure the domU can read the dom0 data
xenstore-chmod $DOM0_KEY b0 r$DOMU_ID
xenstore-chmod $DOMU_KEY b$DOMU_ID r0
```

# Demo

```sh
# DomU: 
@domU: sudo insmod alice_domU.ko; dmesg | tail -n 5
[   70.232619] DomU: Alice_front inited!
[  205.066293] DomU: Probe called.
[  205.069744] DomU: Connecting the frontend now
[  205.071032] DomU: Other side says it is connected as well.

# Dom0
@dom0: sudo insmod alice_dom0.ko; dmesg | tail -n 3
[  367.269307] Dom0: Alice_back inited!
[  414.873681] Dom0: Probe called.
[  414.875169] Dom0: Connect the backend
```

# Reference

<a name="ref1"></a>

1. [The Definitive Guide to the Xen Hypervisor (Prentice Hall Open Source Software Development][1]
2. [Xen - split driver, initial communication][2]


[1]: https://www.amazon.com/Definitive-Hypervisor-Prentice-Software-Development/dp/0133582493
[2]: https://fnordig.de/2016/12/20/xen-split-driver-initial-communication/
[3]: https://github.com/SilentAlice/BlogExamples/tree/master/Xen_Log_15
[8]: http://silentming.net/blog/2016/12/26/xen-log-8-grant-table/
[9]: http://silentming.net/blog/2016/12/28/xen-log-9-io-ring/
[10]: http://silentming.net/blog/2017/02/20/xen-log-10-event-channel/
[12]: http://silentming.net/blog/2017/03/01/xen-log-12-using-event-channel/
[13]: http://silentming.net/blog/2017/03/02/xen-log-13-xenstore/
[14]: http://silentming.net/blog/2017/03/20/xen-log-14-pv-driver/
[15]: http://silentming.net/blog/2017/03/21/xen-log-15-xenbus/

