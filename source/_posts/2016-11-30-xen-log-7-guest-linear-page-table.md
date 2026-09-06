---
layout: post
title: "Xen Log 7-Linear Page Table"
date: 2016-11-30 19:19:03 +0800
comments: true
tags: virtualization
keywords: Xen, Linear Page Table
---
When you see memory layout of Xen, you may found that there is a range named :**Guest Linear Page Table**. You can find this in `$XEN_DIR/xen/include/include/asm-x86/config.h`.
So what is the purpose of this range?

Before we dig into the page table, you may need to read previous post [[The Funny Page Table Terminology](http://silentming.net/blog/2016/11/30/funny-page-table-terminology/)] to learn about some page table terms used in Xen.

This question may help you as well: [What's the purpose of linear page table (PML4 entry 258)](http://old-list-archives.xenproject.org/archives/html/xen-devel/2008-03/msg01021.html)
<!--more-->

In config.h, we can find memory layout of Xen:

```c config.h
...
# HYPERVISOR_VIRT_START
# RO_MPT_VIRT_START
 *  0xffff800000000000 - 0xffff803fffffffff [256GB, 2^38 bytes, PML4:256]
 *    Read-only machine-to-phys translation table (GUEST ACCESSIBLE).
 
# RO_MPT_VIRT_END
*  0xffff804000000000 - 0xffff807fffffffff [256GB, 2^38 bytes, PML4:256]
 *    Reserved for future shared info with the guest OS (GUEST ACCESSIBLE).

 *  0xffff808000000000 - 0xffff80ffffffffff [512GB, 2^39 bytes, PML4:257]
 *    ioremap for PCI mmconfig space
 
 *  0xffff810000000000 - 0xffff817fffffffff [512GB, 2^39 bytes, PML4:258]
 *    Guest linear page table.

 *  0xffff818000000000 - 0xffff81ffffffffff [512GB, 2^39 bytes, PML4:259]
 *    Shadow linear page table.

 *  0xffff820000000000 - 0xffff827fffffffff [512GB, 2^39 bytes, PML4:260]
 *    Per-domain mappings (e.g., GDT, LDT).
 ...
```

The PML4[258] is used as Guest Linear Page Table. What the hell is it???

After printing the PT of Xen after initialization:

```sh
(XEN) |=========PT Info========|
(XEN) |-------L4: 000000008ce4b000
(XEN)   |------id: 0, L3: 000000008d40d000
(XEN)     |-----id: 0, L2: 000000008d40c000
(XEN)       |----id: 0, L1: 000000008ce4c000
(XEN)   |------id: 256, L3: 00000002393b9000
(XEN)     |-----id: 0, L2: 00000002393b7000
(XEN)   |------id: 258, L3: 000000008ce4b000
(XEN)     |-----id: 0, L2: 000000008d40d000
(XEN)       |----id: 0, L1: 000000008d40c000
(XEN)     |-----id: 256, L2: 00000002393b9000
(XEN)       |----id: 0, L1: 00000002393b7000
(XEN)     |-----id: 258, L2: 000000008ce4b000
(XEN)       |----id: 0, L1: 000000008d40d000
(XEN)       |----id: 256, L1: 00000002393b9000
(XEN)       |----id: 258, L1: 000000008ce4b000
(XEN)       |----id: 261, L1: 000000008ce4a000
(XEN)       |----id: 262, L1: 000000008ce49000
(XEN)     |-----id: 261, L2: 000000008ce4a000
(XEN)       |----id: 0, L1: 00000002393b8000
(XEN)       |----id: 256, L1: 00000002393bb000
(XEN)       |----id: 319, L1: 000000008ce48000
(XEN)       |----id: 320, L1: 00000002393b5000
(XEN)       |----id: 321, L1: 00000002393b6000
(XEN)       |----id: 322, L1: 000000008ce47000
(XEN)       |----id: 384, L1: 000000023cd9e000
(XEN)     |-----id: 262, L2: 000000008ce49000
(XEN)       |----id: 0, L1: 000000008ce43000
(XEN)       |----id: 2, L1: 000000008ce45000
(XEN)       |----id: 3, L1: 000000008ce46000
(XEN)       |----id: 4, L1: 000000008f7fd000
(XEN)       |----id: 8, L1: 000000008f7fb000
(XEN)   |------id: 261, L3: 000000008ce4a000
(XEN)     |-----id: 0, L2: 00000002393b8000
(XEN)     |-----id: 256, L2: 00000002393bb000
(XEN)       |----id: 0, L1: 00000002393ba000
(XEN)     |-----id: 319, L2: 000000008ce48000
(XEN)       |----id: 510, L1: 000000008f7fe000
(XEN)       |----id: 511, L1: 000000008d408000
...
```

Wait, see what we found. The contents of PML4[258] has the same physical address of PML4 itself! (See line: 2, 8, 13, 16) They all have same physical address: 8ce4b000. So when we walk this page table, we will always find PML4 and if we use a recursive function withoud limitation, this will cause stack overflow.

From the question, it seems that this can faciliate the locating of a PTE from VA but how and why? (In this post I will use l4pt-l1pt instead of pgd, pud, pmd and pt)

### Page Table Walking

In development, we may want to change a data page to be readonly. Traditionally, you will get a 48-bit VA (The high 16-bit will always be 1 or 0 according to AMD specification).
We will devide 48-bit VA in this way:

```c
|---------------------- 48-bit Virtual Address ------------------------|
|--- 9 bit ---|--- 9 bit ---|--- 9 bit ---|--- 9 bit ---|--- 12 bit ---|
|--L4 offset--|--L3 offset--|--L2 offset--|--L1 offset--|--- offset ---|

|------------ offset is used in corresponding PT/Data Page ------------|

|--- L4 PT ---|--- L3 PT ---|--- L2 PT ---|--- L1 PT ---|- Data Page --|
|64-bit * 512 |64-bit * 512 |64-bit * 512 |64-bit * 512 |-- 4KB Page --|
```

{% img /images/20161130pt.png 500 300 Page Table Walking%}

After walking 4 levels page table, using each 9-bit seg as offset in corresponding level of PT and plusing its 12-bit offset in VA, we can finally locate accurate physical address of this virtual address. The translation is done.

Each level PT is a 4K page saving 64-bit info \* 512 entries. 

```c
/* Info stored in each level PTE */
|------------ 64-bit info stored in PTE -----------|
|--- 16 bit ---|------ 40 bit ------|--- 12 bit ---|
|-- reserved --|- PA of next level -|---- flag ----|
```

While current OS supporting max 52-bit physical address, the higher/most 16 bits of 64-bit info is reserved for future hardware/software using (63-bit is used as NX, non-executable on some hardware). And lower 52-bit will store the physical address of next level PT. As physical memory is also devided into 4K page, the least 12 bits will always be zero for one page. That's why we can use least 12bits to store flags.

### Linear Page Table

Now we want to set one **data page** as readonly (We can only control them in page granularity), meaning that we need to change R/W flag of L1PTE that pointing to this data page. Then, the address of this L1PT is needed.

The intuitive way is using VA of data page to walk PT and stop at L1PTE. And change the flag of L1PTE. So, you need to:

* L4PT-\>L3PT
   * Read PA of L4PT from CR3 (noted as PA<sub>4</sub>), 
   * Add L4 offset(note as offset<sub>4</sub>) to this PA and make it into a VA<sub>4</sub>
   * Using VA<sub>4</sub> to walk 4-level PT and get its 64-bit info which means you get PA of L3PT (noted as PA<sub>3</sub>).
* L3PT-\>L2PT
   * Add offset<sub>3</sub> to PA<sub>3</sub> and make this into a VA<sub>3</sub> 
   * Using VA<sub>3</sub> to walk 4-level PT and get its 64-bit info. Get PA<sub>2</sub>
* L2PT-\>L1PT
   * Add offset<sub>2</sub> to PA<sub>2</sub> and make this into a VA<sub>2</sub> 
   * Using VA<sub>2</sub> to walk 4-level PT and get its 64-bit info. Get PA<sub>1</sub>
* Change flag of L1PT
   * Add offset<sub>1</sub> to PA<sub>1</sub> and make this into a VA<sub>1</sub> so that you can derefer it.
   * `*VA1 &= ~R/W flag`. (\*VA<sub>1</sub> will aslo using VA<sub>1</sub> to walk 4-level PT)

We can find that, to change the flag of this data page, we need to walk 4-level PT 4 times! It's inefficient. And make every PA to VA, we have to prepare a **Direct Mapping** of all physical memory. Now it is the job of Linear Page Table.

Linear Page Table is actually one L4PTE, and its 64-bit info saves the PA<sub>4</sub>. (Not PA<sub>3</sub>! but PA<sub>4</sub> which is exactly same with PA stored in CR3).<br>
So walk this PTE will give you infinite loop of it self. Take the example in Xen (`PML[258]`). If we have a VA that offset<sub>4</sub> is 258, you will find this:

```c
|---------------------- 48-bit Virtual Address ------------------------|
|- 258/0x102 -|--- 9 bit ---|--- 9 bit ---|--- 9 bit ---|--- 12 bit ---|
|--L4 offset--|--L3 offset--|--L2 offset--|--L1 offset--|--- offset ---|

/* L4 offset (PML4[258]) will give you L4PT! ===>

|---------------------- 48-bit Virtual Address ------------------------|
|- 258/0x102 -|--- 9 bit ---|--- 9 bit ---|--- 9 bit ---|--- 12 bit ---|
|--L4 offset--|--L4 offset--|--L3 offset--|--L2 offset--|--L1 offset:000--|
```

Because offset<sub>4</sub> 258 will bring you into L4PT again instead of L3PT, **you will use next 9-bit seg as L4 offset to walk L4PT again**. <br>
Eventually, you will have no extra 9-bit to walk L1PT and stop at L2PTE which saves PA of L1PT(PA<sub>1</sub>).

!!! The PA<sub>1</sub> is gotten ?! We made so much effort and walk the 4-level so many times...

And, you get a bonus. Don't forget the least 12-bit, the 12-bit is final offset, we can use this to locate the L1PTE we want! And this strange new VA is just the VA of this L1PTE (VA<sub>1</sub>). Just with a special L4PTE, we have saved us from 3-times 4-level PT walking and don't need to prepare the **Direct Mapping** as well.

So, let's constuct the new VA: I will use 49-19 to note each 9-bit seg in VA.

```c
/* Original VA: */
|------------------------ 48-bit Virtual Address --------------------------|
|--  9 bits ---|--- 9 bits ---|--- 9 bits ---|--- 9 bits ---|--- 12 bits --|
|--- 47:39  ---|--- 38:30  ---|--- 29:21  ---|--- 20: 12 ---|---- 11:0 ----|
|-- L4 offset--|-- L3 offset--|-- L2 offset--|-- L1 offset--|-- PA offset--|

/* Constructed new VA of L1PTE: */
|- 258/0x102 --|--L4 offset --|--L3 offset --|--L2 offset --|L1 offset 000 |

/* Similarly, VA of L2PTE: */
|- 258/0x102 --|- 258/0x102 --|--L4 offset --|--L3 offset --|L2 offset 000 |

/* VA of L3PTE: */
|- 258/0x102 --|- 258/0x102 --|- 258/0x102 --|--L4 offset --|L3 offset 000 |

/* VA of L4PTE: */
|- 258/0x102 --|- 258/0x102 --|- 258/0x102 --|- 258/0x102 --|L4 offset 000 |
```

The least 12-bit, we can append 9-bit three zero. Because each 64-bit info entry is 8 bytes (so we need 3 zero) and with such sugar, we can locate each level of PTE and any VA as we want.

```c An Implementation
#define LINEAR_PT_OFFSET 258
#define L4_PAGETABLE_SHIFT 39             /* 12 + 9 * 3 */
#typedef unsigned long vaddr_t

pte_t * fun(vaddr_t vaddr, unsigned lv)
{
    vaddr_t ret = 0;
    uintptr_t offset = LINEAR_PT_OFFSET << L4_PAGETABLE_SHIFT; 
    uintptr_t vmask = (1UL << 48) - 1;    /* Most 16 bits are reserved */
    int i;

    if ( lv < 1 || lv > 4 )
        return 0;
    ret |= vaddr & (~vmask);              /* Clear VA, put reserved 16 bits */
    vaddr &= vmask;                       /* Just keep VA */

    for ( i = 0; i < lv; i++ )
        ret |= offset >> (i * 9);         /* Construct our new vaddr as above */
    ret |= (vaddr >> (9 * lv) >> 3 << 3); /* Append 3 zero */
    return (pte_t *)ret;
}
```

### End

This is better to be used in full 4-level page walking. Be careful when use this trick for PSE page (which will not go througn full 4-level page walking). 

### ChangeLog

- 2018-06-27: Refine the desciption of constructed virtual address
