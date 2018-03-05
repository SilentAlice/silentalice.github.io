---
layout: post
title: "Xen Log 5-Debug Xen on Physical Machine"
date: 2016-09-18 16:22:31 +0800
comments: true
tags: virtualization
keywords: Xen, debug, serial, virtualization
---

一开始的时候我们是在虚拟机里面调试Xen的，但是因为Qemu是不能模拟EPT的，所以在虚拟机里面起一个Xen，这个Xen的功能非常受限(不能使用EPT)。而且当时项目在虚拟机里面能跑，一到真机上就跑不了，所以不得不用真机来调，这里记录一下调试Xen的环境搭建。

<!-- more -->

Debug 系列:

* [Add New Hypercall to Xen][3]
* **Debug Xen on Physical Machine(本篇)**
* [Xentrace][6]
* [Debug Key][16]

# Log

Xen的Log是记录在内存中的，所以不能再崩了之后回到Linux里面去翻log, 而且如果Hypervisor在初始化Xen之前就崩掉的话，我们是获取不到任何信息的，所以还是老老实实按老方法用串口来吧..

# rs232串口

使用rs232串口来进行调试，需要注意一点，Xen是不能使用USB来进行调试的！**For serial console you CAN'T use USB-serial dongles on the computer running Xen! (usb-serial dongles are not seen as real serial ports by the hardware or Xen, so usb-serial ports are NOT available in the beginning of boot process).**[(1)][1]

还有一点需要注意的是串口线是有延长线和交叉线的，交叉线的2/3号口是交叉的，一个输入一个输出，可以用根铜线来测试.. 两个电脑相连一般是交叉线。

# USB转rs232

用来读串口的机子可以使用USB转rs232串口线来读数据(毕竟笔记本和比较新的台式机一般是没有串口卡的)

# 测试机minicom

Linux上读写串口可以用非常好用的minicom

```sh
sudo minicom -s [-C filename]
#-s is setup
#-C is capturefile used for log
```

{% img /images/20160920debugxen1.png Open minicom -s %}

基本上打开minicom -s后 根据里面的提示就可以进行设置，在Linux中USB-rs232的设备文件是`/dev/ttyUSB0`, 波特率这些根据需要设定:

{% img /images/20160920debugxen0.png config %}`

设置完后Exit就会出现这样的画面：

{% img /images/20160920debugxen2.png minicom %}

这个时候有任何信息在串口的另一端发过来，这边都可以通过USB-rs232读进来，并且在这个页面我们也可以直接输入信息发送过去(默认自己输入的内容自己这边是带回显的，可以设置成不回显)

**配置的时候请自行dmesg查自己串口的信息去配!**<br>
不是所有的都是`ttyUSB0`的好么.

# Restart Xen only ONCE[(2)][2]

在之前安装Xen的时候我们设置了grub自动启动Xen, 这里由于Xen可能会崩溃，所以我们需要的是仅在下一次启动Xen, 这样崩溃后会自动重启到普通的Linux

#### With GRUB v1
在 `/boot/grub/menu.list` set "default" to "saved". For example:

```sh
default         saved           ## important.
timeout         5color           cyan/blue white/blue

title           Debian GNU/Linux, kernel 2.6.18-4-k7
root            (hd0,2)

kernel          /boot/vmlinuz-2.6.18-4-k7 root=/dev/sda3 ro
initrd          /boot/initrd.img-2.6.18-4-k7

title           WinXP
root            (hd0,0)
makeactive
chainloader     +1
```
之后运行`grub-install`来更改设置

#### With GRUB v2

设置`GRUB_DEFAULT` 为**saved**, 如下:

```sh /etc/default/grub
# If you change this file, run 'update-grub' afterward to update
# /boot/grub/grub.cfg.
# For full documentation of the options in this file, see:
#   info -f grub -n 'Simple configuration'

GRUB_DEFAULT=saved      ## important.
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
```

接下来运行` update-grub` 来更新配置。并运行`grub-set-default 0`来将默认启动设置为第一项

每次我们都可以通过以下命令来启动指定的系统

```sh
sudo grub-reboot 2 #Restart to xen
sudo reboot
# or
sudo grub-reboot 0 #Restart to Linux
sudo reboot
```

如果想启动到Submenu的话，使用`Menu>submenu`即可, 有的系统可能需要转义符。

```sh
sudo grub-reboot 3\>0 # Restart to Xen options, first submenu
#or 
sudo grub-reboot "3>0"
```

# Config Xen

硬件的准备完成后，我们需要配置Xen和Dom0将信息输出到串口:

**配置的时候请自行dmesg查自己串口的信息去配!**<br>
**配置的时候请自行dmesg查自己串口的信息去配!**<br>
**配置的时候请自行dmesg查自己串口的信息去配!**

* `loglvl=all, guest_loglvl=all`: 开启所有log, 可以根据需要选择level
* `com1=115200, 8n1, 0xe020`: Xen会将识别到的串口认为是com1, 而真实的串口需要我们在linux中通过dmesg查: (没启动前Xen时的linux, 启动Xen之后可能查不到)

```sh
sudo dmesg | grep tty

