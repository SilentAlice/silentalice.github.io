---
layout: post
title: "KVM Log 4-kgdb KVM on Hikey960 (ARM64)"
date: 2017-08-16 22:44:28 +0800
comments: true
tags:
- virtualization
- linux
keywords: debug, qemu, kvm, kgdb, gdb, virtualization, linux, hikey960, arm64
description: "debug kvm via kgdb on hikey960"
---

kvm因为是和qemu一起跑的，想必网上搜出来的都是用QEMU-gdb去调试kernel, 本文记录的则是利用kgdb调试kvm module, 利用gdb调试qemu-kvm, 这样就能够在串口调试的基础上更方便的追踪程序的执行流了。

<!-- more -->

# Configuration

我用的是Hikey960的板子，里面有4个Cortex-A73和4个Cortex-A53的核，ARMv8, aarch64的架构。QEMU用的4.10.2

# Run qemu-KVM

需要注意的是目前Cortex-A73还没有被支持，所以直接跑的话如果vcpu被调度到A73的核上那么是会崩的, qemu会报不支持的cpu类型，所以我们要用`taskset`来指定线程被调度的核(0-3是A53, 4-7是A73)

```sh
taskset -c 0-3 qemu-system-aarch64 -m 1024 -M virt -cpu cortex-a53 -smp 4 -bios "bios.fd" -nographic -device -virtio-blk-device,drive-image -drive if=none,id=image,file="disk.img" -enable-kvm
```

# Debug QEMU-kvm

首先我们要下载qemu的源码并编译，之后只要正常用gdb调试程序一样即可，不过依旧要注意的是使用`taskset`来绑定核:

```sh
taskset -c 0 gdb --args qemu-system-aarch64 -m 1024 -M virt -cpu cortex-a53 -smp 4 -bios "bios.fd" -nographic -device -virtio-blk-device,drive-image -drive if=none,id=image,file="disk.img" -enable-kvm
```

这样启动后只要使用`run`就可以执行qemu-kvm了。

# Remote kgdb kvm module

与调试Xen遇到的情况一样，由于kvm是Hypervisor，所以不能放到qemu里面去调试，但是与Xen不同的是kvm属于Linux的一个module, 这样我们就可以借助kgdb来调试kvm module部分的代码:

参考了: [Reference](http://blog.chinaunix.net/uid-23366077-id-4711134.html)

* target ARM Board (e.g. Hikey960)
* Host LinuxPC (e.g. Ubuntu)
    target is connected to host via **Serial** (e.g. ttyAMA6 of target <---> ttyUSB0 of host)

在这之前请先保证Host可以通过串口连接target~

### Enable feature in kernel config:

```
CONFIG_KGDB = y
/* Enable kgdb support */

CONFIG_KGDB_SERIAL_CONSOLE = y
/* Allow serial to debug */

CONFIG_DEBUG_INFO = y
/* Including debug info */

CONFIG_FRAME_POINTER = y
/* Using frame pointer to maintain stack for traceback */

CONFIG_MAGIC_SYSRQ = y
/* We can use echo "g" > /proc/sysrq_trigger to break kernel */

CONFIG_DEBUG_RODATA = n
/* No readonly data */

CONFIG_DEBUG_SET_MODULE_RONX = n
/* No readonly kernel code */
```

Recompile kernel and reboot target
Reinstall kernel modules

* Target

```sh
# you can add linux_cmdline arg: kgdbwait kgdboc=ttyAMA6，115200
# to break kernel at startup

# or using:
echo ttyAMA6 > /sys/module/kgdboc/parameters/kgdboc

# then break kernel:
echo g > /proc/sysrq-trigger
```

我的板子用kgdbwait并没有什么效果..所以最后还是用了`sysrq-trigger`的方法来暂停kernel

* Host

```sh
apt-get install gdb-multiarch

gdb-multiarch vmlinux (cross-comiled)
#(gdb) set_remotebdevaud 115200
(gdb) target remote /dev/ttyAMA6

remote debugging using /dev/ttyS0
```

### Remote Cross-debugging pogram

You need to ensure target can connect to host via **Network**

* Target

```sh
gdbserver :port ./program args
```

* Host

```
gdb-multiarch ./program (cross-compiled)
(gdb) target remote target_IP:port
```

之后只要在Host上使用对应的gdb命令就可以调试运行在target上的Kernel(kvm module)了.

めでたしめでたし~


