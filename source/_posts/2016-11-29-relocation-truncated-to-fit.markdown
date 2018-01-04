---
layout: post
title: "[Forward]Relocation Truncated to Fit"
date: 2016-11-29 12:05:44 +0800
comments: true
tags: programming
keywords: Linker, bug, error
---
# Interesting linker error

When you are programing a x64 program, it's high likely that you encounter such a error: "**relocation truncated to fit: R_X86_64_32S against symbol**". What happened? especially when you can run this program successfully on an old machine with same / old version. It may appears when you write inline assembly or after you changed your linker script.

This article may also help you:
[relocation truncated to fit - WTF?](https://www.technovelty.org/c/relocation-truncated-to-fit-wtf.html)

Although forward is not recommended, this article is pretty useful for me and this can be treated as a replication just in case.

<!-- more -->

Following is forwarded from above article;

```sh
(.text+0x3): relocation truncated to fit: R_X86_64_32S against symbol 'array' defined in foo section in ./pcrel8.o
```
Consider following code snippet:

```asm
$ cat foo.s
.globl foovar
  .section   foo, "aw",@progbits
  .type foovar, @object
  .size foovar, 4
foovar:
   .long 0

.text
.globl _start
 .type function, @function
_start:
  movq $foovar, %rax
```

The C program may be like this:

```c
int foovar = 0;

void function(void) {
  int *bar = &foovar;
}
```

And when you disassembly the code:

```sh
$ gcc -c foo.s
$ objdump --disassemble-all ./foo.o
./foo.o:     file format elf64-x86-64

#Disassembly of section .text:
0000000000000000 <_start>:
   0:        48 c7 c0 00 00 00 00   mov    $0x0,%rax

#Disassembly of section foo:
0000000000000000 <foovar>:
   0:        00 00          add    %al,(%rax)
   ...
```

You may have found that `mov` only has 4 byted allocated for linked to put in the address of foovar.<br>
If you check the relocation:

```sh
$ readelf --relocs ./foo.o

Relocation section '.rela.text' at offset 0x3a0 contains 1 entries:
  Offset          Info           Type           Sym. Value    Sym. Name + Addend
000000000003  00050000000b R_X86_64_32S      0000000000000000 foovar + 0
```

Type `R_X86_64_32S` is only a 32-bit relocation. So you have figurred the problem.

```sh
$ cat test.lds
SECTIONS
{
 . = 10000;
 .text : { *(.text) }
 . = 5368709120;
 .data : { *(.foo) }
}
```

This now means that we can not fit the address of foovar inside the space allocated by the relocation. When we try it:

```sh
$ ld -Ttest.lds ./foo.o
./foo.o: In function `_start':
(.text+0x3): relocation truncated to fit: R_X86_64_32S against symbol `foovar' defined in
```
What this means is that the full 64-bit address of foovar, which now lives somewhere above 5 gigabytes, can't be represented within the 32-bit space allocated for it.

For code optimisation purposes, the default immediate size to the mov instructions is a 32-bit value. This makes sense because, for the most part, programs can happily live within a 32-bit address space, and people don't do things like keep their data so far away from their code it requires more than a 32-bit address to represent it. Defaulting to using 32-bit immediates therefore cuts the code size considerably, because you don't have to make room for a possible 64-bit immediate for every mov.

So, if you want to really move a **full 64-bit immediate into a register**, you want the `movabs` instruction. Try it out with the code above - with `movabs` you should get a `R_X86_64_64` relocation and 64-bits worth of room to patch up the address, too.

If you're seeing this and you're not hand-coding, you probably want to check out the -mmodel argument to gcc.

------

So, you may need to change the origin address in your linker script or use `movabs` instead to avoid this problem.

