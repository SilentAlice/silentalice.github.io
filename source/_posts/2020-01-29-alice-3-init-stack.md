---
layout: post
title: "Alice OS 3-Init Stack"
comments: true
date: 2020-01-29 19:42:01
tags: os-dev
keywords: arm, os, 操作系统, linux, alice os
---

在上一次我们已经知道了内核实际的加载地址在不同平台上是不同的，
本篇我们来设置一个启动的栈，并进入C代码的初始化流程,
同时考虑如何将这不同的加载地址告诉后续的启动代码。

[Alice-OS: Init Stack][0]

<!-- more -->

## `AT` Keyworkd

我首先给不同的Plat里面添加了各自的linker.ld,

```
# alice-os/plat/vexpress-a9/linker.ld

kernel_start_address = 0x80000000;
kernel_load_address = 0x60010000;
```

并在***alice.ld***中include了它们:

```
# alice.ld

INCLUDE linker.ld

ENTRY(entry)

SECTIONS
{
	. = kernel_start_address;

	.text : AT(kernel_load_address) { *(.text) }
	PROVIDE(etext = .);
```

每个plat自己指定内核的启动虚拟地址和加载的物理地址，
我们这里没有用到AT, 因为linker script输出是按照**output section address**来的，
但是AT告诉了Linker这个镜像实际加载的地址，
但是一些程序loader如果使用这个linker script的话就知道到哪里去找实际的代码了;

在linker script的官方说明里也列举了这样的一个demo:

```linker demo script https://sourceware.org/binutils/docs-2.33.1/ld/Output-Section-LMA.html
SECTIONS {
  .text 0x1000 : { *(.text) _etext = . ; }
  .mdata 0x2000 :
    AT ( ADDR (.text) + SIZEOF (.text) )
    { _data = . ; *(.data); _edata = . ;  }
  .bss 0x3000 :
    { _bstart = . ;  *(.bss) *(COMMON) ; _bend = . ;}
}
```

当Loader发现AT指明了数据段(.mdata)实际上是在代码段(.text)的后面，
但是生成的虚拟地址是在0x2000时，
Loader就可能采用如下方式去把数据放到正确的位置上:

```
extern char _etext, _data, _edata, _bstart, _bend;
char *src = &_etext;
char *dst = &_data;

/* ROM has data at end of text; copy it.  */
while (dst < &_edata)
  *dst++ = *src++;
...
```

通过这种方式将data放到真正的地址上.

我们的内核也是一样，如果我们查看反汇编会发现，
我们的代码也是从`0x80000000`开始的，
但是实际上启动的地址却是 `0x60010000`。

所以如果我们想让代码后面能正常运行，
正常找到各种symbol，就需要把整个alice.bin从0x6001000 copy到 0x80000000;
不过好在我们的CPU是可以使用虚拟地址进行映射的，
所以才避免了这种copy。

## Init Stack

我们在上一篇中强行把当前的PC对齐到4K,
然后自己加了0x2000作为栈底。
这样显然是有风险的，如果启动代码过多超过了一个4K页，
那我们的这种计算就会出错。

由于我们现在知道了启动的时候可以通过PC获取启动地址，
又知道了生成的栈地址，
所以我们可以用Addr(栈) - 0x80000000 + Addr(Load\_Start)来获取真正的栈地址:

```asm
.global entry
entry:
    # get load address
    mov r0, pc
    sub r0, r0, #8

    # calculate real stack address
    ldr r1, =#kernel_stack_start
    sub r1, r1, #KERNEL_START_ADDRESS
    add r1, r1, r0

    # set stack
    mov sp, r1

    # r0 is load address
    bl init
```

通过这种方式我们就可以正确的计算出栈的物理地址并赋到sp中，
当我们的栈初始化好了之后，
就可以调用其他的函数了，通过`bl`我们可以直接跳到C代码。

## Function Frame

当发生函数调用时，apcs的calling convention会对函数生成一个栈帧(Frame),
存放栈帧的寄存器在[Alice OS 1][1]中也说过，
是寄存器R11 (FP Frame Pointer)负责保存。

