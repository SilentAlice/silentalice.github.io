---
layout: post
title: "Alice OS 1-First Commit"
comments: true
date: 2020-01-28 17:56:43
tags: os-dev
keywords: arm, os, 操作系统, linux, alice os
---

本篇我们主要来看一下第一个Commit里面的`Makefile`, `alice.ld`
以及最开始代码`startup.S`.

这里会介绍一下查看反汇编的方法以及写ARM汇编的小技巧。

[Alice-OS: First Commit][0]

<!-- more -->

## Makefile & Monitor

我这里使用了Makefile来进行构建，关于Makefile的教程有很多,
由于我也不准备构建多复杂的系统，所以Makefile写的会比较简单。
这里给两个链接以供参考:

- [A Simple Makefile Tutorial][1]
- [Unix Makefile Tutorial][2]

里面的规则等等都比较简单，这里主要说一下启动Qemu的一些区别:

```make
qemu: $(OS).bin
qemu-system-arm $(QEMU_FLAGS) -kernel $(OS).bin

qemu-gdb: $(OS).bin
qemu-system-arm $(QEMU_FLAGS) -gdb tcp::1234 -S -kernel $(OS).bin

qemu-telnet: $(OS).bin
qemu-system-arm $(QEMU_FLAGS) \
    -monitor telnet:127.0.0.1:1234,server,nowait -kernel $(OS).bin
```

`make qemu` 会直接编译并运行，`make qemu-gdb`和`make qemu-telnet`则分别让
qemu将1234端口开放给gdb与telnet;

[QEMU Monitor][3]可以让我们在系统挂住的时候查看一些寄存器的状态
`nowait`的作用是为了让QEMU在monitor连上之前自己也会往下跑，
因为我们主要是为了查看最后系统hung住时的寄存器状态.

GDB的使用我们以后再说~

## Link Script

链接脚本的语法讲解网上也非常多，这里提供一个链接供参考:[Linker Script][4].

这里主要看一下我们的地址:

```
ENTRY(entry)
start_address = 0x0;

SECTIONS
{
    . = 0x80000000 + start_address;

    .text : AT(start_address) { *(.text) }
    PROVIDE(etext = .);

    ...

    .stack : {
        *(.stack);
    }
    kernel_stack_start = .;

    PROVIDE(kernel_end = .);
}
```

我后面打算让Kernel从 `0x80000000`开始映射，所以把kernel最开始的代码放到了
`0x80000000`地址上，
这里引入一个`start_address`的原因是因为不同的平台会默认让系统从不同的地址启动.
为了让后面映射地址时方便计算而引入的。

也就是说，当我们的**虚拟地址映射建立好**之后,
内核的第一行代码应该是从`0x80000000 + start_address`开始的。

## Bin & Elf

接下来就是我们的第一行代码了，ARM平台上当内核镜像被放到内存中之后，
CPU会从加载的第一条指令直接开始执行。
这也就要求我们编译完内核镜像后去掉开头的elf header;

我们用gcc编译完的镜像本身是elf格式的，这个格式有一个header:

    xxd alice.bin > alice.bin.dump
    xxd alice.elf > alice.elf.dump

```
/* alice.bin.dump */
  00000000: 3302 00e3 efbe adde 0000                 3.........

/* alice.dump.asm */
80000000 <entry>:
80000000:       e3000233        movw    r0, #563        ; 0x233
80000004:       deadbeef        cdple   14, 10, cr11, cr13, cr15, {7}
```

用`xxd`查看16进制，会发现alice.bin的内容也就是我们内核实际的内容非常简单,
开头的 `3302` 就是我们的 `0x233`的小端写法，与我们的反汇编一致，开头就是指令;

那么alice.elf.dump呢？

    ...
    4096 0000fff0: 0000 0000 0000 0000 0000 0000 0000 0000  ................
    4097 00010000: 3302 00e3 efbe adde 0000 4126 0000 0061  3.........A&...a
    4098 00010010: 6561 6269 0001 1c00 0000 0543 6f72 7465  eabi.......Corte
    4099 00010020: 782d 4139 0006 0a07 4108 0109 022a 0144  x-A9....A....*.D
    ...

发现我们的代码`3302 00e3`是从第二个页(4097)开始的, 第一个页是elf自己加的东西;
在后面也还有一些跟体系结构相关的东西(Cortex-A9). 所以elf文件本身有自己的格式,
但是ARM设备是从第一条指令直接执行的, 所以我们要用objcopy把我们要的东西从
elf文件里面copy出来!

再次看makefile:

```make
...
$(OS).bin: $(OBJS) $(OS).ld
    $(LD) -T $(OS).ld $(OBJS) -o $(OS).elf
    $(OBJCOPY) -O binary $(OS).elf $(OS).bin
    $(OBJDUMP) -D $(OS).elf > $(OS).dump.asm
...
```

可以看到, 我们的alice.bin实际上就是
`arm-none-eabi-objcopy -O binary alice.elf alice.bin`生成的.
但是我们的objdump又需要用到elf格式，这样它才认识里面的debug symbol,
才能生成方便我们调试的反汇编。

## First Instruction

现在终于可以来看看我们的第一条指令了:

```asm
.global entry
entry:
    mov r0, #0x233
    .word 0xdeadbeef
```

内容非常简单，就是把0x233放到r0里面，
这里`.word 0xdeadbeef`就是在代码段里面插入一个错误的指令，
当CPU执行完`mov r0, #0x233`后就会尝试解析`0xdeadbeef`,
由于解析失败，所以就会卡在这里。

## Register Info

使用 `make qemu-telnet` 并且在另一个shell连上, 我们来看一下寄存器信息:

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
PSR=400001db -Z-- A S und32
```

`R0`和我们想的一样，内容就是233, 启动寄存器这里也一并介绍一下:

|Reg|Alias|Purpose|
|:---|:---|:---|
|R0 - R3|-|Caller Saved General Purpose|
|R4 - R8|-|Callee Saved General Purpose|
|R9|-|Might Callee Saved General Purpose|
|R10|-|Callee Saved General Purpose |
|R11|FP|Frame Pointer / Callee Saved General Purpose|
|R12|IP|Intra Procedural Call (Used by Dynamic Link)|
|R13|SP|Stack Pointer|
|R14|LR|Link Register (Save Return Address)|
|R15|PC|Program Counter|
|PSR|-|Program Status Register|

Caller / Callee 相关的可以看一下aapcs calling convention.
主要是说函数调用时, r0-r3我们可以随便用;
R13是我们的栈, R14存的返回地址, R15是是PC.

但是我们发现，本应该存返回地址的R14里面存的是什么呢:`0x60010008`
也就是说，现在CPU认为我们之前是从60010008跑到了异常的地方.
(我们执行了0xdeadbeef, CPU会产生异常，PC会变,
由于现在还没设置异常向量表，所以跳到了一个奇怪的地址: `0xeb25134`.
同时LR保存之前PC的地址: `0x60010008`).

这也就是说我们的系统一开始是从 `0x60010000` 开始运行的?!

下一次我们来验证一下我们的猜想!

[0]: https://github.com/SilentAlice/alice-os/tree/9d021c0ca4d7a520aa3017108d5906d1661e9bb4
[1]: http://www.cs.colby.edu/maxwell/courses/tutorials/maketutor/
[2]: https://www.tutorialspoint.com/makefile/index.htm
[3]: http://people.redhat.com/pbonzini/qemu-test-doc/_build/html/topics/pcsys_005fmonitor.html
[4]: https://wiki.osdev.org/Linker_Scripts
