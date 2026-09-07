---
title: "Install Both Android Emulator & WSL2 on Windows 11"
comments: true
date: 2022-10-30 20:40:29
tags:
- windows
- linux
- virtualization
keywords: wsl, linux, windows, win11, virtualization, android, Emulator, 安卓, 模拟器
---

Install both android emulator and wsl(windows linux subsystem).

If you directly install the android emulator like nox, mumu it will tell you that "please
open Intel vT" or "system configuration is not compatible".

Let's solve the problem and run both of them!

<!-- more -->

## Brief Introduction to Referred Concepts

#### WSL (Windows Subsystem for Linux)

You could find the detailed info from [wiki][1]. For most target users the wsl is a
fast linux virtual machine running windows.

The wsl released version 2 on May 2019 with Hyper-V (microsoft para-virtualization,
see previous posts [Virtualization Introduction][2] and [What Color Is Your Guest(Chinese)][3])

So it's recommended to use it on latest version of windows 11. (The vim or qemu in wsl runs
slowly when I was using win10. But the issue is fixed on Win11)

#### Hyper-V

The official introduction of [Hyper-V][4] only talked the pros but won't tell you that
your Android Emulator or other VM software (like VMWare) will be breaked once the feature
is enabled. I didn't dig into the implementation only guess that the Hyper-V will intervene
the virtualization interface so that original VM software couldn't get correctly result
when they want to use hardware supported virtualization directly.

The Microsoft will recommend you to build VM using Hyper-V but we actually want to use
our own virtualization managers. So how about just shut down the Hyper-V feature?
Unfortunately, the latest version of WSL force you open the Virtual Machine Platform
which depends on Hyper-V and will open partial related modules even though we didn't
open the Hyper-V feature. So if we want to use both WSL and Emulator we have to find
correct alternatives.

## Run Linux Subsystem

#### Install WSL2

It's easy to install the WSL2 ([official tutorial][5]).

1. Open your microsoft store
2. Search the WSL
3. Choose one distribution (Debian, Ubuntu, SUSE, etc)
4. Run it

Oops, the software tell you that you should open the feature first!

#### Open Virtualization Support

Search VT-x in your BIOS and enable it. The VT-x is microsoft virtualization
support upon which the hypervisor kernel could be run and leverage the hardware
support to create virtual machine(The CPU virtualization in [Virtualization Introduction][2]).

You could also open SR-IOV (Single Root I/O Virtualization, IO virtualization hardware support) if your mainboard support it.

#### Open Features

Easy way:

> 1. Open "Start" (Press Windows key) and search "control panel)
> 2. Open "Programs"
> 3. Open "Turn Windows features on or off" in "Program and Features"
> 4. Check the "Virtual Machine Platform" and "Windows Subsystem for Linux"

or you could open it in cmd:

> 1. "Win+R" to open running
> 2. Open "CMD" as Administrator
> 3. Open the feature in cmd:
>
> ```
> dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
> dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
> ```

You have to reboot the system when you change the above features.

#### Run WSL2

Now we could open and run our WSL. Here to change the default fonts (The fonts will changed back everytime we reopen the wsl), we have to modify the regentry manually.

```
1. Open regedit (Win+R and run regedit)
2. Computer\HKEY_CURRENT_USER\Console\your_linux_subsystem_distribution
3. Add CodePage (Type: DWORD, Value: 0x01b5). This is Lucida Consola
```

## Run Android Emulator

We have no choice but to choose the "correct one". The BludStack has Hyper-V supported version
so we could use it for our gameplay.

[Offical Download Page][6]

Before install it, please open other Hyper-V features: (All of them could be opened in "control panel"

- Hyper-V
- Windows Hypervisor Platform
- Windows Sandbox

Reboot the system and install the bluestacks. It will prompt and let you grant the Hyper-V feature to it. After the installation you could now use BludStack Emulator on Hyper-V enabled windows. The WSL could also be run of course.

---

Most android emulators are built upon the bludstack since it is open source. So we should be
optimistic that other emulators will support Hyper-V in the future. And this will let your
emulators run much faster.

Enjoy your gameplay and works now!


[1]: https://en.wikipedia.org/wiki/Windows_Subsystem_for_Linux
[2]: https://silentming.net/blog/2018/06/13/virtualization-intro-0/
[3]: https://silentming.net/blog/2017/02/28/xen-log-11-what-color-is-your-guest/
[4]: https://learn.microsoft.com/en-us/virtualization/hyper-v-on-windows/about/
[5]: https://learn.microsoft.com/en-us/windows/wsl/install
[6]: https://www.bluestacks.com/
