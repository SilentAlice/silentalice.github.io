---
layout: post
title: "Alice OS 0-Preparation"
comments: true
date: 2020-01-27 16:00:12
tags: os-dev
keywords: arm, os, 操作系统, linux, alice os
---

许多学习OS的小伙伴最终也只是停留在买一本翻了一半的《操作系统原理》、
一个下下来没看几眼的Linux源码，和一个甚至都没怎么跑起来过的Qemu。

关于OS最有名的课程就是MIT的[6.828 Operating System Engineering][1]课程，
课程讲解xv6，并附有一个难度颇高的JOS操作系统实验。
即使是一个专业的计算机学生、全程跟着上这门课在做这门Lab的时候也会
遇到遇到非常多的困难和阻力，操作系统本身的高难度门槛、不便的调试环境、
和狭窄的就业方向使得有兴趣的小伙伴也往往绊倒在学习的路上。

本系列博客旨在从0构建一个用于我演示各种Demo的小小小OS: Alice OS;
由于x86硬件的复杂性，为了简化，我会从arm，使用Qemu去构建Alice OS。

希望能对OS的一些概念进行一些解释，辅助小伙伴们的学习，也是对自己
在ARM的近两年开发进行一些点滴总结。若有本人理解不对的地方，欢迎指摘。

<!-- more -->


## Environment

首先安装我们所需的工具链和qemu:

Linux:

    sudo apt install binutils-arm-none-eabi
    sudo apt install gcc-arm-none-eabi
    sudo apt install qemu

MacOS:

    brew tap PX4/homebrew-px4
    brew install gcc-arm-none-eabi
    brew install qemu

安装完后，就可以查看一下有没有:

```
alice@MacAlice : ~/Codes/temp
[0] % arm-none-eabi-gcc --version
arm-none-eabi-gcc (GNU Tools for Arm Embedded Processors 7-2018-q2-update) 7.3.1 20180622 (release) [ARM/embedded-7-branch revision 261907]
Copyright (C) 2017 Free Software Foundation, Inc.
This is free software; see the source for copying conditions.  There is NO
warranty; not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.


alice@MacAlice : ~/Codes/temp
[0] % qemu-system-arm --version
QEMU emulator version 4.2.0
Copyright (c) 2003-2019 Fabrice Bellard and the QEMU Project developers
```

## Manuals

刚开始构建的时候，与其说是OS，不如说更像是一个bare-metal的app, 所以可以参考一下ARM上 Bare-metal的写法:

- [Bare-metal programming for ARM][2]
- https://github.com/umanovskis/baremetal-arm/
- 一个模仿JOS的ARM上的OS: [Arunos][4]

JOS和MIT 6.828课程相关的链接:

- [6.828 Operating System Engineering][1]
- SJTU的ICS课程[Introduction to Computer Systems][3]

后续开发需要用的一些手册:

- [ARM® Architecture Reference Manual ARMv7-A and ARMv7-R edition][5]
- [ARM® Developer Suite Version 1.2][6]
- [CortexTM-A9 MPCore® Technical Reference Manual][7]
- [Versatile Express motherboard Address Map on QEMU][8]

由于我们默认使用的Cortex-A9的核是ARMv7的，所以需要相关手册; QEMU模拟的Vexpress板子的文档直接看qemu的代码就行,
在编写过程中会用到一些ARM汇编，所以备一本汇编手册。

## Start

那么首先我们先搞个工程出来吧:

[Alice-OS: First Commit][9]

这个是最开始的小工程，下一篇我们看一下Makefile和link script, 这次先说一下我们调试的方式:

进到git clone下来的代码仓，切到`9d021c0`这个commit之后执行 make qemu-telnet

```
alice@MacAlice ‹ 9d021c0 › : ~/Codes/alice-os
[0] % make qemu-telnet
arm-none-eabi-gcc -mcpu=cortex-a9 -g   -c -o kernel/startup.o kernel/startup.S
arm-none-eabi-ld -T alice.ld  kernel/startup.o -o alice.elf
arm-none-eabi-objcopy -O binary alice.elf alice.bin
arm-none-eabi-objdump -D alice.elf > alice.dump.asm
qemu-system-arm -M vexpress-a9 -cpu cortex-a9 -m 512M -nographic -monitor telnet:127.0.0.1:1234,server,nowait -kernel alice.bin
```

再开个shell, 通过telnet 连上去，并使用info registers 查看寄存器信息:

```
alice@MacAlice ‹ 9d021c0 › : ~/Codes/alice-os
[0] % telnet localhost 1234
Trying 127.0.0.1...
Connected to localhost.
Escape character is '^]'.
QEMU 4.2.0 monitor - type 'help' for more information
(qemu) info registers
R00=00000233 R01=000008e0 R02=60000100 R03=00000000
R04=00000000 R05=00000000 R06=00000000 R07=00000000
R08=00000000 R09=00000000 R10=00000000 R11=00000000
R12=00000000 R13=00000000 R14=60010008 R15=0eb25134
...
```

可以看到 R0里面是 0x233, 这个是一开始写进去的值，至此我们非常简易的Alice OS启动啦！
开始我推荐的调试方式就是让代码hang住，并通过qemu的monitor进行查看,
等到后面我们会改成用GDB的方式来调。

[1]: https://pdos.csail.mit.edu/6.828
[2]: http://umanovskis.se/files/arm-baremetal-ebook.pdf
[3]: https://ipads.se.sjtu.edu.cn/courses/ics/
[4]: https://github.com/pykello/arunos
[5]: https://static.docs.arm.com/ddi0406/c/DDI0406C_C_arm_architecture_reference_manual.pdf
[6]: http://infocenter.arm.com/help/topic/com.arm.doc.dui0068b/DUI0068.pdf
[7]: http://infocenter.arm.com/help/topic/com.arm.doc.ddi0407g/DDI0407G_cortex_a9_mpcore_r3p0_trm.pdf
[8]: https://github.com/qemu/qemu/blob/master/hw/arm/vexpress.c
[9]: https://github.com/SilentAlice/alice-os/tree/9d021c0ca4d7a520aa3017108d5906d1661e9bb4
