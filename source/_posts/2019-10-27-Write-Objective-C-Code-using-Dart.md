---
title: 用 Dart 来写 Objective-C 代码
date: 2019-10-27 17:59:40
tags:
- Objective-C
- Dart
- Runtime
---

这篇文章不是讲 Flutter Channel 入门的，可能让你失望了。不过继续往下读可能也会有点收获。

Flutter 提升了客户端开发的效率，但在跟 Native 代码配合开发时也带来了不好的体验。于是我写了个 Flutter 插件 [dart_objc](https://pub.dev/packages/dart_objc)，使开发者可以用 Dart 的语法来写 Objective-C 代码。借助于 Flutter 的热重载，也可以更高效的动态调试 Native 代码，从此告别在两个工程和 IDE 中切来切去。

<!--more-->

## 问题背景

先说说为什么会有开发效率的问题。Flutter 的跨平台多适用于 UI 等上层需求，本来是可以提升开发效率的。但是诸如 LBS、系统和设备信息、获取相册等常用功能都需要两端去写很多 Native 代码。**最终原本的『两端开发』最后成了『三端开发』**。很少会有完全用 Flutter 开发的 App，原因如下：

1. 一些跟系统和设备强相关的功能只能靠调用 API 来实现
2. 旧项目引入 Flutter 后需调用已有的 Native 模块代码

既然『三端开发』无法避免，那么增加了哪些成本呢？

1. 开发过程中需要在至少两个 IDE 打开的工程中来回切换，需单独运行，无论是写代码还是 Debug 都体验不连贯，降低效率
2. 如果 Flutter 和 Native 代码由不同的人来开发和维护，增加了沟通成本
3. Flutter 需要通过编写 channel 代码来与 Native 层交互，需要两端开发时统一数据传输协议。不仅 channel 调用性能较差，Model 数据在 Native 与 Flutter 之间传递过程的序列化和反序列化也降低性能。
4. 通过 channel 在 Flutter 和 Native 之间调用时只支持异步回调

## 分析问题

既然无法避免调用 Native 的 API，那么就要面对这个事实。下一步是如何能让调用 Native API 的这个过程效率更高。具体体现如下：

1. 开发效率提高：直接用 Dart 语言在 Flutter 工程里编写和调试代码，无需切换到 Xcode 等其他 IDE 打开的 Native 工程
2. 运行效率提高：channel 的调用性能差一直被诟病

所以思路就是：

1. 将 Native API 封装成对应的 Dart 语言，解决一系列语言之间的类型转换和语法兼容问题
2. 通过一个更高效的方式来调用 Native API，这里使用 dart:ffi 调用 C 函数，再通过 Runtime 机制调用 Native

## 使用方法

假如你写了个 Objective-C 的类叫 `RuntimeStub`，并实现了个 `fooBlock:` 方法，参数和返回值都是个 block 对象。

```
@interface RuntimeStub ()
@end
@implementation RuntimeStub
typedef int(^BarBlock)(NSObject *a);
- (BarBlock)fooBlock:(BarBlock)block {
    ...
}
@end
```

利用 [dart_objc](https://pub.dev/packages/dart_objc) 写 Dart 代码调用过程如下：

初始化一个 `NSObject` 对象，传入类名就可以 `new` 任意类型的对象。`perform()` 方法可以调用任意对象的任何方法，跟 Objective-C 的用法基本一致。

```
NSObject stub = NSObject('RuntimeStub');
Block block = stub.perform(Selector('fooBlock:'), args: [barFunc]);
```

Objective-C 中 Block 这种匿名函数或闭包的概念在 Dart 中其实就是 Function，所以当参数是 Block 对象的时候，可以直接传入一个与之函数签名一样的 Dart Function 对象。[dart_objc](https://pub.dev/packages/dart_objc) 会自动完成参数类型转换和调用等一系列底层细节。所以用 Dart 实现的 `barFunc` 与 Objective-C 接口 `BarBlock` 的签名需要一致：

```
Function barFunc = (NSObject a) {
    print('hello block! ${a.toString()}');
    return 101;
};
```

Dart 调用 Block 也很简单，调用 `invoke` 方法就行：

```
int result = block.invoke([stub]);
```

最后也可以用 Dart 封装下 `RuntimeStub` 类，这样调用代码更简洁。这种模板代码后续会做成自动生成的，而不用手写。

```
class RuntimeStub extends NSObject {
  RuntimeStub() : super('RuntimeStub');

  Block fooBlock(Function func) {
    return perform(Selector('fooBlock:'), args: [func]);
  }
}
```

## 后续

由于 [dart_objc](https://pub.dev/packages/dart_objc) 组件还在基于 dev 版本的 Dart 开发，可能后续还会有比较大的变动，甚至是 API 的变化。所以没有过多展开讲实现细节，感兴趣可以去自己看代码：https://github.com/yulingtianxia/dart_objc

目前的 Cocoa API 封装打算参考 Swift 版本的文档，毕竟 Dart 有些语法跟 Swift 还有点像。

Android 平台的实现也在规划中，最终将会结束 Flutter 三端开发现状，实现真正的前端大一统。

不吹了，还要做的事情真的太多了。。。