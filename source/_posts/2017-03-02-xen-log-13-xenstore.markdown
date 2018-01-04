---
layout: post
title: "Xen Log 13-Xenstore Usage"
date: 2017-03-02 10:34:38 +0800
comments: true
tags: virtualization
keywords: xen, xenstore
---

XenStore是由Dom0维护的分层的存储系统(像一个小文件系统目录一样), 用于在Guest之间共享信息，通过Shared Memory来进行
数据共享。利用XenStore, Guest之间可以交流外设信息、Dom0可以读取到其他Guest的配置信息。

Hypervisor自身不会意识到XenStore的存在，XenStore的地址也是通过Shared\_info page在Guest启动时进行map. 也因此Hypervisor中没有任何关于XenStore的Hypercall. 但是XenStore却是Xen中非常重要的一部分. 本篇将简单介绍XenStore和其使用。(用的是Linux 4.10.2)

<!-- more -->

1. [Grant Table][8]
2. [I/O Ring Structure][9]
3. [Event Channel Implementation][10]
4. [Event Channel Usage][12]
5. **XenStore Usage(本篇)**
6. [Write a PV Driver][14]
7. [Connect to XenBus][15]

# What is XenStore

XenStore本质上是个软件实现的小数据库，使用`<key, value>`来存储信息，同时是个层级存储，Key之间可以类似目录一样拥有子Key. 一般习惯上一个Key只存value或children一种。

XenStore储存在一个树状数据库(Tree Database), 保存在`/var/lib/xenstore/tdb`文件中，由Dom0上的一个Daemon来维护，Daemon则由xencommons service进行管理。
Dom0会负责对数据库进行读写，并将**接口**通过Shared Page共享给所有的Domain. **所以在Dom之间共享的只有接口，并不是XenStore本身**. 所有的DomU最终都是通过dom0
来对实际的XenStore进行操作的。↓

