---
title: "Using CloudFlare Warp to Access ChatGPT"
comments: true
date: 2023-03-27 19:39:51
tags:
- tutorial
- record
keywords: v2ray, cloudflare, warp, chatgpt
---

最近互联网的宠儿想必非ChatGPT莫属，在人工智能大火以后的这么多年，
第一款让所有打工人都切实感受到或方便或恐惧的AI工具诞生了，
但是在火热的当前更多的小白还无法接触这一最新的技术革命，
直接访问openai得到的是对中国大陆的拒绝，
好不容易使用vps搭了VPN的也惨遭Block封锁……

本篇记录通过CloudFlare Warp套壳获得ChatGPT访问权限的过程。

<!--more-->

## Preparation

- VPN
  首先需要自己的VPN, 能够访问`openai.com`，这是一切的开始<br>
  可以参考: [使用免费的亚马逊云服务(AWS)][1]获取免费的VPS(Virtual Personal Server)
  与[使用V2Ray搭建个人VPN][2]来搭建个人VPN

- OpenAI Account
 OpenAI账号需要在官方自己注册，注册时需要国外的手机号，这里推荐一个比较便宜的平台:
 `https://sms-activate.org/` 20min不限次短信的虚拟个人手机号。
 一个OpenAI的虚拟手机价格大约在3￥RMB左右

理论上来说，这个时候直接访问chatgpt: `https://chat.openai.com/`就可以使用了，
然而大体量的云服务商如亚马逊、甲骨文、阿里云这些都被屏蔽了。
OpenAI使用了CloudFlare的服务，我们也惨遭封禁……

{% img https://live.staticflickr.com/65535/52772012626_8a411e9450_w_d.jpg %}

上面的IP是我AWS服务器日本地区的IP, 通过`ip138.com`也可以查询到结果:

> 您的iP地址是：[18.181.68.227 ] 来自：日本东京 亚马逊云

如果你和我有一样的问题，那么就可以开始我们本篇的正文了:

## CloudFlare Warp

#### What's Warp?

根据[CloudFlare官方][4]的介绍:

> 1.1.1.1 with WARP replaces the connection between your device and
the Internet with a modern, optimized, protocol.

`1.1.1.1`是CloudFlare提供的DNS解析，经过它家的DNS，结合Warp可以给我们的流量套一层安全壳。

#### Warp vs VPN

根据[purevpn官网][3]的介绍:

Warp的作用是: DNS查询将受到Cloudflare的1.1.1.1 DNS服务的保护，
WARP会添加一层加密以确保的流量不会被窥探者获取。
但是WARP不会掩盖IP地址，这也意味着我们无法直接使用它进行翻墙。

所以Warp的作为主要是作为对隐私和安全的保护，达不到翻墙的作用。

#### Why Warp

Warp虽然无法帮助我们翻墙，但是可以帮助我们穿过它们自家的墙:D,
现在想要绕过CloudFlare的墙，要么换真国外机房、要么隐藏我们的IP。
使用Tor也可以达到一样的效果，不过这个听说比较慢，
所以我们使用简单且免费的Warp

## Installation

### 一键安装

一键安装脚本: https://gitlab.com/rwkgyg/CFwarp

```
wget -N https://gitlab.com/rwkgyg/CFwarp/raw/main/CFwarp.sh && bash CFwarp.sh
```

### 手动安装

官方安装指导: `https://pkg.cloudflareclient.com/install`

按照官方教程添加对应的源，并安装: (以ubuntu为例)

```sh
# Install
apt install cloudflare-warp

# Register device
warp-cli register

# 打开代理模式
warp-cli set-mode proxy

# 连接Warp
warp-cli connect
```

验证效果:

```sh
# Check current IP (return proxy ip)
curl ifconfig.me --proxy socks5://127.0.0.1:40000
```
上面会显示现在经过warp后的IP

```sh
# Check ChatGPT
curl chat.openai.com
curl chat.openai.com --proxy socks5://127.0.0.1:40000
```
如果配置正确的话，前者会返回1020的错误，后者则没有返回

## 配置V2Ray

如果有桌面，那么直接设置socks5的代理就可以了，对于使用V2ray (xray)的用户，可以设置一层转发:

在outbounds里添加新的`outbounds`:

```json /usr/local/etc/v2ray/config.json

"outbounds": [
    { ... }, // Original outbounds
    {
        "tag": "chatgpt_proxy",
        "protocol": "socks",
        "settings": {
            "servers": [
                {
                    "address": "127.0.0.1",
                    "port": 40000
                }
            ]
        }
    }
]
```

在routing里面添加路由规则:

```json /usr/local/etc/v2ray/config.json

"routing": {
    "rules": [
        { ... }, // Original rules
        {
            "type": "field",
            "outboundTag": "chatgpt_proxy",
            "domain": [
                "openai.com",
                "ip138.com"
            ],
            "enabled": true
        }
    ]
}
```

上面的 `ip138.com`是为了后面进行测试加入的，
路由规则把所有`openai.com`都转发到了`chatgpt_proxy`的出口上

同样也可以通过`ip138.com`来进行测试:

> 您的iP地址是：[104.28.196.81 ] 来自：澳大利亚新南威尔士悉尼 Cloudflare

至此我们大功造成，可以在Client端访问了！

{% img https://live.staticflickr.com/65535/52772537304_2c3117ec0e_c_d.jpg %}

## Note

目前Android使用V2rayNG的话还是无法访问，即使VPS已经设置了转发, 
Android上的V2rayNG还是无法走Warp从而被拦下,
目前还没有特别好的方法。

不过MacOS(使用v2ray)与Windows(使用V2rayN)均可以访问。

[1]: https://silentming.net/blog/2019/03/03/aws/
[2]: https://silentming.net/blog/2023/03/26/v2ray/
[3]: https://www.purevpn.com/blog/warp-vs-vpn/
[4]: https://1.1.1.1/
