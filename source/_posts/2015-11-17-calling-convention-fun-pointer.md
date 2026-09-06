---
layout: post
title: "Calling Convention&Function Pointer"
date: 2015-11-17 21:54:51 +0800
comments: true
tags: 
- note
- programming
keywords: ICS, Introduction to Computer Systems, 深入理解计算机系统, C, C++, 函数指针, Calling Convention, C#, event, delegate, 委托, 事件, .net, 数组, 指针
---
这一年因为工作原因得以跟着本科生一起学习ICS(Introduction to Computer Systems), ICS原本好像是CMU的课：[https://www.cs.cmu.edu/~213/](https://www.cs.cmu.edu/~213/), 本校的主页：[http://ipads.se.sjtu.edu.cn/courses/ics/](http://ipads.se.sjtu.edu.cn/courses/ics/)。内容基本上涵盖了我本科时期操作系统、计算机组成与x86汇编的大部分内容，而且由于是一门课，所以很好的把这些内容都串了起来，我也有幸能再次学习和温习一下专业的基础知识。这一系列博文主要总结这次学习中的新的收获和以混淆的点，用来温习和回顾。

这次总结函数调用的 Calling Convention和C语言的Function Pointer, 本来还想加上Round to Even 和 x86与x86-64种struct, union对齐的，不过因为扯了C#的事件和委托机制，导致内容有点多，就放到下一篇好了。
<!-- more -->

#Calling Convention
函数调用过程中Registers需要进行保存和恢复，有一些约定来表明哪些寄存器由Caller保存，哪些由Callee保存，编译器会以这种约定来进行编译。约定与ABI(Application Binary Interface)有关

###ARM

在ARM中(From [AAPCS](http://infocenter.arm.com/help/topic/com.arm.doc.ihi0042e/IHI0042E_aapcs.pdf) $5.1.1), 这里不记录浮点寄存器。

* r0-r3 are the arguments and scratch registers;
	* r0-r3(a1-a4) 传递arg1-4
* r0-r1 are also the result registers
	* r0, r1也用于返回值
* r4-r8 are callee-save registers
	* r4-r8(v1-v5)用来存放变量的值
* r9 might be a callee-save register or not (on some variants of AAPCS it is a special register)
	* v6/sb(static base),v6就是存放第6个变量，Static Base in PID,/re-entrant/shared-library variants
* r10-r11 are callee-save registers
	* r10: v7/sl(stack limit)，在检查栈的限长时使用
	* r11: v8/fp(ARM-state frame pointer), 用来存放帧指针，类似于EBP的作用
* r12-r15 are special registers
	* r12:ip (Intra-Procedure-call scratch register) new-sb in inter-link-unit calls. Used by compiler code generators as a local code generator temporary register 
	* r13:sp (Stack Pointer)，类似于ESP的作用
	* r14:lr (Link Regiser), scratch register, 用来存放return address
	* r15:pc (Program Counter)

###Microsoft x64 Software Conventions

From [Register Usage MSDN](https://msdn.microsoft.com/en-us/library/9z1stfyw.aspx)

* Volatile (Caller-saved)
	* RAX:	return value
	* RCX:	1st arg
	* RDX:	2nd arg
	* R8:	3rd arg
	* R9:	4th arg
	* R10, R11: used in syscall/sysret instructions
* Nonvolatile (Callee-saved)
	* R12:R15, RDI, RSI, RBX
	* RBP:	可能作为frame pointer使用
	* RSP:	stack pointer

###AMD64

From [System V.application binary interface amd64 architecture processor supplement](http://www.x86-64.org/documentation/abi.pdf)

* Caller-save
	* %rax:	1st return reg; tmp reg
	* %rcx:	4th arg
	* %rdx:	3rd arg
	* %rsi: 2nd arg
	* %rdi: 1st arg
	* %r8:	5th arg
	* %r9:	6th arg
	* %r10:	tmp reg; passing function's static chain pointer(听老大说是函数嵌套时使用)
	* %r11: tmp reg
* Callee-save
	* %r12-%r15
	* %rbx:	有时用作基址指针(Base Pointer)
	* %rsp: stack pointer
	* %rbp: 有时用作帧指针

其他寄存器可以参考给出的各个链接或手册

x86的Calling Convention比较简单，就不列出来了。

#Pointer and Array
首先看看指针和数组声明：

```cpp Pointer & Array
int a[];       // 1D(imension) Array
int a[][];     // 2D Array

int *p;        // 1L(evel) Pointer p point to int
int **p;       // 2L Pointer p point to int *
```
这是平常会用到的指针和数组的声明，但是int[]和int ** 实际上是不同的。

比如说下面的声明：

```cpp Pointer & Array 2
int *a[];      // Pointers
int (*a)[];    // Pointer a point to an array
```
第一个是许多的指针，比如我们可以一个含有3个指针的数组：

```cpp
int *a[] = {NULL, (int*)0x80000000, NULL};
```
第二个是指向数组的指针，我们可以声明一个指向数组a地址的指针p:

```cpp
int a[] = {233, 123}
int (*p)[] = &a;

// (*p)[0] is 233
// (*p)[1] is 123
```
其实总结一下，下面四种声明方式我们都可以当做二级指针来操作：

```cpp
int a[][];
int ** a;
int *a[];
int (*a)[];
```
之所以会产生这样的区别，在语法上是因为[]的优先级比\*高，所以在\*a外加不加括号会有区别。而对于编译器，如果是int a[][] 在嵌套循环的时候会进行优化，因为每一行所占的空间是已知的，所以就可以声明行指针与列指针。比如下面的函数在使用-O2优化的时候，就会变成下面的样子。

```cpp Optimization of Embedded Loop
// Original Function
void transpose(Marray_t A)
{
	int i, j;
	for ( i = 0; i < M; i++ )
	    for ( j = 0; j < i; j++ ) {
			int t = A[i][j];
			A[i][j] = A[j][i];
			A[j][i] = t;
		}

}

// Optimized Function
void transpose_opt(Marray_t A)
{
	int i, j;
	for ( i = 0; i < M; i++ ) {
		int *Arow = &A[i][0];    // 第i行的第一个元素的地址
		int *Acol = &A[0][i];    // 第0行的第i个元素的地址
		for ( j = 0; j < i; j++ ) {
			int t1 = *Acol;      // 下面Acol += M会把Acol变成第j行的第i个元素
			int t2 = Arow[j];    // 第i行的第j个元素
			*Acol = t2;
			Arow[j] = t1;
			Acol += M;           // 等于是 &A[0 + j*M][i]，把Acol变成第j行的第i个元素
		}
	}
}
```
由于数组是有边界的，所以这种优化才得以实现。但是在二维指针的情况下就不行了:)

#Function Pointer
首先看一组声明：

```cpp Declaration
int a;          // Integer
int a[10];      // Integer Array
int *a;         // Integer Pointer
int *a[10];     // Integer Pointers(array)
int a();        // Function Declaration(return int)
int* a();       // Function Declaration(return int*)
int (*a)()      // Function Pointer(return int)
int (*a[10])()  // Function Pointers(all return int)
int* (*a[10])()  // Function Pointers(all return int*)
```
在记忆的时候，只要记住函数指针的声明需要将\*与变量名括起来即可，记忆的形式可以参考普通的指针数组。

--------------

**以下内容并没有实际使用的意义**，<a href="#skip">点我跳过</a>

现在我们把前面的数组和指针也放到函数指针数组里面，看看下面的声明:)

```cpp
int cons = 1;
int * pcons = &cons;
int acons[] = {1};


int* (*a[10])(int, int*) 
// Function Pointers (All return int*, args:int, int*) use it ↓
pcons = (*a[n])(cons, pcons);


int a(int, int*, int[])[];
// Funtion a, return int array. use it as ↓
cons = a(cons, pcons, acons)[0];
acons = a(cons, pcons, acons);


int (* fun(int))[];
// Function declaration, return pointer pointing to int array, use ↓
int (*p)[] = fun(cons);
acons = *fun(cons);
cons = (*fun(cons))[0];

int* (* fun(int))[];
// Function declaration, return pointer pointing to int* array, use ↓
pcons = (* fun(int))[0];

int *(*(*apfun[2])(int[], int*, int))[];
// Function Pointers, each pointer is a function that 
// get int[], int*, int as args,
// return a pointer which points to an array
// The array consists of int* (pointers pointing to int)

// We can use this one like this:
cons = *(*(*apfun[2])(acons, pcons, cons))[0];
pcons = (*(*apfun[2])(acons, pcons, cons))[0];
```
看到这里，想必感觉非常蛋疼，简直是非人类啊。其实里面有个原因是C语言中数组是不能用来赋值的，所以不能出现这种情况：

```cpp
int Array[] = {1,2,3};
int a[] = Array; // Wrong
```
那么想把数组弄过来怎么办呢？
<br>于是自然想到传递 &Array,这样就可以声明一个指向数组的指针就好了：↓

```cpp
int Array[] = {1,2,3};
int (*pa)[] = Array;

//(*pa)[0] = 1;
//(*pa)[1] = 2;
```
这样就可以实现数组的传递，当然更简单的方法还是 `int *p = Array`。所以一般也没人抽风这么用
<a name="skip"></a>
<br>在记忆的时候，使用和声明的形式是一致的，所以可以通过使用来理解声明的含义。

#Usage of Function Pointer(s)
那么来看看C语言中函数指针的用法：

```c function pointer
/* Suppose number 1-4 represent cheap food 
 * 5+ represent delicious food
 * less than or equal to 0 means no food
 */

int EatFood(int i){
	if (i > 0)
		return 666;
	else
		return -1;
}

int JudgeFood(int i){
	if (i <= 0)
		return -1;
	else if (i < 5)
		return 60;
	else 
		return 100;
}

struct People_t  {
	char *strName;
	int (*eat)(int);
};

int main()
{
	/* Initialization */
	struct People_t customer = 
	{ “Alice”, EatFood }

	struct People_t gourmet =
	{ “Ming”, JudgeFood }

	customer.eat(1); /* return 666 */
	gourmet.eat(4);	 /* return 60 */

	return 0;

}
```
这种形式就非常像面向对象编程了，所以在C语言里面可以通过使用函数指针来达到OO(Object Oriented)编程的目的。

那么再看看函数指针数组的使用：

```c Function Pointers Array
/* Add another defination Food Provider*/
struct Provider_t {
	int (*gave[2])(int);
} provider;

void Register(struct Provider_t *p1, struct People_t *p2, int index)
{
	p1->gave[index] = p2->eat;
}

int main() 
{
	Register(&provider, &customer, 0);
	Register(&provider, &gourmet, 1);

	provider.gave[0](10);
	provider.gave[1](10);
}
```
Register表明有人向Provider注册信息，要求provider提供食物给他们。对于Provider来说，他只用关心有多少人注册了，等到有新货来的时候就给所有注册者分发食物。
而具体的注册者会根据自己的函数定义实现不同的行为。

如果写过C#的delegate的话，会发现有点相似点，事件的发起人会获得接受者的函数指针，并在出现时间时调用这些函数。

不过真正的delegate不但可以引用静态函数，还可以引用非静态成员函数(C语言因为没有成员所以也不存在这种函数);delegate是面向对象、类型安全的。由于C本身并不是面向对象语言，而且也不存在class这种东西，所以他们的区别还是非常好理解的。而刚才介绍的C函数指针的用法实际上也是为了借鉴OO编程的思想而已。

现在看看C#中Delegate的用法：

```c# Delegate Example1
public class DelegateTest {
	// 声明delegate对象
	public delegate void AliceDelegate(int a, int b);

	// 实际执行的函数
	public static void AliceDo(int a, int b)
	{
		Console.WriteLine((a+b).ToString()+"Alice do something");
	}

	public static void Main()
	{
		// 创建delegate对象：
		AliceDelegate ad = 
			// 这里传进去AliceDo的函数地址
			new AliceDelegate(DelegateTest.AliceDo);
		
		// 执行ad, 通过ad实际上执行的是AliceDo函数
		ad(1,2);
	}
}
```
是不是觉得和函数指针的感觉很像？

```c# Delegate Example2
public delegate void AliceDelegate(int i);
public class Program
{
	public static void Main()
	{
		// 创建delegate
		ReceiveAliceDelegateArgsFunc(new AliceDelegate(AliceDo));
	}

	public static void ReceiveAliceDelegateArgsFunc(AliceDelegate func)
	{
		func(666);
	}

	// 实际执行的函数
	public static void AliceDo(int i)
	{
		System.Console.WriteLine("Get A: {0}", i);
	}

}
```
当要发出一个消息的时候，ReceiveAliceDelegateArgsFunc就会被执行，它会调用拿到的delegate，而delegate实际上代表的函数AliceDo则是在new AliceDelegate(AliceDo)的时候传给AliceDelegate的。

delegate支持+=，可以将许多函数交给这个委托，这一点就和函数指针数组很像了。

.Net中的event事件其实也是一种具有特殊签名的delegate，因为实际在实现的时候如果真的是发送了一些消息给接受者，那只有当接受者被激活或者被调度器调度到的时候才能知道自己收到了一个消息，这样就无法立即响应这个消息。所以在实现的时候还是需要由消息的发起者主动去调用这些函数。

来看看OnClick的实现：
```C# OnClick
public class ButtonClickArgs : EventArgs
{
	// 参数可以由我们定义，获得Clicker的信息
	public string Clicker;
}

public class AliceButton
{
	// 定义一个委托
	public delegate void ClickHandler(object sender, ButtonClickArgs e);

	// 定义事件，类型就是上面的委托
	public event ClickHandler OnClick;

	public void Click()
	{
		// 触发Click事件，传入Clicker信息
		OnClick(this, new ButtonClickArgs() { Clicker = "Alice" });
	}
}

public class Program
{
	public static void Main()
	{
		AliceButton btn = new AliceButton();

		// 注册事件， 把btn_OnClick压入事件队列
		// 这里btn_OnClick就是实际执行的函数
		btn.OnClick += new AliceButton.ClickHandler(btn_OnClick);
	}

	public static void btn_OnClick(object sender, ButtonClickArgs e)
	{
		Console.WriteLine("Alice be clicked");
	}
}
```
在Program执行过程中，我们点击了AliceButton，这时就触发了btn里的Click()函数
<br>在Click()函数中，调用了OnClick并传入sender和Arg
<br>OnClick是个事件，而其本身类型是ClickHandler委托类型的事件。所以OnClick可以看做一个函数指针变量(类型为ClickHandler的这种类型)。
<br>而在Program中，通过注册事件:
<br>`btn.Onclick += new AliceButton.ClickHander(btn_OnClick)`
<br>可以看做声明了一个函数指针(类型为ClickHandler的这种类型)，并把这个函数指针赋给event Onclick。
<br>ClickHandler这种类型就是返回值为void，参数为object和ButtonClickArgs的函数类型
<br>所以调用btn.OnClick的时候，等于就调用了btn_OnClick()这一实际执行的函数。

我想现在应该能理解函数指针和C#中的event了吧。关于event的说明，参考了[这篇博文](http://www.cnblogs.com/zhangchenliang/archive/2012/09/19/2694430.html)


