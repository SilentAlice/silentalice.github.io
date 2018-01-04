---
layout: post
title: "在x64linux下编译Qemu"
date: 2015-11-23 14:24:21 +0800
comments: true
tags:
- record
- tutorial
keywords: qemu, compile, x64, 编译, 64位, linux
description: "Compile qemu in x86 linux"
---
做JOS实验的时候，因为想在真机上跑Qemu来做，而自己的机子是Ubuntu x64的，目标应用是x86的，当时编译的时候还遇到了一些问题，这里做个记录:)
<!-- more -->

本文参考了：[https://community.gns3.com/community/forum/blog/2014/12/24/how-to-compile-qemu-220-in-ubuntu-64bit](https://community.gns3.com/community/forum/blog/2014/12/24/how-to-compile-qemu-220-in-ubuntu-64bit)

1. First install Qemu dependencies for Ubuntu

       sudo apt-get install build-essential gcc pkg-config glib-2.0 libglib2.0-dev libsdl1.2-dev libaio-dev libcap-dev libattr1-dev libpixman-1-dev

2. install other dependencies

       sudo apt-get build-dep qemu

3. then download latest Qemu source files from Download - QEMU

       wget http://wiki.qemu-project.org/download/qemu-2.2.0.tar.bz2
       // Change the version of qemu to get latest one

4. extract it

        sudo tar -xvjf qemu-2.2.0.tar.bz2

5. go to extracted folder

       cd qemu-2.2.0/

6. compile it for 64bit (if you want 32 bit too add this ',i386-softmmu')

       sudo ./configure --target-list=x86_64-softmmu  (for additional platform type  ./configure --help)
       sudo make
       sudo make install

******

##Note

* KVM is enable by default ,you can add  --enable-kvm option in ./configure , like the following

 <code>sudo ./configure --target-list=x86_64-softmmu --enable-kvm</code>

 * if you want to build with NETMAP do as following

  * first install  git

         sudo apt-get install git

  * then download and install NETMAP source code (we need that source code location for building NETMAP) , I want to download NETMAP source  in my /opt/ directory

         cd /opt/

* then download NETMAP by git

```sh
sudo git clone https://code.google.com/p/netmap/
cd netmap
cd LINUX
sudo ./configure --no-drivers=virtio_net.c
sudo make
sudo make install
```  

* then we must give sys folder location in netmap , (/opt/netmap/sys) to ./configure ,with  --extra-cflags=-I option , like the following

        sudo ./configure --target-list=x86_64-softmmu --enable-kvm --enable-netmap --extra-cflags=-I/opt/netmap/sys

 * you will see enable netmap=yes and enable kvm =yes after configure

             then sudo make -j4

             sudo make install 
