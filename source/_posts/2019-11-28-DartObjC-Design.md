---
title: 谈谈 dart_objc 混合编程引擎的设计
date: 2019-11-28 17:07:22
tags:
- Flutter
- Dart
---

我之前在 『[用 Dart 来写 Objective-C 代码](http://yulingtianxia.com/blog/2019/10/27/Write-Objective-C-Code-using-Dart/)』 这篇文章讲了下我在解决 Flutter 三端开发问题的一个思路和方案，并给出了 Demo 和简单的对比。这次讲下 [dart_objc](https://github.com/yulingtianxia/dart_objc) 的设计，这包含了上层使用方式和底层技术方案的设计。由于涉及到的技术点很多，这次不会深入太多技术实现细节，不过后续可能会分篇讲下。

<!--more-->

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

## 技术指标

**一句话：运行性能和研发效率都要吊打 Flutter Channel。**

### 研发效率

以『判断是否安装某 App』为例，针对代码行数进行对比：

|  | 代码行数 | 调试成本 |
| --- | --- | --- |
| DartObjC | Native 1 行/Dart 1 行 | [dart_objc](https://github.com/yulingtianxia/dart_objc) 一行代码直接返回 bool 类型，无需调试 Native 和 Dart 逻辑。 |
| Channel | Native 30 行/Dart 15 行 | Channel 需定义返回数据格式，手动转换 BOOL 与 int，判断 channel 和 methodName，需要调试 Native 和 Dart 逻辑 |

由于 [dart_objc](https://github.com/yulingtianxia/dart_objc) 帮开发者完成了类型自动转换，省去了多余的 Channel 逻辑，也就无需调试这部分代码。只需调试 Dart 代码，统一开发环境和语言。

其实使用 [dart_objc](https://github.com/yulingtianxia/dart_objc) 后，理论上是不需要写 Native 代码的。

### 性能数据

分别测试了两个 Native 接口在相同环境下执行 1 万次的耗时情况(ms)：

| 接口案例 | 总耗时对比（Channel/dart_objc） | 仅通道耗时对比（Channel/dart_objc） |
| --- | --- | --- |
| 判断是否安装某 App | 5202/**4166** | 919/**99** |
| 打日志 | 2480/**2024** | 1075/**432** |

严格来讲，对比性能时需要刨除 Native 方法自身的执行耗时，剩下的就是通道的耗时了。在这方面 Flutter Channel 的耗时是 [dart_objc](https://github.com/yulingtianxia/dart_objc) 的好几倍。在测试打日志这个案例时，[dart_objc](https://github.com/yulingtianxia/dart_objc) 耗时瓶颈在于将 Dart `String` 转为 Objective-C `NSString`，所以耗时仅仅比 Flutter Channel 少了 60% 左右。

而在真实场景下，总耗时就更加有意义。由于 Native 方法本身执行的耗时占比较大，所以最终二者的耗时对比并不是几倍的关系，但 [dart_objc](https://github.com/yulingtianxia/dart_objc) 依然有着性能上的优势。

### 支持的特性

为了在 Flutter 中使用，[dart_objc](https://github.com/yulingtianxia/dart_objc) 无法用到 Dart 反射特性，但依然最大限度地实现了对 Objective-C 语法特性的支持。

#### 内存管理

Dart 和 Objective-C 的内存管理方式差异很大。前者使用 GC，后者使用 ARC。目前的解决方案是『半自动引用计数』的内存管理方式，大多数场景下无需关注内存问题。待 Dart 支持 `finalizer` 可优化为『全自动』。这其中用到了一些算不上黑科技的土方子，暂且奏效。

Dart 中临时使用和创建的 Objective-C 对象、C-String 或结构体无需关注内存问题，但如果想长期持有，需要调用 `retain()` 方法，并在不用的时候（比如页面销毁时）调用 `release()` 方法。

#### Native Callback

有很多 Native API 的参数一个 Callback。这类方法大多是一些异步返回的方法，传入参数的方式大多是 Block 或 Delegate。为了让 Dart 能够调用这些 API，[dart_objc](https://github.com/yulingtianxia/dart_objc) 实现了『用 Dart 语法写 Block 和 Delegate』。这需要实现动态创建任意函数签名的 Block 对象和 Objective-C 方法，甚至当 Dart 类并没有对应的 Objective-C 类时，需要动态创建这个类。这其中又涉及到大量内建类型的自动转换和边界问题处理。

#### 多线程 / GCD

Flutter 中运行时，VM 会开辟一些内建的线程来维持 Flutter 的运行。我们编写的 Dart 代码大多跑在 flutter.ui 线程，但这不是 Native 系统的主线程。而有些 API 要求必须在主线程调用，所以 [dart_objc](https://github.com/yulingtianxia/dart_objc) 也支持指定线程和队列调用。

对于 GCD 的 API 仅有部分支持，且计划为 Swift 风格语法。等 dart:ffi 1.1 支持 async callback 后，这部分的功能会得到加强。

#### 方法调用时的类型自动转换

[dart_objc](https://github.com/yulingtianxia/dart_objc) 会自动转换 Dart 与 Objective-C 类型。大部分 Objective-C 类型在 Dart 中都有对应的封装类，或者是可以映射到 Dart 基本类型。目前有的转换是单项的，比如 Dart Function 可以转为 Objective-C Block，反之则不行。

已支持以下类型的自动转换：

| Dart | Objective-C |
| --- | --- |
| int | int8_t |
| int | int16_t |
| int | int32_t |
| int | int64_t |
| int | uint8_t |
| int | uint16_t |
| int | uint32_t |
| int | uint64_t |
| char/int/String | char |
| unsigned_char/int/String | unsigned char |
| short/int | short |
| unsigned_short/int | unsigned short |
| long/int | long |
| unsigned_long/int | unsigned long |
| long_long/int | long long |
| unsigned_long_long/int | unsigned long long |
| NSInteger/int | NSInteger |
| NSUInteger/int | NSUInteger |
| size_t/int | size_t |
| float/double | float |
| double | double |
| double | CGFloat |
| bool | BOOL/bool/_Bool |
| CGSize | CGSize |
| CGPoint | CGPoint |
| CGVector | CGVector |
| CGRect | CGRect |
| NSRange | NSRange/_NSRange |
| UIOffset | UIOffset |
| UIEdgeInsets | UIEdgeInsets |
| NSDirectionalEdgeInsets | NSDirectionalEdgeInsets |
| CGAffineTransform | CGAffineTransform |
| NSObject | NSObject |
| NSObjectProtocol | NSObjectProtocol |
| Block/Function | NSBlock |
| Class | Class |
| Selector/SEL | Selector/SEL |
| Protocol | Protocol |
| NSString/String | NSString |
| String | char * |
| Pointer<Void> | void * |
| void | void |
| NSValue | NSValue |
| NSNumber | NSNumber |
| NSArray/List | NSArray |
| NSDictionary/Map | NSDictionary |
| NSSet/Set | NSSet |


