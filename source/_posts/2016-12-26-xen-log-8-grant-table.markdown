---
layout: post
title: "Xen Log 8-Grant Table"
date: 2016-12-26 15:17:57 +0800
comments: true
tags: virtualization
keywords: Xen, Grant Table
description: "Description of Grant Table"
---
本篇是为了解Grant Table这一共享内存机制。之前的项目中心在Memory上，不过关于内存的部分带我的大哥在[Xen的启动之内存相关实现][1]和[Xen的内存布局][2]中已经比较详细的说明了。在之后的工作中由于要用到I/O的相关部分，所以先探究一下Grant Table，为之后的I/O的章节做个基础准备。

<!-- more -->

I/O部分暂定为以下部分:

1. **Grant Table (本篇)**
2. [I/O Ring Structure][9]
3. [Event Channel Implementation][10]
4. [Event Channel Usage][12]
5. [XenStore Usage][13]
6. [Write a PV Driver][14]
7. [Connect to XenBus][15]


在虚拟化环境中，Hypervisor往往要提供内存共享机制以便Dom之间进行交流，而Grant table就是为此而创作的。

# Grant Table

Xen的内存共享基于页粒度，一次共享的就是一个页，一个DomU可以把自己的一部分内存分享给别人，而其他人则通过**Grant Reference**来获取到这个页，GrantRef可以视为一个整数或者Key来获取到其他Dom共享的页

Xen通过提供`grant_table_op`一系列hypercall以供DomU使用来实现内存共享。 不同的操作可能需要用到不同的结构体，都定义在`$XENDIR/xen/include/public/grant_table.h`<br> 
每一个Dom都有自己的Grant Table, 这个Table是在Xen Tools 建立(build)dom的时候为Guest创建的，并且和Xen共享以提供给Xen"Granted Page"被赋予了什么样的权限等信息。而Table中的各项就是使用Grant Reference来进行索引。目前Xen只支持一个Dom有最多一个Grant Table。

