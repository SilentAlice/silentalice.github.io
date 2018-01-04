---
layout: post
title: "Xen Log 6-Xentrace"
date: 2016-09-21 13:16:03 +0800
comments: true
tags: virtualization
keywords: Xen, xentrace
description: "Use Xentrace"
---
Xentrace 能够帮助你知道在Hypervisor中发生了什么，作为一个统计工具，可以记录所有的VMEnter/Exit、Schedule、Dom0ops等信息，并能够指定统计哪个cpu、记录哪些事件的信息。在进行一些验证、测试或Resource counting的时候有比较大的作用。
<!--more-->

Debug 系列:

* [Add New Hypercall to Xen][3]
* [Debug Xen on Physical Machine][5]
* **Xentrace(本篇)**
* [Debug Key][16]

使用Xentrace非常简单，在安装Xen tools的时候就已经安装好了xentrace, 直接调用即可:

```sh
xentrace -D -e all -T 10 trace.raw
```

-D 删掉之前的buffer, -e 是设置trace的事件类型:
```c $XENDIR/xen/include/public/trace.h 
        ID                 Description

        0x0001f001         TRC_LOST_RECORDS
        0x0002f001         TRC_SCHED_DOM_ADD
        0x0002f002         TRC_SCHED_DOM_REM
        0x0002f003         TRC_SCHED_SLEEP
        0x0002f004         TRC_SCHED_WAKE
        0x0002f005         TRC_SCHED_YIELD
        0x0002f006         TRC_SCHED_BLOCK
        0x0002f007         TRC_SCHED_SHUTDOWN
        0x0002f008         TRC_SCHED_CTL
        0x0002f009         TRC_SCHED_ADJDOM
        ……
```

-T 是设置trace的时间

生成的内容是二进制，我们没有办法直接读取，这时就要借助xenformat: `$XENDIR/tools/xentrace/xentrace_format`

```sh $XENDIR/tools/xentrace/
cat trace.raw | xentrace_format ~/$XENDIR/tools/xentrace/formats > trace.txt
```
在xentrace/formats 可以看到所有的事件类型和对应的输出格式，根据需要我们可以自行修改。

在Xen中，如果我们想要自己记录一些信息，除了在需要的地方加printk，还可以借助trace:

```c $XENDIR/xen/include/xen/trace.h
#define TRACE_0D(_e)                            \
    do {                                        \
        trace_var(_e, 1, 0, NULL);              \
    } while ( 0 )
  
#define TRACE_1D(_e,d1)                                         \
    do {                                                        \
        if ( unlikely(tb_init_done) )                           \
        {                                                       \
            u32 _d[1];                                          \
            _d[0] = d1;                                         \
            __trace_var(_e, 1, sizeof(_d), _d);                 \
        }                                                       \
    } while ( 0 )
```

文件中的0D-5D就是记录的数据的多少，如果我们要记录3个数据，就选用3D即可。

如果想要增加自定义的事件类型，在`$XENDIR/xen/include/public/trace.h`中添加自己的事件类型:
```c $XENDIR/xen/include/public/trace.h
#define TRC_HVM_TRAP_DEBUG       (TRC_HVM_HANDLER + 0x24)
#define TRC_HVM_VLAPIC           (TRC_HVM_HANDLER + 0x25)
/* Add customized event */
#define TRC_HVM_ALICE           (TRC_HVM_HANDLER + 0x26)

/* Record our own event somewhere */
TRACE_0D(TRC_HVM_ALICE);
```

之后再trace.raw中就会出现我们自己定义的Trace.

## Example

我们想捕捉所有关于HVM的信息:

```sh
# 0x8f000 is TRC_HVM, check in trace.h
sudo xentrace -D -e 0x8f000 -T 10 trace.raw
```

经过10s后:

```sh
cat trace.raw | xentrace_format $XENDIR/tools/xentrace/formats > trace.log
```

Log 中的结果如下:

```
CPU2  1712035142503524 (+   22501)  VMEXIT      [ exitcode = 0x00000010, rIP  = 0xffffffff8102d73f ]
CPU2  0 (+       0)  CR_READ     [ CR# = 0, value = 0x000000008005003b ]
CPU2  0 (+       0)  CR_WRITE    [ CR# = 0, value = 0x0000000080050033 ]
CPU2  1712035142544733 (+   41209)  vlapic_accept_pic_intr [ i8259_target = 1, accept_pic_int = 0 ]
CPU2  1712035142546137 (+    1404)  VMENTRY
CPU2  1712035142872709 (+  326572)  VMEXIT      [ exitcode = 0x00000000, rIP  = 0xffffffff810644f4 ]
CPU2  0 (+       0)  CR_READ     [ CR# = 0, value = 0x0000000080050033 ]
CPU2  1712035142878262 (+    5553)  vlapic_accept_pic_intr [ i8259_target = 1, accept_pic_int = 0 ]
```

可以看到Trace记录了期间发生的所有关于HVM的相关事件，VMExit的原因等等，通过修改formats，我们可以使得输出符合我们自己的要求(比如去掉里面的+， 增加空格等)以方便后续进行处理。

## Note

使用Trace的一大好处是我们可以记录一些频繁发生的事件，使用`printk`时会导致console有大量输出而无法响应，trace就可以很好解决我们的这一问题，同时trace可以用来统计一段时间内某个事件发生的频率等等。在debug或者测试的时候非常好用。

## Change Log

* 2017-05-11: Add Debug series

[3]: http://silentming.net/blog/2015/12/13/xen-log-3-add-hypercall/
[5]: http://silentming.net/blog/2016/09/18/xen-log-5-debug-xen/
[6]: http://silentming.net/blog/2016/09/21/xen-log-6-xentrace/
[16]: http://silentming.net/blog/2017/05/11/xen-log-16-debug-key/
