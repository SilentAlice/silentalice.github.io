---
layout: post
title: "加速工作的小工具"
date: 2016-01-30 20:31:29 +0800
comments: true
tags: record
keywords: vim, tmux, zsh, oh-my-zsh, linux, plugin
description: "Record my tools and plugins on Linux and Windows"
---
我个人在工作之前总是喜欢先详细了解一下涉及到的工具，以致于都被实验室的小伙伴吐槽我每日的工作内容就是研究各种工具、插件..说来也惭愧，确实没有干什么活，倒是花了不少时间在配工具上..本文记录一下自己在接触Linux后遇到的非常赞的一些工具以及使用了这么多年Windows后用起来比较顺手的一些小软件。

<!--more-->
#Z-shell、tmux & Vim
这三个文本三巨头网上介绍的文章数不胜数，也确实是因为它们非常好用。

##Z-shell
Zsh推荐使用[oh-my-zsh](https://github.com/robbyrussell/oh-my-zsh), 相比较原本的zsh其插件更全。不过有很多小伙伴下载了oh-my-zsh也就只是使用默认的配置了。默认配置中开启了git插件，可以让我们的git目录产生一些比较不错的效果：

{% img /images/20160130git.png %}

不过还是推荐一下开启一下 z 和 d 插件：
```sh ~/.zshrc
# Add wisely, as too many plugins slow down shell startup.
plugins=(git z d zsh-autosuggestions)

#User configuration
...
```
zsh对于命令和文件名的自动补全要比bash强大太多，这也是为什么我选择它的原因。
###z plugin
z类似于模糊跳转

{% img /images/20160130z.png %}

前面的数字代表文件夹的优先级，优先级高的会优先被匹配。比如如果我们使用 `z e`，根据优先级，发现CVE的优先级最高并且含e，所以就会跳到CVE目录下。
<br>平常使用的时候，在任何目录，只要我输入`z notes`就会跳到PaperNotes目录下，是个非常好用的跳转插件。

###d plugin
d可以显示最近跳转过的目录，然后再输入数字就可以回到最近的目录：

{% img /images/20160130d.png %}

对于在多个目录下工作的情况非常好用。

##tmux
tmux全称是Terminal Multiplexer，作为一个终端复用器可以避免我们开N多个terminal，打开一个tmux就是开了一个session, 关闭session后，下次可以再attach到这个session继续上一次的工作。最大的好处在于ssh时能够继续上次的工作。

tmux里面每一个tag就是一个线程，所以可以开一个tag后开一些阻塞的服务或者虚拟机。tmux本身的分屏也非常方便，滚屏和复制的操作与Vim也十分相似。

##VIM
最后就是文本编辑器vim啦，在安装的时候推荐直接安装vim-gnome的，或者自己从源码编译，打开+寄存器。vim本身的强大和说明网上已经有很多了，这里分享一下我自己非常喜欢的一些小众的插件。

###cscope
cscope的功能是包含ctags的，它可以建立反向索引，来查找一个函数在哪些地方被调用了，这点对于我的帮助还是很大的:)

###OmniCppComplete
对于进行C和C++开发的程序员来说，这个自动补全要比vim本身的自动补全强大的多，它可以根据tags来补全一个struct的成员。

###nerdtree or lookupfile
使用nerdtree的小伙伴非常多，毕竟有一个目录树能方便的打开想要打开的文件。不过个人非常推荐lookupfile，这是一个文件模糊查找+自动补全的插件。我想在寻找某个文件的时候更多是：进入mm.c或者进入那个xxxentry.S的情况:

{% img /images/20160130lookupfile.png %}

这样寻找的效率个人感觉远高于nerdtree，不过lookupfile也是根据tags进行索引，为了避免太多无关选项需要单独为其建立一个文件名的tags

###FuzzyFinder
模糊查找当前目录文件、tags的插件。
<br>与lookupfile的侧重点不太一样，FuzzyFinder对于搜索的关键词数目没有要求，而且不需要为其单独建立tags，个人感觉比较适合用于一个目录下的多个文件的处理：

{% img /images/20160130fuzzyfinder.png %}

###Grep.vim
grep的强大是众所周知的，Grep则将这强大与vim进行了结合，使得我们可以直接跳转到相应的文件中。不适用cscope的同学也是用Grep来搜索函数在哪里被调用...

Linux中最基本的几个工具就是这些了..一般shell本来就带的ssh这些就不介绍了..

---

Windows中的小工具更是多到数不清，不过用了这么多目前感觉最好用的其实也就那几个..

##TreeSize
平常使用TreeSizeFree就够用了，一款查看文件占用情况的小工具，方便我们进行文件的管理。类似于Linux中的df、du

{% img /images/20160130treesize.png %}

平常自己清理文件的时候经常会用这个小工具。

##LastActivityView
类似于Linux的日志中的图形版，能够非常清晰而且详细的记录装机到现在的所有动作...其实就是读了系统日志啦..

{% img /images/20160130lastactivityview.png %}

##Listary
Windows中的搜索神器，不用再嫉妒Bash，不用再忍受Windows本身龟速的搜索啦~

{% img /images/20160130listary.png %}

最最关键的是，平时这东东是隐藏的，在空白处搜索就会自动弹出来，非常好用。而且在Dialog对话窗中，使用Ctrl+G自带的快捷键可以直接让对话框中的目录变成刚才最后一次打开的目录。上传文件再也不用一点点找了..

##Synctoy
微软自家的同步软件，可以看做是Linux中rsync的图形界面版，增量同步、有Synchronize、Echo、Contribute三种模式。

* Synchronize两个文件夹会完全镜像，互为生产者。
* Echo类似于备份，生产者的改动会影响备份，但是反过来不会。
* Contribute类似于Merge, 将生产者的改动merge到拷贝中。

非常好用的备份同步软件。

---

每个人都有自己喜欢的一套工具包，本文仅作为记录和推荐。
