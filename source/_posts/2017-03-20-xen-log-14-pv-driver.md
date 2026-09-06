---
layout: post
title: "Xen Log 14-Write A PV Driver"
date: 2017-03-20 15:40:23 +0800
comments: true
tags: virtualization
keywords: xenbus, xen, linux, pv, driver
---

Xen的PV Driver使用的是Split Model, 到这里现在也比较清楚前后端的交互方式了，通过Grant Table来共享I/O ring, 在ring中放入所需数据的grant reference,
并通过Event Channel机制来告知对方，而初始的grant reference则通过XenStore来进行共享。

在[上一篇][13]中我们了解了XenStore的作用和交互方式，本篇将实现一个最简单的PV Split Driver, 并通过向XenStore中写入相应的配置信息来激活驱动。
而在[下一篇][15]中我将加入XenBus的状态信息。

<!-- more -->
1. [Grant Table][8]
2. [I/O Ring Structure][9]
3. [Event Channel Implementation][10]
4. [Event Channel Usage][12]
5. [XenStore Usage][13]
6. **Write a PV Driver(本篇)**
7. [Connect to XenBus][15]

代码非常简单，没什么要说的，所以直接上代码:)

# DomU (Front End)

```c alice_domU.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_14/domU/alice_domU.c
static int alice_front_probe(struct xenbus_device *dev,
              const struct xenbus_device_id *id)
{
	pr_info("DomU: Probe called.\n");
	return 0;
}

/* This defines the name of the devices the driver reacts to
 * So, this should be consistent with backend */
static const struct xenbus_device_id alice_front_ids[] = {
	{ "alice_dev" },
	{ ""  }
};

static struct xenbus_driver alice_front_driver = {
	.ids  = alice_front_ids,
	.probe = alice_front_probe,
};

static int __init init_alice(void)
{
	pr_info("DomU: Alice_front inited!\n");
	return xenbus_register_frontend(&alice_front_driver);
}
```

非常简单，调用xenbus接口中的`xenbus_register_frontend`函数即可，这个函数的作用就是在linux注册一个驱动.其中驱动的声明如↓

```c xenbus.h http://lxr.free-electrons.com/source/include/xen/xenbus.h
85: struct xenbus_device_id
{
	/* .../device/<device_type>/<identifier> */
	char devicetype[32]; 	/* General class of device. */
};

92: struct xenbus_driver {
	const char *name;       /* defaults to ids[0].devicetype */
	const struct xenbus_device_id *ids;
	int (*probe)(struct xenbus_device *dev,
		     const struct xenbus_device_id *id);
	void (*otherend_changed)(struct xenbus_device *dev,
				 enum xenbus_state backend_state);
	int (*remove)(struct xenbus_device *dev);
	int (*suspend)(struct xenbus_device *dev);
	int (*resume)(struct xenbus_device *dev);
	int (*uevent)(struct xenbus_device *, struct kobj_uevent_env *);
	struct device_driver driver;
	int (*read_otherend_details)(struct xenbus_device *dev);
	int (*is_ready)(struct xenbus_device *dev);
};
```

我们的驱动非常简单，只有名字和检测时调用的函数，完整的驱动把相应的回调函数指针填上即可。其中`xenbus_device_id`是用来在xenstore中分类到对应设备key下用的。

后端的代码和上面几乎一样，就不贴出来了。之后只要仿照其他设备的xenstore配置信息配一下就好:

```sh activate.sh https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_14/dom0/activate.sh
DEVICE=alice_dev
DOMU_KEY=/local/domain/$DOMU_ID/device/$DEVICE/0
DOM0_KEY=/local/domain/0/backend/$DEVICE/$DOMU_ID/0

# Tell the domU about the new device and its backend
xenstore-write $DOMU_KEY/backend-id 0
xenstore-write $DOMU_KEY/backend "/local/domain/0/backend/$DEVICE/$DOMU_ID/0"

# Tell the dom0 about the new device and its frontend
xenstore-write $DOM0_KEY/frontend-id $DOMU_ID
xenstore-write $DOM0_KEY/frontend "/local/domain/$DOMU_ID/device/$DEVICE/0"

# Make sure the domU can read the dom0 data
xenstore-chmod $DOM0_KEY r

# Activate the device, dom0 needs to be activated last
xenstore-write $DOMU_KEY/state 1
xenstore-write $DOM0_KEY/state 1
```

写的时候可以`xenstore-ls`参考一下其他设备的写法就可以了。

# Run Demo

```sh
alice@domU: sudo insmod alice_domU.ko

alice@dom0: sudo insmod alice_dom0.ko
alice@dom0: sudo ./activate.sh

alice@domU: dmesg | tail -n 2
alice@dom0: dmesg | tail -n 2

# Domain U
[  374.365006] DomU: Alice_front inited!
[  432.006567] DomU: Probe called.

# Domain 0
[  719.585539] Dom0: Alice_back inited!
[  771.465989] Dom0: Probe called.
```

如果没有activate的话，probe相关的第二条log不会输出。

# Reference
1. [Xen - a backend/frontend driver example][1]

[1]: https://fnordig.de/2016/12/02/xen-a-backend-frontend-driver-example/
[8]: http://silentming.net/blog/2016/12/26/xen-log-8-grant-table/
[9]: http://silentming.net/blog/2016/12/28/xen-log-9-io-ring/
[10]: http://silentming.net/blog/2017/02/20/xen-log-10-event-channel/
[12]: http://silentming.net/blog/2017/03/01/xen-log-12-using-event-channel/
[13]: http://silentming.net/blog/2017/03/02/xen-log-13-xenstore/
[14]: http://silentming.net/blog/2017/03/20/xen-log-14-pv-driver/
[15]: http://silentming.net/blog/2017/03/21/xen-log-15-xenbus/