Guest在启动的时候通过调Hypercall 使用setup op让xen把初始化后的Grant Table映射给Guest使用。 Linux里面在[$DIR/drivers/xen/grant_table.c](http://lxr.free-electrons.com/source/drivers/xen/grant-table.c)让Xen进行映射。

```c grant_table.h
/* [XEN]: Filled by Xen, [GST]: Filled by Guest */
typedef uint32_t grant_ref_t;
struct grant_entry_v1 {
    /* GTF_xxx: various type and flag information.  [XEN,GST] */
    uint16_t flags;
    /* The domain being granted foreign privileges. [GST] */
    domid_t  domid;
    /* GTF_permit_access: Frame that @domid is allowed to map and access. [GST]
     * GTF_accept_transfer: Frame whose ownership transferred by @domid. [XEN]
     */
    uint32_t frame;
};

/* 
Flag:  16bit |----- 7bit -----| 1 | 1 | 1 | 1 | 1 | 1 | 1 |   2   |
             |---------------- Sub Flags -----------------| Types |
             |----Reserved----|SUB|PAT|PCD|PWT| W | R |RO |PERMITS|
             |--------------Reserved- ------------|CMT|CPT| TRANS |
*/
```

我们可以发现，grant\_ref类型就是个无符号整型。Grant\_Table中的entry就如上，`flags`里面是定义这个grant frame的各种类型、权限等，`domid`是接受者的ID, `frame`则根据flag中的信息不同，有不同含义，不过都是这个grantRef对应的页。

而根据Type的不同，sub\_flags中的bit也表达不同的含义:

* 0-Invalid: 这个entry不给予任何权限
* 1-Permit Access(PERMITS): 允许@domid访问或映射这个@frame
* 2-Accept Transfer(TRANS) : 允许@domid将页的拥有者转移给当前dom, 此时frame由Xen填写
* 3-Transitive            : 允许@domid访问给予的部分页，但不允许映射 (v2)

Sub\_flags在Type为Permit Access时:  W/R/RO 分别定义写、读和只读权限，PAT/PCD/PWT则是定义cache类型的(和控制页表的entry里的语义一样, Page Attribute Table Index, Page Cache Disable, Page Write Through, 这里不赘述...), Sub\_page (SUB)则是限制@domid的访问范围(v2)<br>
当Type为Accept Transfer时transfer\_commited(CMT)表示当前的Frame正在转移拥有者，这时Guest不能对这个Frame进行任何修改，只有当状态变为transfer\_completed(CPT)表示frame已经的拥有者已经转移完毕时Guest才能开始正式使用这个frame。

因此通过查这张表，Xen就能知道当前的DomU能对这些Grant Ref做什么样的操作了。

### Grant Table OPs

Grant Table上可以进行两种操作：Mapping 和 Transfer。Mapping 会将Grant Ref这一Page映射到自己的地址空间内，接收方收到后也将这个Page映射到自己的地址空间，则建立了一个共享页；而Transfer则是将自己的一个Page交给别人，用于传输数据给其他的Dom或者用于Dom0分发空闲页给DomU(balloon driver)

```c grant_table.h
/* enum neg_errnoval
 * HYPERVISOR_grant_table_op(enum grant_table_op cmd, void *args, unsigned int count)
 *
 * @args points to an array of a per-command data structure.
 * The array has @count members (struct gnttab_*)
 */

#define GNTTABOP_map_grant_ref        0 /* 映射一个ref */
#define GNTTABOP_unmap_grant_ref      1 /* 取消ref的映射 */
#define GNTTABOP_setup_table          2 /* 建立grant table */
#define GNTTABOP_dump_table           3 /* 导出grant table到console, 仅用于debug */
#define GNTTABOP_transfer             4 /* 移交一个页 */
#define GNTTABOP_copy                 5 /* 拷贝一些页/gref对应的页 */
#define GNTTABOP_query_size           6 /* 查询grant table的当前/最大大小 */
#define GNTTABOP_unmap_and_replace    7 /* 撤销对gref的映射，并替换为其他的映射 */
```

传给Hypercall的操作有上面这些，其中在map操作执行后，会返回一个handle(一个记录当前映射的整型), 在unmap的时候需要传入对应的handle以及HPA(Host Physical Address)并将原来的映射替换为映射到新的Machine Address (可以是Null)。

# Grant Table Version

Xen在3.0之后加入了Grant Table Version 2 (v2), 对1进行了一些扩展，在Version 2中有更多的操作和更细粒度的控制(比如transitive access, 让接受者只能访问部分页而非全部页，并且要求接受者不能映射到这个页，只能通过拷贝数据的方式读取其中的数据)等等。也相应的增加了一些其他的操作和种类。不过v2是向后兼容的，所以做的事情都是一样的。

一个dom在启动的时候会设置好自己使用的是哪个版本的grant table，一旦设置后在运行期间该dom中的所有grant table都必须为这一版本。上面介绍的也是以比较简单的v1版本为准。

# Map & Transfer a Page Frame

很显然我们最关心的是如何共享或移交一个page给另一个dom。这里就着重看一下Mapping 和 Transfer。

#### Mapping

```c
struct gnttab_map_grant_ref {
    /* IN parameters. */
    uint64_t host_addr;
    uint32_t flags;               /* GNTMAP_* */
    grant_ref_t ref;
    domid_t  dom;
    /* OUT parameters. */
    int16_t  status;              /* => enum grant_status */
    grant_handle_t handle;
    uint64_t dev_bus_addr;
};
```

在前面已经介绍了，每个操作都对应有自己相应的结构体类型作为参数，map_grant_ref的结构体如上，`dom`:ref的来源；`flags`会描述如何map这个页:

* GNTMAP_device_map: page会被I/O设备使用，如果系统使用了IOMMU，那么就会在IO地址空间中加入新的映射。相应的，dev_bus_addr就会被填上对应的IO地址作为返回值。
* GNTMAP_host_map: page会被映射到调用者的地址空间中
* GNTMAP_application_map: 在host_map被set的情况下，如果这个flag也被set，那么就可以ring3级访问，否则只能被ring0级访问。
* GNTMAP_readonly: 映射为只读，比如单向传数据的时候，给予方写数据，接收方读数据
* GNTMAP_contains_pte: 指明`host_addr`的类型，默认情况下，host_addr是要更新的PTE的paddr。

#### Transferring

如果是移交一个页(用于dom间传数据), 这时接收方需要首先声明它愿意接受页..(不能你想给我就给我，要先经过我同意，或者...我求求你给我一个页吧..)，通过在自己的Grant Table建一个entry(设置flag为accept transfer), 这个entry会告诉Xen当前的Dom允许domid给它页, 也能表示为请求domid给它页。Xen发现后会通知相关的dom，由dom通过`gnttab_transfer`来移交一个页过来。

```c
struct gnttab_transfer {
    /* IN parameters. */
    xen_pfn_t     mfn;
    domid_t       domid;
    grant_ref_t   ref;
    /* OUT parameters. */
    int16_t       status;
};
```
将mfn所指的frame交给<domid, ref>, @domid在之前已经通过它grant\_table中的ref请求了页。无论操作成功与否，mfn所指的页都将不再属于当前的Guest。

# Demo: Sharing Memory between Domains

现在我们就来尝试使用Grant Table在DomU和Dom0之间共享数据。由于Grant Table没有提供用户接口，所以我们就使用Kernel Module来写吧..这篇《[Kernel Module][3]》介绍如何写一个Kernel Module.

#### DomainU

想要Map一块共享内存，首先需要给予方(domU)在自己的Grant Table中添加一条entry: <flag, domid, frame>；因此我们先来看DomU的代码:

```c alice_domU.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_8/domU/alice_domU.c source
static int init_alice(void)
{
    pr_info("--------->Hello, This is Alice\n");
    vpage = __get_free_pages(GFP_KERNEL, 1);
    pr_info("Alice: Get free page from kernel, virt: 0x%lx\n", vpage);

    mfn = virt_to_mfn(vpage);
    gref = gnttab_grant_foreign_access(DOM0_ID, mfn, 0);
    pr_info("Alice: Grant_Ref is %d, input this as alice_dom0.ko param\n", gref);

    /* Step 2: Write some contents */
    strcpy((char *)vpage, "Hello, by Alice in domU\n");
    return 0;
}

static void exit_alice(void)
{
    if ( gnttab_query_foreign_access(gref) == 0 ) {
        pr_info("Alice: No one is mapping this ref\n");
        gnttab_end_foreign_access(gref, 0, vpage);
    }
    pr_info("Alice: Exit Successfully\n");
    return ;
}
```

首先使用`__get_free_pages`从kernel里拿一个物理页，获取到machine frame number。在Xen提供给的linux的头文件中已经对grant table的相关操作进行了封装，具体的可以查看linux源码，其中`gnttab_grant_foreign_access(DOM0ID, mfn, 0);`的声明是:

```c
int gnttab_grant_foreign_access(domid_t domid, unsigned long frame, int readonly);
```

这个函数会调用`gnttab_interface->update_entry`去更新自己的grant table并加入一个entry, 表示同意别人进行映射。<br>
之后向里面写入"Hello, by Alice in domU"。在domU中插入这个Module: 

```sh
alice@domU $ sudo insmod alice_domU.ko
alice@domU $ dmesg

[  210.410379] --------->Hello, This is Alice
[  210.410385] Alice: Get free page from kernel, virt: 0xffff880034372000
[  210.410389] Alice: Grant_Ref is 399, input this as alice_dom0.ko param
```

{% img https://farm1.staticflickr.com/270/31817428581_bf80f18f8d_o_d.png domU_init %}

记下gref是399, 以及domUID

#### Domain0

Dom0则要用我们上面提到的map_grant_ref, 部分代码如下: (完整代码请点source)

```c alice_dom0.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_8/dom0/alice_dom0.c full source
int init_alice(void)
{
    struct vm_struct *v_start;
    info.gref = gref;
    info.domid = domid;
    pr_info("Alice: init_module with gref = %d, domid = %d\n", info.gref, info.domid);

    /* Reserve a range of kernel address space, fill page table to map this range 
     * This PAGE_SIZE is used for map granted page */
    v_start = alloc_vm_area(PAGE_SIZE, NULL);

    /* Init map ops */
    gnttab_set_map_op(&ops, (unsigned long)v_start->addr, GNTMAP_host_map,
            info.gref, info.domid);
    HYPERVISOR_grant_table_op(GNTTABOP_map_grant_ref, &ops, 1);

    pr_info("Alice: shared_page = %lx, handle = %x, status = %x\n",
        (unsigned long)v_start->addr, ops.handle, ops.status);
    pr_info("Alice: info from domU: %s\n", (char *)(v_start->addr));

    /* Prepare for unmap */
    unmap_ops.host_addr = (unsigned long)(v_start->addr);
    unmap_ops.handle = ops.handle;
    return 0;
}
```

首先我们要在地址空间中划出来4K大小用来映射共享的页, `alloc_vm_area`就是为此而存在的。由于每个domain只有一个grant table, 所以为了拿到grant table的实例，这里需要使用`gnttab_set_map_op`，它会通过Xen实现映射给自己的grant table来初始化接下来要做的map操作。<br>
map就比较简单了，通过gref(399)和domid就能找到domU共享的页并映射到刚才申请的虚拟地址空间中。

运行dom0 module:

```sh
alice@dom0: $sudo insmod alice_dom0.ko gref=399 domid=1
alice@dom0: $dmesg

[98367.531038] Alice: init_module with gref = 399, domid = 1
[98367.531053] Alice: shared_page = ffffc90000cf6000, handle = 30c, status = 0
[98367.531055] Alice: info from domU: Hello, by Alice in domU
```

成功读到了domU共享过来的值, 由于我们这里内存是共享的，所以其实dom0也可以改这些数据的。

dom0 插入Module:

{% img https://farm1.staticflickr.com/275/31561008440_95d6fc3b82_o_d.png dom0_init %}

dom0先删除module:

{% img https://farm1.staticflickr.com/641/31786684502_62f56faf37_o_d.png dom0_exit %}

最后domU删除module:

{% img https://farm1.staticflickr.com/342/31933900005_50079d313e_o_d.png domU_exit %}



[1]: http://ytliu.info/blog/2015/07/30/xende-qi-dong-zhi-nei-cun-xiang-guan-shi-xian/
[2]: http://ytliu.info/blog/2015/07/28/xende-nei-cun-bu-ju/
[3]: http://silentming.net/blog/2016/12/28/kernel-module/
[8]: http://silentming.net/blog/2016/12/26/xen-log-8-grant-table/
[9]: http://silentming.net/blog/2016/12/28/xen-log-9-io-ring/
[10]: http://silentming.net/blog/2017/02/20/xen-log-10-event-channel/
[12]: http://silentming.net/blog/2017/03/01/xen-log-12-using-event-channel/
[13]: http://silentming.net/blog/2017/03/02/xen-log-13-xenstore/
[14]: http://silentming.net/blog/2017/03/20/xen-log-14-pv-driver/
[15]: http://silentming.net/blog/2017/03/21/xen-log-15-xenbus/
