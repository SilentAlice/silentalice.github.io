---
layout: post
title: "Xen Log 9-I/O Ring Structure"
date: 2016-12-28 20:24:14 +0800
comments: true
tags: virtualization
keywords: xen, ring, io
---

在上一篇中我们通过Grant Table让DomU和Dom0能够通过内存共享进行通信，众所周知在Xen里domU的I/O都是交由dom0来完成的。而I/O driver也有两种实现方式: paravirtualized和qemu-emulated。本篇主要讨论Xen上PV Driver所使用的数据结构: I/O Device Ring。

<!-- more -->
1. [Grant Table][8]
2. **I/O Ring Structure(本篇)**
3. [Event Channel Implementation][10]
4. [Event Channel Usage][12]
5. [XenStore Usage][13]
6. [Write a PV Driver][14]
7. [Connect to XenBus][15]

# Origin of Virtualization

最早提出虚拟化的是Gerald J. Popek和Robert P. Goldberg在1974年发表的一篇[*Formal requirements for virtualizable third generation architectures*][1]中提出来的，在其中作者提到了几个对虚拟化的几个要求:

* Efficiency
  * Innocuous instructions should execute directly on hardware
* Resource control
  * Executed programs may not affect the system resources
* Equivalence
  * **The behavior of a program executing under the VMM should be the same as if the program were executed directly on the hardware (except possibly for timing and resource availability)**

最后一点要求Guest是不能知道自己运行在虚拟化下的。然而这样一个要求使得当时不得不对许多情况进行二进制的模拟以致虚拟机的性能一直非常糟糕。其中I/O的模拟就是由Qemu完成的，通过Qemu来模拟一个设备，当Guest有请求的时候请求会被转发给Qemu来模拟执行。

# Paravirtualization

Xen的理念是对domU进行适当的修改，让domU意识到自己是在虚拟化环境下，这样可以大大简化hypervisor的设计和实现。
而I/O部分Xen就使用了PV driver, PV driver的详细部分我会在之后的文章中去讨论。
这里需要了解的是PV driver分为前端和后端，domU里跑的是frontend, dom0里跑的是backend, 这时I/O的操作实际上通过frontend直接交由dom0在硬件上直接执行, 免去了qemu模拟带来的性能开销。

既然有front和back, 那么它们之间就需要通信, 两端通信所使用的是一个生产者消费者模型的ring, 由一方填入数据，另一方处理数据。

# Ring

Ring的好处在于异步通信，domU的front可以把数据丢到ring里立刻执行接下来的任务，不用等dom0的back进行回应。而ring的建立和数据传递则要以来Grant Table机制。由于front的request和back的response是相同频率(每次backend都消费一个request并填回一个response), 所以一个ring刚好服务一对driver。

