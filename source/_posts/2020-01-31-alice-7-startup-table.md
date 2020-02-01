---
layout: post
title: "Alice OS 7-Startup Table"
comments: true
date: 2020-01-31 13:12:23
tags: os-dev
keywords: arm, os, linux, alice os, pagetable, mmu
---

上一篇都是理论，都是虚的，
学过操作系统的小伙伴这些东西也都听了好多遍了，
我们这次就来实际配一下页表，
看看需要注意哪些事项~

[Alice-OS: Startup Table][0]

<!-- more -->

## Address Map Layout

我们的目的是把`KERNEL_START_VADDR(0x80000000)`让它能映射为
`KERNEL_LOAD_PADDR(0x60010000 or 0x00010000)`,
所以首先我们要把0x80000000对应的STE entry填成load\_paddr的base address;

```c startup_table.c https://github.com/SilentAlice/alice-os/blob/26c3882632f12a377b78f64f58f16aafc6e86bc1/arch/arm/startup_table.c
#define STE_RSRV_BITS       (0x2)
#define STE_AP_SHIFT		10
#define STE_BASE_SHIFT		20

#define STE_KERNEL_DEF      (STE_RSRV_BITS | STE_DOMAIN(0) | (0x2 << STE_AP_SHIFT))
#define STE_ADDR(base, offset) (((base >> STE_BASE_SHIFT) + offset) << STE_BASE_SHIFT)

__attribute__((__aligned__(SECTION_TABLE_ALIGN)))
uint32_t startup_table[4096] = {
    /* KERNEL_START_VADDR maps KERNEL_LOAD_PADDR */
    [(KERNEL_START_VADDR >> 20) + 0] = STE_ADDR(KERNEL_LOAD_PADDR, 0) | STE_KERNEL_DEF,
};
```

根据前一篇的原理分析，我们将`0x80000000 - 0x80100000` 1M 的空间映射到了`0x60000000 - 0x60100000`,
这样当我们取地址时就能拿到正确的数据了。

Domain我们取Domain 0, DACR[1:0]我们配置为Client 01, 也就是要应用页表的这些访问控制检查;
AP我们使用0b10, 也就是映射的区域可读可写;
`RSRV_BITS`实际上是确定table entry是使用section table entry的意思。

但是这里有个问题，如果我们就这样enable MMU之后,
我们的下一条指令还是0x6001xxxx吧? 虽然0x80000000映射好了，
但是0x6001xxxx这个是我们正在用的地址，用这个去访存取指令不就没有物理页对应么？

所以除了0x80000000, 我们对原来的Load Address也要映射为真正的Load Address,
这部分就是1:1直接映射:

```c startup_table.c https://github.com/SilentAlice/alice-os/blob/26c3882632f12a377b78f64f58f16aafc6e86bc1/arch/arm/startup_table.c
__attribute__((__aligned__(SECTION_TABLE_ALIGN)))
uint32_t startup_table[4096] = {
    /* KERNEL_LOAD_PADDR is direct mapping */
    [(KERNEL_LOAD_PADDR >> 20) + 0] = STE_ADDR(KERNEL_LOAD_PADDR, 0) | STE_KERNEL_DEF,

    /* KERNEL_START_VADDR maps KERNEL_LOAD_PADDR */
    [(KERNEL_START_VADDR >> 20) + 0] = STE_ADDR(KERNEL_LOAD_PADDR, 0) | STE_KERNEL_DEF,
};
```

好了，这样我们的映射就构建好了，我们下一条指令0x6001xxxx也能正常执行，
取地址什么的0x8000xxxx也能正常取到。由于只映射了1M的空间，
如果我们镜像慢慢变大可能会不够用，
所以实际实现过程中我各映射了16M。

