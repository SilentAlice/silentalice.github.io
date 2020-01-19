---
layout: post
title: "ARM (Break) WatchPoint 使用"
comments: true
date: 2020-01-19 20:42:40
tags: linux, arm
keywords: watchpoint, arm
---

你是否好奇GDB的单步调试是怎么实现的？
你是否在内存被踩而又毫无头绪时又对毫无办法的自己感到气馁？
想不想抓住那些神不知鬼不觉悄悄修改你变量的罪魁祸首？

在ARM你可以使用它自带的调试寄存器: WatchPoint 与 BreakPoint

<!--more-->

```
#define sysreg_read_cp15(code)
({ 
    unsigned int v;
    asm volatile("mrc p15, "code", ":"=r" (v));
    v;
})

#define sysreg_write_cp15(code, val)
({
    unsigned int v = (unsigned int)(val);
    asm volatile("mcr p15, "code" "::"r" (v));
})

#define BVR(n)  "0, %0, c0, c"#n", 4"   /* Breakpoint Value Register */
#define BCR(n)  "0, %0, c0, c"#n", 5"   /* Breakpoint Control Register */
#define WVR(n)  "0, %0, c0, c"#n", 6"   /* Watchpoint Value Register */
#define WCR(n)  "0, %0, c0, c"#n", 7"   /* Watchpoint Control Register */

#define DSCR    "0, %0, c0, c2, 2"      /* Debug Status Control Register */
#define DSCR_MDBGEN 

    
```
