---
layout: post
title: "C语言预处理"
date: 2016-02-03 11:35:08 +0800
comments: true
tags: note
keywords: Precompile, C/C++, define, 预编译
---
C语言预处理有三种：**宏定义**，**文件包含**，**条件编译**
<br>文件包含很常见，条件编译则可以通过是#ifdef, #if 使得编译时的源码包含(不包含)某些内容。宏定义则主要是进行替换，本文主要记录宏定义的相关内容。
<br>部分内容参考了贴吧：http://tieba.baidu.com/f?kz=1044315227
<!--more-->

##语法

```c
#define identifier string
```
需要注意的是：

* 名称一般全部大写
* 宏定义是预编译使用的，不是语句，末尾没有分号
* 宏定义可以嵌套
* 可以使用#undef来终止宏定义的作用域
* 不替换""中的字符串内容

##带参宏定义
宏定义可以带参数，用小括号表示参数：

```c
#define S(a,b) a*b

area = S(3,2);
=> area = a*b;
=> area = 3*2;
```
不过这样容易出现一些问题：

```c
#define S(r) r*r
area = S(a + b);
=> area = a + b * a + b;

#define S(r) ((r)*(r))
=> area = ((a + b) * (a + b));
```
预编译只对宏进行简单的替换

###常见用法
* 防止头文件被重复包含

```c
#ifndef COMDEF_H
#define COMDEF_H
/* Contents of header*/
#endif
```
* 得到指定地址上的一个字节/字

```c
#define MEM_B(x) (*( (byte *)(x) ))
#define MEM_W(x) (*( (word *)(x) ))
```
* 求最大值or最小值

```c
#define MAX(x,y) ( ((x) > (y)) ? (x) : (y) )
```
* 得到一个变量的地址

```c
#define B_PTR(var) ( (byte *)(void *) &(var) )
```
* ROUNDUP or ROUNDDOWN

```c
#define ROUNDUP(var, base) (((var) + (base) - 1) / (base) * (base))
#define ROUNDDOWN(var, base) ((var) / (base) * (base))
```
* HIGH/LOW Byte

```c
#define WORD_LOW(var) ((byte) ((word)(var) & 255))
#define WORD_HIGH(var) ((byte) ((word)(var) >> 8))
```

* UPCASE

```c
#define UPCASE (c) ( ((c) >= 'a' && (c) <= 'z') ? ((c) - 0x20) : (c) )
```

* 防止溢出

```c
#define INC_SAT(var) (var = ((var) + 1 > (var)) ? (var) + 1 : (var))
```

* 防止出错

```c
#define ADD(a, b) (a + b);\
	a++

#define ADDv2(a, b) do {\
	a + b;\
	a++;\
	} while(0)

if (condition)
		ADD(a, b);
=> 
if (condition)
	(a + b);
a++; /* Wrong!! */

if (condition)
		ADDv2(a, b);
=>
if (condition)
	do {
		a + b;
		a++;
	} while(0);
/* Right */
```
### struct相关用法
<br>为了得到一个field在结构体中的偏移，可以使用这样宏

```c
#define FPOS(type, field) \
	( (dword) &((type *)0)->field )
```
由于取地址会将field的偏移加上struct的首地址后返回，而我们如果将0转换为当前struct的首地址的话，那么返回的值刚好就是field在此struct中的偏移了。

为了得到field所占用的字节数：

```c
#define FSIZ(type, field) sizeof( ((type *)0)->field )
```
##GCC Standard Predefined Macros
GCC预定义了一些宏能帮助我们进行调试和输出，常见的有：`__FILE__`, `__LINE__`, `__DATE__`, `__TIME__`, `__attributes__`, `__DEBUG__`等等，

具体可以参考:
<br>[GCC Standard Predefined Macros](https://gcc.gnu.org/onlinedocs/cpp/Standard-Predefined-Macros.html)
<br>[GCC Extensions to the C Language Family](https://gcc.gnu.org/onlinedocs/gcc/C-Extensions.html#C-Extensions)

## \#\#和\#的用法
使用\#可以将宏参数变成一个字符串，而\#\#则可以把宏参数单纯地拼接起来

```c
#define STR(s) #s
#define CONS(a, b) int(a##e##b)

printf(STR(alice));
=> printf("alice");

printf("%d", CONS(2,3));
=> printf("%d", 2e3); /* printf 2000 */
```
##宏的嵌套
当宏里面含有\#或\#\#的时候，这一部分的宏不会再被展开

```c
#define TOW (2)
#define MUL(a, b) (a * b)

printf("%d", MUL(TOW, TOW));
=>
printf("%d", ((2) * (2)));

#define NUM (2)
#define STR(s) #s
#define CONS(a, b) int(a##e##b)

STR(NUM) => "NUM"
CONS(NUM, NUM) => int(NUMeNUM)
```
为了解决这种情况，需要加一层中间转换宏：

```c
#define _STR(s) #s
#define STR(s) _STR(s)
#define CONS1(a, b) axxxxxb
#define CONS2(a, b) a##xxxxx##b

printf(STR(CONS2(1, 2)));
=> printf(_STR(1xxxxx2));
=> printf("1xxxxx2");

printf(STR(CONS1(1, 2)));
=> printf(_STR(axxxxxb));
=> printf("axxxxxb");
```
###相关用法
* 合并匿名变量

```c
#define __ANONYMOUS1(type, var, line) type var##line
#define _ANONYMOUS0(type, line) __ANONYMOUS1(type, _anonymous, line)
#define ANONYMOUS(type) _ANONYMOUS0(type,__LINE__)

ANONNYMOUS(static int);
=> _ANONYMOUS0(static int, __LINE__); /* Suppose line number is 33 */
=> __ANONYMOUS1(static int, _anonymous, 33);
=> static int _anonymous33;
```
* 填充结构

```c
#define FILL(a) {a, #a}

enum IDD{OPEN, CLOSE};
struct MSG {
	IDD id;
	const char * msg;
}

struct MSG _msg[] = { FILL(OPEN), FILL(CLOSE) };
=> struct MSG _MSG[] = { { OPEN, "OPEN" }, { CLOSE, "CLOSE" } };
```

* 得到数值类型所对应的字符串的大小

```c
#define _TYPE_STR_SIZE(type) sizeof #type
#define TYPE_STR_SIZE(type) _TYPE_STR_SIZE(type)
```

##typedef
许多人会把typedef也作为预处理的一部分，包括我参考的这个贴吧的原文。但是typedef与define本质是不同的，typedef是语句。
<br>语句意味着：
<br>1. 末尾有分号
<br>2. 在编译时才进行处理
<br>3. 在函数内部不能使用typedef
<br>4. 编译器会对typedef后变量的使用进行编译时检查

```c
#define PINT int *
#typedef int * pint; /* Has semicolon ; */

const pint p1; /* Declare a const pointer */
=> int * const p1;
p1 = NULL;	/* Wrong */
*p1 = 0;	/* Right */

const PINT p2; /* Declare a pointer pointing a const value */
=> const int *p2; <=> int const *p2;
p2 = NULL;	/* Right */
*p2 = 0;	/* Wrong */
```
