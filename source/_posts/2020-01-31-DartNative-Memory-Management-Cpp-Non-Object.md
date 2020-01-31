---
title: 'DartNative Memory Management: C++ Non-Object'
date: 2020-01-31 23:12:26
tags:
- Dart
- Flutter
---

[dart_native](https://github.com/dart-native/dart_native) 基于 Dart FFI，通过 C++ 调用 Native 的 API。这种跨多语言的 bridge 就需要考虑到内存管理的问题。[上一篇文章](http://yulingtianxia.com/blog/2019/12/26/DartObjC-Memory-Management-Object/) 介绍了 Objective-C 对象类型的管理，本篇算是它的续篇，讲下对 `struct` 和 `char *` 内存的管理。

<!--more-->

如果你还不了解 [dart_native](https://github.com/dart-native/dart_native) 是什么，建议先看下我之前的两篇文章：

- [用 Dart 来写 Objective-C 代码](http://yulingtianxia.com/blog/2019/10/27/Write-Objective-C-Code-using-Dart/)
- [谈谈 dart_native 混合编程引擎的设计](http://yulingtianxia.com/blog/2019/11/28/DartObjC-Design/)
- [DartNative Memory Management: NSObject](http://yulingtianxia.com/blog/2019/12/26/DartObjC-Memory-Management-Object/)

PS：dart_objc 已经更名为 dart_native。

## 问题分析

Cocoa(Touch) 中的好多 API 都用到了系统内建的 `struct` 或 `UTF8String`(`char *`) 类型，它们不像 Objective-C 对象那样只存在于堆上（Block 除外），既可以存在堆上也可以在栈上。**如果能将 `struct` 和 `char *` 用对象的形式包一层**，那么就可以**将堆上非对象类型的生命周期转换为对象类型，交由 ARC 来管理**。由此继续借助[上一篇文章](http://yulingtianxia.com/blog/2019/12/26/DartObjC-Memory-Management-Object/)的经验和流程，自动释放存储在堆上的 `struct` 和 `char *` 类型。

## 何时销毁非对象类型

首先要确定非对象类型传递的方式。这里的解决方案是全都存储于堆上，并用一个 Wrapper 对象包一层来传递。下面说说为何这么做。

非对象类型如果存储在栈上，那么当调用结束返回后就会被销毁。在跨语言异步调用时，栈上的内存也会被回收，Dart 侧无法长期持有并访问这些数据。Objective-C 大多使用 Block 的方式来实现异步调用逻辑，由于 Block 会去捕获外部变量，所以可以正常运行。

这个 `PointerWrapper` 类也很简单，它包了个 `void *pointer` 属性，在析构的时候会释放 `pointer` 指向的内存：

```
- (void)dealloc {
    free(_pointer);
}
```

这样就可以把一个非对象类型先 copy 到堆上，然后封装成对象类型来传递了。确保其不会过早被释放，且在同步或异步调用完成后由 ARC 自动释放。

## Dart 从 C++ 获取非对象类型

这里分两种情况：

1. Dart 创建新的 `struct` 或 `char *`（`Pointer<Utf8>`）。会通过 Dart FFI 的 `allocate` 在堆上开辟新的内存，**需要释放**。
2. Dart 调用 C++ 函数或 Objective-C Block 时获取的返回值。`struct` 会被拷贝到新创建的堆内存上，**需要释放**；`char *` 会自动转换成 `String`，**不需要释放**。
3. C++ 调用 Dart callback 时传入的参数。`struct` 会被拷贝到新创建的堆内存上，**需要释放**；`char *` 会自动转换成 `String`，**不需要释放**。

至于如何在 Dart 侧创建诸如 `CGRect` 之类的 `struct`，可能又能单开一篇文章来讲了，这里不细说了。Dart 侧并不会直接从 Objective-C/C++ 侧拿到 `struct` 类型，而是拿到一份 `malloc` 并拷贝后的指针。

上面这些需要释放的 `struct` 均可以通过 `PointerWrapper` 来自动释放，也就是默认创建的是临时变量，用完会自动销毁。Dart 的 `struct` 都以 `NativeStruct` 作为基类。其中 `addressOf` 为指向 `struct` 的指针，`wrapper` 接管了 `struct` 的生命周期。

```
abstract class NativeStruct {
  Pointer get addressOf;

  PointerWrapper _wrapper;
  PointerWrapper get wrapper {
    if (_wrapper == null) {
      _wrapper = PointerWrapper();
    }
    Pointer<Void> result = addressOf.cast<Void>();
    _wrapper.value = result;
    return _wrapper;
  }

  NativeStruct retain() {
    wrapper.retain();
    return this;
  }

  release() => wrapper.release();
}
```

也就是 Dart 获取到的 `struct` 是个临时变量，不用就会自动销毁。如果需要长期持有，则需要手动 `retain` 和 `release`。而 Dart 获取到的 `char *` 则会被自动转为 `String` 类型，无需关心内存管理。

## C++ 从 Dart 获取非对象类型

这里分两种情况：

1. Dart 调用 C++ 函数或 Objective-C Block 时传入的参数。
2. Objective-C 调用 Dart callback 时获取的返回值。

Dart 侧的 `struct` 早已由 `PointerWrapper` 交给 ARC 来接管生命周期，**在调用完成后自动释放**。不过需要注意的一点是，Dart 的 `String` 自动转换为 C++ 的 `char *`（`Pointer<Utf8>`）时属于新创建 `char *`，**需要交给 `PointerWrapper` 自动释放**:

```
dynamic storeCStringToPointer(dynamic object, Pointer<Pointer<Void>> ptr) {
  Pointer<Utf8> charPtr = Utf8.toUtf8(object);
  PointerWrapper wrapper = PointerWrapper();
  wrapper.value = charPtr.cast<Void>();
  ptr.cast<Pointer<Utf8>>().value = charPtr;
  return wrapper;
}
```

### Dart 向 C++ 传参

1. 由于字符串比较特殊，即便在函数调用结束后，字符串很多以常量的形式被继续使用。所以传递 `char *` 的时候，即便已经通过传递 `PointerWrapper` 来保证调用过程中不被释放，但还需要利用 `NSTaggedPointerString` 将其生命周期交给 Foundation 管理。
2. 原本传递结构体现在改成了传递结构体的指针。因为跨语言调用时，使用 Dart FFI 传递单个数据最大为 64bit，可以为整型、浮点型或指针等。所以可能无法容纳下比较大的结构体，需要传递指向结构体的指针。
3. 其余类型照常传递。

```objc
void
_fillArgsToInvocation(NSMethodSignature *signature, void **args, NSInvocation *invocation, NSUInteger offset) {
    for (NSUInteger i = offset; i < signature.numberOfArguments; i++) {
        const char *argType = [signature getArgumentTypeAtIndex:i];
        NSUInteger argsIndex = i - offset;
        if (argType[0] == '*') {
            // Copy CString to NSTaggedPointerString and transfer it's lifecycle to ARC. Orginal pointer will be freed after function returning.
            const char *temp = [NSString stringWithUTF8String:(const char *)args[argsIndex]].UTF8String;
            if (temp) {
                args[argsIndex] = (void *)temp;
            }
        }
        if (argType[0] == '{') {
            // Already put struct in pointer on Dart side.
            [invocation setArgument:args[argsIndex] atIndex:i];
        } else {
            [invocation setArgument:&args[argsIndex] atIndex:i];
        }
    }
}
```

### Objective-C 调用 Dart callback 时获取的返回值

由于 Dart callback 所对应的 C++ Function 由 libffi 动态创建，而基于动态创建的 C++ Function 又动态创建了 Objective-C Block 和方法。所以这一切都是我们创建的，尽在掌控之中。而这个动态创建的过程又有点复杂，可以再单独开一篇文章来讲了。

Objective-C 中方法和 Block 的返回值如果是比较大的 `struct`，运行在 x86 架构上时，实际上调用更底层函数时的参数列表会有变化。此时第一个参数是指向返回结构体的指针，其余参数依次后移一位。这在 Objective-C 中缩写为 stret，也就是 struct return 的意思。

如果没有触发 `stret` 条件，此时的策略是 Dart callback 返回非对象类型锁对应的 `PointerWrapper`，然后 Objective-C 侧再从 `wrapper` 中取出对非对象类型，并塞入到 libffi 提供的 `ret` 指针里：

```objc
if (wrapper.hasStret) {
    // synchronize stret value from first argument.
    [invocation setReturnValue:*(void **)args[0]];
} else if ([wrapper.typeString hasPrefix:@"{"]) {
    DOPointerWrapper *pointerWrapper = *(DOPointerWrapper *__strong *)ret;
    memcpy(ret, pointerWrapper.pointer, invocation.methodSignature.methodReturnLength);
} else if ([wrapper.typeString hasPrefix:@"*"]) {
    DOPointerWrapper *pointerWrapper = *(DOPointerWrapper *__strong *)ret;
    const char *origCString = (const char *)pointerWrapper.pointer;
    const char *temp = [NSString stringWithUTF8String:origCString].UTF8String;
    *(const char **)ret = temp;
}
```

## 后记

非对象类型的内存管理要比对象类型复杂得多，光是把 `struct` 在 Dart 中转换出来就已经有些麻烦了。好在大部分问题都已经克服过去了，最终实现了一套半自动化的内存管理系统，也实现了跨语言的类型自动转换。后续可能还会对 stret 的情况进行优化，甚至对方案进行大改。

哎真是太难了，我还是继续骑着小摩托去找人马吧。