```c startup_table.c https://github.com/SilentAlice/alice-os/blob/26c3882632f12a377b78f64f58f16aafc6e86bc1/arch/arm/startup_table.c
__attribute__((__aligned__(SECTION_TABLE_ALIGN)))
uint32_t startup_table[4096] = {
    /* KERNEL_LOAD_PADDR is direct mapping (16M) */
    [(KERNEL_LOAD_PADDR >> 20) + 0] = STE_ADDR(KERNEL_LOAD_PADDR, 0) | STE_KERNEL_DEF,
    [(KERNEL_LOAD_PADDR >> 20) + 1] = STE_ADDR(KERNEL_LOAD_PADDR, 1) | STE_KERNEL_DEF,
    ...
    [(KERNEL_LOAD_PADDR >> 20) + 15] = STE_ADDR(KERNEL_LOAD_PADDR, 15) | STE_KERNEL_DEF,

    /* KERNEL_START_VADDR maps KERNEL_LOAD_PADDR (16M) */
    [(KERNEL_START_VADDR >> 20) + 0] = STE_ADDR(KERNEL_LOAD_PADDR, 0) | STE_KERNEL_DEF,
    [(KERNEL_START_VADDR >> 20) + 1] = STE_ADDR(KERNEL_LOAD_PADDR, 1) | STE_KERNEL_DEF,
    ...
    [(KERNEL_START_VADDR >> 20) + 15] = STE_ADDR(KERNEL_LOAD_PADDR, 15) | STE_KERNEL_DEF,
};
```

## Enable MMU!

好了，Startup Table已经填好，接下来就是配置TTBR、SCTLR用起来了:

```c arch/arm/init.c https://github.com/SilentAlice/alice-os/blob/26c3882632f12a377b78f64f58f16aafc6e86bc1/arch/arm/init.c
uint32_t val;
/* init DACR, we only use domain 0 */
val = 0x1;
sysreg_write32(DACR, val);

#if ARM_VERSION == 7
 /* bit[2-0]: All address translation use TTBR0 */
val = 0x0;
sysreg_write32(TTBCR, val);
#endif

val = (uintptr_t)(&startup_table);
val = va2pa(val);
sysreg_write32(TTBR0, val);

/* enable mmu */
sysreg_read32(SCTLR, val);
val |= SCTLR_M;
sysreg_write32(SCTLR, val);

asm volatile ("mov r7, #0xAA");
asm volatile (".word 0xdeadbeef");
```

首先配置DACR, 把Domain 0设置为Client,
ARMv7上我还把TTBCR配置为只使用TTBR0,
需要注意的是我们取到的`&startup_table`是链接脚本里的虚拟地址，
需要给他转换成物理地址(减去`KERNEL_START_VADDR` 再加上`KERNEL_LOAD_PADDR`),
之后将它填到TTBR(0)里面, 使能MMU!

我们来验证一下，使能MMU之后我们`mov r7, #0xAA`是否可以执行成功吧！

vexpress-a9:

    QEMU 4.2.0 monitor - type 'help' for more information
    (qemu) info registers
    R00=60010000 R01=6001a000 R02=60018000 R03=00c50079
    R04=00000000 R05=00000000 R06=00000000 R07=000000aa
    R08=00000000 R09=00000000 R10=00000000 R11=60019fec
    R12=00000000 R13=00000000 R14=00000010 R15=0000000c

versatilepb:

    QEMU 4.2.0 monitor - type 'help' for more information
    (qemu) info registers
    R00=00010000 R01=0001a000 R02=00018000 R03=00090079
    R04=00000000 R05=00000000 R06=00000000 R07=000000aa
    R08=00000000 R09=00000000 R10=00000000 R11=00019fdc
    R12=00019fe0 R13=00019fb8 R14=000100d0 R15=000100a8

R7里面就是我们想要的AA! 我们的页表配置成功!

## Next

我们接下来就要把栈、PC等跳到真正的0x80000000了，
让他们跑在自己应该跑的地方~

之后我们设置的就是操作系统非常重要的异常向量表,
如果上面这些代码小伙伴自己哪里写错的话会发现PC会跑到一个奇怪的地址,
那个地址就是当异常发生时系统控制流直接跳转的地方，
不设置异常向量表，我们的操作系统就无法处理任何错误，
发生错误时我们也得不到任何有用的信息，
不能处理系统调用请求和中断...

[0]: https://github.com/SilentAlice/alice-os/tree/26c3882632f12a377b78f64f58f16aafc6e86bc1
