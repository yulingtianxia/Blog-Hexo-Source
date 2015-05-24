---
layout: post
title: "GitHub Page build warning"
date: 2014-05-02 13:57:53 +0800
comments: true
tags: 
- GitHub

---
几天前博主的GitHub Page闹了些小情绪：  
<!--more-->  
>The page build completed successfully, but returned the following warning:

>GitHub Pages recently underwent some improvements (https://github.com/blog/1715-faster-more-awesome-github-pages) to make your site faster and more awesome, but we've noticed that `yulingtianxia.com` isn't properly configured to take advantage of these new features. While your site will continue to work just fine, updating your domain's configuration offers some additional speed and performance benefits. Instructions on updating your site's IP address can be found at https://help.github.com/articles/setting-up-a-custom-domain-with-github-pages#step-2-configure-dns-records, and of course, you can always get in touch with a human at support@github.com. For the more technical minded folks who want to skip the help docs: your site's DNS records are pointed to a deprecated IP address.   

>For information on troubleshooting Jekyll see:  

>https://help.github.com/articles/using-jekyll-with-pages#troubleshooting  

>If you have any questions please contact us at https://github.com/contact.  

也就是说只是warning而已，程序员根本不理睬的，加载速度慢点就慢点儿呗，可是。。。每次pushGitHub都发一次邮件啊，博主强迫症犯了，决心搞定它。  
GitHub很贴心的给出了整改意见啊，也就是第一个URL：https://github.com/blog/1715-faster-more-awesome-github-pages  
简单的说，就是因为我的自定义一级域名需要指向一个可以让GitHub Page加载更快的IP，或者是让我的子域名指向`username.github.io`(username为GitHub用户名，我的是yulingtianxia)，如果你没有自己的域名，那么根本不会出现warning邮件，因为`username.github.io`本身已经做了加速优化。  
我在terminal中运行了dig命令：  
`dig yulingtianxia.github.io +nostats +nocomments +nocmd`  
结果如下：  
```
; <<>> DiG 9.8.3-P1 <<>> yulingtianxia.github.io +nostats +nocomments +nocmd
;; global options: +cmd
;yulingtianxia.github.io.	IN	A
yulingtianxia.github.io. 2684	IN	CNAME	github.map.fastly.net.
github.map.fastly.net.	7	IN	A	103.245.222.133
fastly.net.		12821	IN	NS	ns3.p04.dynect.net.
fastly.net.		12821	IN	NS	ns1.p04.dynect.net.
fastly.net.		12821	IN	NS	ns2.p04.dynect.net.
fastly.net.		12821	IN	NS	ns4.p04.dynect.net.
ns1.p04.dynect.net.	21893	IN	A	208.78.70.4
ns2.p04.dynect.net.	20599	IN	A	204.13.250.4
ns3.p04.dynect.net.	21929	IN	A	208.78.71.4
ns4.p04.dynect.net.	26356	IN	A	204.13.251.4
```
于是我在我的域名管理后台将我的一级域名`yulingtianxia.com`指向`103.245.222.133`，问题解决。