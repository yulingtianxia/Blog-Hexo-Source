---
layout: post
title: "Setup Your Own VPN With PPTP"
date: 2014-07-11 13:22:16 +0800
comments: true
tags: 
- VPN

---

博主买的DigitalOcean的VPS服务，在配置好SSH远程访问后，准备继续配置pptp来搭建VPN科学上网。DO官网有详细的[配置教程](https://www.digitalocean.com/community/tutorials/how-to-setup-your-own-vpn-with-pptp)  

PS:这里附上我的优惠链接，你用这个链接注册可以获得10美元：[https://www.digitalocean.com/?refcode=2c163841a4f4](https://www.digitalocean.com/?refcode=2c163841a4f4)  

但是一步一步配置效率较低，多亏了脚本[http://yansu.org](http://yansu.org/2013/12/11/deploy-pptp-vpn-in-ubuntu.html)  
<!--more-->

脚本虽然方便，但是需要改动几个地方，比如你可以设定你喜欢的`remoteip`范围，这样就可以调整你的VPN分配的IP范围；还可以添加可以使用VPN的自定义账户密码，下面是我修改过的脚本，里面添加了两个账户：yulingtianxia和802，每行四个参数分别是账户名、服务类型、密码和验证IP：  

<script src="https://gist.github.com/yulingtianxia/296b1b3b2edf5d762ae7.js"></script>

在VPS上使用自动脚本只需要下面的操作：
```
wget -c https://gist.githubusercontent.com/yulingtianxia/296b1b3b2edf5d762ae7/raw/e2ef1b18e85b393d22c82d26d72b20af14567e9c/pptp.sh
chmod +x pptp.sh
./pptp.sh
```

上面的命令先是用ssh的wget命令下载gist上的原始Shell脚本文件到VPS上，速度之快和安全性是ftp上传所不能比拟的。然后赋予pptp.sh可执行权限，最后执行pptp.sh  
