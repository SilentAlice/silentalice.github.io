---
layout: post
title: "Using cntlm Proxy on Linux"
date: 2017-07-30 17:16:38 +0800
comments: true
tags:
- tutorial
- linux
- record
keywords: cntlm, proxy
description: "Using cntlm proxy service on Linux"
---

在公司或学校的代理往往只给固定IP(host)上网的权限，或者验证服务器只能用NTLM(v2)方式而拒绝明文密码方式，而我们的其他设备如果想通过host来上网的话就需要将host作为一个小的踏板, 
Cntlm 是一款能满足这个需求的轻量级小程序，本文对其进行简单的介绍。

<!-- more -->

# Installation

安装非常简单:

```sh
sudo apt-get install cntlm
```

# Configuration

安装好了之后在`/etc/cntlm.conf`这里就会有一个默认的配置文件，需要sudo权限编辑，

```sh
# username of your proxy
Username      username 

# Domain of your proxy (e.g. ipads.se.sjtu.edu.cn)
Domain        ipads.se.sjtu.edu.cn

# Password (Not secure, we will introduce other way)
Password      password 

# Parent proxy address (e.g. 10.0.0.1:8080)
Proxy         10.0.0.1:8080

# Bypass some address
NoProxy         localhost, 127.0.0.*, 10.*, 192.168.*

# Listen port, you can add more 
Listen        port

# Gateway (if yes, other device can using hostip:listen port as proxy)
Gateway         yes

# White list
# Allow 192.168.0.0/16
# Allow 10.140.23.223/32

# Deny all addresses
Deny 0/0
```

Now device can use hostIP:port to connect to internet

简单的配置文件如上，其实就是将已有的代理转到了一个本地的代理，省去了配置用户名密码的麻烦；
如果Gateway是yes的话其他的设备也可以通过host来使用代理。

不过Password如果是明文非常不安全，加上有的机构可能指定验证方式(比如指定NTLM), 这样的话我们就需要把password那行换掉:

```sh
$ cntlm -H
(input your password)

PassLM          D3626C186D2CE90B552C4BCA4AEBFB11
PassNT          40CC50018882A102366D14C431E315FF
PassNTLMv2      B6E48FB02DE891073BB38151E826EF5D    # Only for user '', domain ''
```

将上面所需内容直接拷到配置文件中，并添加:

```
# e.g. NTLM
Auth  NTLM
```

之后就可以使用 `hostip:port` 代理来上网了

### Proxy setting

```sh
# Add to bashrc/zshrc etc.
export http_proxy=hostip:port
export https_proxy=hostip:port
...
```

### Let sudo perserve proxy

```sh
sudo vi /etc/sudoers

# Add one more line:
Default env_keep="http_proxy https_proxy"
```

if your sudores is corrupted. Using `pkexec vi /etc/sudoers` to repair it

### Git Configuration

```sh
# ~/.gitconfig

[http]
        proxy=http://hostip:port

[https]
        proxy=https://hostip:port

```

