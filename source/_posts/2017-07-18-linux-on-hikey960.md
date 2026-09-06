---
layout: post
title: "Run Debian9 Linux on Hikey960"
date: 2017-07-18 20:05:08 +0800
comments: true
tags:
- tutorial
- linux
- record
keywords: hikey960, linux, arm64, uefi
---

Hikey960目前来说是个比较新的板子，网上大部分教程都是针对Hikey，而Hikey960和Hikey的
差别比较大，现有的教程也比较杂，所以这里记录一下自己踩过的小坑。

Curently, Hikey960 is not fully supported by debian9. Tutorials and docs are all about hikey (620).
This post records the process about running Debian 9 on Hikey960.

<!-- more -->

(Reference)本文参考了: [HikeyUEFI][18], [ATF-UEFI-build-from-source][17]

# Cross Compilation Environment

先给下载链接: [aarch64-linux-gnu-5.3][1] <br>
Download link: [aarch64-linux-gnu-5.3][1]

注意请用5.3, 5.0以下的一会我们编译的时候会有一些参数5.0以下还不支持，我用5.4的时候会遇到一个[bug][2], 有兴趣的可以看看，一个宏展开的时候较新的gcc会报错。5.3是可以的..<br>
Note that only gcc 5.0 is usable while there are some bugs (See [this][2] for details) in 5.4. What I used is gcc 5.3.

下载解压后把bin目录加入到自己的path中就可以了。<br>
Add `bin` to your $PATH variable to use these cross-compilation tools.

# Hikey960 Introduction

[这里][4]能够看到板子的简单介绍，我们需要注意的只有不同模式如何调:<br>
[This page][4] shows some introduction about hikey960. What we need to know is how to config it into different mode:

|--------Mode--------|---Link Switch---|---Auto Power---|---Fastboot---|---Recovery---|
|:---|:---|:---|:---|:---|
|Auto Power up    |link 1-2/Switch 1|closed/ON|closed/ON|closed/ON|
|Recovery |link 3-4/Switch 2|open/OFF|open/OFF|closed/ON|
|Fastboot |link 5-6/Switch 3|open/OFF|closed/ON|open/OFF|

还有需要注意的是 如果是跳线来连的属于Ver1, 如果是直接用板子背面开关调的属于Ver2
<br>The Ver2 correspons to switches and jumper is Ver1.

这里可以看到每个signal在板子上的意义和位置: [Manual][3]
<br>This [Hardware User Manual][3] shows the meaning of different pins and components of this board.

可以连接`UART_TXD`, `UART_RXD`, `GND` 用TLL to RS232，再转个USB就能通过串口来调试了, 板子的信息输出可以通过这个来看，本身烧板子用的是type-c的口。
UART的接线可以看[Understanding and Connecting UART Devices][6]
<br>You can use a TTL to RS232 convertor and connect to corresponding pins to get serial (UART) output. (Or buy an integrated one)
The connecting methods are shown on [Understanding and Connecting UART Devices][6]

而关于如何观察串口输出和调试，可以参考之前的这篇:[Debug Xen on Physical Machine][5]
<br>Using minicom or screen on your host machine to read the output

# Build UEFI loader

我们的loader直接从源码编译，(现有的bin很多都是针对Hikey其他板子的，960没法直接拿来用)
<br> Compile loader from source. (Currently, it may be a little difficult to find one)

Download links:

* [ARM Trusted Firmware][7]
* [EDK2][8]
* [OpenPlatformPkg][9]
* [l-loader][10]
* [uefi-tools][11]
* [atf-fastboot][12]

下载到同一个目录，记为`BUILD_PATH`
<br> Move them to one dir. The `path/to/this/dir` is remembered as `BUILD_PATH`

