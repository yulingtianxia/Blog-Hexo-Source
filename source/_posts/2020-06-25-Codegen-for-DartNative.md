---
title: 告别 Flutter Channel，调用 Native API 仅需一行代码！
date: 2020-06-25 16:48:18
tags:
- Dart
- Flutter
- NodeJS
- DartNative
---

在 [DartNative](https://github.com/dart-native/dart_native) 自研超级通道的性能已经数倍优于 Flutter Channel 之后，我将目光转向了开发成本的优化。于是 [Codegen](https://github.com/dart-native/codegen) 应运而生，开发者可以用它很方便地将 Native API 转为 Dart 封装，直接拿来用就可以了！从而优化 Flutter 调用 Native API 的开发体验，实现『**运行性能和开发效率的双提升**』：

- [x] 无需编写 Flutter Channel 的胶水代码
- [x] 无需跨 IDE 联调 Channel 两边的代码
- [x] Native API 也被赋予了热重载功能
- [x] 支持同步调用，打日志顺序不再错乱

<!--more-->

如果你还一脸懵逼，来看一段[实操视频](https://www.bilibili.com/video/BV1Bt4y197Jg)吧（第一次做 UP 主，跪求一键三连）：

<iframe src="//player.bilibili.com/player.html?aid=626168423&bvid=BV1Bt4y197Jg&cid=205348003&page=1" scrolling="no" border="0" frameborder="no" framespacing="0" allowfullscreen="true"> </iframe>

视频中为了演示方便，对 [Codegen](https://github.com/dart-native/codegen) 代码有些特殊处理：去掉了自动生成 `import` 的代码。

## DartNative 整体解决方案&展望

1. **DartNative Bridge**: 自研超级通道，性能甩开官方 Flutter Channel 好几倍，支持 Native 绝大部分类型
2. **DartNative Codegen**: 将 Native API 转为 Dart API，可在 Flutter 工程中直接调用
3. **DartNative Dispatch**: 各平台 API 终究是有差异的，且只能靠开发者手动抹平。通过分发机制为开发者提供一个抹平平台差异代码的地方。
4. **DartNative Component Market**：基于 DartNative 的开源组件市场，未来会有越来越多的 Native 组件通过 DartNative 转为 Flutter 组件。

![](http://yulingtianxia.com/resources/DartObjC/DartNative%20Future.png)

从 2019 年的九月份开始做 [DartNative](https://github.com/dart-native/dart_native) 的第一个版本（那时候还叫 DartObjC），到如今初具规模并在线上小范围使用，可谓是有些漫长。漫长的原因有亮点：

1. 为了追求性能与效率双提升，技术方案上走了 Hard 模式。抛弃 Channel 是一条没人走过的路，虽说 [DartNative](https://github.com/dart-native/dart_native) 开源后陆陆续续出现了一些相同 idea 的项目，但都没有走我这条最艰难的路。不仅技术有难度，设计方案也要反复推翻，打磨，优化。。。做新的解决方案就是很漫长，我最然做的很早，但是战线拉得太长。
2. 这是一个利用打游戏剩下的业余时间搞出来的 side project，全凭自身兴趣和满腔热血。有时候也羡慕那些有 KPI 的开源项目，起码有排期的保证，能够快速推进项目进度。

个人的力量终究是有限的，尤其是 Android 我一窍不通。还好后来也有更多感兴趣的小伙伴加入这个项目，补齐 Android 侧的超级通道能力，继续推进 [Codegen](https://github.com/dart-native/codegen) 的完成度。

## Codegen 的用法

[Codegen](https://github.com/dart-native/codegen) 是一个 CLI 工具，可以很方便地使用 npm 来安装：

```
$ npm install -g @dartnative/codegen
```

跟其他标准的 CLI 工具一样，通过 `-h` 选项可以查看用法：

```
Usage: codegen [options] <input>

Generate dart code from native API.

Options:
  -V, --version              output the version number
  -l, --language <language>  [objc, java, auto(default)]
  -o, --output <output>      Output directory
  -p, --package <package>    Generate a shareable Flutter project containing modular Dart code.
  -h, --help                 display help for command
```

[Codegen](https://github.com/dart-native/codegen) 默认会自动监测输入源代码的语言，目前还只支持 Objective-C 语言。默认的 Dart 文件输出目录是当前目录，也可以通过 `-o` 选项来指定输出目录。生成的 Dart 代码会通过 [DartNative](https://github.com/dart-native/dart_native) 的超级通道(Bridge)来调用 Native API。

![](https://github.com/dart-native/codegen/blob/master/images/introduction.png?raw=true)

[Codegen](https://github.com/dart-native/codegen) 还支持将一个 Native SDK 转成 Flutter 组件，不过此功能尚在完善中，也就是 `-p` 选项。

![](https://github.com/dart-native/codegen/blob/master/images/login_sample.png?raw=true)

## 后记

曾经有两位大佬看了 [DartNative](https://github.com/dart-native/dart_native) 后问我有没有计划将它 Merge 到 Flutter 官方仓库里，我那时候觉得这个想法真的很大胆。现在看起来，如果完成了上述解决方案的大部分，好像也并不是不可以。