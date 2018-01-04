---
layout: post
title: "The funny page table terminology"
date: 2016-11-30 19:28:26 +0800
comments: true
tags:
- linux
- note
keywords: Page Table, linux
description: "Funny page table terminology"
---

What’s the next word in this sequence: PT, PD, PDP, …? If you have seen linux code, these page table terms may make you confused. So today I will simply introduce the history and difference between these terms in a hope that this can help you understant them.

I refered [[The funny page table terminology on AMD64](http://www.pagetable.com/?p=1)] and add some new dishes.<br>
Also, this questions may help you as well:

* [What does the 'R' in x64 register names stand for?](http://softwareengineering.stackexchange.com/questions/127668/what-does-the-r-in-x64-register-names-stand-for)
<!-- more -->

###Register Name
I still remembered that when I learned x86 assembly, it took me long time to figure out what eax, ebx, ecx... and SF, OF, etc mean. As **EAX** means **Extend AX**. With the 64 bit extensions of the 8080 architecture, AMD chose “RAX”, not adding another “extended”… Here, the '**R**' means register. Wondering what is the next one :)

> The history reason is that Intel got itself into the habit of enumerating registers with letters with the 8008 (A through E plus H and L). That scheme was more than adequate at the time because microprocessors had very **few registers** and weren't likely to get more, and most designs did it. 

> The prevailing sentiment then was that software would be rewritten for new CPUs as they appeared, so **changing the register naming scheme between models wouldn't have been a big deal**. Nobody foresaw the 8088 evolving into a "family" after being incorporated into the IBM PC, and the yoke of backward compatibility pretty much forced Intel into having to adopt schemes like the "E" on 32-bit registers to maintain it.

> The non-historical part is all practical. Using letters for general-purpose registers limits you to 26, fewer if you weed out those that might cause confusion with the names of special-purpose registers like the program counter, flags or the stack pointer.

> I don't have a source to confirm it, but I suspect the choice of R as a prefix and the introduction of R8 through R15 on 64-bit CPUs signals a transition to numbered registers, which have been the norm among 32-bit-and-larger architectures not derived from the 8008 for almost half a century. IBM did it in the 1960s with the 360 and has been followed by the PowerPC, DEC Alpha, MIPS, SPARC, ARM, Intel's i860 and i960 and a bunch of others that are long-forgotten.

> You'll note that the existing registers would fit nicely into R0 through R7 if they existed, and it wouldn't surprise me a bit if they're treated that way internally. The existing long registers (RAX/EAX/AX/AL, RBX/EBX/BX/BL, etc.) will probably stay around until the sun burns out.

These answer is from [Blrfl](http://softwareengineering.stackexchange.com/users/20756/blrfl). When using number instead of letters, we can mark them as we want and using letter to indicate some special meaning.

###Page Table Terminology

**2-Level**<br>
Something similar happened with PT terms. The i386 (1985) can only map 4GB memory and 2-level page tables will fulfill the need. It is easy to understand that higher level act like the directory which has 32bit \* 1024 entries. So we call high level table as Page Directory Table (PD) and entries as Page Directroy Entries (PDE), pointing to 4KB * 1024 "Page Tables (PT)". The entries of PT is called Page Table Entries (PTE).

**PAE and 3-Level**<br>
But 4GB is no longer enough and Pentium Pro (1995) borned with a trick called "Physical Address Extension (PAE)" that allow up to 64GB of RAM without chaning the 4GB limit per address space. And in this implementation, PT have to be 64bits wide. Every PTE will be extended to 64bit and number of entries per page will be reduced to 512 to fit 4KB page limitation. It is the same with Page Directory.

You will find that 2-level page table is not enough any more. So we need another level page table: Page Directroy Pointer Table (PDP) that pointing to Page Directories. But PDP just has 4 entries (64bit) indicating 4 PD, so totally address space is still 4GB: 4 \* 512 \* 512 \* 4KB = 2<sup>2</sup> \* 2<sup>9</sup> \* 2<sup>9</sup> \* 2<sup>12</sup>= 2<sup>2+9+9+12</sup> = 2<sup>32</sup> = 4GB. 

{% img /images/20161130nopae.png No PAE %}Without PAE

{% img /images/20161130pae.png PAE %}With PAE

But opearing system can leverage Page tables to map 4GB virtual address to physical 64GB memory. That's why Intel bring PAE in. And CR3 which originally pointing to PD now pointing to PDP got the alternate name: PDPTR (Page Directory Pointer Table Register).

**4-Level**<br>
In 2003, AMD introduced AMD64, the 64-bit extensions to i386 architecture, page tables have to be extended again: current CPUs will map 48-bit virtual addresses to 52-bit physical addresses. Even making full use of 512 entries of PDP can only allows 39-bit (12+9+9+9) virtual address (512 GB). So, the new level was introduced to support at most 48-bit (256 TB) virtual memory (They will introduce more level if 256 TB virtual memory is not enough, and this just need changing of OS leaving application-level intact.

The questions is what is its name... "Page Direcotry Indirect Pointer (PDIP)"? "Page Directory Pointer Directroy (PDPD)"? Sounds like [PPAP (Pen Pienapple Apple Pen)](https://www.youtube.com/watch?v=d9TpRfDdyU0). No, they finally found how stupid it is to use this kind scheme and number will be a smart idea (like registers). The new level is called "Page Map Level 4 (PML4)" and other levels are unchanged for consistency.

The AMD specification requires that bits 48 through 63 of any virtual address must be copies of bit 47 (in a manner akin to sign extension)

###Linux Terminology

As you know, programmers are all unruly and always have their own regulations. In linux, may be easier to programming I guess, they use other terms. For level1 (The least level), the terms are same: PT & PTE (Page Table & Page Table Entry). Other levels have their own name in Linux:

* Level 2: Page Middle Directroy (PMD)
* Level 3: Page Upper Directroy (PUD)
* Level 4: Page Global Directroy (PGD)

And an 'E' suffix means corresponding entry. Because every time OS will be changed, so this may not a big deal for kernel developers.

###Xen

In Xen you will find that they are more straight: Use Level 4-1 to indicating the 4 level page table. And here we have to mention another term: Machine address.

You may have known that with segment mechanism, we use linear address to indicate address translated by segment mechanism. So **Virtual Address (VA)** -> **Linear Address** and we use **Linear Address** to walk page table to get **Physical Address (PA)**. But in virtualization environment, we have to distinguish **Guest Physical Address (GPA)** and **Host Physical Address (HPA)**, so we introduce **Machine Address (MA)** to indicate the **real** physical address. Leave physical address unchanged so that guest kernel doesn't need any knowledge from host.

And another page table: Extend Page Table (EPT) in Intel / Nested Page Table (NPT) in AMD is introduced to translate GPA to HPA(MA). PT is used to translate **Host Virtual Address (HVA)** to **HPA** or **GVA** to **GPA** in virtualization environment.

###End

It's clear that L4PTE/L3PTE is better than PGDE/PUDE or PML4E/PDPTE... When you are using EPT/NPT, L4EPTE/L4NPTE is easier to understand as well.

### Misc

**2017-03-09**

The GFP in linux means "Get Free Page".


