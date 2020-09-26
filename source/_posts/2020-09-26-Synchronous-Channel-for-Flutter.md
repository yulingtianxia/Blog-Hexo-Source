---
title: 如何实现 Flutter 同步调用通道
date: 2020-09-26 17:53:16
tags:
- Dart
- Flutter
---

Flutter Channel 是一个异步调用通道，如果想在 Dart 侧同步获取到 Native 返回的结果，调用的时候加上 `await` 就可以了：

``` dart
final int result = await platform.invokeMethod('hello channel');
```

所以这篇文章到此为止了？

不！上面这行代码其实是个『假同步』，因为它只保证了 Dart 代码的同步执行，而 Native 代码与 Dart 并不在同一条线程执行。试想下，如果你通过 Flutter Channel 打日志，但由于打日志的消息是异步传递到 Native 的，最后日志顺序可能是错的。而通过日志来排查一些时序性相关的 Bug 时，日志的顺序很重要。

因为 Flutter Channel 设计之初就是异步的，使用 `await` 来回切换线程所带来的开销不小。而且协程的 `await` 语法具有传递性，上层调用方也需要使用 `await`，层层传递。

而 [DartNative](https://github.com/dart-native/dart_native) 设计之初就是同步调用的，且也支持异步调用。

<!--more-->

## Why DartNative?

1. [DartNative](https://github.com/dart-native/dart_native) 是『真同步』，保证了执行顺序。
2. 一行代码实现同步调用，告别 Flutter Channel 胶水代码带来的开发成本。
3. 同步调用性能是 Flutter Channel 的数倍。分别使用 Flutter Channel 和 [DartNative](https://github.com/dart-native/dart_native) 调用 `fooNSString:` 方法，耗时相差三到四倍。详见 [Benchmark 代码](https://github.com/dart-native/dart_native/blob/3af52f7d3cfa0d93fd9fc04a10a05d4a2e0d5398/dart_native/example/lib/ios/ios_main.dart)。

## 实现原理

下图以 Dart 同步调用 iOS Objective-C API 为例，描述了 [DartNative](https://github.com/dart-native/dart_native) 同步调用的原理。以一个字符串参数为例，讲述了从 Dart `String` 自动转为 Objective-C `NSString` 并传递给 `hello:` 方法的过程。返回值也是自动转换类型的，由于篇幅原因没在图片中描述。

![](http://yulingtianxia.com/resources/DartObjC/sync_call_whole.png)

![](http://yulingtianxia.com/resources/DartObjC/sync_call_optimize.png)
