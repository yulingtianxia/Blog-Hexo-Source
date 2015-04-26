---
layout: post
title: "让软件支持Retina"
date: 2014-06-19 16:07:28 +0800
comments: true
tags: 

---
1. 右键单击程序，选择“显示包内容”  
2. 找到“info.plist”文件并打开  
3. 如果用Xcode打开：添加一个新的键值对，类型为Boolean，Key为“NSHighResolutionCapable”，Value选择“YES”；如果用其他软件打开，直接在plist节点中的dict中添加一个键值对就可以：<key>NSHighResolutionCapable</key>  
<true/> 
4. 为了使系统更新，复制一份“软件.app”，改成别的名字如“软件1.app”，删除原来的“软件.app”，再把“软件1.app”重命名为“软件.app”