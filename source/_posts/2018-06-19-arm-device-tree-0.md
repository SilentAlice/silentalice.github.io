---
title: ARM Device Tree 0
comments: true
date: 2018-06-19 15:03:07
tags:
- linux
- tutorial
keywords: ARM, dtb, device tree, linux, tutorial, silentming
---

工作原因接触到了ARM上常用的Device Tree, 本篇简单介绍一下Device Tree的由来和使用。

<!-- more -->

## Overview

Device tree的诞生是源于Linux要求启动时有所有可使用硬件的说明和描述，
不然Kernel是不知道怎么配置的。
X86的PC这部分工作是由BIOS来完成的，但是ARM没有BIOS，
因此才需要Device-tree这样一个东西来告诉kernel设备的信息。

在kernel的 `/proc/device-tree/`可以看到kernel识别出的所有device:

```sh
$ ls /proc/device-tree
#address-cells  interrupt-controller@e82b0000   pmic@fff34000
#size-cells     interrupt-parent                pmu
aliases         keys                            psci
...
```

## History

在Device tree出现之前，会有一个专门的文件来记录ARM上的设备信息，
command-line, 内存大小等参数则是作为ARM Tags (ATAGs),
让bootloader作为入口参数,
通过寄存器R2(ARM)传给kernel.
而极其类型就通过R1传给kernel,
所以每个kernel就只为特定的板子进行编译。

其解决方案就是**Device Tree** 或者叫做**Open Platform (OF)** or
**Flattened Device Tree (FDT)**,
其本质是一种byte code类型的树状数据结构来描述设备信息。

当今的bootloader会使用两个文件: kernel image 和 device tree blob (DTB)来启动OS.
DTB的地址通过R2传给kernel, R1则不再使用。

**A device tree is a tree data structure with nodes that describe the physical devices in a system.**

## Usage

ARM的device tree都在 */arch/arm/boot/dts/* (device tree source)
用Linux的脚本来编译dtb:

```sh
$ scripts/dtc/dtc -I dts -O dtb -o /path/my_tree.dtb /arch/arm/boot/dts/my_tree.dts
```

或者反过来从dtb获取dts:

```sh
$ scripts/dtc/dtc -I dtb -O dts -o /path/my_tree.dts /path/my_tree.dtb
```
foundation-v8.dtsi
dtb只不过是dts信息的二进制压缩版而已。

## Syntax

### Structure

1. 每个Module在Device Tree中都是一个Node, 根据driver的实现，可以有父节点或者子节点;
2. Root是所有module最终的父节点；

常见的Top-level module:

- **cpus**: its each sub-nodes describing each CPU in the system.
- **memory** : defines location and size of the RAM.
- **chosen** : defines parameters chosen or defined by the system firmware at boot time. In practice, one of its usage is to pass the kernel command line.
- **aliases** : shortcuts to certain nodes.
- One or more nodes defining the buses in the SoC
- One or mode nodes defining on-board devices

以ARM的foundation v8 作为例子: [Foundation Platform](https://developer.arm.com/products/system-design/fixed-virtual-platforms)是ARM提供的满足其Specification的虚拟板子，
有最基本的硬件功能)

```sh foundation-v8.dtsi https://github.com/96boards-hikey/linux/blob/hikey960-v4.9/arch/arm64/boot/dts/arm/foundation-v8.dtsi

/* * ARM Ltd.
 * ARMv8 Foundation model DTS */

