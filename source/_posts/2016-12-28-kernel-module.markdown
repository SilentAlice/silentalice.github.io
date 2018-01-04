---
layout: post
title: "Kernel Module Using&Blacklisting"
date: 2016-12-28 14:48:57 +0800
comments: true
tags:
- tutorial
- linux
keywords: kernel module, linux
description: "kernel module demo"
---

本来觉得这个挺简单，不过发现每次写都会忘，这次就把常用的关于Kernel Module的操作和命令放一起做个小的总结吧~

<!-- more -->

# Why Kernel Module

Kernel Module的存在能使得对于操作系统的扩展更为灵活，将非kernel的功能放到module里，当kernel起来后再对它们进行加载。Linux自带的Module的源码在linux的源代码里面就有。通过查看`/lib/modules/linux-source-dir/modules.buildin`就能知道系统启动时会加载哪些modules。

# Write a Module

```c alice_module.c https://github.com/SilentAlice/BlogExamples/blob/master/kernel_module/alice_module.c source
#include <linux/module.h>
#include <linux/kernel.h>
#include <linux/types.h>

static int init_alice(void)
{
    
    pr_info("--------->Hello, This is Alice\n");
    return 0;
}

static void exit_alice(void)
{
   pr_info("================================>Exit Successfully\n");
}
module_init(init_alice);
module_exit(exit_alice);

MODULE_LICENSE("GPL");
```

一个Kernel Module写起来是十分简单的，这里`MODULE_LICENSE("GPL")`是声明该Module使用GPL License, 这样的话这个module就可以调用其他module中通过`EXPORT_SYMBOL_GPL(funname);`暴露出来的接口了。

> 如果不用`module_init/exit`来指定函数的话，就需要使用`init/exit_module`来写。

# Compile & Run

```sh
$make -C /lib/modules/3.16.0-4-amd64/build M=/home/alice/kernel_module modules

make[1]: Entering directory '/usr/src/linux-headers-3.16.0-4-amd64'
make[1]: Entering directory `/usr/src/linux-headers-3.16.0-4-amd64'
  Building modules, stage 2.
    MODPOST 1 modules
    make[1]: Leaving directory '/usr/src/linux-headers-3.16.0-4-amd64'
```

编译的之前需要先安装linux的头文件,之后正常编译就行。最终会生成一个\*.ko文件。

插入/删除Module:

```sh
$ sudo insmod alice_module.ko
$ sudo rmmod alice_module
```

查看dmesg:

```sh
$ dmesg
[84980.087670] --------->Hello, This is Alice
[85059.455243] ================================>Exit Successfully
```

如果要给module传入参数的话，引用相关的头文件并声明就好:

```c
#include <linux/moduleparam.h>

static int arg1;
static int arg2;

module_param(arg1, int, 0644);
module_param(arg2, int, 0644);
```

```sh
sudo insmod arg1=233 arg2=245
dmesg | tail

[885090.422275] ================================>Exit Successfully
[885103.935079] --------->Hello, This is Alice
[885103.935081] param arg1:233, arg2:245
```

# Commands

其他的常用命令:

* 安装Linux自带的module: modprobe
```sh
$ sudo modprobe -v i8k
insmod /lib/modules/3.16.0-4-amd64/kernel/drivers/char/i8k.ko
```

`modprobe` 与 `insmod`的不同在于，`modprobe`会查找module依赖的其他module, 并先加载被依赖的module. 但是相对的，`modprobe`只能加载内核里的标准module, 我们自己写的还是要用`insmod`

* 查看module信息: modinfo
```sh
$ sudo modinfo alice_module.ko
filename:       /home/alice/kernel_module/alice_module.ko
license:        GPL
depends:
vermagic:       3.16.0-4-amd64 SMP mod_unload modversions
```

* 列出所有modules: lsmod
```sh
$ lsmod
Module                  Size  Used by
alice_module           12385  0
binfmt_misc            16949  1
cfg80211              413730  0
rfkill                 18867  1 cfg80211
...
```

* 删除Linux自带module: modprobe -r / rmmod
```sh
$ sudo modprobe -v i8k
```

  或者

```sh
$ sudo rmmod i8k
```

# Blacklisting

Linux 启动的时候会自动加载一些Module，如果我们不想让它加载某些module的话就要用黑名单了:)

#### Blacklist
在`/etc/modprobe.d/fbdev-blacklist.conf`中添加要屏蔽的module名字即可

#### FakeInstall
创建文件`/etc/modprobe.d/<modulename>.conf` 并写入`install <modulename> /bin/true`.


# ChangeLog

* 2017-09-22

    Add module_param
