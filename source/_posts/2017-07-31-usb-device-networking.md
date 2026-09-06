---
layout: post
title: "Virtualize USB as Network Card"
date: 2017-07-31 17:13:54 +0800
comments: true
tags:
- tutorial
- linux
- record
keywords: usb, virtualize, g_ether, hikey, network
---

开发板一般最稳定的接口就是USB串口，而Linux中`g_ether` module允许我们将usb虚拟化为网卡，
这样我们的开发板就可以通过这块虚拟网卡借助host PC的代理连接到外部互联网。

<!-- more -->

本文参考了: [How to USB device networking][1]

# Compile linux kernel with `USB_ETH` Support

在交叉编译arm的内核时我们需要配置kernel，开启USB\_ETH支持：

默认是不支持的，根据搜索结果开起来就可以了

```sh
Symbol: USB_ETH [=n]                                                             
 Prompt: Ethernet Gadget (with CDC Ethernet support)
 
Symbol: USB_GADGETFS [=m]
  Prompt: Gadget Filesystems
```

# Enable g\_ether

###  Device

通过指定参数`dev_addr`和`host_addr`可以制定虚拟网卡在device和host PC显示的MAC地址，方便我们host PC配置IP.

```sh
sudo modprobe g_ether dev_addr="00:FF:FF:FF:FF:FF" host_addr="5a:77:1e:af:8e:9e"
```

如果这个mod是自动加载的，可以在kernel启动参数里面加上`g_ether.dev_addr=XX:XX:XX:XX:XX:XX g_ether.host_addr=XX:XX:XX:XX:XX:XX`


成功之后使用`ifconfig usb0`将可以看到相应的网卡信息，输出类似于:

```sh
usb0      Link encap:Ethernet  HWaddr BE:B5:85:EF:48:33  
          BROADCAST MULTICAST  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:0 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:0 (0.0 B)  TX bytes:0 (0.0 B)
```

为其分配一个IP(这里是`TARGET_USB_IP`)，并添加路由

```sh
HOST_USB_IP=10.0.1.1
TARGET_USB_IP=10.0.1.2
ifconfig usb0 $TARGET_USB_IP netmask 255.255.255.0
route add default gw $HOST_USB_IP
route

Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
10.0.1.0        *               255.255.255.0   U     0      0        0 usb0
default         10.0.1.1        0.0.0.0         UG    0      0        0 usb0
```

### host PC

当板子上的虚拟网卡成功配置后，hostPC的log中会有相应的信息:

```sh
kernel: [1638241.377831] usb 1-4.4.2: new high speed USB device using ehci_hcd and address 47
kernel: [1638241.510787] cdc_subset: probe of 1-4.4.2:1.0 failed with error -22
kernel: [1638241.513437] cdc_subset 1-4.4.2:1.1: usb0: register 'cdc_subset' at usb-0000:00:02.1-4.4.2, Linux Device, 82:13:56:20:b4:cb
kernel: [1638241.513490] usbcore: registered new interface driver cdc_subset
kernel: [1638241.533442] cdc_ether: probe of 1-4.4.2:1.0 failed with error -16
kernel: [1638241.533619] usbcore: registered new interface driver cdc_ether
```

也能看到相应的网卡信息:

```sh
ifconfig usb0

usb0      Link encap:Ethernet  HWaddr 82:13:56:20:b4:cb  
          inet6 addr: fe80::8013:56ff:fe20:b4cb/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:0 errors:0 dropped:0 overruns:0 frame:0
          TX packets:1 errors:0 dropped:0 overruns:0 carrier:0
          collisions:0 txqueuelen:1000 
          RX bytes:0 (0.0 B)  TX bytes:78 (78.0 B)
```

这个时候只要为host PC的这块网卡分配一个IP即可与板子通信

```sh 
HOST_USB_IP=10.0.1.1
sudo ifconfig usb0 $HOST_USB_IP netmask 255.255.255.0
route

Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
10.0.1.0        *               255.255.255.0   U     0      0        0 usb0
...
link-local      *               255.255.0.0     U     1000   0        0 eth0
default         gw              0.0.0.0         UG    100    0        0 eth0
```

利用[上一篇][2]所述的代理, 板子只要使用`HOST_USB_IP:port`即可利用host PC代理到外部网络。

引用的链接里还有NFS和Domain Server的相关配置，因为我没怎么用到就省略啦。

# Note

host PC的路由表几分钟就会刷新，所以为了保证这条信息一直有，在相关配置文件添加这个ip比较好，如果有图形化界面的话 在网络设置里面为这块虚拟网卡分配相应的IP即可，由于我们配置的这块虚拟网卡是固定MAC地址的，因此配置一次后以后只要两者相连，IP就会自动分配了。






[1]: https://developer.ridgerun.com/wiki/index.php/How_to_use_USB_device_networking
[2]: http://silentming.net/blog/2017/07/30/cntlm-proxy-on-linux/
