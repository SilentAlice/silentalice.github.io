---
layout: post
title: "Alice OS 6-Address Translation"
comments: true
date: 2020-01-31 01:22:39
tags: os-dev
keywords: arm, os, linux, alice os, pagetable, mmu
---

本篇主要解释一下为什么要使用页表系统，
构建页表系统需要注意什么，
然后再看一下ARMv5与ARMv7页表格式的区别,
看能不能尽可能把两者的代码统一起来。

已经熟悉地址翻译的小伙伴可以直接看下一篇，
不玩虚的直接上手！

<!-- more -->

## 页表系统

我们学习操作系统原理的时候一定会讲页表，
我们也都知道虚拟地址经过页表翻译会变成物理地址。
那么页表是为了解决什么问题呢？

设想一下，如果我们没有页表，就像我们之前的代码那样一行行直接跑，
我们在linker script里面把起始地址改成和实际启动地址一样，
好像也是OK的。只要链接脚本生成的地址和实际启动地址一致，
我们的访存也不会出错，好像已经很完美了。

在没有OS的时候，我们的CPU直接跑的裸程序(bare metal),
那么如果想跑多个APP的话，就需要保证APP之间地址**不能互相重叠**。
但这样一个APP也基本上只能跑在这个CPU上了，
换个CPU可能别的APP就把这个给占了，
总不能我们每次换一个CPU要么赌运气别的APP没用我们的地址，
要么我们重新编、甚至重新写吧？

所以我们一定需要一个地址翻译，
每个APP都可以从同一个地址开始执行，
只要我给他们映射到不同的物理地址上就行了。

至于为何慢慢发展成2级或者如今64位系统的4级页表，
则主要是为了满足硬件越来越大的物理地址以及减少内存外部碎片的原因。
内存碎片和页表的发展有兴趣的小伙伴可以私下自己再看啦。

## TTBR & First Level Table

将输入的va(virtual address)翻译为pa(physical address)的过程叫做page walk,
也叫address translation. ARMv5的页表非常简单，只要我们构建一个表装到这个TTBR里，
SCTLR里的M-bit一使能，MMU就会开始地址翻译了。

{% img /images/2020/20200131alice0.png %}

那么页表翻译的规则是什么样的呢?
这里我用ARMv7的页表翻译过程来说, ARMv5的类似，不过v7的图更简洁:

{% img /images/2020/20200131alice1.png %}

我们在ARMv7上会将图中的N设置为0，这样ARMv7上就只使用TTBR0且格式与ARMv5的TTBR保持兼容，
可以看到，va的bit[31-20]会作为一级页表的index,
通过这个index和TTBR里存放的base,
就可以找到对应的页表项(Page Table Entry, PTE or Section Table Entry, STE)。

如图中所示，我们1级页表有3种格式，分别是Section, Page Table和Supersection,
Page Table更为细粒度，还需要2级页表，在2级页表里还有大页和小页等等。

总的来说:

- 使用section, 那么每个entry对应**1M**物理内存区域;
- 使用Supersection, 每16个entry内容一模一样, entry指向**16M**物理内存区域;
- 使用Page Table
  - 大页和section类似, 一个指向**1M**物理内存,
  - 小页是常见的4K页，一个指向**4K**物理内存。

我们随后再解释为什么它们指向1M、16M或者4K物理内存，
我们首先观察，由于一级页表的index范围是 bit[31-20]，
所以可以存放2^12 = 4096个entry。每个entry是个32位长变量(4byte)，
所以一级页表的大小就是 4byte * 4096 = 16KB.

由于每个STE对应1M物理内存，所以这个页表最大能够映射 1M * 4096 = 4G的物理地址空间。
而为什么是4G物理内存呢? 是因为我们虚拟地址长度32位 2^32 = 4G,
所以虚拟地址空间的范围最大就是4G。物理地址也是32位，同样最大也就是4G物理地址空间了。

(Long-descriptor format 支持更大的物理地址空间, 虚拟地址空间仍为4G)。

现在再回头看看图1中TTBR的Format: 他的bit[13-0]是(Sould Be Zero/SBZ),
其原因就是1级页表是16K大小，而TTBR又要求一级页表是16KB对齐的，
因此页表地址的后14位一定为0.

## Address Translation

由于Section最为简单，我们以一级页表是Section为例
每个entry是一个STE, 对应1M物理内存。

详细的查表过程如下:

{% img /images/2020/20200131alice2.png %}

32位的va, 取bit[31:20]作为index, 加到TTBR里的Base上,
这样产生的**物理地址** `|Base[31:14] | va[31:20] | 00 |`
指向的就是1级页表的某个entry (STE)。
由于entry都是4byte (32bits), 又是对齐的，所以最后两个bit一定是0;

再来看看输入的va, va只用了bit[31:20], 还有[19:0]呢，
这后20位又是怎么使用的呢？这就要看我们上一步取出来的STE了。

STE格式如下:

{% img /images/2020/20200131alice3.png %}

可以看到STE的bit[31:20]存放的是section base address,
这个section base address就是我们刚刚说的这个STE对应的1M物理内存的基址！

最后翻译得到的物理地址就是 | section base address | va[19:0] | 这样一个32位地址了。

