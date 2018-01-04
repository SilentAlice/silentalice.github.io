---
layout: post
title: "Xen Log 16-Debug Key"
date: 2017-05-11 10:40:42 +0800
comments: true
tags: virtualization
keywords: Xen, debug key
---

之前介绍过Xentrace可以用来记录Hypervisor中发生的事情，不过有时我们希望手动触发print log的行为(比如观看此时Xen的页表结构、内存状态或者打印当前的cpu栈等等). 亦或是按下某个按键之后的Hypercall就会输出Log，再按一次后就停止输出Log等等。此时Xentrace或者手动添加Hypercall就不能满足我们的需求，而Xen提供了一套方便的接口可以解决这个问题: Debug Key
<!--more-->

Debug 系列:

* [Add New Hypercall to Xen][3]
* [Debug Xen on Physical Machine][5]
* [Xentrace][6]
* **Debug Key(本篇)**

# Register a key handler

Debug Key的使用同样非常简单，Xen的源码里面已经实现了一个用例:

```c $XENDIR/xen/common/page_alloc.c http://code.metager.de/source/xref/xen/xen/common/page_alloc.c
/* Code is in source is stale, you can refer it in latest xen source code */


#include <xen/keyhandler.h>


static void pagealloc_info(unsigned char key) {...}

static struct keyhandler pagealloc_info_keyhandler = {
    .diagnostic = 1,
    .u.fn = pagealloc_info,
    .desc = "memory info"
};

static __init int pagealloc_keyhandler_init(void)
{
    register_keyhandler('m', &pagealloc_info_keyhandler);
    return 0;
}

```

代码中首先注册了一个key handler, 并通过`register_keyhandler`注册到按键`m`上, 之后定义
`struct keyhandler`变量并在其中指定handler函数`pagealloc_info`。而自己需要实现的功能
就在`pagealloc_info`中。

我们自己使用的时候可以再任何Xen的源文件中include `xen/keyhandler.h`而后按样例实现自己的函数即可，比如设置某个全局变量的值来控制log的打印和关闭等等。

# Using debug key

使用同样也很简单, 在dom0中输入:

```sh
sudo xl debug-key m
sudo xl dmesg

(XEN) Physical memory information:
(XEN)     Xen heap: 0kB free
(XEN)     heap[13]: 252kB free
(XEN)     heap[15]: 61184kB free
(XEN)     heap[16]: 3960kB free
(XEN)     heap[17]: 92328kB free
(XEN)     heap[18]: 123284kB free
(XEN)     heap[19]: 1031944kB free
(XEN)     heap[20]: 1492392kB free
(XEN)     heap[21]: 1501064kB free
(XEN)     heap[22]: 169628kB free
(XEN)     Dom heap: 4476036kB free
```

debug-key需要`xen tools`的支持，因此安装了tool的dom0是调用debug-key最简单的地方。上面的log就是默认的`pagealloc_info`的信息输出。

## Note

如果根据[Xen Log-5][5]中配置配好了后，log同样是可以通过串口打印出来的，这又提供了一种方便的调试手段:)

[3]: http://silentming.net/blog/2015/12/13/xen-log-3-add-hypercall/
[5]: http://silentming.net/blog/2016/09/18/xen-log-5-debug-xen/
[6]: http://silentming.net/blog/2016/09/21/xen-log-6-xentrace/
[16]: http://silentming.net/blog/2017/05/11/xen-log-16-debug-key/
