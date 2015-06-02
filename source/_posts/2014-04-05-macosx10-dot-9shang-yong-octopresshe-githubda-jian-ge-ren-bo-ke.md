---
published: true
layout: post
title: "MacOSX10.9上用Octopress和GitHub搭建个人博客"
date: 2014-04-05 14:28:54 +0800
comments: true
tags: 
- MacOSX
- Octopress
- GitHub

---
网上已经有很多关于搭建Octopress的文章了，但我写这篇文章的目的是帮助Mac新手们搭建自己的Octopress，尤其是最新的Mavericks系统

这篇博文包括：

- Octopress搭建
- Github Page 部署
- Blog的美化工作

<!-- more -->
---
Octopress搭建
==
众所周知，MacOSX自带Ruby，10.9系统带了两个版本的Ruby：1.8和2.0，因为Octopress需要Ruby1.9.3以上的支持，所以Mavericks自带的Ruby2.0是可以胜任的，新手们可以松一口气了。  
如果没有安装command line tools，可以直接安装Xcode。Xcode5之后，command line tools都是跟随Xcode自带的，不用单独安装，想卸载也就麻烦了，可以在Xcode中Preferences->Locations中查看command line tools版本。  

系统没升级到最新版的童鞋，可以打开终端（terminal）通过下面的命令查看自己的Ruby版本：

    ruby --version
没安装RVM的童鞋运行下面的命令：

    curl -L https://get.rvm.io | bash -s stable --ruby

下面我们需要从Github上clone下Octopress
    
    git clone git://github.com/imathis/octopress.git octopress
    