所以我们看到1级section table实际上只对**va的前12位 bit[31:20]进行了翻译**，
翻译成了section base address, **va的后20位直接拿来使用**，组成了一个物理地址。

所以我们如果想让这个翻译成立，就必须对物理内存进行切分，切分成**1M**大小的块，
每一块的起始物理地址都要对齐到1M大小(即后20位为0),
这些物理地址块就可以作为STE里面的section base address。

所以这也是为什么我们开头说section对应1M物理内存区域，
这1M的物理块是va通过地址翻译找到的，
找到了这个物理块之后，后面的20位地址就可以直接拿来用了。

假如: (答案在文末)
1. section指向的是2M的物理内存, 那么Section Table的大小要如何改变？STE如何改变?
2. 虚拟地址我们最大只有2G, Section Table大小和STE如何改变?
3. 物理地址我们想支持8G, 又要改变什么呢？
4. 我们想支持16G的虚拟地址, 需要怎么办?

## Page Table

那么Page Table的格式也就类似了:

va会被拆成3部分:

- va[31:22] : index of first level page table
- va[21:12] : index of second level page table
- va[11:0]  : offset of page

其中1级页表的PTE (也叫PDE: Page Directory Entry) 存放2级页表的base;
2级页表的PTE存放4K物理页的base,
最后从2级页表的PTE中取出20位长的4K物理页base再加上va[11:0]组成真正的物理地址(如上图Fine page table)。

所以使用页表，物理页就会被分成4K的小块，也就更为灵活了。

## Bits in Table Entry

我们发现上图中，Table Entry不止存放有物理页的base,
还有一些其它的东西: AP, Domain, C, B

AP是Access Permission, 可以控制这块内存是否可以访问，是否可以被非特权的用户态访问,
是否可写等等。

Domain: ARM有个Domain Access Control Register DACR。
32位的寄存器被分成了16个Domain, 每个Domain 2个bit:

|Value|Meaning|Description|
|:---|:---|:---|
|00|No access| Any access generates a domain fault.|
|01|Client| Accesses are checked against the access permission bits in the section or page descriptor.|
|10|Reserved| Reserved. Currently behaves like the no access mode.|
|11|Manager| Accesses are not checked against the access permission bits so a permission fault cannot be generated.|

每个Domain可以设置是否可以访问或者是否启用安全检查，
页表项指向的这个区域会对应于一个Domain，在访存时进行访问控制检查。
我们当然还是希望应用检查的，所以会用0b01 Client;

C, B就是Cache属性, 对应的内存区域是否是cachable, 是否为Write-Back等等;
关于Cache我们暂时不会涉及，有兴趣的可以自己查一下。

## ARMv5 vs ARMv7

ARMv7的页表可以用两个TTBR, 可以分别用于内核和用户态，
等我们以后用到TTBR1的时候再解释这么做的好处。

ARMv7里面的AP还有第3个: AP[2] 可以进行更细粒度的控制，
或者通过配置SCTLR.AFE将AP[0]用做Access Flag,
可以查看内存是否被硬件访问过，用于刷Cache等等。

ARMv7还有Execution Not bit, 用来表明某个内存区域不可执行等等。

总之ARMv7有更多有关安全、Cache的bits,
目前我们为了方便演示，会将ARMv7配置为兼容ARMv5的形式,
所以这些bit暂且不用理会, 有兴趣的自己可以研究一下。

## Next

现在我们已经知道了地址翻译的原理和过程，
下面就来看看我们如何来构建启动的页表吧。

## Notes

1. 如果section指向2M物理内存, 就意味着4G的地址范围需要 2048个entry,
   每个entry 4B, Section Table大小就是 4B * 2048 = 8K, 对齐到8K 所以后13位要全为0。
   TTBR的格式就是 bit[31:13]是Base (19bits), bit[12:0]SBZ;<br>
   由于entry变少，用于index的va就只需要[31:21] 11个bit用来作为index了,
   和TTBR的19个bits拼起来就是STE的地址，依旧是最后两位为0。<br>
   STE由于对应2M区域，所以后21位可以都作为other bits,
   section base address就只需要32-21 = 11bits, 即 bit[31:21];

2. 虚拟地址最大为2G, 我们要翻译的地址大小就少了一半，
   所以Section Table entry减半, 其他不变。

3. 物理地址想支持8G, 那就是说最后的STE中填写的Base要多一个bit,
   这样才能索引到更大的物理地址，
   所以STE中的section base address要多一位来保证能索引到8G的物理地址范围。
   ARM本身支持物理地址扩大到16G, 可以自己参考一下ARM手册是怎么改Descriptor格式的吧~

4. 如果我们想支持16G的虚拟地址(va 34位)，要么把Table番两番，entry加到 4096 * 4;
   要么就要再引入多级页表, 把va拆成多份,
   va[a|b|c|d|...], a作为1级页表的index, b是2级页表的index, c是3级页表的index...
   最后在最后一级页表中取出来physical address base, 拼上最后没用做index的va;

本质上，多级页表就是添加了更多的table entry, 又保持每张页表小一些，不至于16K 64K 256K...这样越来越大。
