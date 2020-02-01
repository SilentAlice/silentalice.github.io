---
layout: post
title: "Alice OS 2-Load Address"
comments: true
date: 2020-01-29 01:01:03
tags: os-dev
keywords: arm, os, 操作系统, linux, alice os
---

为了方便不同平台的演示，这次我们添加一个新的平台，
是ARM versatilepb 平台的[arm926ej-s][0]处理器,
这是一款比较老的ARM处理器 CPU是A9系列的ARM926EJ-S, ARMv5TE架构;
我们来看看这个CPU起始的地址，并且考虑如何给我们的Alice OS初始化一个临时的栈~

[Alice-OS: Load Address][1]

<!-- more -->

## Versatilepb & ARM926EJ-S

我们仿照vexpress-a9建一个新的平台，并用类似的方式看看启动之后的LR地址:

```
# Another shell:
alice@MacAlice ‹ 521074d ↑●● › : ~/Codes/alice-os
make PLAT=versatilepb qemu-telnet

alice@MacAlice ‹ 521074d ↑●● › : ~/Codes/alice-os
[0] % telnet localhost 1234
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
QEMU 4.2.0 monitor - type 'help' for more information
(qemu) info registers
R00=000000a3 R01=00000183 R02=00000100 R03=00000000
R04=00000000 R05=00000000 R06=00000000 R07=00000000
R08=00000000 R09=00000000 R10=00000000 R11=00000000
R12=00000000 R13=00000000 R14=00010008 R15=00010004
```

可以发现，这次的LR (R14)是0x10008了, 说明启动是从0x10000开始执行的,

所以我们现在知道, vexpress-a9是从0x60010000开始执行,
而versatilepb是从0x00010000开始执行的

接下来让我们给他们都给一个初始的栈吧

## Init Stack

我们在汇编里面声明一段空间，并把它当做我们的内核栈:

```
.global entry
entry:
    mov r0, pc
    # R5 save PC
    mov r5, r0

    # make r0 4k aligned
    mov r0, pc
    bic r0, r0, #0xFF0
    bic r0, r0, #0xF

    # This is the .L_stack_start
    add r0, #0x2000
    mov sp, r0
    ldr r1, =.L_stack_start
    ldr r2, =#kernel_stack_start
    mov r3, sp
    push {r0}
    mov r4, sp
    .word 0xdeadbeef

    .align
    .section ".stack", "aw"
.L_stack: .space 4096
.L_stack_start:
```

我们在代码段的最下面声明一个4K大小的空间，并将它连接到".stack"段里面:

```
    .bss : { *(.bss COMMON) }
    . = ALIGN(4096);

    .stack : {
            *(.stack);
    }
    kernel_stack_start = .;
```

我们可以看一下，r0到r5里面的值都是多少:

- r0是我们计算出来并赋值给sp的栈;
- r1是直接加载`.L_stack_start`这个tag得到的地址;
- r2是从linker script中取得的`kernel_stack_start`这个symbol地址;
- r3是赋值之后的sp;
- r4是push一次之后的sp;
- r5是程序一开始的PC;

```
alice@MacAlice ‹ 521074d ●● › : ~/Codes/alice-os
[0] % telnet localhost 1234
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
QEMU 4.2.0 monitor - type 'help' for more information
(qemu) info registers
R00=60012000 R01=80002000 R02=80002000 R03=60012000
R04=60011ffc R05=60010008 R06=00000000 R07=00000000
R08=00000000 R09=00000000 R10=00000000 R11=00000000
R12=00000000 R13=00000000 R14=60010034 R15=016a8000
PSR=400001db -Z-- A S und32

(qemu) x /x 0x60011ffc
60011ffc: 0x60012000
```

我们计算栈的方式是这样:
假设启动这部分代码最长不超过4K大小, 那我空4K出来将当前PC后12位清零，
加上两个4K页就是我的栈底。

但是我们直接Load Symbol会发现, 无论是tag还是从linker script取出来的
地址都是0x80002000。这是由于我们linker一开始给的其实地址是80002000,
导致我们的栈变成了这样。

但是至少我们了解了，代码开始往后2个页就是栈底，所以我们使用
0x60012000作为栈底是没有问题的!

通过 x 命令我们也看到了，push一次之后，栈里确实存了我们要的数据。

那么接下来，我们就考虑如何更优雅并且正确的设置栈，尽快从汇编跳到C代码吧!



[0]: http://infocenter.arm.com/help/topic/com.arm.doc.ddi0198e/DDI0198E_arm926ejs_r0p5_trm.pdf
[1]: https://github.com/SilentAlice/alice-os/tree/521074dd49a8b329d7c87d6540d3fc445618274a
