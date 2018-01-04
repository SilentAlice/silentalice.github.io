---
layout: post
title: "PARSEC & SPEC CPU Benchmark Deployment"
date: 2017-05-31 12:56:02 +0800
comments: true
tags:
- tutorial
- record
keywords: benchmark, parsec, spec
description: "My setup of parsec and spec benchmark"
---

测Evaluation的时候一般会测一下SPEC 和 PARSEC benchmark, 本篇简单介绍一下两者的部署和运行。

<!-- more -->

# SPEC CPU

目前比较新的是[SPEC CPU 2006][1], SPEC主要是CPU性能测试，内存也有一部分，首先从官网下载压缩包..

```sh
# ls
benchspec  config  Docs      install.bat  LICENSE      MANIFEST      README      redistributable_sources  Revisions  run.sh  shrc.bat    tools         version.txt
bin        cshrc   Docs.txt  install.sh   LICENSE.txt  original.src  README.txt  result                   rr_moved   shrc    SUMS.tools  uninstall.sh
```

解压后直接运行`install.sh`的话可能会有权限问题, 那么手动改权限↓:

```sh
find . -type d -exec chmod 755 {} ";"
chmod 644 MANIFEST
rm -rf bin
./install.sh
```

↑中`find`找出所有的目录，并对每个目录调用`chmod 755`, `";"`是为了结束`chmod`命令，否则这之后所有的东东都会作为`chmod`的参数。权限改为`x + r`。
之后删除已有的bin，安装即可。

### Usage

使用前需要修改shell 的source: (我用的zsh), 而后根据需要build和run我们的benchmark即可

```sh
source shrc
# Build
runspec --action build 429.mcf

# Run
runspec --action onlyrun 429.mcf
```

### Misc

SPEC的结果会放到result文件夹，跑一个比较慢，写个脚本跑一晚上第二天到result里面翻就行

# [PARSEC][2]

类似，下载解压:

```sh
CHANGELOG  CONTRIBUTORS  FAQ  LICENSE  README  bin  config  env.sh  ext  log  man  pkgs  toolkit  version
```

Parsec的环境需要在bash中用，所以请先切到Bash, 而后用给的env.sh

```sh
bash
source env.sh
```

### Usage

```sh
# Replace 'streamcluster' to 'all' if you are going to test all benchmarks
parsecmgmt -a build -p streamcluster
parsecmgmt -a run -p streamcluster [-i simlarge [-n 2]]
parsecmgmt -a fulluninstall -p streamcluster 
```

具体参数自己可以查.. 这个跑一个比较快，结果直接就输出了，所以随手记就行。


# Note

一些依赖库↓:

```sh
sudo apt-get install -y build-essentail m4 x11proto-xext-dev libglu1-mesa-dev libxi-dev libxmu-dev libtbb-dev gfotran libglib2.0-dev zlib1g-dev libxml2-dev gettext
```

其中`dedup`直接运行可能有一些问题, 需要替换一些东东:

```sh replace.sh
#! /bin/bash
for i in 0 1 2 3 4 5 6 7 8 9
do
    echo "Replacing '=item $i' to '=item C<$i>'"
    grep -rl "=item $1" * | xargs sed -i "s/=item $i/=item C<$i>/g"
done
```

Reference:
[parsec-3.0-installation-issues](https://yulistic.gitlab.io/2016/05/parsec-3.0-installation-issues/)






[1]: https://www.spec.org/cpu/
[2]: http://parsec.cs.princeton.edu/