```sh
cd ${BUILD_PATH}/edk2
ln -s ../OpenPlatformPkg # Link file must be named as this, will be used when compile edk2

# 前面提到过的，如果板子是Ver1, 需要在uefi-tools/platform.config中去掉下面这句:
# Ir your board is Ver1, remove following one in your uefi-tools/platform.config
BUILDFLAGS=-DSERIAL_BASE=0xFDF05000

BUILD_OPTION=DEBUG
export AARCH64_TOOLCHAIN=GCC5
export UEFI_TOOLS_DIR=${BUILD_PATH}/uefi-tools
export EDK2_DIR=${BUILD_PATH}/edk2
EDK2_OUTPUT_DIR=${EDK2_DIR}/Build/HiKey960/${BUILD_OPTION}_${AARCH64_TOOLCHAIN}
cd ${EDK2_DIR}

# Build UEFI & ARM Trust Firmware
# Again, please use gcc-5.3 to build
${UEFI_TOOLS_DIR}/uefi-build.sh -b ${BUILD_OPTION} -a ../arm-trusted-firmware hikey960

# Generate l-loader.bin
cd ${BUILD_PATH}/l-loader
ln -sf ${EDK2_OUTPUT_DIR}/FV/bl1.bin
ln -sf ${EDK2_OUTPUT_DIR}/FV/fip.bin
ln -sf ${EDK2_OUTPUT_DIR}/FV/BL33_AP_UEFI.fd
python gen_loader_hikey960.py -o l-loader.bin --img_bl1=bl1.bin --img_ns_bl1u=BL33_AP_UEFI.fd

# Generate partition table (You can download from net directly)
# See generate_ptable.sh to config your own ptable
PTABLE=linux-32g SECTOR_SIZE=4096 SGDISK=./sgdisk bash -x generate_ptable.sh
```

PTABLE这一步可以根据自己需要修改`generate_ptable.sh`中的分区，比如如果使用的Debian的镜像的话4G的system
分区是不够的，如果板子的Flash足够大也可以自己把分区分的更大一些方便之后的使用。
<br> Generate your own partition table via `generate_ptable.sh`(in l-loader dir). For example, 4G flash storage is not
enough for debian 9. My system partition is 20G.

# Flash Loader

将板子调成recovery mode, (1, 3 ON, 2 OFF), 下载[tools-images-hikey960][13]
<br> Config board to recovery mode (1, 3 ON, 2 OFF), Download [tools-images-hikey960][13]

修改config: 把我们自己的l-loader替换原来的
<br> In tools-images-hikey960 dir, modify config and using our compiled l-loader.bin to replace original one:

```sh
./sec_usb_xloader.img 0x00020000
./sec_uce_boot.img 0x6A908000
./l-loader.bin 0x1AC00000
```

Linux的话要移除modemmanger: `sudo apt-get purge modemmanger`
<br> If you are using a linux host, please remove `modemmanger` otherwise there may be one bug.

利用tools的工具来刷我们的l-loader: `sudo ./hikey_idt -c config -p /dev/ttyUSB1`, (这个ttyUSB是type-c所连的那个)
这个刷成功后，设备就会开始跑fastboot程序，我们就可以开始刷其他的东东了:
<br> Using tools in this dir to flash our new loader: `sudo ./hikey_idt -c config -p /dev/ttyUSB1`, (ttyUSB1 is the one your type-c is connecting).
After this step, the board will run a fastboot program which means we can flash other files.


l-loader, fip这两个和板子关系比较密切，不同板子版一样，ptable则根据我们flash的容量来自己设置,
boot分区我们会刷uefi的程序， system分区则会刷我们的linux所在的文件系统。
<br> l-loader, fip is board associated. Usually, different boards has different loader and fip. ptable is generated by ourselves.
boot partition will be flashed with uefi loader and system partition will contain our Debian 9.

目前支持的Linux只有[rpb][14], 下载我们需要的dtb (device tree blob), uefi.img, 和 rootfs.img
<br> As currently only [rpb][14] linux supports hikey960, first, we will flash its dtb (device tree blob), uefi.img and rootfs.img

