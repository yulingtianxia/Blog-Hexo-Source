---
title: DirtyWords for Xcode - 做个文明的程序员
date: 2018-12-23 15:36:27
tags:
---

开发者经常会在代码中看到各类脏话，有吐槽产品的瞎改早晚还会改回来的，有吐槽这块代码写的太烂无法直视的，或是干脆心情不好就一顿骂。公司内部的项目想必是无数天坑 f*ck 无数，连对外开源的项目也难逃一劫，比如前一段时间 [OpenJDK](https://bugs.openjdk.java.net/browse/JDK-8215217) 就因为脏话太多火了一把。

于是我做了一个 Xcode 插件来寻找代码中的脏话，将其高亮可以被选中，作为一个强提示让开发者修改。目前逻辑还只是简单替换而已，代码在这里：[DirtyWords-for-Xcode](https://github.com/yulingtianxia/DirtyWords-for-Xcode)

为了体现汉字的博大精深，瞎画了个 icon，见笑了：

![](https://github.com/yulingtianxia/DirtyWords-for-Xcode/blob/master/images/艹.png?raw=true)

<!--more-->

## 安装

### AppStore

圣诞节苹果暂停审核。。。日

### GitHub Release

直接从 GitHub Release 页面下载最新的安装包：
https://github.com/yulingtianxia/DirtyWords-for-Xcode/releases

## 使用方式

用法很简单，反正目前也就这么一个功能。Editer -> Dirty Words -> Highlight

![](https://github.com/yulingtianxia/DirtyWords-for-Xcode/blob/master/images/usage.png?raw=true)

例如下图中的 "fuck" 就会被高亮，可以文明用语代之。

![](https://github.com/yulingtianxia/DirtyWords-for-Xcode/blob/master/images/highlight.png?raw=true)

如果在 Editor 菜单中找不到的话，打开系统偏好设置 -> 拓展，并勾选 “DirtyWords for Xcode” 拓展项.

![](https://github.com/yulingtianxia/DirtyWords-for-Xcode/blob/master/images/appui.png?raw=true)

可以给 DirtyWords 自定义快捷键。 Xcode > Preferences > Key Bindings > 搜索 “Dirty Words”.

![](https://github.com/yulingtianxia/DirtyWords-for-Xcode/blob/master/images/keybindings.png?raw=true)

## 脏词黑名单

脏词列表文件跟随 app 打包进去了。在拓展加载完成后，也会通过网络下载 [dirtywords](https://github.com/yulingtianxia/DirtyWords-for-Xcode/blob/master/SourceEditorExtension/dirtywords) 文件进行更新。这样方便以后调整脏词列表，也欢迎大家提 PR 补充。

在收集脏词的过程中真是长了见识了，不搜不知道一搜吓一跳，哈哈。有[各国语言版的](https://github.com/LDNOOBW/List-of-Dirty-Naughty-Obscene-and-Otherwise-Bad-Words)，还有据说是 [Google 版的](https://github.com/RobertJGabriel/Google-profanity-words)。

因为分词会比较耗性能，代码中有些 API 其实是触碰脏词的，比如 "UIButton" 中包含了 "butt"，所以有些脏词需要从黑名单剔除，避免误判。不过我觉得 "fuck" 这种词无论怎么组合都难洗白的。


