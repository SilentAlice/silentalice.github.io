---
layout: post
title: "Xen Log 2-Build HVM DomainU"
date: 2015-11-29 21:35:45 +0800
comments: true
tags:
- tutorial
- virtualization
keywords: Xen, Hvm, DomainU, Virtualazation, Ubuntu
---
经过[上一篇](http://silentming.net/blog/2015/11/28/xen-log-1-running-xen/)的步骤之后，Xen已经运行并且将原来的OS作为Domain0启动了起来。在文章末尾提到过HVM与PV，本篇会使用建立一个硬盘镜像并安装Ubuntu14.04，最后以HVM启动。

可以参考[这里](http://www.virtuatopia.com/index.php/Building_a_Xen_Virtual_Guest_Filesystem_on_a_Disk_Image_%28Cloning_Host_System%29)，这是通过克隆自己的host OS来作为Guest Domain的。不过我弄完后磁盘配置好像出了点问题，因此就重新安装一个ubuntu来使用。
<!-- more -->

###创建硬盘镜像

创建一个10G左右的磁盘镜像：

     dd if=/dev/zero of=xen-ubuntu.img bs=1024k seek=10240 count=0

跳过10240M 左右的空间，基本上可以建立一个10G的磁盘镜像。

创建文件系统：

     mkfs -t ext3 xen-ubuntu.img

{% img https://farm6.staticflickr.com/5523/30688939036_2547e4f0ce_o_d.png %}

###创建虚拟机的配置文件：

配置文件的详细语法见[XL Configure File Syntax](http://xenbits.xen.org/docs/unstable/man/xl.cfg.5.html)
<br>hvm的配置文件(*hvm-ubuntu.cfg*)如下：

```cfg hvm-ubuntu.cfg https://github.com/SilentAlice/BlogExamples/blob/master/Xen_Log_2/hvm-ubuntu.cfg source
name="hvm-ubuntu"
builder = 'hvm'
vcpus = 1
memory = 512
disk=['file:/home/alice/Xen/Img/xen-ubuntu.img,hda,w', 'file:/home/alice/Xen/ISO/ubuntu14.iso,hdc:cdrom,r']
boot="dc"
```
详细的配置文件见附件(附件中boot顺序已经改为从disk启动)，根据自己的配置进行修改。

###启动GuestVM

```sh
    sudo xl create hvm-ubuntu.cfg
    vncviewer localhost:0
```
vncviewer 可以观看我们的虚拟机，如果开启多个，则为`localhost:1, localhost:2 ...`

正常安装，之后修改配置文件为从硬盘启动即可

{% img https://farm6.staticflickr.com/5689/30688939186_2479ecabcc_o_d.png %}

使用`xl list`查看，可以发现hvm-ubuntu已经启动：

{% img https://farm6.staticflickr.com/5563/30608988462_8691907aed_o_d.png %}

### Network

如果要为Guest配置网络的话可以使用网桥, Ubuntu的可以直接参考: http://ask.xmodulo.com/configure-linux-bridge-network-manager-ubuntu.html

Debian默认用的是bridge-utils, Ubuntu的话也可以先安装下, 之后在配置文件里面加一下，最后重启网络服务就行。

```sh
sudo apt-get install bridge-utils

# Add config to /etc/network/interfaces
auto xenbr0
iface xenbr0 inet dhcp
    bridge_ports eth0

# Comment original eth0 and restart networking service
sudo service networking restart

# Now we can add network config for our guest in cfg file,
add vif=["bridgename"] (see the source)
```

### Misc

开机如果因为找一个module需要大量1Min30s的话，可以取消它的开机自动probe:

```sh
nano /etc/modprobe.d/blacklist.conf
blacklist i2c-piix4
```

# ChangeLog

* 2017-05-07: Add bridge in Ubuntu
