---
layout: post
title: "Xen Log 3-Add New Hypercall to Xen"
date: 2015-12-13 22:57:08 +0800
comments: true
tags:
- tutorial
- virtualization
keywords: Xen, Hypercall
description: "Add a new hypercall to xen"
---
首先第一步便是给Xen中添加新的Hypercall, Hypercall、Hypervisor与GuestVM的关系与Systemcall、OS与Process的关系类似，如果GuestVM想要执行一些特权行为(如请求硬件)那么就要使用hypercall，控制权会转交给hypervisor，当hypervisor完成相关操作时会将控制权再交回GuestVM。
<!--more-->

Debug 系列:

* **Add New Hypercall to Xen**
* [Debug Xen on Physical Machine][5]
* [Xentrace][6]
* [Debug Key][16]

可以参考Chang Hyun Park的[此文](http://heartinpiece.blogspot.com/2014/01/adding-hypercalls-to-your-hvm.html)中添加Hypercall到hvm的描述。

# 修改Xen文件

假定XEN为xen源码的顶级目录，我的是**xen-4.4.3**

* 修改*hvm.c*
<br>在 *XEN/xen/arch/x86/hvm/hvm.c*中 查找**hvm_hypercall64_table, hvm_hypercall32_table**, 并添加自己的hypercall：
<br>{% img https://farm6.staticflickr.com/5591/30637571681_29d1bb806f_o_d.png hvm.c %}
<br>我添加了两个，本例以alice_op为例。 添加HYPERCALL(your hypercall name)，使用的hvm-ubuntu是32位的，不过为了64位的也能使用，两个表都添加上了。

* 修改*entry.S*
<br>在*XEN/xen/arch/x86/x86_64/entry.S*中查找 **ENTRY(hypercall_table)**，并添加自己的hypercall.(均以do开头)
<br>{%img https://farm6.staticflickr.com/5748/30637571631_9b4d29d6be_o_d.png entry.S(1) %}
<br>39号本身是给用户预留的，如果要添加多个顺次增加。
<br>之后，在下面的`hypercall_args_table`添加参数项
<br>{% img https://farm6.staticflickr.com/5670/30637571611_3478684e17_o_d.png entry.S(2) %}
<br>其中.byte后的数字表示有几个参数。为了简便，do_alice_op我们就不使用参数。

PS:如果Xen是在32位机子上的，则修改的是*XEN/xen/arch/x86/x86_32/entry.S*

* 修改*hypercall.h*
<br>在*XEN/xen/include/xen/hypercall.h* or *XEN/xen/include/asm/hypercall.h*(如果有架构依赖)中添加自己的hypercall声明:
<br>{% img https://farm6.staticflickr.com/5776/30637571781_44fec28bd0_o_d.png hypercall.h %}
<br>(我放到*asm/hypercall.h*中了)

* 添加hypercall number到*xen.h*
<br>在*XEN/xen/include/public/xen.h*中添加自己的hypercall 号:
<br>{% img https://farm6.staticflickr.com/5596/30093350774_beb3dc2305_o_d.png %}
<br>注释掉xc_reserved_op

* 添加hypercall实现
<br>hypercall如果是共用的功能，实现可以放到*XEN/xen/common/kernel.c*，与某些功能相关的话可以放到任何在*XEN/xen/arch/x86/*目录下的文件中，因为我之后要进行memory相关的学习，所以就放到*XEN/arch/x86/mm.c*里面了
<br>{% img https://farm6.staticflickr.com/5526/30090793353_e27d916b0f_o_d.png mm.c %}


#重新编译xen

`make xen -j8` 并安装 `make install-xen -j8`，之后重启后，现在就可以调用hypercall了

由于hypercall只能在内核态进行调用，所以可以放到systemcall中或者编译为kernel module在进行加载时调用；xen本身也提供了使用privcmd的工具能够来调用hypercall。下面使用hypercall和kernel module两种方式进行实现。

#Privcmd

```c privcmd.c
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <sys/ioctl.h>
#include <linux/types.h>
#include <fcntl.h>
#include <xenctrl.h>
#include <xen/sys/privcmd.h>
#include <string.h>
int main()
{
        int fd, ret;
        char * message;
        privcmd_hypercall_t alice_op={
                __HYPERVISOR_alice_op,
                {0,0,0,0,0}
        };
        fd = open("/proc/xen/privcmd", O_RDWR);
        if(fd<0){
                perror("can't open /proc/xen/privcmd");
                exit(1);
        } else {
                printf("privcmd's fd = %d\n", fd);
        }
        ret = ioctl(fd, IOCTL_PRIVCMD_HYPERCALL, &alice_op);
        printf("ret = %d\n", ret);
}
```
使用gcc -o test test.c进行编译后`sudo ./test`
<br>{% img https://farm6.staticflickr.com/5465/30090793803_a34dace13d_o_d.png %}
<br>使用`sudo xl dm`查看日志后，也可以看到hypercall被调用的日志
<br>{% img https://farm6.staticflickr.com/5593/30090793053_751203c7b6_o_d.png %}

#Kernel Module

###**在Debian中使用Kernel Module方式**

现在的Linux中已经有对于Xen的支持，所以在源码文件中是有xen.h这一文件的。这次我们修改Kernel Header文件来简化Kernel Module的编写。
<br>在linux-src-dir/xen/interface/xen.h中添加自己的hypercall声明
<br>linux-src-dir在debian上是在/usr/src中，其他的系统自己可以找一下。
<br>{% img https://farm6.staticflickr.com/5797/30608988582_363a9376a1_o_d.png %}
<br>之后在 linux-src-dir/arch/x86/include/asm/xen/hypercall.h中添加我们hypercall的声明。
<br>{% img https://farm6.staticflickr.com/5634/30688939396_22cc425afa_o_d.png %}
<br>(别人的图，忘截了)接下来就可以着手编写kernel module啦：

```cpp hypercall_ko_debian.c https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_3/hypercall_ko_debian.c source
#include <linux/module.h>
#include <linux/kernel.h>

#include <xen/interface/xen.h>
#include <asm/xen/hypercall.h>

static int init_hypercall(void)
{
	HYPERVISOR_alice_op();	
	printk("Hello Alice\n");
	return 0;
}

static void exit_hypercall(void)
{ }

module_init(init_hypercall);
module_exit(exit_hypercall);

MODULE_LICENSE("GPL");
```
需要注意的是，需要在最后加上MODULE_LICENSE("GPL")，否则有些lib不能使用就会报错。
<br>相应的makefile:
```basemake Makefile https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_3/Makefile source
obj-m += hypercall_ko_debian.o
all:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) modules

clean:
	make -C /lib/modules/$(shell uname -r)/build M=$(PWD) clean
```
现在就可以调用hypercall了~
# Note

1. 如果使用System Call来实现的话，需要修改内核源码。
2. Kernel Module的编程可以参考《Linux Kernel Module Programming Guide》 Peter Jay Salzman, Michael Burian, Ori Pomerantz

# Change Log

* Add Debug series (2017-05-11)
* Delete ubuntu-example (2016-12-26)

Ubuntu 的那个Kernel Module是用别人的，写的不是很简洁，而且不推荐在Module内再自己重新写Hypercall的相关操作等，所以就去掉了。



[3]: http://silentming.net/blog/2015/12/13/xen-log-3-add-hypercall/
[5]: http://silentming.net/blog/2016/09/18/xen-log-5-debug-xen/
[6]: http://silentming.net/blog/2016/09/21/xen-log-6-xentrace/
[16]: http://silentming.net/blog/2017/05/11/xen-log-16-debug-key/