{% img https://farm1.staticflickr.com/716/31586043100_7eaa9f5ca7_b_d.jpg ring %}

response的开头永远紧接着request的结尾，因此只要比较request start和response end就能知道ring是不是已经用完了，用完的话就扩充整个buffer。

```c xen/interface/io/ring.h
/* To make a new ring datatype, you need to have two message structures,
 * let's say struct request, and struct response already defined.
 *
 * In a header where you want the ring datatype declared, you then do:
 *
 *     DEFINE_RING_TYPES(mytag, struct request, struct response);
 *
 * These expand out to give you a set of types, as you can see below.
 * The most important of these are:
 *
 *     struct mytag_sring      - The shared ring.
 *     struct mytag_front_ring - The 'front' half of the ring.
 *     struct mytag_back_ring  - The 'back' half of the ring.
 *
 * To initialize a ring in your code you need to know the location and size
 * of the shared memory area (PAGE_SIZE, for instance). To initialise
 * the front half:
 *
 *     struct mytag_front_ring front_ring;
 *     SHARED_RING_INIT((struct mytag_sring *)shared_page);
 *     FRONT_RING_INIT(&front_ring, (struct mytag_sring *)shared_page,
 *		       PAGE_SIZE);
 *
 * Initializing the back follows similarly (note that only the front
 * initializes the shared ring):
 *
 *     struct mytag_back_ring back_ring;
 *     BACK_RING_INIT(&back_ring, (struct mytag_sring *)shared_page, *		      PAGE_SIZE);
 */
```
在`ring.h`中定义了`DEFINE_RING_TYPES`宏，使用它当我们传入request和response的类型时，它就会据此类型为我们建立一个shared ring和其front end与back end。两者共同操纵shared ring, 在各自的内部又会记录consume的数目。front需要调用`SHARED_RING_INIT`来初始化真正共享的页, 它会初始化start, end指针的起始位置。而后front与back分别使用`FRONT_RING_INIT`与`BACK_RING_INIT`初始化各自操作ring时使用的数据结构。

`mytag_sring`中记录了`req_prod`, `rsp_prod`, `req_event`, `rsp_event`4个变量，
其中`req/rsp_prod`记录的是最新的info的地址,
分别由front和back来更新。
而`struct front/back_ring` 中则记录了`req/rsp_prod_pvt`和`rsp/req_cons`,
每次push新的req/rsp时，都先更新pvt(pivot)变量，调用宏后宏会更新`req/rsp_prod`。
在consume时就更新自己本地的`rsp/req_cons`变量；在更新完后进行check，
`FINAL_CHECK`宏会检查有没有pending的req/rsp并更新`sring`中的`rsp/req_event`。
因此只要判断`(pvt - event) < (pvt - prod)`就能知道是不是应该通知远端ring中还存在未处理的内容。

# Demo: Ring Buffer

Ring本身就是依靠Grant Table进行共享的(共享一个ring buffer), 而本身通过ring我们可以异步的传数据。在I/O传输中ring中传的就是grant refernece. front将一个个gref放入ring作为request, back就不断地处理这些request并返回response。以此来完成大量数据的传递。因此我们这次对之前的内存共享进行修改，在Grant Table基础上建立ring并用ring来进行通信。

目前的demo没有调用`FINAL_CHECK`。

#### DomU

首先定义类型: 

```c alice_domU.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_9/domU/alice_domU.c source
/* Ring request & respond, used by DEFINE_RING_TYPES macro */
struct as_request {
    int hello;
};

struct as_response {
    int hi;
};

/* this macro will create as_sring, as_back_ring, as_front_ring */
DEFINE_RING_TYPES(as, struct as_request, struct as_response);

typedef struct front_end_t {
    struct as_front_ring ring;  /* Record real ring */
    grant_ref_t gref;           /* gref of shared page */
} front_end_t;

front_end_t front_end;
```

按照说明初始化, 并发送一个request给dom0

```c alice_domU.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_9/domU/alice_domU.c source
/* Step 2: Put shared ring on this page to be shared */
sring = (struct as_sring *)vpage;
SHARED_RING_INIT(sring);

/* Step 3: Front init */
FRONT_RING_INIT(&(front_end.ring), sring, PAGE_SIZE);

/* Write a request and update the req-prod pointer */
ring_req = RING_GET_REQUEST(&(front_end.ring), front_end.ring.req_prod_pvt);
ring_req->hello = hello;
front_end.ring.req_prod_pvt += 1;

RING_PUSH_REQUESTS_AND_CHECK_NOTIFY(&(front_end.ring), notify);
```

#### dom0

后端的代码和前端类似，取出一个request并填回一个response。注意，这里我没有使用`FINAL_CHECK`，正常使用中是要加上的。

```c alice_dom0.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_9/dom0/alice_dom0.c source
rc = back_end.ring.req_cons;
rp = back_end.ring.sring->req_prod;

/* Copy this info local */
memcpy(&req, RING_GET_REQUEST(&back_end.ring, rc), sizeof(req));
pr_info("Alice: Receive hello=%d\n", req.hello);

/* Fill response hi = hello + 1 */
rsp.hi = req.hello + 1;

/* update req-consumer */
back_end.ring.req_cons = ++rc;
barrier();
memcpy(RING_GET_RESPONSE(&back_end.ring, back_end.ring.rsp_prod_pvt),
        &rsp, sizeof(rsp));
back_end.ring.rsp_prod_pvt++;

RING_PUSH_RESPONSES_AND_CHECK_NOTIFY(&back_end.ring, notify);
```

处理的时候拷贝到本地再处理。

# Summary

可以发现，其实I/O ring只不过就是一些操作共享内存的数据结构和宏定义，而对于Xen来说它只提供了Grant Table这一内存共享机制，在上面进行什么样的操作Xen并不关心。在I/O driver中就是利用ring来传递真正存放内容的内存页的grant refernece的。如果要做batch的话把`FINAL_CHECK`中event的更新改为+N (N为每次batch的数目), 前端在push request的时候也要按照N个N个来push。

#### 运行示例

运行的时候忘记了，先退出了domU的kernel module。 所以这里刚好也看一下错误退出的错误提示...

```sh
alice@domU: $ sudo insmod alice_domU.ko; dmesg
[  577.380602] Alice: Hello, This is Alice
[  577.380608] Alice: Get free pages from kernel, virt of page: 0xffff880074d26000
[  577.380612] Alice: Grant_Ref is 315, input this as param of alice_dom0.ko

alice@dom0: $ sudo insmod alice_dom0.ko gref=315 domid=1; dmesg
[ 1079.748454] Alice: init_module with gref = 315, domid = 1
[ 1079.748469] Alice: shared_ring = ffffc90010e8e000, handle = 264, status = 0
[ 1079.748472] req_comsumer: 0, req_producer: 1
[ 1079.748474] Alice: Receive hello=233
[ 1079.748477] Alice: Need to send notify to dom1

# 0x13b is 315 in decimal
alice@domU: $ sudo rmmod alice_domU; dmesg
[  742.819814] Alice: Get response, hi = 234
[  742.819818] Alice: Cleanup grant ref...
[  742.819821] Alice: Someone is mapping this ref now
[  742.819824] xen:grant_table: WARNING: g.e. 0x13b still in use!
[  742.819828] deferring g.e. 0x13b (pfn 0x74d26)
[  742.819830] Alice: Exit Successfully

alice@dom0: $ sudo rmmod alice_dom0; dmesg
[ 1173.124539] Alice: cleanup_module
[ 1173.124559] Alice: unmap shared page successfully
```

[1]:http://dl.acm.org/citation.cfm?id=808061
[8]: http://silentming.net/blog/2016/12/26/xen-log-8-grant-table/
[9]: http://silentming.net/blog/2016/12/28/xen-log-9-io-ring/
[10]: http://silentming.net/blog/2017/02/20/xen-log-10-event-channel/
[12]: http://silentming.net/blog/2017/03/01/xen-log-12-using-event-channel/
[13]: http://silentming.net/blog/2017/03/02/xen-log-13-xenstore/
[14]: http://silentming.net/blog/2017/03/20/xen-log-14-pv-driver/
[15]: http://silentming.net/blog/2017/03/21/xen-log-15-xenbus/

