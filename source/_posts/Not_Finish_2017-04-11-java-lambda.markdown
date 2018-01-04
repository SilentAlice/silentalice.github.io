---
layout: post
title: "[Not Finish]Lambda Expression in Java"
date: 2017-04-11 20:54:41 +0800
comments: true
tags: 
- programming
- record
keywords: java, lambda
description: "Notes of lambda in java"
---

本篇简单介绍一下Java中Lambda表达式，Lambda是在Java 1.8中正式引入的，正巧自己之前学了程序语言理论，对Lambda也有了一定的了解，所以进行一下记录。

# Lambda Calculus

> Lambda calculus (also written as λ-calculus) is a formal system in mathematical logic for expressing computation based on function abstraction and application using variable binding and substitution.[wiki][1]

Lambda表达式的目的在于使用函数来解决计算问题，这已经被证明是图灵完备的，因此我们之前所写的所有程序都可以在Lambda Calculus中对应的表达出来。

详细的内容可以才考教材[Types and Programming Languages Benjamin C. Pierce][2], 主要讲了Untyped Lambda Calculus, Simply Typed Lambda Calculus, Normalization, References, Exceptions, Subtyping, Recursive Types, Type Reconstruction等. 有这些基础会更好理解Lambda，不过不是必须的。

|Syntax|Name|Description|
|:---|:---|:---|
|a|Variable|A character or string representing a parameter or mathematical/logical value|
|(λx.M)|Abstraction|Function definition (M is a lambda term). The variable x becomes bound in the expression.|
|(M N)|Application|Applying a function to an argument. M and N are lambda terms.|

* 普通变量没什么好解释的
* `λx.M`就可以看做一个函数，需要接受一个参数x, 返回一个M的表达式，参数可以是其他函数，而M本身可以是另一个函数:`λx.λy.x+y`就是接受一个参数x 返回一个函数:`λy.x+y`, 这个函数接受一个y返回x+y.
* `(M N)`被称作Application, 可以理解为两个表达式放一起，由于M, N可以为其他的App or Abs, 所以我们由上面的函数定义: `λx.λy.x+y 2 3` -> `λy.2+y 3` -> `2+3` -> `5`.

这就是函数式语言的特点之一，一个函数可以被当做参数传递给其他函数。函数可以通过这样一个个串起来来执行。

# Functional Languages

### Immutable

> In computer science, functional programming is a programming paradigm—a style of building the structure and elements of computer programs—that treats computation as the evaluation of mathematical functions and avoids changing-state and mutable data.[wiki][3]

这里可以看出函数式语言的特点之一在于**avoid changing-state and mutable data**, 变量的不变性, 这里可以看个例子:

```java
// We want to change `i am alice` to `I am Alice`
// And we have String str = "i am alice"
// Non-functional:
void change(String str) {
  str.charAt(0) = 'I';
  str.charAt(5) = 'A';
  return ;
}

// Functional:
String change(const String str) {
  String ret = "I am Alice";
  return ret;
}
```

上面的例子主要是为了帮助理解**数据不变性**, 函数式语言中接受的参数不会进行修改，而会返回一个新的值。这样的好处是什么呢？在于并行。试想一下，现在我们有10个函数，每个函数要处理'i am alice'中的一个字符，函数式就可以同时并行执行，因为每个没有哪个函数会修改原本的值，**接受一个，返回一个**. 而非函数式会对对象本身进行操作，因此**必须等到前一个执行完才能执行下一个**. 

这个例子同样:

```java
int num;
void increment() {
  num++;
}

// Functional 
int increment(int num) {
  return num + 1;
}
```

### Stateless

数据的不变性也即是函数之间的独立，一个函数处理的上下文与其他函数没关系，因此函数不需要记录共享变量的状态。 关于状态和无状态的最明显例子就是: REST **Representational state transfer**[4]，其主要特点就是stateless, 而一个明显应用就是HTTP, 一个HTTP请求都是独立的，服务器接受一个请求发起一个回复，不用记录状态，因此不但易于维护而且可以高并发；TCP就属于需要记录状态的，因此双方需要协商来维护状态的一致。 函数式编程的一个思想同样也是stateless, 这样一个函数不用依赖其他函数, 一个变量a, fun1 获得一个a的拷贝进行修改，返回b, fun2获得一个a的拷贝修改返回c, fun1, fun2可以同时执行。而如果我们传的是指针，那么就要保证两者不会同时修改。

### Pipeline

其实上面的例子很容易能够发现函数的pipeline, `a -> fun1() -> b -> fun2() -> c -> fun()3 -> result`. 这样当数据是批量产生的时候，比如有茫茫多的a要处理成result,
那么就可以利用pipeline的形式来处理，着同样是函数是高并行的原因之一。

一个例子就是Linux的管道:

```sh
ps aux | awk '{print $2}' | sort -n | xargs echo
<=>
result = foreach(pid) do {awk 'print $2'; sort -n; xargs echo}
```

里面ps aux打出所有进程，就是一个数据源，里面每一个数据都要打印第二列的PID, 并排序, 之后显示. 

### Readability

由于函数是编程可以给另一个函数传递一个函数，所以往往从写法我们就能看出来函数要执行的功能，这也同样增加了代码的易读性。

```java
Person[] selectedPeople = Person.getSelected(people, p->p.getAge() >= 18);
```

↑是Java里一种lambda用法，从数组中选出符合条件的元素，一方面这里的条件可以当做参数指定:`p->p.getAge() >= 18`, 而同时由于条件是当做参数传入的，所以代码也更加易读，
同时代码也更加简洁，因此这样能提高编码效率.












[1]: https://en.wikipedia.org/wiki/Lambda_calculus
[2]: http://www.cis.upenn.edu/~bcpierce/tapl/
[3]: https://en.wikipedia.org/wiki/Functional_programming
[4]: https://en.wikipedia.org/wiki/Representational_state_transfer
