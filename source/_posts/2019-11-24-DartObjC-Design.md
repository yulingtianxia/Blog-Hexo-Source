---
title: DartObjC Design
date: 2019-11-24 23:07:22
tags:
- Flutter
- Dart
---

[用 Dart 来写 Objective-C 代码](http://yulingtianxia.com/blog/2019/10/27/Write-Objective-C-Code-using-Dart/) 这篇文章讲了下我在解决 Flutter 三端开发问题的一个思路和方案，并给出了 Demo 和简单的对比。这次讲下 dart_objc 的设计，以及在一些开发场景的对比。由于涉及到的技术点很多，且可能会有变动，后续会分开讲下。

## 设计思路

### 宇宙真理①：Native 平台接口随版本变化，差异随时间增长。

- iOS 有太多的平台独有框架的 CloudKit、PhotoKit、StoreKit …
- 同理安卓也是，且这些差异都跟 UI 无关，无法通过图形引擎统一。
- 随着版本发布，不断有新增和废弃的 API，平台差异只会越来越大。

### 宇宙真理②：任何跨平台开发框架，Native API 该用还得用，可能只是换一种语言封装调用，逃不掉的。

无论是现今炙手可热的 Flutter，还是之前的 RN 和 Weex，都逃不掉这条真理。

还有些跨平台框架不通过 Bridge 或 Channel 调用 Native，而是直接将某种语言代码编译成对应平台的二进制。比如最近出的 Kotlin/Native，或是古老的 Xamarin，也都逃不掉这条真理。

![Flutter vs RN/Weex](https://github.com/yulingtianxia/Blog-Hexo-Source/blob/master/source/resources/DartObjC/flutter_rn.png?raw=true)

Flutter 通过图形引擎的跨平台帮我们抹平了 UI 层面的平台差异，这在跨平台开发框架中已经是个突破了。但其余的部分仍然需要开发者编写很多 Channel 代码来抹平不同平台的差异。不妨将二者结合下，取其精华去其糟粕，于是有了一种新的开发方式：

![DartNative](https://github.com/yulingtianxia/Blog-Hexo-Source/blob/master/source/resources/DartObjC/dart_native.png?raw=true)

### 为何这样设计

1. Native API 很多，逐个用 Channel 封装的话要多写很多代码。而这里可以借鉴其他跨平台框架『用同一种语言调用不同平台 API』的成熟经验，以 Dart 语言的形式将 Native API 暴露给 Flutter 来调用。将『三端开发』切换语言和开发环境的场景消灭到最低。
2. 通过 Native Runtime 来应对不同版本 API 变化问题，以不变应万变。搭配 Dart API 自动化生成工具提升效率，解放手写 Channel 带来的一系列开发成本。

## 数据对比

[进度](https://docs.qq.com/sheet/DRGNtVVVpTlZialdI?tab=BB08J2)

### 研发效率

以『判断是否安装某 App』为例，针对代码行数进行对比：

|  | 代码行数 | 调试成本 |
| --- | --- | --- |
| DartObjC | Native 1 行/Dart 1 行 | dart_objc 一行代码直接返回 bool 类型，无需调试 Native 和 Dart 逻辑。 |
| Channel | Native 30 行/Dart 15 行 | Channel 需定义返回数据格式，手动转换 BOOL 与 int，判断 channel 和 methodName，需要调试 Native 和 Dart 逻辑 |

### 性能数据

以『判断是否安装某 App』为例，抛出 Native 方法本身耗时，单独测试通道性能数据进行对比。相同环境下执行 1 万次耗时(ms)：

- DartObjC: 133
- Channel: 933