[    0.000000] console [tty0] enabled
[    3.494349] 00:05: ttyS0 at I/O 0x3f8 (irq = 4, base_baud = 115200) is a 16550A
[    7.807560] usb 1-1.3: pl2303 converter now attached to ttyUSB0
```

上面这种就属于启用的是ttyS0, 0x3f8是串口的地址, 中断为4, 波特率是115200, 因此com1在配置的时候就需要配置为`com1=115200, 8n1, 0x3f8`, `8n1`指的是数据位为8，无校验位，停止位为1(一般默认这样就行). 因此这里就是告诉Xen com1真实对应的串口地址在哪里。(我用的是ttyS2, 地址是0xe020)

* `sync_console`: 保证输出是同步的，以防一些内容在xen crash之前打不出来
* `console_to_ring`: 将Guest的log同步到dom0中打印输出.
* `console=com1,vga`: 将终端连到com1上，这样我们就可以通过串口输入用户名密码登陆

`GRUB_CMDLINE_LINUX`的配置主要是将dom0的信息通过Xen的串口输出.

* `console=hvc0 earlyprintk=xen`:是将dom0的log通过xen输出, xen对上层虚拟了一个hvc0, 所以dom0用这个就可以将输出打到Xen的串口中。
* `console=ttyS2, 115200n8`: 这里`ttyS2`同样根据自己查出来的结果改，目的是在不启动Xen的情况下linux的log通过串口输出。

```sh /etc/default/grub
GRUB_CMDLINE_XEN="loglvl=all guest_loglvl=all com1=115200,8n1,0xe020 console=com1,vga com0_mem=4096"
# This can guarantee sync output when using `printk`
# GRUB_CMDLINE_XEN="loglvl=all guest_loglvl=all sync_console console_to_ring com1=115200,8n1,0xe020 console=com1,vga com0_mem=4096"

GRUB_CMDLINE_LINUX_DEFAULT="console=tty0 console=ttyS2,115200n8"
GRUB_CMDLINE_LINUX="console=hvc0 earlyprintk=xen"
```

loglvl在Xen Log4中我已经提到过，能够决定哪些log被显示; CMDLINE\_XEN 中Xen有一个build-in的串口COM1, 所以我们将Console连到com1即可获取到Xen的输出。

当LINUX作为dom0运行在Xen上的时候，需要使用hvc0(Hypervisor Virtual Console)进行输出。为了保证dom0不至于因为console没有初始化好而使得crash过早没有输出，我们可以打开earlyprintk, 这样console会提前进行初始化，并将输出交给xen, xen会将dom0的输出一并输出到com1。

```sh
sudo update-grub
```

现在就可以在测试机上调试被测试机的Xen了。

# Config Guest

如果想要让Guest能够通过 `xl console domid`来进行交互的话，需要在Guest的启动参数中将Console连到ttyS0:

```c
GRUB_CMDLINE_LINUX="console=ttyS0"
```

这样就可以在被测试上通过串口来调试Guest了。

# Tips
想关掉X11也有很多方法，ubuntu上只要在LINUX_CMDLINE制定成text就行了，Debian的话把` /etc/X11/default-display-manager`里面设置成`/bin/true`就可以了，不过比较暴力..

不过如果Hypervisor因为死循环而挂那了...除非有watchdog(我现在还没有启动起来过), 要不然就只能用一个板子连个跳线过来物理重启了...

## Misc

### Remote Force Restart

有的时候在家，调Bug的时候可能实验室的测试机会死循环，这种情况下我们根本发不过去指令，目前我们用的方法比较笨。

* 在BIOS里面， Power management中设置AC BACK (接通电源时) 里面设置后面的选项为"**Always ON**"，这个每次有电源接通时电脑就会自动启动。
* 用能远程断电的电源(小米智能插座等，其他的继电器等)，远程关掉电源再接上，电脑就会自动接电。

这样电脑会重启到正常的Linux中，然后再用上面的方法就可以继续调试了。

## Changelog:

* 2017-05-11: Add debug series
* 2017-03-28: Although I addressed to grep to find tty config...But it seems readers will ignore it... Address it three times:)
* 2017-03-21: Add detailed description of cmdline config
* 2017-01-08: Add remote Force Restart





[1]: https://wiki.xenproject.org/wiki/Xen_Serial_Console
[2]: https://wiki.debian.org/GrubReboot 
[3]: http://silentming.net/blog/2015/12/13/xen-log-3-add-hypercall/
[5]: http://silentming.net/blog/2016/09/18/xen-log-5-debug-xen/
[6]: http://silentming.net/blog/2016/09/21/xen-log-6-xentrace/
[16]: http://silentming.net/blog/2017/05/11/xen-log-16-debug-key/

