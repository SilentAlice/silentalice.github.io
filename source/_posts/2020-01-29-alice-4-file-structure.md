---
layout: post
title: "Alice OS 4-File Structure"
comments: true
date: 2020-01-29 22:19:51
tags: os-dev
keywords: arm, os, 操作系统, linux, alice os
---

在开始内存映射之前，我们暂且小憩一下，
聊一聊比较玄学的问题: 目录结构。
之所以这个单拎出来讲是因为在工作中发现许多专业的开发人员对目录结构都不以为意，
即使是有好多年开发经验的人目录结构也可能是一团糟。

但是一个好的目录结构对于构建的效率、代码的可维护性是极为重要的，
所以本篇来说一下我们的Alice OS准备采用的目录结构。

[Alice-OS: File Structure][0]

<!-- more -->

## 头文件

大体上来说，我们希望在kernel的C文件中只用关心kernel的东西，
将arch、plat相关的东西都放到头文件中隐藏掉，
一级级抽象上来:

```
[0] % tree
.
├── arch
│   └── arm
│       ├── build.mk
│       ├── config.mk
│       └── include
│           └── arch
│               ├── memory.h
│               └── type.h
├── kernel
│   ├── include
│   │   └── alice
│   │       ├── memory.h
│   │       └── type.h
│   └── init.c
│
└── plat
    ├── versatilepb
    │   ├── include
    │   │   └── plat
    │   │       └── memory.h
    └── vexpress-a9
        └── include
            └── plat
                └── memory.h
```

- plat 里面存放的是跟各个平台紧相关的内容，
  包含kernel的起始地址、各种外设的物理地址等等;
- arch 存放的是跟体系结构相关的内容，
  比如像各种`uint32_t`、`uint64_t`的typedef等等，
  这种就是跟体系结构相关的，所以我们把这些内容放到arch目录下;
- kernel 中的内容就是跟体系结构也不相关的内容了;

在include头文件时，`arch/include`会include `plat/include`目录下的头文件，
`kernel/include`会include`arch/include`目录下的头文件。

我们将 plat, arch 与 kernel依次规定为下->上，最上层的kernel视为最高抽象。

那么每一级`include`下存在的头文件，都只能include本级以及下一级的头文件:

    /* kernel/include/alice/memory.h */
    #include <arch/memory.h>

    /* arch/arm/include/arch/memory.h */
    #include <plat/memory.h>

这样我们就能一层层在头文件中把细节给抽象掉。

## 源文件

如果说头文件是抽象过程，那么源文件就是对抽象的使用，
也因此更具体的源文件是可以使用更抽象的内容的。
具体来说，上图中 `arch/init.c` 就可以include `kernel/include` 与 `arch/include`。

这是因为对于体系结构这一更具象的内容来说，kernel层面的东西更为抽象，
所以体系结构可以使用更抽象的kernel中定义的方法和常量，
因为Kernel定义的内容必然更为通用。

## 路径

可以发现我在include目录下又添加了 arch/plat/alice 的目录，看起来有些冗余，
其实主要目的就是让我们能在代码里通过

    #include <arch/xxx.h>
    #include <plat/xxx.h>
    #include <alice/xxx.h>

这种明显的方式知道使用的哪一级的头文件，也允许了不同抽象级头文件的重名。

## Future

后续当我们的代码慢慢变多之后，还会有driver、lib、uapi等等，
但是无论我们添加什么目录或者组件，
我们的核心思想都是保证抽象的东西只使用抽象的东西，
我们和具体体系结构无关的代码就只关心逻辑，
这样才能使得代码有更好的可移植性。

当然这个目录结构也是我个人习惯啦，
只要目录结构方便扩展、移植就完全OK.

[0]: https://github.com/SilentAlice/alice-os/tree/89fa5e265dfa77290d481d4a8e4d9b110dcadcd5