{% img https://farm1.staticflickr.com/686/33199326375_036c2e88aa_o_d.png %}

共享的接口↓

```c Shared Interface (xs_wire.h) http://lxr.free-electrons.com/source/include/xen/interface/io/xs_wire.h
84: struct xenstore_domain_interface {
    char req[XENSTORE_RING_SIZE]; /* Requests to xenstore daemon. */
    char rsp[XENSTORE_RING_SIZE]; /* Replies and async watch events. */
    XENSTORE_RING_IDX req_cons, req_prod;
    XENSTORE_RING_IDX rsp_cons, rsp_prod;
};
```

### Difference between XenBus

这里需要注意下，在Linux中，XenBus是与XenStore进行交互的接口，因此关于Xenstore的代码在Linux源码中都是与Xenbus相关的部分，而在Xen中XenBus仅仅是一套交互协议，
用于连接到XenStore的设备协商时使用。所以在Linux中XenBus已经融合了XenStore.

# XenStore/XenBus in linux

在Linux的XenBus初始化的时候会判断XenStore是不是在本地，如果是本地(dom0)就会对访问Xenstore的接口所占用的内存进行初始化。如果是DomU则会直接从`start_info`或`hvm_get_parameter`
来找到接口的地址并进行映射。

```c xenbus_probe.c http://lxr.free-electrons.com/source/drivers/xen/xenbus/xenbus_probe.c
761: static int __init xenbus_init(void) {
...
case XS_LOCAL:
  err = xenstored_local_init();
  ...
}

703: static int __init xenstored_local_init(void) {
...
/* Allocate Xenstore page */
	page = get_zeroed_page(GFP_KERNEL);

}
```

这个Page里面存放的就是两个ring, 一个用于请求，一个用于回复，xenbus backend 收到请求后会将数据写入对应的文件。

# Message in ring

通过前面接口的定义，可以发现与I/O使用ring传递gref不同，与XenStore的通信消息会直接放在ring中，而与Console还不同的是，XenStore的消息一次就要处理一个完整的请求，而非stream,
因此传递消息使用的就类似网络包的形式，每次都会发一个个msg过去，如果需要处理的内容太多，就会把多个消息放在一个transaction中。消息包的声明如↓

```c xs_wire.h http://lxr.free-electrons.com/source/include/xen/interface/io/xs_wire.h
64: struct xsd_sockmsg
{
    uint32_t type;  /* XS_??? */
    uint32_t req_id;/* Request identifier, echoed in daemon's response.  */
    uint32_t tx_id; /* Transaction id (0 if not related to a transaction). */
    uint32_t len;   /* Length of data following this. */

    /* Generally followed by nul-terminated string(s). */
};
```

`type`是request的类型，`req_id`是请求者自己维护的id号，用于判断response回复的是哪个request, `tx_id`用于多个消息放入一个transaction中时使用，len则是消息的长度。

# Userspace usage

在`$XENDIR/tools/xenstore/`目录下，实现了常用的用户态的工具，用法如下:

```sh 
alice@amd-a10 : ~/VMConfig
[0] % sudo xenstore-write /alice ""

alice@amd-a10 : ~/VMConfig
[0] % sudo xenstore-write /alice/foo bar

alice@amd-a10 : ~/VMConfig
[0] % sudo xenstore-list /alice
foo

alice@amd-a10 : ~/VMConfig
[0] % sudo xenstore-read /alice/foo
bar

alice@amd-a10 : ~/VMConfig
[0] % sudo xenstore-rm /alice/foo

alice@amd-a10 : ~/VMConfig
[0] % sudo xenstore-ls /alice
```

这些可以直接通过`xenstore_daemon`与xenstore进行交互, 

# Kernelspace Usage

但是对于DomU并没有这样的tool, 因此我们需要自己去找到xenstore inteface的位置并自己利用ring来进行通信。
我是在PVDom中使用Kernel Module, 利用同步的方法来与XenStore交互的，即是说发起1个请求后就立即通知BackEnd, 然后再轮询response.

```c alice_pvdom.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_13/pvdom/alice_pvdom.c
/* Click link↗  to see full source code */
int init_alice(void)
{
    /* xen_start_info is exported by linux, and inited when pvdom start up */
    xenstore_gfn = xen_start_info->store_mfn;
    xenstore = gfn_to_virt(xenstore_gfn);
    /* get evtchn number, used to notify backend */
    xenstore_evtchn = xen_start_info->store_evtchn;

    pr_info("Alice: Begin xenstore test\n");

    alice_xs_read("name", buffer, 1023);
    pr_info("Alice: Name: %s\n", buffer);

    alice_xs_write("alice", "test");
    alice_xs_read("alice", buffer, 1023);
    pr_info("Alice: read alice:%s\n", buffer);
}

/* Read is similar */
int alice_xs_write(char *key, char *value)
{
    int key_length = strlen(key);
    int value_length = strlen(value);
    struct xsd_sockmsg msg;

      /* Fill Message */
    msg.type = XS_WRITE;
    msg.req_id = req_id;
    msg.tx_id = 0; 
    msg.len = 2 + key_length + value_length;

    /* Write the message */
    fill_request((char*)&msg, sizeof(msg));
    fill_request(key, key_length + 1);
    fill_request(value, value_length + 1);

    /* Notify the back end */
    NOTIFY();
    ... 
    return 0;
}

/* Fill request: (read_response is similar) */
static int fill_request(char *msg, int len)
{
    int i;
    int ring_index;
    
    /* Wait for back end to clear enough space in buffer */
    /* Message may be long, we will clean byte by byte */
    for ( i = xenstore->req_prod; len > 0; i++, len-- ) {
        /* Copy bytes */
        ring_index = MASK_XENSTORE_IDX(i);
        xenstore->req[ring_index] = *msg;
        msg ++;
    }

    /* Ensure data is into ring */
    wmb();
    xenstore->req_prod = i;
    return 0;
}
```

`fill_request`用于将请求拷贝到ring中, `alice_xs_write`则是构造一个消息包，(消息头、类型、req\_id、长度为key和value的和), 字符串中间用'\0'进行分割。
填写完后通过Evtchn通知dom0, 由Daemon完成response的填写，`read_response`(没有贴出来代码) 会一直polling response, 发现response则读出来并输出。

我使用的是PV Domain上的Kernel module, 如果是HVM的话则要调用Hypercall来获取一开始的各种参数。

# Running Demo

```sh
(ssh) alice@ryzen : ~/XenStore
[0] % sudo insmod alice_pvdom.ko; dmesg | tail -n 3
[140237.068340] Alice: Begin xenstore test
[140237.068433] Alice: Name: Domain-0
[140237.068544] Alice: read alice:test

(ssh) alice@ryzen : ~/XenStore
[0] % sudo xenstore-ls | grep alice
   alice = "test\000"
```

可见我们成功读出了写入的`<alice, test>`键值，通过`xenstore-ls`也可以查到。

# Reference:

1. [XenStore: Configuration Database Shared between Domains][1]
2. [The Definitive Guide to the Xen Hypervisor][2]-Chapter8

[1]: https://doc.opensuse.org/documentation/leap/virtualization/html/book.virt/cha.xen.xenstore.html
[2]: https://www.amazon.com/Definitive-Hypervisor-Prentice-Software-Development/dp/0133582493
[8]: http://silentming.net/blog/2016/12/26/xen-log-8-grant-table/
[9]: http://silentming.net/blog/2016/12/28/xen-log-9-io-ring/
[10]: http://silentming.net/blog/2017/02/20/xen-log-10-event-channel/
[12]: http://silentming.net/blog/2017/03/01/xen-log-12-using-event-channel/
[13]: http://silentming.net/blog/2017/03/02/xen-log-13-xenstore/
[14]: http://silentming.net/blog/2017/03/20/xen-log-14-pv-driver/
[15]: http://silentming.net/blog/2017/03/21/xen-log-15-xenbus/

