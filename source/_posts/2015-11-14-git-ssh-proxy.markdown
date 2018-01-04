---
layout: post
title: "使用SSH通过代理连接Git"
date: 2015-11-14 15:22:10 +0800
comments: true
tags: tutorial 
keywords: Git, SSH, Proxy
description: "Use ssh with proxy to access git"
---
假设现在有3台计算机：
A (IP_A), B1(IP_B1), B2(IP_B2)， B1与B2是在同一内网下，B1是该内网的网关，对外拥有独立IP。
最终目标是在A1使用ssh以网关B1为跳板连接到B2上进行工作。
<!-- more -->

#B2 ssh B1
在工作或者实验室经常会有这种场景，需要ssh到服务器上进行一些操作。

    ssh UserOnB1@IP_B1 //即可
拷贝的话使用：

    scp ~/xxx UserOnB1@IP_B1:~/xxx   //第一个~是B2上的用户主目录，第二个~是UserOnB1在B1上的主目录

###密钥
ssh可以使用密钥认证，省去输入密码的麻烦

    ssh-keygen -C "xxx" -t rsa
> -C : Comment 是为了标记这个密钥对是属于哪个用户的，邮箱即可<br>
> -t 加密方式为rsa

生成完后，在~/.ssh下会有新建的id_rsa.pub 与id_rsa
将id_rsa.pub的内容追加到 IP_B1: ~/.ssh/authorized_keys中即可：

    scp .ssh/id_rsa.pub UserOnB1@IP_B1: ~/.ssh/    #将公钥拷贝到B1上
    ssh UserOnB1@IP_B1    #登录B1
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys    #将公钥内容加入authorized_keys
    rm -f ~/.ssh/id_rsa.pub    #删除公钥文件

这样之后在B2上使用用户 UserOnB1来连接B1时就不用输入密码了。

###多密钥配置
如果连接不同的host需要使用不同的密钥时，就不能只用默认的id_rsa了<br>
在.ssh下建立config文件，并进行配置：<br>
假设登陆B1使用的密钥文件名为 B1_rsa：↓

    host B1                // B1在本地的名称
        user UserOnB1      // 登陆B1使用的用户
        hostname IP_B1     // B1的主机名或者IP
        port 22            // 使用的端口
        identityfile ~/.ssh/B1_rsa //使用的密钥
这样就可以使用B1_rsa来登录B1了
    
    ssh B1 #因为我们加了user选项，所以直接 ssh host就行了
比较常用的就是本地登陆Github时使用专门的密钥：↓

    host github.com           // 本地的名称
        user git              // 用来登陆的用户名
        hostname github.com   // 用来登陆的机子IP或名称
        port 22               // 使用的端口号
        identityfile ~/.ssh/github_rsa    // 指定使用的密钥文件
使用↓来连接git

    ssh github.com
类似的，如果不加user选项，那么在连接的时候需要使用↓

    ssh git@github.com
###B1作为跳板，从A登陆IP_B2
经常会有在家里需要登陆公司、实验室的机子，外网连不到内网的B2上，此时可以将B1作为跳板来连接到B2上 ↓ (操作是在A上)

    ssh UserOnB1@IP_B1 #连到B1上
	# 连接到B1后，在B1的shell中：
    ssh UserOnB2@IP_B2 #从B1连到B2上
或者，直接使用代理命令：
    
    ssh UserOnB2@IP_B2 -p22 -o "ProxyCommand ssh UserOnB1@IP_B1 exec nc %h %p 2>/dev/null" username2@IP2
    # nc (natcat) %p : port, %h : hostname
相应的，可以在A的.ssh/config进行如下配置↓
        
    host B1
        port 22
        hostname IP_B1
        identityfile ~/.ssh/B1_rsa
        #Host B2↓
    host B2
        port 22
        hostname IP_B2
        ProxyCommand ssh UserOnB1@B1 exec nc %h %p 2>/dev/null
    #上面这条Command会使用 前面B1配置的内容，使用B1_rsa进行连接。
完成后在A上登陆B2↓

    ssh UserOnB2@B2
ssh会在config中找到B2 host，并采用proxycommand连接B1，而command中的命令，又会使用host B1并使用B1_rsa来连接。

同样，如果不想输入密码的话，那么在A的.ssh/config中，在host B2下也加入identityfile：↓

    host B1
        port 22
        hostname IP_B1
        identityfile ~/.ssh/B1_rsa
        #Host B2↓
    host B2
        port 22
        hostname IP_B2
		identityfile ~/.ssh/B2_rsa
		ProxyCommand ssh UserOnB1@B1 exec nc %h %p 2>/dev/null
在B2的authorized_keys里加入B2_rsa.pub<br>
最后就可以在A1上，输入↓

	ssh UserOnB2@B2

便可以直接通过B1连接到B2了

---
#GitHub与GitCafe
GitHub:<br>
在个人Profile->左侧导航栏SSH Keys->Add SSH Key 复制git_rsa.pub里的内容进去即可

GitCafe<br>
Profile->Setting->SSH Keys->Add a new public key中操作相同

在本地配置config：
```cfg .ssh/config
host github.com
	hostname github.com
	port 22
	identityfile ~/.ssh/github_rsa
	
host gitcafe.com
	hostname gitcafe.com
	port 22
	identityfile ~/.ssh/gitcafe_rsa	
```
之后运行↓来改为使用ssh方式登录

    git remote set-url origin user@host:UsernameOnGit/xxx.git
    # 如果config中有user, 则这里user@可以省略。
可以使用↓来验证一下：

	ssh -T git@github.com
	ssh -T git@gitcafe.com
	
{%img https://farm6.staticflickr.com/5706/30090789993_177a5ffbf8_o_d.png %}

之后再进行pull、push等操作时就可以使用ssh的方式了。
