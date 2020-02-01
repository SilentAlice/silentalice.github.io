---
layout: post
title: "Alice OS 5-System Regs"
comments: true
date: 2020-01-30 17:11:06
tags: os-dev
keywords: arm, os, 操作系统, linux, alice os
---

为了配置内存，首先我们要先熟悉一下ARM的系统控制寄存器。
除了CPU提供的功能外，ARM提供了16个协处理器(Coprocessor)接口,
芯片厂商可以自己外接协处理器来完成更为复杂的功能。

如果想要使用地址映射，那就需要借助MMU(Memory Management Unit)单元对地址进行翻译。
而包含MMU功能在内的诸多系统控制都是要通过Control Coprocessor接口CP15来完成，
这也是ARM预留的几个4个协处理接口之一。

本篇我们主要来看一下ARM访问这些控制寄存器的方式，
并简单看一下我们随后要用到的几个控制寄存器。

[Alice-OS: System Register][0]

<!-- more -->

## Control Register CP15

根据ARM的手册([ARM1176JZ-S TRM][1])描述:

> The processor supports the connection of on-chip coprocessors through
> an external coprocessor interface. All types of coprocessor instruction are supported.

> The ARM instruction set supports the connection of 16 coprocessors,
> numbered 0-15, to an ARM processor.
> In the processor, the following coprocessor numbers are reserved:
>
> - CP10 VFP control
> - CP11 VFP control
> - CP14 Debug and ETM control
> - CP15 System control.
>
> You can use CP0-9, CP12, and CP13 for your own external coprocessors.

ARM使用了CP15的接口来实现系统控制的寄存器，
访问这些寄存器需要使用特殊的指令:`mrc`和`mcr`, 分别对应读和写,
访问一个cp15的寄存器格式类似于:

    mrc p15, op1, Rd, CRn, CRm, op2

关于op1, op2, CRn, CRm我们在查相关寄存器的时候看手册就行,
Rd是我们使用的通用寄存器。

利用GCC内联汇编的语法，参考一下Linux我们可以写出类似的读写:

```c sysreg.h https://github.com/SilentAlice/alice-os/blob/c8060eb6b3dfb9d6ca10a7f32a20a1df08422fd6/arch/arm/include/arch/sysreg.h

#define sysreg_read32(name, var) do {               \
    uint32_t __val;                                 \
    asm volatile("mrc p15, " name : "=r" (__val));  \
    var = __val;                                    \
} while (0)

#define sysreg_write32(name, val) do {              \
    uint32_t __val = val;                           \
    asm volatile("mcr p15, " name :: "r" (__val) : "cc"); \
    isb();                                          \
} while (0)
```

其中name就是系统寄存器的名称，比如我们之后要看的System Control Register (SCTLR)
编码就是: `#define SCTLR "0, %0, c1, c0, 0"`;
目的就是将系统寄存器的值读到var中，或将val中的值写到系统寄存器里。

## SCTLR & TTBR

系统中非常重要的控制寄存器就是SCTLR (在ARMv5中叫Ctrl Register c1),
它负责控制系统的各种重要功能: 中断、FIQ、Cache、Alignment Check、MMU使能等等,
如果我们想要使能MMU的话，就需要将SCTLR的M (bit[0])置为1。

TTBR (Translation Table Base Register)顾名思义，
就是存放页表基址的寄存器，
里面存放有页表的**物理地址**,
当我们打开MMU之后，
每一次访存操作MMU都会把输入地址作为虚拟地址，
从这个寄存器中找到Translation Table,
把地址翻译成物理地址后真正的去访存。

我们可以看一下启动之后这两个寄存器的内容:

```c kernel/init.c https://github.com/SilentAlice/alice-os/blob/c8060eb6b3dfb9d6ca10a7f32a20a1df08422fd6/kernel/init.c
void init(pa_t kernel_load_address)
{
    uint32_t val;

    arch_init();

    sysreg_read32(SCTLR, val);
    asm volatile("mov r5, %0" : "=r" (val));
    sysreg_read32(TTBR0, val);
    asm volatile("mov r6, %0" : "=r" (val));

    asm volatile(".word 0xdeadbeef");
}
```

TTBR0带个0的原因是ARMv7有两个TTBR, ARMv5只有一个,
但是两者的编码是一致的，所以用TTBR0统一起来。
置于为什么有两个TTBR,
等我们以后用到了再说~

小伙伴们可以checkout到我开头给的这个commit, 自己验证一下~
SCTLR的值放到了r5里面， TTBR0放到了r6里面。

```
# vexpress-a9 (armv7)
make PLAT=vexpress-a9 qemu-telnet
telnet localhost 1234

(qemu) info registers
R00=60010000 R01=60013000 R02=60000100 R03=00000000
R04=00000000 R05=00c50078 R06=00000000 R07=00000000
R08=00000000 R09=00000000 R10=00000000 R11=60012ffc
R12=00000000 R13=00000000 R14=60010080 R15=01698c00
```

```
# versatilepb (armv5)
make PLAT=versatilepb qemu-telnet
telnet localhost 1234

(qemu) info registers
R00=00010000 R01=00013000 R02=00000100 R03=00000000
R04=00000000 R05=00090078 R06=00000000 R07=00000000
R08=00000000 R09=00000000 R10=00000000 R11=00012ffc
R12=00000000 R13=00012fe0 R14=0001004c R15=0001007c
```

然后分别对照手册armv7 TRM与arm926ejs\_trm查一下两个之间有什么区别。

vexpress-a9上sctlr是 `0x00C50078`, versatilepb上是 `0x00090078`,
ttbr则都是0。

那么接下来我们就要认真研究一下TTBR的格式，来构建我们的页表啦。

## Note

aarch64上系统寄存器已经不是用cp15访问了，以后我们开始支持aarch64的时候再说~


[0]: https://github.com/SilentAlice/alice-os/tree/c8060eb6b3dfb9d6ca10a7f32a20a1df08422fd6
[1]: http://infocenter.arm.com/help/index.jsp?topic=/com.arm.doc.ddi0333h/Bgbhbiah.html
