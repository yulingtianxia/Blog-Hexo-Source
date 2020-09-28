---
title: DartNative 内存自动管理
date: 2020-08-22 23:05:38
tags:
- Dart
- Flutter
- DartNative
---

[DartNative](https://github.com/dart-native/dart_native) 可以让开发者一行代码实现调用 Native 代码，且支持高性能同步调用。之前曾经写过一篇文章讲述 Dart 与 Objective-C 对象的生命周期管理，当时的实现是『半自动』的解决方案。如今 [DartNative](https://github.com/dart-native/dart_native) 更新到 0.3 后实现了生命周期的自动管理，也就是『全自动』的解决方案。

<!--more-->

## 新版本的变化

[DartNative](https://github.com/dart-native/dart_native) 0.3 版本基于 Flutter 1.20.2，Dart 1.9.0。我不得不提的是，Flutter 和 Dart 对 API 兼容性设计的确很糟糕，不仅没有 API Available 的文档或语法标注，也经常会发生 breaking change。[DartNative](https://github.com/dart-native/dart_native) 也因此表现的同样『激进』，毕竟我们还没有发布 1.0 版本。

新版本不再需要手动管理内存，Objective-C 对象会被对应的 Dart 对象持有，当 Dart 对象析构时就不再持有 Objective-C 对象。于是 iOS 侧直接干掉了 `NSObject` 和各种 `struct` 的 `retain()` 和 `release()` 等手动操作引用计数的方法。如果从旧版本升级过来，发现编译失败，直接删掉对这些方法的调用就可以。

## 实现原理

这里只讲下对象的生命周期管理，非对象类型基本上依然复用[之前的策略](http://yulingtianxia.com/blog/2020/01/31/DartNative-Memory-Management-Cpp-Non-Object/)。

### Dart 封装的 NSObject 对象

之前我写过一篇文章《[DartNative Memory Management: NSObject](http://yulingtianxia.com/blog/2019/12/26/DartObjC-Memory-Management-Object/)》，其中讲述了对象类型的内存管理，并且埋了个坑：

>
如果 Dart VM 支持了 finalize，那么现在的『半自动』内存管理就成了『全自动』了，不过那样的话，内存管理方案也会改变。

嗯，下图简要描述如何手动实现 Dart Finalizer，并将 Objective-C 对象的生命周期『部分绑定』到 Dart 对象上的。这里之所以是『部分绑定』，是考虑到 Objective-C 对象不仅可以被 Dart 对象持有，也可以被其他 Objective-C 对象持有。Dart 对象的构造和析构只是对关联的 Objective-C 对象引用计数加一和减一：

![](http://yulingtianxia.com/resources/DartObjC/DartNative_Object_Memory_Management.png)

Flutter 内嵌的 Dart VM 中也内嵌了一些 C 的 API 来供 Native Extension 调用。虽然可以在二进制文件中链接到函数符号，但开发时依然需要引入 Dart SDK 源码中相应的头文件来进行编译。

### 由 Dart Function 创建的 Block 对象

还有一种特殊场景，就是 Dart 调用带有 Block 回调的 API。此时是 Native 的 Block 来回调 Dart 函数，需要保证回调的时候 Dart 函数及上下文依然存在。此时的 Dart Function 会被 Dart Block 持有，而 Dart Block 的生命周期被绑定到了对应的 Objective-C Block 上：

![](http://yulingtianxia.com/resources/DartObjC/DartNative_Block_Memory_Management.png)

Objective-C 的 Block 析构时，会通过 isolate 注册好的 Port 去异步回调 Dart。实际的实现其实比上图描述的还要复杂得多，这里为了阐述思路，简化了很多细节。其实像 `dealloc` 这种无需阻塞的异步回调可以直接用 Flutter Channel 来完成，但因为 [DartNative](https://github.com/dart-native/dart_native) 基于 Dart VM API 和 FFI 等技术搭建了通用的异步回调机制，这里直接复用这个能力了。至此 [DartNative](https://github.com/dart-native/dart_native) 彻底告别了 Flutter Channel。

## 结论

[DartNative](https://github.com/dart-native/dart_native) 0.3 版本虽然没有新的 Feature，但其实是在修内功。在 iOS 侧的内存管理和异步回调上修复了一系列问题，后续还会将对应能力同步到 Android 侧。

## Reference

- [dart_native](https://github.com/dart-native/dart_native)
- [dart:ffi GC finalizers](https://github.com/dart-lang/sdk/issues/35770)
- [Support asynchronous callbacks](https://github.com/dart-lang/sdk/issues/37022#issuecomment-671310270)