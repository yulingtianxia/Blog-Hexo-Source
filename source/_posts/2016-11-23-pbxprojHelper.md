---
title: pbxprojHelper--Xcode工程文件助手
date: 2016-11-23 00:03:08
tags:
- macOS
- Xcode
- Swift

---

[pbxprojHelper](https://github.com/yulingtianxia/pbxprojHelper) 可以帮你快速配置 Xcode 工程文件，省去麻烦的人工手动操作。项目开源，使用 Swift 开发，详细介绍请见[使用说明](https://github.com/yulingtianxia/pbxprojHelper/blob/master/Documentation/README_ZH.md)。除了 Mac App 外还提供了命令行工具 [`pbxproj`](https://github.com/yulingtianxia/pbxprojHelper/releases/download/1.1.3/pbxproj)，它集成了 [pbxprojHelper](https://github.com/yulingtianxia/pbxprojHelper) 的核心功能，同样简易实用。

<!--more-->

因为[README_ZH](https://github.com/yulingtianxia/pbxprojHelper/blob/master/Documentation/README_ZH.md)中对使用方法已经讲得很详细了，这里重点说的是产品方案和技术实现。

## 产品方案

### 为什么造这个工具？

在开发公司的项目时，check out 代码到本地后需要修改工程文件。比如更改证书和 Bundle Identifier、删除一些编译不过的 Target，修改 Build Settings 等配置。重复手动修改这些配置的场景很多：

1. 第一次 check out 新的分支，需要使用自己的配置。
2. 增删代码文件前会先 revert project.pbxproj 文件，修改完成后再 commit。此时本地工程文件需要重新配置。
3. 没有增删代码文件但 project.pbxproj 文件有冲突（conflict），需要先 revert 后重新配置工程文件。
4. 一些自动化流程（比如 CI）每次执行都需要特定的编译选项和证书来编包。

而我本人最常遇到的场景是 1 和 2，因为不能用公司的证书配置来编译，一些跟苹果开发者账号相关的功能导致一些 target 编译不过，还有些 debug 模式下需要设置的编译选项。所以每次都需要手动修改 Xcode 工程配置，很是麻烦。

### 需求！

可以说开发这个工具一开始完全就是为了解决我个人的痛点的，基本没考虑做成功能强大的通用工具。虽然做的事情比较小众，但也能满足一批苹果开发者的需求了。我把需求分为以下几点：

1. 将程序员对工程文件做出的配置修改记录下来，并保存成 JSON 文件
2. 下次使用时直接导入 JSON 文件，将配置修改应用到当前的工程文件上
3. 支持回滚操作
4. 支持工程文件内容的预览、过滤
5. 快速切换最近使用的工程
6. 提供命令行工具

可以说 1 和 2 是刚需，也是常用功能。3、4 和 5 是辅助功能，6 是附加需求。我平时最常碰到的需求点就是 2 和 5 了。

## 技术实现

### 对比工程文件

### 应用 JSON 配置

### 回滚操作

### 预览工程文件

### 快速切换

### 命令行工具