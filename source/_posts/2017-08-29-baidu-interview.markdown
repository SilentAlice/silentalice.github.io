---
layout: post
title: "上海百度校招2018面经"
date: 2017-08-29 15:20:41 +0800
comments: true
tags: essay
keywords: baidu, interview
description: "百度面试经历"
---

找学长内推了上海百度的团队，团队主要负责人工智能的全栈支持，依旧是比较底层的研发部分。从AI芯片、
到平台再到上层对百度各个部门的支持。本篇记录一下面试的经历。

<!-- more -->

# 简历

还是之前准备的简历，由于投的都是研发所以也不怎么需要修改。没什么需要再说明的.

# 一面

一面技术面更多的变成了对于百度内业务的介绍，主要还是在了解团队具体在做什么，这里不方便太过详细的介绍就略过了。
不过一般一面也不难，简单的算法数据结构加上一些操作系统知识都不难应付。

# 二面

二面是团队里另一个人的技术面，算法问的是给一串整数，再给一个数字，求这些整数里面有多少满足条件的数对(a, b)，使a+b等于
给定的这个数字。

非常简单的算法题，排序+一遍遍历就可以，O(nlogn)的时间复杂度, 遍历的时候从两边向中间。

之后主要是操作系统的相关知识，在了解了我所做的项目内容后，考察进程管理、内存管理等。这些之前的也都问到了，所以基本上还是把自己所知道的内容答上来就行。而后又问了些slab和buddy system的相关问题，这些不是很难简单说下就好了。后面又问道一个Red Zone，不过这个我没用过所以就没答上来。

[Red Zone](http://eli.thegreenplace.net/2011/09/06/stack-frame-layout-on-x86-64/) 是 rsp下面128bytes的空间，可以被最后一个被调用的函数所使用，这段空间不会被exception/interrupt等Handler所使用，因此这就意味着最下层的函数可以利用这部分空间进行优化。对于**RedZone的使用不需要改变RSP**，因此可以减少一些开销。但是Redzone仅在rsp-1到rsp-128。所以push、pop以及function会改变red zone的位置。


之后又问Spin lock、Semaphore和RCU之间的区别, 这些具体的自己去搜一下就好。在问到spin-lock的时候，就又问到了`spin_lock_irq`和`spin_lock_irqsave`. 对比可以看[这一篇](https://stackoverflow.com/questions/2559602/spin-lock-irqsave-vs-spin-lock-irq)

> From Robert Love's book "Linux Kernel Development", if interrupts are already disabled on the processor before your code starts locking, when you call `spin_unlock_irq` you will release the lock in an erroneous manner. If you save the flags and release it with the flags, the function `spin_lock_irqsave` will just return the interrupt to its previous state.

如果在关中断情况下使用lock, 之后使用unlock会导致一些问题.

之后围绕中断问了非常多的问题，主要考察中断的实现，硬中断、软中断(Timer中断这种)区别，tastset又是什么(软中断的一种)。 中断的处理过程等等。由于我自己回答的时候比较了和调度的区别，因此就继续问我中断能否被调度，在中断处理过程中如果sleep让调度器进行调度会有什么效果？(中断的栈用了进程原有的栈，如果被调度的话栈会崩). 继续又问如何才能实现能被调度的中断，支持中断里面sleep？这个真是把我问蒙了，不过从实现上进行考虑至少可以说出来一些点，比如满足调度的话必须有自己的上下文，而且需要维护这些上下文，和Process原有的栈分开等等。这些东西还是需要了解调度单位的本质和中断的目的和实现才能答一些，后来也是在面试官的帮助下我也是学习到了不少。

整个面试过程不到40min。


# 总结

研发面试关注的还是对于事物本质的把握，如果是考算法不但要会用，还要知道背后的实现原理，同时还要继续了解背后实现的设计原则。当然，一切都要先以会用为基本要求，所以还是要先刷题补一些常见算法再说。

算法的面试可能是因为我是系统工程方向的，被问到的都不是很难的算法(也有时间的原因)，正常情况下这些是笔试中会考察的。所以，主要还是了解常见算法即可。

如果是工程方向，对于系统的理解要尽可能深，书本上一般上学到的都是一些实现方法，但是具体实现还是需要自己去了解，而Linux这一成熟的操作系统所使用的诸多设计我们还是需要去深深理解的，我就属于见识还是太少... 有时间还是要把Linux Kernel Development 和 Linux Kernel Primer看一下... 
