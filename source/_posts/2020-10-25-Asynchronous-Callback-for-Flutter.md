---
title: 实现 Native 异步回调 Flutter
date: 2020-10-25 13:15:24
tags:
- DartNative
- Flutter
- Dart
---

看到标题的你可能已经充满疑问：Channel 不是本来就支持 Native 调用 Flutter 的么？别着急，先往下看。[DartNative](https://github.com/dart-native/dart_native) 要实现的是一个用 Channel 无法做到的回调场景：

![](http://yulingtianxia.com/resources/DartObjC/async_callback_block_code.png)

为什么说 Flutter Channel 无法做到呢，有两点：

1. 使用 Channel 从 Native 调用 Dart 时，想获取返回值就只能通过在 Channel API 在主线程的异步回调 `FlutterResult`。上面的例子是在 Native 的主线程调用 Flutter 并可以**同步**获取到返回值，如果用 Channel 会直接导致死锁。
2. Flutter Channel 需要写额外的胶水代码，而上面的例子简单清爽，跨语言调用无缝衔接。

<!--more-->

PS: 考虑到性能问题，在 Native 主线程调用 Flutter 并同步等待返回值这种场景，可能会引起卡顿。实事求是地说，这可能本身是个不该考虑到的场景，但不代表 [DartNative](https://github.com/dart-native/dart_native) 就不去做。毕竟 [DartNative](https://github.com/dart-native/dart_native) 在实现 Flutter Channel 没覆盖到的场景的同时，也在尝试不断替代它。

除了 Block 的回调场景，还有 iOS 里常见的 Delegate：

``` objc
@implementation RuntimeStub
- (void)fooDelegate:(id<SampleDelegate>)delegate {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSObject *result = [delegate callback];
    });
}
@end
```

使用 [DartNative](https://github.com/dart-native/dart_native) 是这么玩的：

``` dart
DelegateStub delegate = DelegateStub();
RuntimeSon stub = RuntimeSon();
stub.fooDelegate(delegate);
```

当 OC 的 `[delegate callback]` 被执行时，Dart 类 `DelegateStub` 实例的 `callback()` 方法会被调用：

``` dart
class DelegateStub extends NSObject with SampleDelegate {
  DelegateStub() : super(Class('DelegateStub', type(of: NSObject))) {
    super.registerSampleDelegate();
  }
  
  @override
  callback() {
    print('callback succeed!');
    return NSObject();
  }
}
```

类似 Native 需要回调给 Dart 的场景还有很多，比如 `NSNotification`、`dealloc` 等渠道。这些回调需求无法直接用 Channel 来实现，[DartNative](https://github.com/dart-native/dart_native) 基于 DartVM 提供的能力实现了一套回调机制，支持阻塞和非阻塞两种方式。

下面以 Block 回调为例来讲下具体实现，在这之前先熟悉下 Dart Function 是如何变成 Block 并传递给 OC 的。这部分原理在之前的[《在 Flutter 中玩转 Objective-C Block》](http://yulingtianxia.com/blog/2020/03/28/Using-Objective-C-Block-in-Flutter/)也有讲过：

![](http://yulingtianxia.com/resources/DartObjC/async_callback_block_workflow.png)

Block 能够回调到对应的 Dart Function 的前提是能建立起绑定关系，也就是上图右侧的『指针绑定』那里。这里是通过 DartFFI 提供的能力来将 Dart Function 转为函数指针 `callback`，更加具体的关联逻辑实现如下图所示：

![](http://yulingtianxia.com/resources/DartObjC/async_callback_block_correlative.png)

绑定好 OC Block 和 Dart Function 后，重点来了：如何在 Native 调用 `callback` 函数指针指向的函数？要知道，这个函数肯定要在 Dart Function 传入时的线程来调用的（一般是 `flutter-ui` 线程），而且还不能位经由 `isolate` 直接切到对应线程去调用。

这里使用的 Port 相关 API，在 Dart isolate 库中可以找到。不过在 Native 侧 Flutter 框架并未暴露这些 API，但是可以在 Dart VM 源码中找到。Native 异步调用到 Flutter 的实现流程如下，具体函数实现可以查阅 [DartNative](https://github.com/dart-native/dart_native) 源码：

![](http://yulingtianxia.com/resources/DartObjC/async_callback_block_port.png)

上面讲完了 Block 执行后回调 Dart。Block `dealloc` 后回调 Dart 并释放资源的原理跟上面大同小异，只是异步回调的时候不会阻塞等待返回值罢了。更详细流程可以看之前我写的[《[DartNative](https://github.com/dart-native/dart_native) 内存自动管理》](http://yulingtianxia.com/blog/2020/08/22/[DartNative](https://github.com/dart-native/dart_native)-Automatic-Memory-Management/)对 Block 内存的处理。

而 Delegate 和 Notification 回调的调用原理都跟 Block 回调相同，只是在上层类型封装和参数列表上有少许差异，这里不再赘述。