/dts-v1/;
/memreserve/ 0x80000000 0x00010000;
/ {
    model = "Foundation-v8A";
    compatible = "arm,foundation-aarch64", "arm,vexpress";
    interrupt-parent = <&gic>;
    #address-cells = <2>;
    #size-cells = <2>;

    chosen { };
    aliases {
    	serial0 = &v2m_serial0;
        ...
    };

    cpus {
    	#address-cells = <2>;
    	#size-cells = <0>;

    	cpu@0 { ... };
    	cpu@1 { ... };
    	cpu@2 { ... };
    	cpu@3 { ... };
    	L2_0: l2-cache0 {
    		compatible = "cache";
    	};
    };
	memory@80000000 { ...  };
	gic: interrupt-controller@2c001000 { ... };
    timer: { ... };
    pmu: { ... };
    smb: { ... };
```

```sh foundation-v8.dts https://github.com/96boards-hikey/linux/blob/hikey960-v4.9/arch/arm64/boot/dts/arm/foundation-v8.dts
#include "foundation-v8.dtsi"
/ { gic: interrupt-controller@2c001000 { ...  }; };
```

Foundation的device tree信息非常清晰，

- `include`: 跟C一样，可以include其他文件，这里`foundation-v8.dts`就include了`foundation-v8.dtsi`
- `*.dtsi`: 扩展的dts文件，但是其本身不能include其他的dts文件。
- `/`: root node, Device tree从该节点开始。

chose是空的，如果想看实例可以参考hikey960的devicetree:

```sh hi3660-hikey960.dts https://github.com/96boards-hikey/linux/blob/hikey960-v4.9/arch/arm64/boot/dts/hisilicon/hi3660-hikey960.dts
chosen { stdout-path = "serial6:115200n8"; };
```

hikey960在device tree中设定了输出的串口为uart6,
这也是我们在使用Hikey960默认使用UART6的原因。

### Properties

上面每个Node里面都有许多关键词，称为**Property**, 每个property是一个Key-value键值对，

**Key**

- `Compatible`: 这是连接硬件与Driver最为重要的一段信息，
告诉Driver应该与哪个Node相匹配。
其优先级与字符串里的顺序一致，
在Linux中用来与`DT_MACHINE`结构中的`dt_compat`进行匹配。
top-level的compatible一般是适配的板子的信息:`<manufacture>,<model>`。
我们的Tree中，是ARM foundation，但是实现了vexpress的接口，
所以描述时的值为:`"arm,foundation-aarch64", "arm,vexpress"`
- Node name: must as `<name>[@<unit-address]`, 描述node的类型而非具体型号，最大31个char
- Addressing
 - `reg`: Node/device 的物理地址: `reg = <address1 length1 [address2 length2] [address3 length3] ... >`，
 由于address 和 length都是变长，所以需要parent-node指定下面两个Property来帮助确定reg中的值长度。
 - `#address-cells`: `reg`中base address 需要多少cell(32bits values)
 - `#size-cells`: `reg`中的size大小
- Interrupt
 - `interrupt-controller`: bool类型来表明当前的node是不是interrupt controller
 - `#interrupt-cells`: 表示interrupts属性中多少个cell是被选定的interrupt controller所管理
 - `interrupt-parrent`: 是不是有个一个`phandle`指向当前node

**value**: value可以为空or任何字节流，由于数据类型信息是没有包含在数据结构中的，
所以在device tree中有一些基本的通用类型表示方法:

- **text-string**: 双引号, `"string-property = "a string";`
- **cell**: 32-bit无符号整型: `< >`, `cell-property = <0xbeef 123 0xabcd1234>;`
- **binary-property**: `[ ]`, `binary-property = [0x01 0x23 0x45 0x67];`
- **mixed-property**: 不同类型的可以放一起: `mixed-property = "a string", [0x01 0x23 0x45 0x67], <0x12345678>;`
- **string-list**: 逗号也用来建立字符串列表: `string-list = "red fish", "blue fish";`

## Address Examples

### CPU

```sh foundation-v8.dtsi
cpus {
#address-cells = <2>;
#size-cells = <0>;

    cpu@0 {
        device_type = "cpu";
        compatible = "arm,armv8";
        reg = <0x0 0x0>;
        enable-method = "spin-table";
        cpu-release-addr = <0x0 0x8000fff8>;
        next-level-cache = <&L2_0>;
    };
    cpu@1 { ... };
    cpu@2 { ... };
    cpu@3 { ... };
L2_0: l2-cache0 {
          compatible = "cache";
      };
};
```

以`cpus`为例，其拥有4个`cpu@n`子节点和一个`l2-cache0`子节点, 其中`L2_0`是`l2-cache0`的label。
`#address-cells`为`<2>`说明子节点中reg的地址为两个cell(`uint64`), 没有size。
其中cpu@0的地址为`0x0 0x0`, (两个cell)。
根据习惯，如果一个Node含有`reg`，那么其名称中必须含有`unit-address`也即`reg`中的第一个值。
所以CPU@0的0取自`0x0`，

### Memory (Mapped Device)

```sh foundation-v8.dtsi
memory@80000000 {
		device_type = "memory";
		reg = <0x00000000 0x80000000 0 0x80000000>,
		      <0x00000008 0x80000000 0 0x80000000>;
	};
```
内存的话，上面的信息表示内存有两个range: 分别是从`0x8000_0000`-`0xFFFF_FFFF`(2GB)与`0x08_8000_0000`-`0x08_FFFF_FFFF`(2GB)一共4GB的空间。
不过手册上的信息是，后面一段内存是从`0x08_8000_0000`-`0x09_FFFF_FFFF`(6GB)的内存, Linux只用了后半段的2GB。
**Memory-mapped Device**的格式与内存类似,不过要含有`compatible`信息。

### Device Live on Bus

这种设备在Bus上的设备有不同的寻址模式，一般会有片选线来选出chip号。

```sh foundation-v8.dtsi
smb@08000000 {
		compatible = "arm,vexpress,v2m-p1", "simple-bus";
		arm,v2m-memory-map = "rs1";
		#address-cells = <2>; /* SMB chipselect number and offset */
		#size-cells = <1>;
        
        ranges = <0 0 0 0x08000000 0x04000000>,
                 <1 0 0 0x14000000 0x04000000>,
                 <2 0 0 0x18000000 0x04000000>,
                 <3 0 0 0x1c000000 0x04000000>,
                 <4 0 0 0x0c000000 0x04000000>,
                 <5 0 0 0x10000000 0x04000000>;
        ...
            ethernet@2,02000000 {
                compatible = "smsc,lan91c111";
                reg = <2 0x02000000 0x10000>;
                interrupts = <15>;
            };
        ...
}
```

比如System Management Bus(SMBus, SMB)上的Ethernet@2, 就首先使用片选线2来选出对应的chip,
之后是在chip上的基地址`0x0200_0000`，size是`0x10000`。

### Range (Address Translation)

在root下的设备地址是可以直接被CPU理解的，
但是像SMBus上的设备，
其地址由于是有片选地址的原因，
需要映射为CPU可以理解的地址才能被CPU使用,
这时就可以使用**range**。

range中的每个entry都是由**child address**, **parent address**, **child size**组成，
格式分别按child `#address-cells`, parent `#address-cells`, 和 child `#size-cells`

如上所示，smb中的基址`0x0`被翻译为root下的`0x0800_0000`, 大小为`0x0400_0000`，
所以ethernet@2,02000000在内存中的基址是在`0x1800_0000` + `0x0200_0000` = `0x1A00_0000`，
最终的内存范围是`0x1A00_0000` - `0x1A00_FFFF`。

如果子节点和父节点的地址空间一样，可以加一个空的range property, 这表示子节点和父节点的内存一一映射。
需要地址翻译的原因在于PCI设备地址空间复杂，需要将这些详细信息交给kernel来处理，
而DMA设备又需要知道bus上的真实地址而非这些翻译后的地址，
还有的时候设备可以被分为一组而使用同样的映射等等。

有一些使用片选的外设我们会发现没有range, 这种外设说明不是memory-mapped的设备，CPU也只能通过其父节点间接对其访问。

## Interrupts

Interrupt signal可能由任何设备发起，或结束于任何设备，所以不同于address树状的描述方式，
中断一般是按照与Device Tree无关的节点间的Link来描述。

- `interrupt-controller` 用于指明一个device是否接受中断信号。
- `interrupt-cells` 中断控制器的Property之一，
用来描述有多少cell在当前终端控制前的**interrupt specifier**中，
作用与`#address-cells`和`#size-cells`类似。
- `interrupt-parent` 含有`phandle`的结点的Property之一，不含有`phandle`的node可以从父节点继承这一property.
注意我们的foundation-v8.dtsi的开头有一句`interrupt-parent = <&gic>;`, 所以root下的所有子节点默认继承该属性。
- `interrupts` Node所含有的**interrupt specifier**，每个中断输出信号对应一个。

**interrupt specifier**是一个或多个cell(`#interrupt-cells`指定)大小的数据，
描述了某个设备中断对应于哪个中断接受者，
一个设备可能含有多个中断信号输出，
这时就有多个sepcifier来描述这些输出分别对应于哪个中断接受端。
至于specifier中的数据表示什么意思则要根据interrupt controller的手册来了。

```sh foundation-v8.dts
/ {
	gic: interrupt-controller@2c001000 {
		compatible = "arm,cortex-a15-gic", "arm,cortex-a9-gic";
		#interrupt-cells = <3>;
		#address-cells = <2>;
		interrupt-controller;
		reg = <0x0 0x2c001000 0 0x1000>,
		      <0x0 0x2c002000 0 0x2000>,
		      <0x0 0x2c004000 0 0x2000>,
		      <0x0 0x2c006000 0 0x2000>;
		interrupts = <1 9 0xf04>;
	};
};
```

在foundation-v8的dts文件中，gic(v2)是从`0x2c00_1000` - `0x2c00_7FFF`的这段空间中，
* `interrupt-controller`，所以他是一个中断控制器。
* `#interrupt-cells = <3>`, 所有以它作为中断接受者的设备都要用3个cell来描述中断信息。

```txt gic.txt https://elixir.bootlin.com/linux/v4.2/source/Documentation/devicetree/bindings/arm/gic.txt
The 1st cell is the interrupt type; 0 for SPI interrupts, 1 for PPI
interrupts.

The 2nd cell contains the interrupt number for the interrupt type.
SPI interrupts are in the range [0-987].  PPI interrupts are in the
range [0-15].

The 3rd cell is the flags, encoded as follows:
        bits[3:0] trigger type and level flags.
            1 = low-to-high edge triggered
            2 = high-to-low edge triggered (invalid for SPIs)
            4 = active high level-sensitive
            8 = active low level-sensitive (invalid for SPIs).
        bits[15:8] PPI interrupt cpu mask.  Each bit corresponds to each of
        the 8 possible cpus attached to the GIC.  A bit set to '1' indicated
        the interrupt is wired to that CPU.  Only valid for PPI interrupts.
        Also note that the configurability of PPI interrupts is IMPLEMENTATION
        DEFINED and as such not guaranteed to be present (most SoC available
        in 2014 seem to ignore the setting of this flag and use the hardware
        default value).
```

Linux源码arm gic的binding文档中对三个cell如何描述进行了说明，<br>
第一个是指明Shared processor interrupts(SPI)还是Per processor interrupts(PPI);<br>
第二个是中断号;<br>
第三个是flag。

```sh foundation-v8.dtsi
timer {
		compatible = "arm,armv8-timer";
		interrupts = <1 13 0xf08>,
			     <1 14 0xf08>,
			     <1 11 0xf08>,
			     <1 10 0xf08>;
		clock-frequency = <100000000>;
	};
```

timer就是一个PPI, 分别对应中断号10, 11, 13, 14，
并且对4个CPU与之相连, 且为adtive low level-sentitive(0xf08)

到这里为止，一个device tree中的常见信息我们都可以理解了，
不过我们还发现在smb中有interrupt-map这种东西，这个我们在下一篇继续分析。
下一篇我们主要来看PCI设备、中断的映射和对Device的一些总结。

Reference List:
- [Linux Kernel For Newbies](https://saurabhsengarblog.wordpress.com/2015/11/28/device-tree-tutorial-arm/)
- [Linux Device tree](http://wiki.dreamrunner.org/public_html/Embedded-System/Linux-Device-Tree.html)
- [Device Tree Mysteries](https://elinux.org/Device_Tree_Mysteries)
- [Device Tree Usage](https://elinux.org/Device_Tree_Usage)
- [Devicetree Specification](https://elinux.org/Device_tree_future#Devicetree_Specification)

