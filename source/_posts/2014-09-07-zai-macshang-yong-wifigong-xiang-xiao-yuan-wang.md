---
layout: post
title: "在Mac上用WiFi共享校园网"
date: 2014-09-07 18:00:14 +0800
comments: true
tags: 
- macOS

---

开学了，好多稚嫩的学弟学妹踏入了憧憬许久的校园，住上了宽敞明亮的寝室（某工除外），用上了速度超快的校园网。然而这里却有一个严峻的问题摆在了Mac用户面前：蛋疼的锐捷！这篇文章将会详细的教学弟学妹们如何科学地通过WiFi共享校园网。  

<!--more-->

记得在我刚上大学那年，锐捷的Mac客户端简直是不忍直视，非程序员无法hold住，即使现在Mac版本的锐捷客户端也是经常连接不上，界面不够友好，检测网卡速度慢等一系列反人类问题。网上也有一些第三方的校园网客户端，我认为最好的就是[CocoaMento](https://code.google.com/p/mentohust/downloads/detail?name=CocoaMento.dmg&)。下载后最好在程序图标处右击，选择显示包内容，用Windows版锐捷客户端的内容替换`/Contents/Resources/data/`目录下的对应文件:  

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20140907-1%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

你可以将你们学校提供的定制版锐捷客户端32位安装包（标注x86的exe文件）解压（exe文件和dmg等一样，都是类似于rar之类的压缩文件），然后在解压后的文件中找到需要替换的那三个文件：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20140907-2%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

PS：因为CocoaMento是用Qt写的，且为32位，千万不要把64位安装包中对应的文件替换到上述目录中，否则会认证失败无法上网。  

其实不用替换这三个文件也能上网，但是替换下更好，因为随着锐捷版本的更新，认证机制也会变化。这三个文件可以让我们的Mac伪装成Windows，骗过锐捷认证。  

打开CocoaMento，它并不在Dock上占有一席之地，而是跑到了顶端的菜单栏，图标是一个蓝色的地球，如果认证失败它会变成红色。点击这个地球，在偏好设置中的账号设置中填写好你的账户密码，最后点击开始验证：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20140907-3%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

在上图中，使用网卡那项的选择需要查看以太网卡的BSD名称(左上角->关于本机->更多信息->系统报告->硬件->以太网卡)，直到认证成功后勾选再上自动登录。  

在Mac上将以太网通过WiFi共享给其他设备很简单，只需要打开 **系统偏好设置->共享**，点击“互联网共享”，在“共享以下来源的连接”那栏选择“XXX以太网”（有可能是Thunderbolt以太网或USB以太网），在“用以下端口共享给电脑” 复选框中勾选“WiFi”，并点击“WiFi选项”，设置好WiFi名称和密码，最后别忘勾选上左侧的“互联网共享”。此时如果WiFi没有打开，会提示先打开WiFi，然后会提示是否开启共享，选择开启即可：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20140907-4%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

然而锐捷最蛋疼之处还是其通过802.1x协议限制了我们共享无线网络：一旦WiFi开启，官方的锐捷客户端就会警告存在其他网卡balabala然后给你断网。。。我在MacOSX 10.9中即使用CocoaMento依然无法将校园网通过WiFi共享（有的时候重启下还是可以的，但那只是因为bug导致的巧合）  

如果我们开启了VPN，则可以在共享WiFi的时候在“共享以下来源的连接”那栏选择你的VPN连接，这样不仅可以越过锐捷的网卡限制，还能让共享的WiFi通过VPN连接到互联网，探索神秘的西方极乐世界。  

然而一直使用VPN共享WiFi会在速度上大打折扣，而且也不经济划算，为了逃过802.1x协议的限制，我发现在 **系统偏好设置->网络->高级->802.1x** 选项卡中如果将“启用自动连接”取消勾选，就可以逃过802.1x验证：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20140907-5%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)   

经过亲测屡试不爽啊，成功的看到了那个扇形箭头标志：![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20140907-6%402x.png)，这证明了WiFi共享成功。  

为了能快速的连接上校园网并用WiFi分享，请始终勾选“互联网共享”，因为即使WiFi分享不成功，也不会耽误我们使用WiFi来连接到其他网络。然后在 **系统偏好设置->用户与群组->(你的账户)->登陆项** 选项卡下将CocoaMento添加进去，这样开机的时候就会自动启动CocoaMento连接上校园网，并将其通过WiFi分享，一气呵成 : )      

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20140907-7%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  







