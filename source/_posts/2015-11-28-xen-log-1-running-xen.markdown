---
layout: post
title: "Xen Log 1-Running Xen"
date: 2015-11-28 15:55:07 +0800
comments: true
tags:
- tutorial
- virtualization
keywords: Xen, Virtualization, 虚拟化
description: "How to run xen"
---
之后的一段时间里面将会围绕Xen开展工作，所以这一系列博客就记录一下学习的过程和问题。本篇介绍如何从源码编译并运行Xen。主要部分都是从大哥那里现学现卖的:)
[原文地址](http://ytliu.info/blog/2015/02/02/running-xen-on-xen%3Axende-qian-tao-xu-ni-hua-ji-zhu/)
<br>[官网教程](http://wiki.xenproject.org/wiki/Xen_Project_Beginners_Guide)也介绍的比较详细。
<br>[相关书籍](http://wiki.xenproject.org/wiki/Books)里面介绍了许多相关的书能帮助学习和开发。<!-- more -->

#直接安装

据说很简单

```sh
sudo aptitude -P install xen-linux-system
sudo dpkg-divert --divert /etc/grub.d/08_linux_xen --rename /etc/grub.d/20_linux_xen
sudo update-grub # regenerate the /boot/grub/grub.cfg file
```
#从源码编译

遇到什么问题的话可以参考[官网指导](http://wiki.xenproject.org/wiki/Compiling_Xen_From_Source)

```sh
$ sudo aptitude build-dep xen
$ git clone git://xenbits.xen.org/xen.git
$ cd xen
$ ./configure
$ make xen

$ make tools
$ sudo make install-xen
$ sudo make install-tools
$ sudo dpkg-divert --divert /etc/grub.d/08_linux_xen --rename /etc/grub.d/20_linux_xen
$ sudo update-grub
```
安装完成以后，在`/boot` 下会有xen.\*.gz的镜像

{% img https://farm6.staticflickr.com/5817/30608988082_d3bed91705_o_d.png %}

* *xen-4.4.3.gz*是我安装的xen的镜像(我使用的是4.4.3版本)
* *vmlinuz-3.16.0-4-amd64* 是Domain0的镜像
* *initrd.img-3.16.0-4-amd64* 是initrd(initial ram disk)

**启动选项(Optional)**

`/boot/grub/grub.cfg`会有 with xen的启动选项：

{% img https://farm6.staticflickr.com/5715/30608987962_19878e0a1a_o_d.png %}

* *grub.cfg* 是根据`/etc/default/grub`生成的， 如果需要修改启动顺序的话，可以在`/etc/default/grub`中进行修改，查看一下想要默认启动的项是第几个(从0开始)，在grub中将`set default=n`设置为需要的即可。

* 也可以直接下面的命令修改

```sh
sudo dpkg-divert --divert /etc/grub.d/08_linux_xen --rename /etc/grub.d/20_linux_xen
```
这里数字越小优先级越高。

* 完成后使用 `sudo update-grub`来更新grub，就可以将其设为默认启动

**启动服务**

重启后，默认情况下服务时没有开启的，手动开启:

```sh
sudo service xendomains start
sudo service xencommons start or restart
```
或者

```sh
sudo ./etc/init.d/xendomains start
sudo ./etc/init.d/xencommons start / restart
```

如果之后让它自动加载这两个服务的话:

```sh
sudo update-rc.d xencommons defaults 19 18
sudo update-rc.d xendomains defaults 21 20
```

重启后 使用`$ sudo xl list` 可以看到当前运行的虚拟机，而原本的系统会以Domain0启动

{% img https://farm6.staticflickr.com/5467/30608988202_4195292348_o_d.png %}

至此，已经成功将Xen跑了起来

* 如果显示缺少lib 使用`ldconfig`命令刷新链接
* 之后重启xen的相关服务

接下来就可以启动虚拟机了，使用的还是xl的工具，同时准备好相应的iso镜像。
<br>关于虚拟化，有两个概念：**半虚拟化(para-virtualization)**以及**全虚拟化(full virtualization)**详细的可以参考：

[The Paravirtualization Spectrum, part 1: The Ends of the Spectrum](https://blog.xenproject.org/2012/10/23/the-paravirtualization-spectrum-part-1-the-ends-of-the-spectrum/)

[The Paravirtualization Spectrum, Part 2: From poles to a spectrum](https://blog.xenproject.org/2012/10/31/the-paravirtualization-spectrum-part-2-from-poles-to-a-spectrum/)

这部分不在讨论范围，具体的可以参考我师兄的blog(原文那里)

***

### **Note**

从CD启动虚拟机：[官网指导](http://www.virtuatopia.com/index.php/Building_a_Xen_Virtual_Guest_Filesystem_on_a_Disk_Image_%28Cloning_Host_System%29)
<br>如何启动DomainU：[How to Do](http://wiki.xenproject.org/wiki/Category:HowTo)

### **问题**

在安装过程中可能遇到以下问题：

* 在Debian启动时卡到界面上进不去
<br>这种要安装Linux-firmware-nonfree，原因是少了nonfree firmware里的显卡相关驱动

* 全虚拟化模式下启动客户端虚拟机发生重启:
<br>可以查看下/proc/cpuinfo里面是不是有vmx或svm的flag，只有CPU支持vmx(Intel)/svm(AMD)的才能使用全虚拟化。如果CPU不支持，或者BIOS里没打开的话是不行的
###**找不到依赖**

* Unable to find xgettext:

        sudo aptitude install gettext

* Unable to find as86:

       sudo aptitude install bcc

* Unable to find iasl:

       sudo aptitude install iasl

* Unable to find yawl:

       sudo aptitude install libyajl-dev

       sudo aptitude install libpixman-1.dev

* Unable to find pixman-1:

       sudo aptitude install libpixman-1.dev

* cdefs.h not found: (or compile x86 program on x64)

       sudo apt-get install gcc-multilib

       sudo apt-get install g++-multilib

* zlib.h not found

       sudo apt-get install zlib1g-dev

* openssl/md5.h not found

       sudo apt-get install libssl-dev

* uuid.h not found

       sudo apt-get install uuid-dev

* -lncurses not found

       sudo apt-get install libtool

       sudo apt-get install lib32ncurses5-dev

* Python.h not found

       sudo apt-get install python-dev

* glib2.12 required to compile qemu

  参考[glib](http://www.linuxfromscratch.org/blfs/view/6.3/general/glib2.html)，不用配置，直接安装，之后再安装这些：

       make stubdom

       sudo make install-xen

       sudo make install-tools PYTHON_PREFIX_ARG=

       sudo make install-stubdom

* [standards.info] error 1

       sudo apt-get install texinfo

* yacc not found

       sudo apt-get install byacc flex

* fig2dev not found

       sudo apt-get install transfig

* Unable to find a suitable curses library

       sudo aptitude  install libncurses5-dev

* glib.h
  
       install libgtk2.0-dev

## ChangeLog

* 2017-05-03: Add `update-rc.d`