这条命令将octopress的源码下载到了你个人文件夹下的octopress文件夹，如果对git命令不太熟，可以在[这里](https://mac.github.com)下载Github的Mac客户端，关于Github的使用，网上有很多教程。  
下一步，安装依赖

    cd octopress ＃进入octopress目录
    gem install bundler
这里碰到的问题可能有两种：  
1. 权限不够，无法访问到一些文件夹  
2. 等了很久没有反应  
如果你之前对Linux比较熟，第一个问题可以很简单的解决，这是因为一些文件夹需要root权限访问，运行
    
    sudo gem install bundler
提示输入密码的时候，输入你自己的MacOSX开机密码后回车，注意输入密码的过程中终端无任何显示，这跟Linux一样  
如果半天都没有反应，这是因为rubygems.org 的文件资源被墙了，可以在[这里](http://ruby.taobao.org)查看解决方法，或者干脆翻墙，推荐[云梯VPN](http://tizipro.com/?r=ee0508bc191f5651)科学上网，我个人比较推荐翻墙。  

PS：云梯VPN优惠链接：[http://tizipro.com/?r=ee0508bc191f5651](http://tizipro.com/?r=ee0508bc191f5651)

接下来运行：    
    
    bundle install
不出意外，肯定会出错，最后一句应该是“Make sure that `gem install RedCloth -v '4.2.9'` succeeds before bundling.”再往前追寻问题的根源，会发现这么一句“clang: error: unknown argument: '-multiply_definedsuppress' [-Wunused-command-line-argument-hard-err”。  
这是因为Xcode 5.1的LLVM编译器将未识别的命令行选项认为是error，导致诸如Python本地拓展和Ruby Gem报错，解决方案：在执行命令行前加ARCHFLAGS=-Wno-error=unused-command-line-argument-hard-error-in-future，这样就忽略了报错。感谢[Andrew Hay的文章](http://www.andrewhay.ca/archives/2558?utm_source=tuicool)帮我解决了问题。  
所以应该这样：

    ARCHFLAGS=-Wno-error=unused-command-line-argument-hard-error-in-future bundle install
问题解决  
最后安装默认的主题

    rake install    
如果出现“You have already activated rake 10.3.1, but your Gemfile requires rake 0.9.6. Prepending `bundle exec` to your command may solve this.”这样的提示，有三种解决方法：  
1. 运行`bundle update`
2. 按照提示在前面加上`bundle exec`，即运行`bundle exec rake install`
3. 卸载不一样的版本 gem uninstall rake -v=10.3.1 
这三种方法建议先用方法1，如果不行再用方法3，方法2是无奈之举  

**关于创建博文**
    
    rake new_post["first post"]＃双引号中为博文标题，可以自己定义，生成markdown文件
    rake generate ＃生成HTML文件

这里推荐一个markdown编辑器[Mou](http://mouapp.com)，markdown是用来编写我们博客的语言，文件后缀名为md或markdown，学过Latex的童鞋可能会了解得更快一些，用markdown编写HTML版面是再好不过得了，markdown速成[传送门](http://www.ituring.com.cn/article/23)。网上教程也挺多的，语法风格跟Latex有点像。  
Github Page 部署
==
首先要有一个Github账号，假设用户名为username，那么新建一个仓库，名字叫“username.github.io”，Github会自动识别它为你的个人页面。你可以通过username.github.io这个网址来访问你部署的静态网页。创建完成后，获取你这个仓库的Git Url，SSH或者Http协议的都可以，然后执行`rake setup_github_pages`，当提示你的时候输入你前面创建的仓库的Git Url。比如`git@github.com:username/username.github.com.git`  
你会发现octopress文件夹中多了\_deploy目录，并将这个目录当作master分支，而其余的文件都作为新建立的source分支。octopress原理是在source分支保存框架所需要的文件，还有博客的markdown文件，然后每次将生成的html文件放入master分支，通过username.github.io访问到的是已经生成好的master分支的文件，也就是_deploy文件夹的内容。  
运行下面代码来生成部署网页到Github：
    
    rake generate
    rake deploy
现在访问你的网站，已经有了一个页面，使用的是系统默认主题。为了避免博客的源码受到破坏，需要把source分支也commit上去。不会用git命令的同学可以用Github的Mac客户端。
    
    git add .
    git commit -m 'your message'
    git push origin source
    
如果你有自己的域名，可以通过在仓库中新建CNAME文件进行配置映射，这里不再细说。


Blog的美化工作
==
可以用[greyshade](https://github.com/shashankmehta/greyshade)或者[slash](https://github.com/tommy351/Octopress-Theme-Slash)主题美化博客，根据个人喜好了。需要注意的是，greyshade这个主题有些不足之处，比如，disqus实效，还有如何添加新浪微博链接，请看[这里](http://bryanone.com/blog/2014/03/01/problem-with-greyshade/)和[这里](http://imallen.com/blog/2013/05/12/add-support-for-weibo-and-dribbble-to-greyshade.html)。如果首页左侧没有显示title和subtitle等信息，可以修改/source/_includes/header.html文件，添加

    <h1><a href="{{ root_url }}/">{{ site.title }}</a></h1>
    <p class="subtitle">{{ site.subtitle }}</p>
修改\_config.yml文件，可以配置博客的参数，网上有很多详细的教程来说明每个属性是干什么的，需要注意的一点就是冒号后面一定要加空格，否则编译不通过。建议下载一个Sublime Text来打开这些前台文件，增加效率。博客头像和Github一样采用[gravatar](www.gravatar.com)的头像托管服务，在_config.yml文件中的email属性中填入你在gravatar的邮件或者在email_md5属性中填入md5码也可。  
**关于添加标签云效果**  
1. 将[category_cloud.rb](https://github.com/yulingtianxia/yulingtianxia.github.io/blob/source/plugins/category_cloud.rb)复制到你的`/octopress/plugins/`文件夹下  
2. 拷贝[category_cloud.html](https://github.com/yulingtianxia/yulingtianxia.github.io/blob/source/source/_includes/custom/asides/category_cloud.html)到你的`octopress/source/_includes/custom/asides/`目录  
3. 在你的 `octopress/_config.yml` 文件中的`default_asides`项中加入第二步添加的路径：`custom/asides/category_cloud.html`  
4. 拷贝[tagcloud.swf](https://github.com/yulingtianxia/yulingtianxia.github.io/blob/source/source/javascripts/tagcloud.swf)到`source/javascripts/`文件夹  
如果想修改标签云的颜色可以在`category_cloud.rb`文件中改变：  
```
		@opts['bgcolor'] = '#3D4349'
      @opts['tcolor1'] = '#8B85C3'
      @opts['tcolor2'] = '#C03999'
      @opts['hicolor'] = '#ffffff'
```
`tcolor1`为文章数量比较多的分类颜色  
`tcolor2`为普通分类颜色  
`hicolor`为鼠标高亮颜色  
诸如添加Google Analyse和百度统计，添加分享和评论系统，还有版权信息，网上的教程也很多，参考[oec2003](http://www.cnblogs.com/oec2003/archive/2013/05/31/3109577.html)和[破船](http://beyondvincent.com/blog/2013/07/27/107-hello-page-of-github/)的文章，本文主要是介绍MacOSX上面的部署工作。





    
  
