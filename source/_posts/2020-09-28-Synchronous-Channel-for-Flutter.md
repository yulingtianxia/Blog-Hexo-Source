---
title: 如何实现 Flutter 同步调用 Native API
date: 2020-09-28 17:53:16
tags:
- Dart
- Flutter
- DartNative
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

1. [DartNative](https://github.com/dart-native/dart_native) 是『真同步』，保证了执行顺序。同时也支持异步调用。
2. 一行代码实现同步调用，告别 Flutter Channel 胶水代码带来的开发成本。
3. 同步调用性能是 Flutter Channel 的数倍。分别使用 Flutter Channel 和 [DartNative](https://github.com/dart-native/dart_native) 调用 `fooNSString:` 方法，**耗时相差三到四倍**。性能数据可能在不同场景下有波动，可以通过执行 [Benchmark 代码](https://github.com/dart-native/dart_native/blob/3af52f7d3cfa0d93fd9fc04a10a05d4a2e0d5398/dart_native/example/lib/ios/ios_main.dart) 来对比结果。

## 实现原理

下图以 Dart 同步调用 iOS Objective-C API 为例，描述了 [DartNative](https://github.com/dart-native/dart_native) 同步调用的原理。以一个字符串参数为例，讲述了从 Dart `String` 自动转为 Objective-C `NSString` 并传递给 `hello:` 方法的过程。返回值也是自动转换类型的，由于篇幅原因没在图片中描述。

![](http://yulingtianxia.com/resources/DartObjC/sync_call_whole.png)

在实现了基本的同步调用后，开发重点也转向了性能优化。

## 方法签名的优化

在 Dart 同步调用 Native 时，为了实现跨语言调用时参数和返回值类型的自动转换，需要先获取到 Native 的方法签名。这里做了两方面的性能优化：

1. 通过 DartFFI 调用 OC Runtime 获取方法签名占据了一定耗时。可以在 Dart 侧加一层 Cache 来减少通信和反射次数。
2. 方法签名字符串的构成是 "TypeEncoding+offset" 的组合，跨语言之间传递字符串的编解码的耗时较多，而只有 TypeEncoding 那部分才是类型自动转换所需要的。绝大部分类型对应的 TypeEncoding 都是固定的，于是只需要传递 TypeEncoding 的指针即可。

![](http://yulingtianxia.com/resources/DartObjC/sync_call_optimize.png)

## 字符串转换的优化

Dart `String` 在与 Objective-C `NSString` 相互转换的过程中，数据传输的格式的选择至关重要。因为 Dart `String` 是使用 UTF16 编码的，所以 [DartNative](https://github.com/dart-native/dart_native) 使用 `Uint16List` 作为数据传输的格式。通过性能测试，使用 UTF16 来回传输字符串的总耗时（包含 Native 方法自身耗时）相比 UTF8 [减少了 35% 左右](https://github.com/dart-native/dart_native/issues/22)，如果只计算通道自动类型转换耗时减少的比例会更多。

### 转换 Dart `String` 为 Objective-C `NSString`:

使用 DartFFI 在堆上创建 `uint16_t` 数组，将 Dart `String` 转为 UTF16 格式后装载进去。最终通过 `perform` 方法反射调用 `stringWithCharacters:length:` 方法来创建 `NSString` 对象。

```dart
final units = value.codeUnits;
final Pointer<Uint16> charPtr = allocate<Uint16>(count: units.length + 1);
final Uint16List nativeString = charPtr.asTypedList(units.length + 1);
nativeString.setAll(0, units);
nativeString[units.length] = 0;
NSObject result = Class('NSString').perform(
    SEL('stringWithCharacters:length:'),
    args: [charPtr, units.length]);
free(charPtr);
```

### 转换 Objective-C `NSString` 为 Dart `String`:

`NSString` 转为 UTF16 稍微麻烦一点。这里的方案是先转为 UTF16 的 `NSData`，然后将 `uint16_t` 数组的地址和字符长度（不是字节长度）返回给 Dart 侧。

```objc
const void *
native_convert_nsstring_to_utf16(NSString *string, NSUInteger *length) {
    NSData *data = [string dataUsingEncoding:NSUTF16StringEncoding];
    // UTF16, 2-byte per unit
    *length = data.length / 2;
    return data.bytes;
}
```

Dart 拿到 `uint16_t` 数组后会转为 `Uint16List` 类型，并用它初始化一个 `String` 对象。

```dart
Pointer<Uint64> length = allocate<Uint64>();
Pointer<Void> result = convertNSStringToUTF16(ptr, length);
Uint16List list = result.cast<Uint16>().asTypedList(length.value);
free(length);
String str = String.fromCharCodes(list);
```

## 后记

写了这么多 [DartNative](https://github.com/dart-native/dart_native) 的相关文章，终于轮到了介绍最基础最核心的同步调用功能。其实异步调用也是支持的，看来用 [DartNative](https://github.com/dart-native/dart_native) 来替换 Flutter Channel 的理由又多了。

这篇文章主要讲的是 iOS 的同步调用实现以及性能优化，Android 也已经实现同步调用中基本类型的自动转换。
