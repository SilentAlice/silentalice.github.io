---
layout: post
title: "KVM Log 1-QEMU Object Module (QOM)"
date: 2017-08-14 15:39:41 +0800
comments: true
tags: virtualization
keywords: QOM, Qemu, kvm, module
description: "Qemu Module Introduction"
---

KVM分为两部分，User态部分在Qemu中，Kernel态部分集成到了Linux的代码里作为Kernel Module的形式对上提供服务。由于整个大的流程还是在QEMU里面的，所以本篇先介绍一下设备注册的相关信息。

<!-- more -->

Reference: [Mctrain's Blog: Qemu中的设备注册](http://ytliu.info/blog/2015/01/10/qemushe-bei-chu-shi-hua/)

# QEMU Object Module

[关于QOM(Qemu Object Module)的介绍](http://wiki.qemu.org/Features/QOM)

其发展如下图(从Mactrain's Blog里面摘过来的，原来的PDF链接失效了)

{% img https://farm5.staticflickr.com/4425/36422045141_f6ee9cabd8_o_d.png %}

在`kvm-all.c`文件的最后，我们可以发现有个`type_init(kvm_type_init)`, 其中`type_init`的定义在

```c include/qemu/module.h
35 #define module_init(function, type)                                         \
36 static void __attribute__((constructor)) do_qemu_init_ ## function(void)    \
37 {                                                                           \
38     register_module_init(function, type);                                   \
39 }

52 #define type_init(function) module_init(function, MODULE_INIT_QOM)
53 #define trace_init(function) module_init(function, MODULE_INIT_TRACE)
...
```

可以发现最终会变成`do_qemu_init_kvm_type_init(void) { ... }`，其中
`register_module_init`的实现在对应的C文件↓

```c util/module.c
 33 static ModuleTypeList init_type_list[MODULE_INIT_MAX];
 36
 37 static void init_lists(void)
 38 {
 39     static int inited;
 40     int i;
 41
 42     if (inited)
 43         return;
 45
 46     for (i = 0; i < MODULE_INIT_MAX; i++) {
 47         QTAILQ_INIT(&init_type_list[i]);
 48     }
 49
 50     QTAILQ_INIT(&dso_init_list);
 52     inited = 1;
 53 }

 56 static ModuleTypeList *find_type(module_init_type type)
 57 {
 58     init_lists()；
 60     return &init_type_list[type];
 61 }

 63 void register_module_init(void (*fn)(void), module_init_type type)
 64 {
 65     ModuleEntry *e;
 66     ModuleTypeList *l;
 67
 68     e = g_malloc0(sizeof(*e));
 69     e->init = fn;
 70     e->type = type;
 71
 72     l = find_type(type);
 73
 74     QTAILQ_INSERT_TAIL(l, e, node);
 75 }
```

`find_type`会调用`init_lists`进行链表的初始化。

`register_module_init`里面会malloc一个新的`ModuleEntry`并插入对应`init_type_list[Module_Init_Type]`链表中，
Entry的初始化函数指针`init`和类型`type`会被赋值为传进来的参数。
`Module_Init_Type`稍后再说，这里主要强调一下`__attribute__((constructor))`，这个是GCC提供的特性，能够让函数在
`main()`执行前被执行。**所以这些代码都在`main()`之前执行了！**

关于`__attribute__((constructor))`的介绍可以参考这篇: [C Language Constructors and Destructors with GCC](https://phoxis.org/2011/04/27/c-language-constructors-and-destructors-with-gcc/)。

因此在QEMU运行之前，全局的所有Module对应的Entry就已经被插入到`init_type_list`中。

# KVM\_accel\_module

```c include/qemu/module.h
42 typedef enum {
43     MODULE_INIT_BLOCK,
44     MODULE_INIT_OPTS,
45     MODULE_INIT_QOM,
46     MODULE_INIT_TRACE,
47     MODULE_INIT_MAX
48 } module_init_type;
```

Qemu里面一共就4种Module: `BLOCK`,`OPT`,`QOM`,`TRACE`，在`include/qom/object.h`中详细介绍了如何使用已有的接口来实现自己的`Module_Init_Type`, 所以根据上面的分析，
在Main函数执行之前，我们就获得了一个这样的链表↓:

```c
init_type_list:                init_type_list[MODULE_INIT_QOM]:
       ↓                                  ↓
-------------------    |----------> ModuleEntry-0
MODULE_INIT_BLOCK      |              ↑     ↓    
-------------------    |            ModuleEntry-1
MODULE_INIT_OPTS       |              ↑     ↓    
-------------------    |            ModuleEntry-2
MODULE_INIT_QOM  ------|              ↑     ↓    
-------------------                    ......
MODULE_INIT_TRACE
-------------------
```

其中`kvm_accel_type`就是QOM的其中一个ModuleEntry:

```c accel/kvm/kvm-all.c
2615 static const TypeInfo kvm_accel_type = {
2616     .name = TYPE_KVM_ACCEL,
2617     .parent = TYPE_ACCEL,
2618     .class_init = kvm_accel_class_init,
2619     .instance_size = sizeof(KVMState),
2620 };
2621
2622 static void kvm_type_init(void)
2623 {
2624     type_register_static(&kvm_accel_type);
2625 }
2626
2627 type_init(kvm_type_init);
```

根据上面的分析，kvm 通过`type_init`这个洪在`init_type_list[MODULE_INIT_QOM]`链表中加入了一个自己的`ModuleEntry`，其中`ModuleEntry`的`init`被初始化为
`kvm_type_init`, 进而注册了`kvm_accel_type`这个module的信息。

类似的，在QEMU运行的时候只要挨着调用这些List里面Entry的 .init函数就会挨着初始化所有的Module.