```sh
# Using our own ptable
$sudo fastboot flash ptable ptable.img
$sudo fastboot flash xloader sec_xloader.img

# Using compiled l-loader
$sudo fastboot flash fastboot l-loader.bin

# Using Compiled fip.bin
$sudo fastboot flash fip fip.bin
$sudo fastboot flash boot uefi.img
$sudo fastboot flash system rootfs.img

# Only Android will use
$sudo fastboot flash cache cache.img
$sudo fastboot flash userdata userdata.img
```

Reboot

Now you can login into this rpb linux using default accout `linaro`

# Run Debian 9 on hikey960

To run a debian 9, we will replace `boot` and `kernel image` of *debian 9 for hikey*. 

Download Debian 9 rootfs: [Debian 9 for hikey][19] (`hikey-jessie_developer_20151130-387-8g.emmc.img.gz` as an example)

The images are all **sparse image**, which means you need [simg2img][20] to convert them.


### Replace boot and kernel image

You may found that `uefi.img` from rpb linux will read configuration from `system partition/boot/grub/grub.cfg`. 
So, just mount this debian image and replace `boot` dir with the one from `rpb`.

Then you need new linux kernel image and dtb. Compile it from [source][21]. (The hieky960-v4.9 branch in this tree)

Get dtb from `arch/arm64/boot/dts/hisilicon/hi3660-hikey960.dtb` You can get this when you cross-compile this linux.

Put your new kernel image (in `arch/arm64/boot/Image`) in your debian image and modify grub.cfg to boot this new kernel.

Reboot!

### Some issues

1. Now you can boot into your debian linux. As this debian rootfs is 8G, you may use `checkfs` to repair the filesystem to 20G.
2. For connecting to network, you can flash wifi module or [virtualize type-c usb to netcard][22].
3. Now just modify your `source.list` and `apt-get` your needed pacakages.



# ChangeLog

* 2017-09-10
  
    添加Debian 9支持

* 2017-07-31
    
    添加prm_table.sh的说明，删除无用的ToDo.


[1]: http://releases.linaro.org/components/toolchain/binaries/5.3-2016.05/aarch64-linux-gnu/
[2]: https://github.com/ARM-software/tf-issues/issues/401
[3]: https://github.com/96boards/documentation/blob/master/ConsumerEdition/HiKey960/HardwareDocs/HardwareUserManual.md
[4]: https://www.96boards.org/documentation/ConsumerEdition/HiKey960/GettingStarted/
[5]: http://silentming.net/blog/2016/09/18/xen-log-5-debug-xen/
[6]: http://www.egr.msu.edu/classes/ece480/capstone/fall14/group04/assets/application-paper-of-august.pdf
[7]: https://github.com/ARM-software/arm-trusted-firmware/tree/integration
[8]: https://github.com/96boards-hikey/edk2/tree/testing/hikey960_v2.5
[9]: https://github.com/96boards-hikey/OpenPlatformPkg/tree/testing/hikey960_v1.3.4
[10]: https://github.com/96boards-hikey/l-loader/tree/testing/hikey960_v1.2
[11]: https://git.linaro.org/uefi/uefi-tools.git
[12]: https://github.com/96boards-hikey/atf-fastboot/tree/master
[13]: https://github.com/96boards-hikey/tools-images-hikey960
[14]: http://builds.96boards.org/snapshots/reference-platform/openembedded/morty/hikey960/rpb/latest/
[18]: https://github.com/96boards/documentation/wiki/HiKeyUEFI
[17]: https://github.com/96boards-hikey/tools-images-hikey960/blob/master/build-from-source/README-ATF-UEFI-build-from-source.md
[19]: http://builds.96boards.org/releases/hikey/linaro/debian/latest/
[20]: https://github.com/anestisb/android-simg2img
[21]: https://github.com/96boards-hikey/linux/tree/hikey960-v4.9
[22]: http://silentming.net/blog/2017/07/31/usb-device-networking/
