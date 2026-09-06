---
layout: post
title: "Symbol与Pointer、Array与Function"
date: 2015-12-23 21:57:27 +0800
comments: true
tags:
- programming
- note
keywords: Pointer, Array, Function, Linker, 函数, 数组, 指针, 链接, C
---
在[上一篇Summary](http://silentming.net/blog/2015/11/17/ics-summary-1/)里面已经提到过Array、Function与Pointer了。里面都是标准的语法，理解上也没有什么有问题的地方。本篇则讨论不知是编译器or链接器出于人性考虑进行优化还是什么的引起的一些语义和语法上的不一致。
<!--more-->
# Function & Pointer

详细看过第一篇的博客后，对于Function Pointer的语法理解应该没什么问题了：
```c
int fun_o()
{
	printf("Hello Alice\n");
}
int (*fun)() = fun_o;

```
上面代码申请了一个function pointer fun 指向了 fun_o
<br>所以我们现在可以直接通过fun来调用fun_o()`(*fun)()`会输出"Hello Alice"
<br>但是机智的小伙伴可能已经发现：
```c
int fun_o()
{
	printf("Hello Alice\n");
}

int (*fun)() = fun_o;

int main()
{
	fun();
	(*fun)();
}
```
这fun()和(\*fun)()竟然输出一样！！！
<br> fun()直接就可以当做函数来用...好像编译器自己帮我们解引用(Derefer)了fun这个指针。
<br>没有找到正规的文档，也没看编译器源码，不过事实好像确实如此:)
<br>也就是说，**编译器会自动把函数指针给解引用使其使用起来就像普通函数一样**

现在看看另一个例子
```c
/* main.c */

extern void fun();

int main()
{
	printf("Main: %x\n", main);
	fun();
	return 0;
}


/* fun.c */
extern int main;

void fun()
{
	printf("Fun: %x\n", main);
}

/* shell */
gcc -m32 -o a.out main.c fun.c
./a.out
```
会发现printf打出来的结果不一样！！！
<br>在main()中打印出来的main是函数的地址(我的结果是80483fb),而fun中打印出来的main是4244c8d。
<br>查看汇编后发现：

{% img /images/20151223outdump.png 反汇编代码 %}

发现fun()打印的是main的第一条指令`lea 0x4(%esp), %ecx`,对应的编码是8d 4c 24 04，刚好按小端打印出来后就是04244c8d。

`printf(%x,var);`的语义按道理说，只是把变量里的值打出来，由于在fun.c中，main是int，指向了0x80483fb，里面的内容就是8d 4c 24 04，所以这个打印没有任何问题。但是打印main的时候，语义明显发生了变化。所以我们可以发现：**编译器会自动把打印的函数给取地址**。

当把fun.c里面的`extern int main;` 换成 `extern int (*main)();`
<br>此时打印的内容，fun()中输出的依旧是4244c8d。
<br>把`extern int(*main)()`再换成`extern int *main`，打印出来的结果依旧是4244c8d。

也就是说，如果是变量，那么`printf(%x,var);`的语义是没有变化的，都是将变量的内容取出来并打印，只有在处理函数的时候，会自动取地址。

#Array & Pointer

在上一篇中同样还提到了Array 和 Pointer的不同，当时的一个例子是优化的问题，编译器对于二维数组会进行优化，而对于二维指针却不会，这次我们来看语义上的不同。
<br>数组在内存中的存在形式与函数十分类似。我们如果申请了数组`int Arr[3] = {1, 2, 3};`，在内存中的存储方式也是1,2,3连续存数，不会有一个变量Arr,然后Arr再指向数组这样的情况。

{% img /images/20151223Array.png 数组内存存储方式 %}

现在有下面的代码：
```c
/* main.c */

extern void fun();

int Arr[3] = {1, 2, 3};

int main()
{
	printf("Main: %d\n", Arr[1]);
	fun();
	return 0;
}

/* fun.c */

extern int *Arr;

void fun()
{
	printf("Fun: %d\n", Arr[1]);
}
```
编译链接后，当执行这段代码的时候，main中会输出2，fun中会发生segmentation fault。

{% img /images/20151223segfault.png %}

也就是说，平时我们使用的 `int *p = Arr`这样的情况，**编译器会自动对Arr取地址**，并把Arr的地址存到p中。因此代码中以下这两种是一样的：
```c
int Arr[3] = {1, 2, 3};

/* Following expressions are same !*/
int *p1 = Arr;
int *p2 = &Arr;

int main()
{
	printf("%d, %d\n", p1[1], p2[1]);
	return 0;
}
```
输出的结果也都是2。而直接把int \*p的p当做和Arr一样的话就会出问题:)
<br>而对于`p[1]`这种表达，**编译器又会自动把p给解引用，取出数组地址进行运算**
<br>所以在第一个例子中，由于fun中把Arr当做指针，会自动解引用，取出Arr中的内容01 00 00 00后小端表示，等于0x1 进行[1]的运算：对0x1 + 1后访问0x00000002这个地址，所以发生segmentation fault。

#Conclusion

编译器在处理数组或函数时，会进行一些语义的转换，或许是为了保持形式的一致(p[1]与Arr[1], fun()与fun_o()),或许是考虑到不会有人想要函数的第一个指令byte...，所以在理解的时候需要注意一下这里:)。这是在学习链接的时候额外发现的问题~ 也再一次感谢实验室的各位大大们。
