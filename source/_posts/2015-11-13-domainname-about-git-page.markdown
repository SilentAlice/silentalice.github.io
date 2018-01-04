---
layout: post
title: "Octopress博客(2)-将Github Page绑定到自己的域名上"
date: 2015-11-13 21:38:16 +0800
comments: true
tags: tutorial
keywords: Github, Page, Blog, Octopress, Domain
description: "Use individual domain to access github pages"
---
#Introduction
[上一篇文章](http://silentming.net/blog/2015/11/13/build-blog-on-github-with-octopress/)主要介绍了如何在Windows上搭建Octopress博客，我们的博客使用的是Github Page或GitCafe Page，默认情况下访问的域名是username.github.io。如果自己拥有自己的顶级域名的话，就会想要将自己的域名绑到自己的域名上。

<!-- more -->
#Prerequisite
* 有自己的域名
<br>我买的是[中国数据](http://www.com.top/err.asp)的顶级域名silentming.net

#Octopress
在blog(your blog dir name)/source/ 下新建一个名为CNAME的文件，内容为:
```ruby Cotent of CNAME https://github.com/SilentAlice/silentalice.github.io/blob/master/CNAME My CNAME
silentming.net

# 之后重新发布
rake deploy
```
确保在repository的master分支下有CNAME文件，其作用就是将username.github.io映射为CNAME里的域名，所以现在我访问silentalice.github.io就会变成访问silentming.net了

#Domain
首先ping github.io来查看它的IP

{% img https://c2.staticflickr.com/6/5726/30425461540_04e2220b6e_o_d.png %}

在自己的域名管理中进行相应的设置，如果是顶级域名的话要添加一条A记录：

{% img https://farm6.staticflickr.com/5672/30425461640_2709d3aaba_o_d.png %}

之后就可以使用自己的域名访问博客了
