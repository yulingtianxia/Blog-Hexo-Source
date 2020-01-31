---
title: 'DartNative Memory Management: NSObject'
date: 2019-12-26 12:49:13
tags:
- Dart
- Flutter
---

[dart_native](https://github.com/dart-native/dart_native) 基于 Dart FFI，通过 C++ 调用 Native 的 API。这种跨多语言的 bridge 就需要考虑到内存管理的问题。由于篇幅有限，会分开来讲，本篇文章只涉及 Objective-C 对象类型的管理。

<!--more-->

如果你还不了解 [dart_native](https://github.com/dart-native/dart_native) 是什么，建议先看下我之前的两篇文章：

- [用 Dart 来写 Objective-C 代码](http://yulingtianxia.com/blog/2019/10/27/Write-Objective-C-Code-using-Dart/)
- [谈谈 dart_native 混合编程引擎的设计](http://yulingtianxia.com/blog/2019/11/28/DartObjC-Design/)

## 问题分析

先看看不同语言是如何管理内存与对象的生命周期的。

- Dart VM 使用 GC 来管理内存，且 Dart 语言一切皆为对象。
- C++ 在堆上手动开辟的内存需要手动释放。
- Objective-C 上的对象普遍使用 ARC 来管理，但也可以使用 MRC。其余跟 C++ 一样。

GC 和引用计数都是常见的内存管理方式，这里就不科普具体算法的细节了。两者差别固然很大，[dart_native](https://github.com/dart-native/dart_native) 在这里做了一些事情，尽量让开发者写 Dart 时少关心内存问题。

由于 Dart 对象的生命周期实际完全由 VM 的 GC 决定，所以这里没有可操作性的空间，只能调整 Objective-C 对象的生命周期。Objective-C 对象都是存储在堆上的，跨语言之间传递的都是指针。而使用栈上的一个 64 位空间也足够存储大部分基本类型数据，足够覆盖到各种长度精度的整型和浮点数类型。

跨语言之间的方法调用，更多关注的是方法返回值给到另一种语言时的生命周期，以及对象被销毁后的处理。

## Objective-C 对象销毁后的处理

读过我之前文章的人可能会对 [dart_native](https://github.com/dart-native/dart_native) 的使用方式稍有了解，其实就是自定义 Dart 类来把 Objective-C 类封装了一层。比如我写了个 Dart 类叫 `NSObject`，封装了大部分基本的 API。打通了方法的调用时类型的自动转换，支持所有基本类型。

Dart 的 `NSObject` 类有个指向 Objective-C 对象的指针 `_ptr`，当这个 Objective-C 对象被销毁时，那么对应的 Dart 对象各种状态也需要置空。虽然 Dart 对象没被及时销毁，但是对其的任何操作都是无效的了。当然，这很容易导致难以发现的 bug。所以需要有效地措施来让开发者知道这个 Dart 对象已经失效了。

首先是提供 `dealloc` 方法，让开发者自己清理子类中的内容，这跟写 MRC 代码很像。
这是基类中 `dealloc` 方法的实现（简略版），它清空了 `_ptr` 指针。当 Objective-C 对象被销毁后，[dart_native](https://github.com/dart-native/dart_native) 框架会负责调用 `dealloc` 方法，开发者不能手动调用。篇幅原因，这部分的实现原理就不展开讲了。

```
/// Clean NSObject instance.
/// Subclass can override this method and call release on its dart properties.
dealloc() {
    _ptr = nullptr;
}
```

当 `dealloc` 方法被调用后，需要有能够对 Dart 对象判空的能力。于是我创造了个 Dart 版本的 `nil`，其实就是一个指向 `nullptr` 的 Dart 对象。

```
final id nil = id(nullptr);
```

然后重写了 Dart `NSObject` 的 `==` 判等方法，使得 `NSObject` 的判等变成了指针之间的判等。

```
bool operator ==(other) {
    if (other == null) return false;
    return pointer == other.pointer;
}
```

如此一来，一旦 Dart 对象内部指向的 Objective-C 对象被销毁，它就等于 `nil` 了。

## Dart 从 Objective-C 获取对象

从 Objective-C 获取对象的方式可能是新创建的，也可能是某个普通方法的返回值。从形式上二者都是调用方法返回对象，但是内存引用计数却不一样。以 `new`, `alloc`, `copy` 和 `mutableCopy` 开头的方法会被认为引用计数加一，这样就相当于把 Objective-C 对象的管理权交给了 Dart。而普通方法返回的 Objective-C 对象的管理权并不归属 Dart。

为了简化操作，让这两种获取方式的结果统一，我会在 Dart 侧 `NSObject` 基类的这四个相关方法中调用一次 `autorelease`。这样就又把带 `new`, `alloc`, `copy` 和 `mutableCopy` 前缀的方法返回的 Objective-C 对象的管理权交由 ARC，而又不会过早释放导致 crash。

这里从使用方式可分两种情况：

1. 临时使用 Objective-C 对象，当为局部变量：Dart 侧编写代码时无需关心内存管理
2. 长期使用 Objective-C 对象，作为属性持有：Dart 侧需手动 `retain` 和 `release`

针对第二种情况，写过 MRC 代码的会很熟悉。这是对应的 Dart 代码，是不是很像。

```
class _MyAppState extends State<MyApp> {
  NSObject object = NSObject().retain();
  ...
  @override
  void dispose() {
    object.release();
    super.dispose();
  }
}
```

如果 Dart VM 支持了 `finalize`，那么现在的『半自动』内存管理就成了『全自动』了，不过那样的话，内存管理方案也会改变。这里就不谈 Plan B 了。

## Objective-C 从 Dart 获取对象

[dart_native](https://github.com/dart-native/dart_native) 是支持传入回调方法的，也就是 Objective-C 是可以直接调用 Dart 方法的。当 Objective-C 从 Dart 方法的返回值是对象，需要处理好它的生命周期。

当 Dart 返回给 Objective-C 一个对象时，其内部指向的 Objective-C 对象是交给 ARC 管理的。当 Dart 与 Objective-C 在同一线程时倒还好，切了不同线程后 Objective-C 对象很可能被销毁了，那么就会 crash。此时就需要在 Dart 侧记录下要返回的 Objective-C 对象，这里用到了线程局部存储（TLS）。利用 Dart FFI 调用下面这个 C++ 函数，它在当前线程下持有了 Dart 要返回的 Objective-C 对象，防止被提前销毁。

```
void
native_mark_autoreleasereturn_object(id object) {
    int64_t address = (int64_t)object;
    [NSThread.currentThread do_performWaitingUntilDone:YES block:^{
        NSThread.currentThread.threadDictionary[@(address)] = object;
    }];
}
```

当然还需要在 Objective-C 侧调用完 Dart 方法后，将 TLS 置空，确保不会造成内存泄露。

## 后记

这篇文章依然没有讲 Dart 如何调用 Objective-C API，没有贴很多代码晒技术细节，满篇都是讲思路和方法。可能是我觉得这些都是 Runtime 的基础，没太多自己思考的东西。写出来也只是简单的科普知识罢了。

张小龙说『思辨大于执行』，当大家都有很强的执行力的时候，先理清思路就显得很重要。

主要还是技术细节太多，几篇文章的篇幅都讲不完，我也懒得一次写完。