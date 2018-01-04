---
layout: post
title: "Octopress博客(4)-基础操作"
date: 2015-11-14 09:50:18 +0800
comments: true
tags: tutorial
keywords: Octopress, Markdown, 基础操作
description: "Basic operation on octopress with markdown"
---
博客已经能够正常访问了，本篇主要介绍一下Octopress的基本操作，关于基本操作官网有更详细的，这里只简单进行必要的总结~

#Configuration
配置文件一共有4个：

* _config.yml	# 关于Jekyll的配置文件，也是主要是用的配置文件
* Rakefile		# 有关部署的配置文件
* config.rb		# 有关文件路径的配置文件
* config.ru		# 有关出错处理的配置文件

在前面的文章中，我们已经修改了*Rakefile*以实现同时部署gitcafe和github，其他的内容一般也涉及不到。*config.rb*与*config.ru*使用默认的路径就可以，所以我们主要修改的是*_config.yml*文件。这里只说一下一般会用到的配置：

<!-- more -->

```cfg _config.yml
#网站的链接，自己没有域名的话就是http://username.github.io
url: http://silentming.net 

# 博客的名字
title: SilentMing's Blog

# 副本题(名字下面的小字)
subtitle: xxxxx

# 作者，用来写在footer里或者license里面的
author: SilentMing

# 网站内搜索使用的引擎
# Google的话，搜索时会加上site:url keyword
# Baidu的还没研究
simple_search: https://www.google.com/search

# 描述
description: this is a xxx blog

# RSS订阅
subscribe_rss: /atom.xml
subscribe_email: 

# 邮箱
email: yumingwu233@gmail.com

# 中间是在blog页面显示多少文章等
# 之后是侧边栏的定制：
default_asides: [asides/about.html, asides/xxx.html]

# 后面是Github等内置的侧边栏或分享的系统配置
# 如果在上面敲上自己的账户名的话，它会自己拉取公开信息并显示
```
#Post and Site
在bash or terminal中：
```sh
new_post["name of post"]  # 创建新的post

# 创建markdown site,访问用 url/sitename/
new_site["sitename"]	  # 会在source/sitename/下创建index.markdown

# 创建普通site, 如果不是index.html则访问为 url/dir/site.html
new_site["dir/site.html"] # 会在source/dir/创建site.html
```

#Img and Code
由于markdown本身支持内嵌html，所以嵌入图片可以使用：


```sh
<img src="path/to/img" title="title" alt="xxx">

<!-- 也可以使用Octopress提供的更简单方法 -->
{% img [class name] /path/to/img [width] [heigh] [title] [alt] %}

<!-- 如果想嵌入gist代码的话，可以直接使用：-->
{ % gist gist_id [filename] % }

```
嵌入代码的更多内容可以参考[官网文档](http://octopress.org/docs/plugins/codeblock/)

如果使用的是默认模板和配置的话，以上的操作已经够用，自己只需要在\*.html或\*.markdown上写内容就好。

#Misc
* Markdown的教程推荐[Daring Fireball](http://daringfireball.net/projects/markdown/syntax)，对应的中文版本是[http://www.appinn.com/markdown/](http://www.appinn.com/markdown/)
* Git的教程推荐[官网教程](http://git-scm.com/book/zh/v2)，有配图说明且十分详细, 也可以生成电子书下载！
