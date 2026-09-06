---
layout: post
title: "Octopress博客(3)-同时部署管理GitCafe和GitHub与CDN加速"
date: 2015-11-13 23:09:18 +0800
comments: true
tags: tutorial
keywords: Octopress, Github, Gitcafe, Page, Cloudflare, CDN
---
#Introduction
在上一篇中我们已经能够成功应用自己的域名，但是会发现github对于国内的用户访问好像比较慢，而gitcafe对于国外的用户又没有github好，因此本篇将说明如何同时部署博客到github和gitcafe，以及调整域名管理让国内的用户访问gitcafe，国外的用户访问github。最后介绍一个CDN(Content Delivery Network)服务来加速博客的访问。

#Preparation
* [Gitcafe](https://gitcafe.com)
<br>注册Gitcafe账号，并仿照Github建立repository (gitcafe里repository是username，不需要加gitcafe.io)。

* [Cloudflare](https://www.cloutflare.com)
<br>Cloudflare是一个CDN服务提供商，它能将你的网站的CSS、img、js缓存到世界各地的服务器中，当用户访问时便可以用最近的缓存来加载网页提升访问速度，个人使用的话可以使用它的免费计划。
<br>我们先注册个账号:)

<!-- more -->

#Deploy on gitcafe
进入octopress目录：

```ruby
cd _deploy
git remote add gitcafe git@gitcafe.com:SilentAlice/silentalice.git
git push -u gitcafe master:gitcafe-pages
```

Gitcafe的Page只能发布到gitcafe-pages分支上，所以git push -u gitcafe(设定upstream为gitcafe) master:gitcafe-pages(将本地的master分支推送到remote的gitcafe-pages上)。之后博客也就被部署到了gitcafe上。

如果觉得手动比较麻烦的话，修改octopress/Rakefile, 

```ruby
Rake::Task[:copydot].invoke(public_dir, deploy_dir)
puts "\n## Copying #{public_dir} to #{deploy_dir}"
cp_r "#{public_dir}/.", deploy_dir
cd "#{deploy_dir}" do
  system "git add -A"
  message = "Site updated at #{Time.now.utc}"
  puts "\n## Committing: #{message}"
  system "git commit -m \"#{message}\""
  puts "\n## Pushing generated #{deploy_dir} website"
  Bundler.with_clean_env { system "git push origin #{deploy_branch}" }
  puts "\n## Github Pages deploy complete"

# Add your new code here
  system "git push -u gitcafe master:gitcafe-pages"
  puts "\n## Gitcafe Pages deploy complete"
```

在添加这些代码之前，需要先在\_deploy中添加remote add gitcafe哦。现在博客也会发布到Gitcafe上了。

#Domain

Gitcafe的域名解析要比Github简单许多：在setting->Pages添加自己的域名即可：

{% img https://farm6.staticflickr.com/5500/30090789803_de2c7714fd_o_d.png %}

依旧是ping gitcafe.io来查看IP：

{% img https://farm6.staticflickr.com/5501/30090789673_e232823d2d_o_d.png %}

然后在自己域名的DNS解析管理中添加新的A记录解析：

{% img https://farm6.staticflickr.com/5792/30090789563_2e650c1d4a_o_d.png %}

中国数据的DNS解析服务提供针对不同线路不同解析的服务，我们可以将国内的电信、联通等解析到Gitcafe的IP上，而将默认线路解析到Github即可实现让国内外不同用户访问不同服务器的策略。

#CDN

刚才已经介绍了，Cloudflare可以让访问你博客的流量通过他们智能的云实现负载均衡。同时Cloudflare还提供对于访问的保护：

{% img https://farm6.staticflickr.com/5738/30425461700_b8746629be_o_d.png %}

通过使用他们的服务，我们网站的内容便可以缓存到世界各地他们的服务器上，Octopress很多模板会用到Google字体，Cloudflare会事先缓存js, css, img；当访客得到回复的html时便会使用本地的js, css迅速渲染。只是改动html的话不会影响他们的缓存，所以博客的访问一方面可以实现负载均衡，也能提升安全，尤其是对于使用个人服务器的情况。Cloudflare对免费非盈利的个人网站提供有免费计划，我们便可以借此来提升博客的浏览体验。

在最上面点Add site后，按照指导一步步走就可以了，最后它会提供给你两个新的DNS:

{% img https://farm6.staticflickr.com/5623/30425461770_c7961de613_o_d.png %}

在我们自己的域名管理页面中，替换原来的Nameserver为Cloudflare的即可：

{% img https://farm6.staticflickr.com/5736/30090789883_c195704d8f_o_d.png %}

之后就会发现网页的加载速度非常快了。

# Migrate to New Computer

当我们需要在多个地方维护博客，或者更换电脑时重新回复博客内容，需要先提交最新的source，之后再在新电脑安装环境即可：

```sh
# old Computer
cd octopress
git add .
git commit -m 'prepare for migration'
git push origin source #push 到origin的source分支

# new Computer
# You need to build your environment first (ruby, python etc)
git clone -b source git@github.com:SilentAlice/silentalice.github.io.git octopress
cd octopress
git clone -b master git@github.com:SilentAlice/silentalice.github.io.git _deploy

# install dependency
gem install bundler
bundle install

# generate site
rake generate
rake preview
```

之后就可以在新电脑上继续维护博客啦~

#Note

#### 360网站卫士公共库停止运行 (2016-09-17)

这几天打开网站发现一直卡在ajax.useso.com这边，原来以为是360那边抽风就没鸟，后来查了下发现360已经停止了这个服务(Are u kidding me?!)<br>
(公告)http://bbs.360.cn/thread-14471550-1-1.html<br>
不过Google已经在北京设置了服务器，所以直接使用Google API的速度已经非常快了... 于是换回去就行了。<br>
或者在自己的主题里把google api去掉吧..用离线的也行，只不过享受不了google的CDN服务就是了

#### Google Library (2016-01-30)

由于众所周知的原因，国内一般上Google是上不去的。而Octopress的许多主题都会用到Google的公共库，所以导致网页在国内久久不能打开。我刚加上CDN服务的时候由于频繁的访问使得缓存服务器中缓存了Google的文件，所以也没遇到打开很慢的情况。不过后来博客搭起来之后就没有频繁访问了，估计缓存服务器里面也没相应的文件，打开就很慢。不过好在国内有Google公共库的代理。这次尝试的是360的常用前端公共库CDN服务：http://libs.useso.com/
<br>只需要将所有域名换成对应的useso的即可。
```
ajax.googleapis.com -> ajax.useso.com
fonts.googleapis.com -> fonts.useso.com
```
------

#### Individual Repo (2015-12-02)

在添加了home页之后，发现总是出现Not Found。
<br>本来是将home页的工程单独部署到了一个单独的Repository:WebGL，由于Gitcafe和Github会自己将silentalice.github(cafe).io解析到silentming.net，所以本来只要silentming.net/WebGL就可以直接访问新的添加页。
<br>但是由于我使用了CDN加速，CloudFlare在加速的时候会将网页的Img、css等文件提前下载到本地服务器，而我的WebGL不在网页的目录树中，所以本地服务器中没有缓存WebGL的相关内容。
<br>用户在访问的时候会先访问本地服务器，于是就找不到WebGL了orz。
<br>CDN的加速可以让网页访问速度提高3-5倍，实在是不想放弃啊，当初用的时候就有用户提过这个问题，我还完全没有在意，不过现在看来确实这个是它的弊端。

最开始我不想将home的相关内容放到octopress的repo中一是想方便管理，而是以为每次ruby的脚本都会删除和重新创建网站，pull的时候会有很大开销。不过今天发现，source里面的目录也只有post会被重新创建，但是img这些是不会的，所以放进来的开销其实也还好。

------

#### GitCafe is gone (2016-07-15)
Gitcafe已经合并到coding.net，coding.net由于建立的初衷不是用来建站，因此其演示功能是按天收费的，并且不支持绑定自己的域名而只能使用其提供的二级域名，所以目前我只部署到github上了，不过由于CDN的加速，国内的访问速度依旧非常快。并且将用到google渲染的内容给去掉后，现在也不会因为需要翻墙等原因导致网页加载缓慢。目前就保持这样了...

