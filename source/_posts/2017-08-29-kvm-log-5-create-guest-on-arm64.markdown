---
layout: post
title: "Kvm Log 5-Create QEMU-kvm Guest on Hikey960 (ARM64)"
date: 2017-08-29 15:31:18 +0800
comments: true
tags:
- virtualization
- tutorial
keywords: kvm, guest, qemu, hikey960, arm64
description: "Run qemu-kvm guest on arm64 (hikey960)"
---

This post is about booting guest using qemu-kvm.

<!-- more -->

# Guest Image

Like create domU on xen, you still need to prepare a guest image including guest
kernel, bios image.

For qemu image on arm64, you can download it from [official site:][1]

```sh
wget https://releases.linaro.org/components/kernel/uefi-linaro/15.12/release/qemu64/QEMU_EFI.fd
wget https://releases.linaro.org/components/kernel/uefi-linaro/15.12/release/qemu64/QEMU_EFI.img.gz
```

# Build Qemu

Get qemu from source on hikey960 (I recommend to compile on board directly if
you dont want to handle those annoying libs

```sh
git clone http://git.qemu.org/git/qemu.git
```

If your guest is downloaded from above link, set target as `aarch64-softmmu` is
enough. Config qemu and compile it:

```sh
# ./configure --target-list="aarch64-softmmu aarch64-linux-user" 
./configure --target-list="aarch64-softmmu" 
make
make install
```

# Run Guest

```sh
taskset -c 0-3 qemu-system-aarch64 -m 1024 -M virt -cpu cortex-a53 -smp 4 -bios "/path/to/QEMU_EFI.fd" -nographic -device virtio-blk-device,drive=image -drive if=none,id=image,file="/path/to/QEMU_EFI.img.gz" -enable-kvm
```

Currently, Cortex-A73 is not supported by qemu, we have to pin vcpus on
cortex-a53 via `taskset -c 0-3` (cpu 0 - 3 are all cortex-a53)

I dont have a screen to show results, that's why `-nographic` is needed.

`-enable-kvm` to let qemu make use of kvm to boost guest.

Now you should boot guest successfully.

[1]: https://releases.linaro.org/components/kernel/uefi-linaro/15.12/release/qemu64/
