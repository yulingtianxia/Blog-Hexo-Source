---
layout: post
title: "Publish Your Pods on CocoaPods with Trunk"
date: 2014-05-26 12:03:08 +0800
comments: true
tags: 
- CocoaPods
- GitHub

---

##简介

2014年5月20日，CocoaPods不再接受向[CocoaPods/Specs](git@github.com:CocoaPods/Specs.git)的pull request，官方的说法是为了安全考虑，防止每个人的pod被其他人修改，于是CocoaPods团队开发了trunk服务，这样每个人都是其发布的pod的owner，没有权限的人无法修改，这样更安全。  

更改后的提交架构是这样的：(来自官方图片)  

![](http://yulingtianxia.qiniudn.com/140353388207.png)  

<!--more-->

以前的podspec文件都是ruby格式，而trunk为我们带来了更轻便的json格式，你后你可以用json来配置你的pod了。不用担心过去我们发布的pod，他们依然健在，并且trunk会将podspec文件转化为podspec.json文件。    

这里给出一个官方的介绍链接（自备梯子）：http://blog.cocoapods.org/CocoaPods-Trunk/#transition  

**废话不多说，简要介绍下如何使用trunk新建我们的pod：**  

##开始注册
trunk需要CocoaPods 0.33版本以上，用`pod --version`命令查看版本，如果版本低，需要升级：

``` 
sudo gem install cocoapods
pod setup

``` 

然后会一直卡在`Setting up CocoaPods master repo`这里，这条命令用于跟新本地电脑上的保存的Pods依赖库tree。由于每天有很多人会创建或者更新Pods依赖库，这条命令执行的时候会相当慢，还请耐心等待。我们需要经常执行这条命令，否则有新的Pods依赖库的时候执行pod search命令是搜不出来的。再开启一个终端，通过`cd  ~/.cocoapods`命令进入cocoapods根目录，然后通过`du -sh *`命令查看总的文件大小，如果隔一阵子会增加，那么说明一切正常，下载速度取决于你的网络。  

更新完成后，下一步是注册trunk，这一步需要自备梯子，否则就会出现这种[问题](https://github.com/CocoaPods/CocoaPods/issues/2174)

``` 
pod trunk register yulingtianxia@gmail.com 'Yang Xiaoyu' --description='macbook pro' --verbose
``` 
上面的命令是我注册时使用的，你需要把邮箱和名字以及描述替换成你的，加上`--verbose`可以输出详细debug信息，方便出错时查看。  

注册后CocoaPods会给你的邮箱发送验证链接，点击后就注册成功了，可以用`pod trunk me`命令查看自己的注册信息：  

``` 
bogon:YXYNumberAnimationLabel yangxiaoyu$ pod trunk me
  - Name:     Yang Xiaoyu
  - Email:    yulingtianxia@gmail.com
  - Since:    May 25th, 20:27
  - Sessions: 
    - May 25th, 20:27 - September 30th, 22:41. IP: 23.228.209.171
  Description: macbook pro
``` 
上面是我的注册信息，CocoaPods不通过密码来验证用户，而是通过一个session token。  

##部署你的Pod
首先你需要建立一个podspec文件，这是我的podspec文件：  

``` 
Pod::Spec.new do |s|
  s.name         = "YXYNumberAnimationLabel"
  s.version      = "1.0.1"
  s.summary      = "一个可以动起来的数字Label"
  s.description  = <<-DESC
                    通过设置数字变化的插值来展现动画效果
                   DESC
  s.homepage     = "https://github.com/yulingtianxia/YXYNumberAnimationLabel"
  
  s.license      = 'MIT'
  s.author       = { "YangXiaoyu" => "yulingtianxia@gmail.com" }
  s.social_media_url = "http://twitter.com/yulingtianxia"
  s.source       = { :git => "https://github.com/yulingtianxia/YXYNumberAnimationLabel.git", :tag => s.version.to_s }

  s.platform     = :ios, '6.0'
  s.requires_arc = true

  s.source_files = 'YXYNumberAnimationLabel/*'
  s.frameworks = 'Foundation', 'UIKit'
  #s.private_header_files = 'Classes/ios/private/*.h'
  
  #s.dependency 'FLKAutoLayout', '~> 0.1'
end
``` 
**具体配置什么的大家走很熟悉，这里只是讲述使用trunk后需要注意的地方和新的操作**  

在验证和上传你的podspec文件到trunk之前，需要将你的源码push到Github上，tag一个版本号并发布一个release版本，这样podspec文件中的`s.source`的值才能是准确的：  

``` 
git add -A && git commit -m "Release 1.0.1."  
git tag '1.0.1'  
git push --tags  
git push origin master
``` 

这两条命令是为pod添加版本号并打上tag:  

``` 
set the new version to 1.0.1
set the new tag to 1.0.1
``` 



在你podspec文件下的路径运行`pod trunk push YXYNumberAnimationLabel.podspec` 命令，同样需要翻墙梯子自备，别忘了将`YXYNumberAnimationLabel.podspec`替换成你的podspec文件名。  

pod trunk push命令做了如下三个工作：  

1. 验证你本地的podspec文件（你也可以用`pod lib lint`命令来验证）
2. 上传你的podspec文件到trunk
3. 将你的podspec文件转化成trunk需要的JSON文件

如果部署成功，CocosPods会在Twitter上@你  

就像文章最开始的架构图描述的那样，你在trunk中的操作依然会在[CocoaPods/Specs](git@github.com:CocoaPods/Specs.git)仓库中更新。以后再做更改时只需要更新版本号然后通过trunk来提交，不用向[CocoaPods/Specs](git@github.com:CocoaPods/Specs.git)pull request并等待审核和merge了。  

运行`pod setup`来更新你的Pods依赖库tree后，再使用`pod search YXYNumberAnimationLabel`命令来查找刚刚加入的名字叫`YXYNumberAnimationLabel`的依赖库：  

``` 
-> YXYNumberAnimationLabel (1.0.1)
   一个可以动起来的数字Label
   pod 'YXYNumberAnimationLabel', '~> 1.0.1'
   - Homepage: https://github.com/yulingtianxia/YXYNumberAnimationLabel
   - Source:   https://github.com/yulingtianxia/YXYNumberAnimationLabel.git
   - Versions: 1.0.1, 1.0.0 [master repo]
``` 

##将其他人加入到你的Pod

为了让其他人也有权限来和你一起建设你的代码，你需要运行下面的命令来赋予别人权限，假如我将`kyle@cocoapods.org`加入到我的名字叫`ARAnalytics`的库中，我需要运行下面的命令：  

``` 
pod trunk add-owner ARAnalytics kyle@cocoapods.org
``` 


