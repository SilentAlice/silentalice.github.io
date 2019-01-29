---
title: (DesignWare 8250) UART Driver
comments: true
date: 2019-01-16 14:58:22
tags:
- tutorial
- linux
keywords: uart, dw, 8250, linux, driver
---

工作中遇到了UART的编写，UART算是一个比较简单和经典的驱动了，之前调试的时候也用过，
最简单版本的只需要一个TX(Transmit)传输口和RX(Receive)接受口再加个电源就可以直接工作，
而软件处理逻辑则都需要我们驱动来完成。本篇就以 DesignWare标准的 8250 UART为例，
简单介绍一个串口的驱动。

本文参考了: [DesignWare DW\_apb\_uart Databook](https://linux-sunxi.org/images/d/d2/Dw_apb_uart_db.pdf)官方手册。

<!-- more -->

## Basic Info

对于需要编写功能全备的驱动开发人员来说，手册和Linux源码已经足够参考，
也没必要看这篇简陋的新手向文章，所以本篇主要介绍的是:1)UART涉及到的常用寄存器与2)最简单功能的驱动代码。


