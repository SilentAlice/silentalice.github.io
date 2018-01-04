---
layout: post
title: "Octopress博客(1)-在windows 10上使用octopress搭建个人博客"
date: 2015-11-13 19:53:20 +0800
comments: true
tags: tutorial
keywords: octopress, github, gitcafe, page, blog, windows, windows 10
description: "build blog on github with octopress"
---
#Introduction
[Octopress](http://octopress.org/)是一款基于Jekyll的静态网页生成框架，使用[Ruby](https://www.ruby-lang.org/en/)实现。

Octopress的博客支持[Markdown语法](http://daringfireball.net/projects/markdown/syntax)，Markdown是一种标记语言，可以快速生成Html并能内嵌Html，因此用来写文章或笔记的效率会很高。

Octopress是静态网页生成框架，因此可以利用GitPage部署在Github上，国内可以部署在Gitcafe上面。
<!-- more -->
---
#Prerequisite
* 了解简单的命令行操作
* 了解Git的基本操作和分支概念
* 具有一定的编程基础
* 了解Html脚本基础
* 了解简单的Markdown语法

#Preparation
我搭建的环境是Windows 10 64位，Ruby2.2.3, Python2.7.10, Octopress3.0, 命令行用的就是GitBash，没有使用cmd

* Git: [http://git-scm.com/download/](http://git-scm.com/download/)
* Ruby2.3.3&DevKit: [http://rubyinstaller.org/downloads/](http://rubyinstaller.org/downloads/)
* Python2.7: [https://www.python.org/downloads/](https://www.python.org/downloads/)
* Octopress3.0: git://github.com/imathis/octopress.git

32位的请选择对应的版本，Python只能使用2.7，因为之后要用的一个代码高亮脚本不支持Python3.5

#Installation
* Git or GitBash的安装就一直next就行
* Ruby 一路next，路径中最好不要含有空格或中文,不过注意选择上将ruby的可执行文件添加到环境变量中"Add Ruby executables to PATH"。或者自己在环境变量里配置。安装完成后可以使用Gitbash or cmd 输入`ruby --version`来查看。
* Python2.7 与安装Ruby类似，路径中不要含有中文或空格，添加到PATH也勾选上。
* 安装DevKit，解压后进入该文件夹，运行
```ruby
ruby dk.rb init
ruby dk.rb install
```
* 代码高亮脚本Pygments: 在GitBash中:`easy_install pygments`<br>
	安装完Python后在安装目录下的Scripts文件夹中，应该有easy_install.exe, 如果没有的话请自行下载，并且确保该Scripts文件夹也在环境变量PATH中(我放在全局的PATH中好像用不了，无奈放到了当前用户的PATH路径下才能正常使用)
* Octopress
```sh
cd /D/
git clone git://github.com/imathis/octopress.git blog(your dir name)

# 安装依赖项
gem install bundler
bundle install

# 安装octopress默认主题
rake install
rake preview
```

之后在浏览器里输入127.0.0.1:4000就可以观看效果了

#Deployment
* Github Page<br>
在Github上注册一个账号，并新建一个Repository:名为：username.github.io (我的为silentalice.github.io)
<br>在Bash中发布：
```ruby
rake setup_github_pages #配置Github_page的路径，按照提示输入自己的repository地址
git@github.com:SilentAlice/silentalice.github.io.git

rake deploy #将网站发布到github的master分支上

# 之后可以将源码也放到Git上方便维护：
git add .
git commit -m "source of octopress"
git push origin source # 放到source分支
```
使用git@github.com这种形式的要用到ssh，有关ssh的文章请参考另一篇文章：[《使用SSH通过代理连接Git》](http://silentming.net/blog/2015/11/14/git-ssh-proxy/)

#Note
发布文章或者site的话可以使用：

```
rake new_post[title of post] # post在source/_post/下
rake new_site[name of site] # site会自动生成到source/nameofsite/index.markdown

# 写完保存后，就可以生成了
rake generate

# 最后就是发布
rake deploy
```

###Linux
Linux上安装Ruby与Python更加简单，其余的操作和在Windows上是一致的，这也是使用Octopress的优点：跨平台~