我们来查看一下生成的*** alice.dump.asm ***观察一下arm的栈帧:

    80000000 <entry>:
    80000000:  e1a0000f   mov   r0, pc
    80000004:  e2400008   sub   r0, r0, #8
    80000008:  e59f100c   ldr   r1, [pc, #12]   ; 8000001c <kernel_start_addr    ess+0x1c>
    8000000c:  e2411102   sub   r1, r1, #-2147483648    ; 0x80000000
    80000010:  e0811000   add   r1, r1, r0
    80000014:  e1a0d001   mov   sp, r1
    80000018:  eb000000   bl    80000020 <init>
    8000001c:  80002000   andhi r2, r0, r0

    80000020 <init>:
    80000020:  e1a0c00d   mov   ip, sp
    80000024:  e92dd800   push  {fp, ip, lr, pc}
    80000028:  e24cb004   sub   fp, ip, #4
    8000002c:  e24dd008   sub   sp, sp, #8
    80000030:  e50b0010   str   r0, [fp, #-16]
    80000034:  deadbeef   cdple 14, 10, cr11, cr13, cr15, {7}
    80000038:  e320f000   nop   {0}
    8000003c:  e24bd00c   sub   sp, fp, #12
    80000040:  e89da800   ldm   sp, {fp, sp, pc}

我们来看一下当`init`被调用时首先做了什么:
我们发现当有函数调用时，arm和x86类似，
会首先将原来的sp放到ip中，保存当前的fp, ip(原来的sp), lr, pc 到栈上。
之后将原来的sp - 4存放到fp里面;
所以现在fp就指向了当前函数栈的**栈底**，
sp由于push的原因指向了当前栈的**栈顶**。

我们可以利用monitor来验证一下: (0x80000038行是我们的`0xdeadbeef`,
会导致程序挂在这里)

    [0] % telnet localhost 1234
    Trying 127.0.0.1...
    Connected to localhost.
    Escape character is '^]'.
    QEMU 4.2.0 monitor - type 'help' for more information
    (qemu) info registers
    R00=60010000 R01=60012000 R02=60000100 R03=00000000
    R04=00000000 R05=00000000 R06=00000000 R07=00000000
    R08=00000000 R09=00000000 R10=00000000 R11=60011ffc
    R12=60012000 R13=00000000 R14=60010038 R15=026f7c00

    (qemu) x /4x 0x60011ff0
    60011ff0: 0x00000000 0x60012000 0x6001001c 0x6001002c

我们查看一下Push的值: (`push {fp, ip, lr, pc}`)

可以看到，R11(FP)指向当前栈底(0x60011ffc)，R12(IP)根据上面的反汇编，
存的就是之前的栈顶(0x60012000). 而LR指向了0x6001001c;

我们现在看一下`entry`在`bl`到`init`后的下一条指令(0x8000001c),
正是init如果返回的话应该执行的地址! (换算成Load Address)

所以总结一下:

- ARM在函数调用时会产生栈帧，所以如果我们一上来要call C代码的话就要初始化栈;
- ARM的栈结构如下:

|Pointer|Content|Note|
|:---|:---|:---|
|IP(old SP)->|Prev Stack Content|前一个函数的栈|
|FP->|pc|Curr Stack Bottom|
|-|lr|Return Address|
|-|old sp|-|
|SP->|old fp|-|

而当init执行完毕时, 
arm会首先利用fp(当前栈底) - #12移动sp到栈顶,
之后恢复fp, sp, pc.

这里我们注意一下,
`ldm   sp, {fp, sp, pc}`依次将old fp, old sp, 
return address; 恢复到fp, sp 和 pc中。

控制流跳回，sp恢复，fp恢复，函数调用完毕。

## Next

现在我们已经可以运行C代码了，
但是我们当前的代码还是无法获取data，
data实际都在0x60010000往后的地址里，
而生成的代码是按0x80000000计算的。
所以接下来我们就要想办法让物理地址0x60010000映射到0x80000000这个虚拟地址上。 

## Note

当前这个栈帧之所以如此明显是因为我们没有打开编译器的优化，
如果打开优化之后看到的就不一定是这样了~


[0]: https://github.com/SilentAlice/alice-os/tree/45c2f3581eca85d7a15261ea335dc106cffa8cd1
[1]: http://silentming.net/blog/2020/01/28/alice-1-first-commit/
