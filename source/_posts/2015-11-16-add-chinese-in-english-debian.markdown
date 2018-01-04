---
layout: post
title: "在英文版Debian/Ubuntu中添加中文拼音(双拼)输入法"
date: 2015-11-16 12:38:54 +0800
comments: true
tags: 
- tutorial
- linux
- record
keywords: english, pinyin, shuangpin, debian, ubuntu, input method, chinese
description: "Add chinese input method in English Debian"
---
Although for most time english is enough, we have to input some chinese when browse some chinese sites.This post will show how to add chinese input method in Debian(english version). 
<!-- more -->
#Chinese Support

* add chinese locales support:

```sh
sudo dpkg-reconfigure locales 

```

  Add **zh_CN GB2312**, **zh_CN_GBK**, **zh_CN.UTF-8**

{% img https://farm6.staticflickr.com/5565/30608987322_25954a88fb_o_d.png %}  

  but still set default locale as en_US.UTF-8

  > This step can be manually configured in /etc/locale.gen

* install fonts

      sudo aptitude install fonts-arphic-uming xfonts-intl-chinese xfonts-wqy



#Fcitx Input Method

* install fcitx and fcitx-pinyin


      sudo aptitude install fcitx fcitx-pinyin

* install im-config to config the input method


      sudo aptitude install im-config

* config the input method to fcitx


  use `im-config`, then choose fcitx


{% img https://farm6.staticflickr.com/5709/30608987562_21e78eaf6e_o_d.png %}

* restart the xwindows with `sudo startx`

* Add shuangpin or pinyin in Input Method

  use `fcitx-configuretool` to add shuangpin and pinyin

{% img https://farm6.staticflickr.com/5754/30090790343_181194982e_o_d.png %}

# Problem

sometimes, we can't add pinyin or shuangpin in english environment. Just set system's **Region and Language** as chinese. (Language Support on Ubuntu)

In chinese environment, use `fcitx-configuretool` to add shuangpin or pinyin in Input Method (I think system will not found pinyin in eng environment). Then change system language back to english. Now you can just use chineseinput in english debian. 

#Supplement

To use Wubi or Google Pinyin etc, you have to add these input method like `sudo aptitude intall fcitx-googlepinyin`.  

As I am used to use MS shuangpin schema. To change it, use `fcitx-configtool` and configure shuangpin schema to MS:

{% img https://farm6.staticflickr.com/5766/30608987722_08cdb09fb2_o_d.png %}
