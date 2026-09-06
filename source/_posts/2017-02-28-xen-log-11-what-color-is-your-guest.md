---
layout: post
title: "Xen Log 11-What Color Is Your Guest"
date: 2017-02-28 20:14:08 +0800
comments: true
tags: virtualization
keywords: xen, pvhvm, pvh, hvm, pv
---

PV, HVM, PV-on-HVM, PVHVM, PVH... Xen在刚提出的时候针对的是二进制模拟下的虚拟化低效问题, 
而随着Intel与AMD不断推出支持虚拟化的硬件后，使用PV已经不再是一个最恰当的选择。而如今，Xen
已经有了眼花缭乱的各种模式，本文将介绍他们之间的区别。

<!-- more -->

本文参考了[Brendan Gregg's Blog Xen Modes: What Color Is Your Xen][1]

# The Virtualization Spectrum

{% img https://farm1.staticflickr.com/700/33126526786_d069884d58_z_d.jpg spectrum %}

# Full Virtualization

虚拟化最开始的提出是因为硬件资源的不均衡，大企业拥有大量硬件但是没有那么大的需求，而小企业架一个网页就需要购买昂贵的服务器。因此，虚拟化的目的在于如何让硬件资源被多个客户使用，而客户在虚拟化场景下应该和跑在正常硬件上一样。

于是大家想用软件模拟各种硬件，从OS的启动到各种外设，所使用的“二进制重写”就是理解二进制码的语义，再用
软件进行模拟执行。这种模式就是Full Virtualization.

由于每次执行都要经过一轮软件的模拟，因此这种效率非常低，难以被接受。

# Para Virtualization

Xen为了解决低效这一问题，提出让OS知道自己运行在虚拟化场景下，这样就意味着可以对OS进行代码的少量修改，
具体的可以参考[Xen and the Art of Virtualization(SOSP 2003)][3]. 

简单来说，vcpu直接运行在CPU上，所有的特权指令(syscall等)全部改为调用hypercall, hypercall是另一个中断
作用于syscall类似，此时控制流会从ring3降到ring0, 经由hypervisor处理后再返回。

由于Guest要使用自己的页表(即自己的cr3)将gva(Guest Virtual Address)翻译为gpa(Guest Physical Address),
Hypervisor也要使用扩展/嵌套页表(Extended/Nested Page Table)将gpa翻译为map/hpa(Machine/Host Physical Address). 在只有一个CR3的情况下，
就需要引入影子页表(Shadow Page Table), shadow PT 会遍历Guest PT和EPT/NPT，并将gva直接翻译为mpa保存在Shadow PT中，CR3里面放到就是Shadow PT.

I/O DomU与Dom0直接通过split driver, domU中运行frontend, dom0中运行backend, 通过内存共享来实现数据共享。

Kernel 和 initrd在使用存放在dom0中的disk直接进行加载。

### PV or FV ?

在Guest启动后通过查看`lscpu`即可非常简单的了解自己是在PV还是FV下: FV↓

<pre>
alice@pvhvm:~$ lscpu
...
Stepping:              1
CPU MHz:               4092.612
BogoMIPS:              8193.82
<span style="font-weight:bold">Hypervisor vendor:     Xen
Virtualization type:   full</span>
L1d cache:             16K
L1i cache:             64K
L2 cache:              2048K
NUMA node0 CPU(s):     0,1
</pre>

PV Guest↓

<pre>
% lscpu
...
CPU MHz:               4092.612
BogoMIPS:              8185.22
<span style="font-weight:bold">Hypervisor vendor:     Xen
Virtualization type:   none</span>
L1d cache:             16K
L1i cache:             64K
L2 cache:              2048K
NUMA node0 CPU(s):     0-3
</pre>

PV的Virtualization Type是None.  或者查看 dmesg : `dmesg | grep -i xen`

<pre>
alice@pvhvm:~$ dmesg | grep -i xen
<span style="font-weight:bold">[    0.000000] DMI: Xen HVM domU, BIOS 4.5.1 12/22/2016</span>
[    0.000000] Hypervisor detected: Xen
[    0.000000] Xen version 4.5.
</pre>

<pre>
alice@pv:~$ dmesg | grep -i xen
[    0.000000] bootconsole [xenboot0] enabled
<span style="font-weight:bold">[    0.000000] Booting paravirtualized kernel on Xen</span>
[    0.000000] Xen version: 4.5.1 (preserve-AD)
[    0.000000] xen:events: Using FIFO-based ABI
</pre>

# Hardware Virtualization Support

随着软硬件技术的发展，安全问题变得日益重要，这时业界发现虚拟化是一个完美的沙箱，可以极大提高安全性。
因此在安全日益重要的如今，虚拟化再次得到了极大发展。Intel和AMD也针对传统虚拟化中的各种问题提供了硬件的虚拟化支持VT-x 与 SMV

硬件的虚拟化支持主要针对的是CPU和Memory, CPU拥有了VMRUN / VMENTER指令，Non-root与root模式，这就避免了以往特权指令在ring0与ring3行为不一致，部分特权指令在ring3不下陷使得下层Hypervisor无法捕获的问题。

Memory则提出了EPT / NPT, 使得Guest和Hypervisor可以分别使用一个寄存器来完整两轮的翻译，Shadow Page Table也不再被使用，因此硬件虚拟化后的CPU与Memory变成了主流。

I/O则需要由各个厂家来实现(Single Root I/O Virtualization), 使一个外设能够同时被多个Guest占用。

由于硬件对虚拟化的支持，HVM的性能已经不再是其缺点，I/O由于支持不如CPU, Memory普遍，因此目前的虚拟机都采用了混合(Hybrid)的模式.

# PV Drivers

模拟的Driver需要通过软件来模拟所有中断过程，但是PV Drivers则通过[Grant table][4] 和 [event channel][5], 借助
共享内存将数据交给dom0, 而dom0负责直接在物理设备上进行读写。

从dmesg中可以看出是否使用的是PV Driver. 在HVM上使用PV Drivers的话需要在配置文件加上

```
xen_pci_platform = 1
```

<pre>
alice@pvhvm:~$ dmesg | grep -i xen
...
[    0.000000] DMI: Xen HVM domU, BIOS 4.5.1 12/22/2016
[    0.000000] Hypervisor detected: Xen
[    0.000000] Xen version 4.5.
<span style="font-weight:bold">[    0.000000] Xen Platform PCI: I/O protocol version 1
[    0.000000] Netfront and the Xen platform PCI driver have been compiled for this kernel: unplug emulated NICs.
[    0.000000] Blkfront and the Xen platform PCI driver have been compiled for this kernel: unplug emulated disks.</span>
</pre>

PV Driver会unplug 模拟设备。

# PV Timer & Interrupt

Full Virtualization模式下，中断要通过软件模拟的PIC、PIC bus, local APIC, IO APIC等等来实现，软件模拟的开销很大，而PV Interrupt则利用Callback 由Hypervisor直接转给目标Domain.

<pre>
[    0.000000] Booting paravirtualized kernel on Xen HVM
[    0.000000] xen: PV spinlocks enabled
[    0.000000] xen:events: Using FIFO-based ABI
<span style="font-weight:bold">[    0.000000] xen:events: Xen HVM callback vector for event delivery is enabled
[    0.083041] clocksource: xen: mask: 0xffffffffffffffff max_cycles: 0x1cd42e4dffb, max_idle_ns: 881590591483 ns
[    0.083056] Xen: using vcpuop timer interface</span>
[    0.083068] installing Xen timer for CPU 0
[    0.084000] installing Xen timer for CPU 1
[    0.216361] xen: --> pirq=16 -> irq=9 (gsi=9)
</pre>

`vcpuop timer interface`表明使用了PV Timer, `HVM callback vector`表明使用了PV Interrupt

# PVH

在VT-x + EPT, SMV + NPT出现后，PV下的Memory(使用Shadow PT), 反而变成了性能的瓶颈，而VT-x 与 SMV则拥有更好的隔离性与安全性。因此PV在原来的基础上采用这套硬件虚拟化技术后就变成了PVH. 也是目前性能最高的混合模式<sup>[PDF][7]</sup>。

使用PVH的话需要在编译Kernel的时候配置`CONFIG_XEN_PVH=y`. 可以参考[wiki][6].

# Setup Flow

最后附上一张Xen启动的检查流↓ (Copied from Brendan's Blog)

{% img https://farm4.staticflickr.com/3669/33126526446_9c54ce7349_b_d.jpg setupflow %}








[1]: http://www.brendangregg.com/blog/2014-05-07/what-color-is-your-xen.html
[2]: https://blog.xenproject.org/2012/10/23/the-paravirtualization-spectrum-part-1-the-ends-of-the-spectrum/
[3]: http://www.cl.cam.ac.uk/research/srg/netos/papers/2003-xensosp.pdf
[4]: http://silentming.net/blog/2016/12/26/xen-log-8-grant-table/
[5]: http://silentming.net/blog/2017/02/20/xen-log-10-event-channel/
[6]: https://wiki.xen.org/wiki/Linux_PVH
[7]: http://events.linuxfoundation.org/sites/events/files/slides/PVH_Oracle_Slides_LinuxCon_final_v2_0.pdf
