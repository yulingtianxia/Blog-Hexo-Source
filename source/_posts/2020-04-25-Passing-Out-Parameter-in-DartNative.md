---
title: Passing Out Parameter in DartNative
date: 2020-04-25 15:55:41
tags:
- Objective-C
- Flutter
- Dart
- DartNative
---

[dart_native](https://github.com/dart-native/dart_native) 作为一条比 Channel 性能更高开发成本更低的超级通道，通过 C++ 调用 Native 的 API，深入底层且考虑全面。很多 Objective-C 接口含有 `NSError **` 这种 out parameter，[dart_native](https://github.com/dart-native/dart_native) 也对这种场景做了支持。

<!--more-->

## 封装 Objective-C 里的 Out Parameter

说白了用的最多的就是 "A pointer to a pointer" 啊！`NSError **` 啊！

```objc
NSError *error;
[self fooWithError:&error];
```

那换成 Dart 语言该咋表示呢？？？首先要知道 Dart 是不支持 out parameter 的，只能另辟蹊径，在语法上做一些妥协，最终跑通流程实现目的。

```dart
NSObjectRef<NSObject> ref = NSObjectRef<NSObject>();
fooWithError(ref);
```

还记得之前 [dart_native](https://github.com/dart-native/dart_native) 是如何封装 `NSObject *` 的么？用一个同名的 Dart 类包一个 OC 对象的指针就行了。那想封装 out parameter 的话，在此基础之上再套一层不就行了！只要用泛型，就能一层层套下去。。。

```dart
class NSObjectRef<T extends id> {
  T value;
  Pointer<Pointer<Void>> _ptr;
}
```

接着要考虑如何初始化 out parameter 了。在 OC 里只需要在栈上的一个地址就够了，也就是声明一个变量。但 Dart 的对象并没有对应指针的概念，但是可以通过 dart ffi 手动创建一个指向指针的指针。不过它指向的内存是在堆上，需要手动释放。此时可以通过[我之前讲内存管理的文章](http://yulingtianxia.com/blog/2020/01/31/DartNative-Memory-Management-Cpp-Non-Object/)里讲到的 `PointerWrapper` 来实现临时指针变量的自动释放，简单来说就是把 dart ffi 创建的内存交给 OC ARC 管理。

加上构造方法和自动释放后的 `NSObjectRef` 实现如下：

```dart
class NSObjectRef<T extends id> {
  T value;
  Pointer<Pointer<Void>> _ptr;
  Pointer<Pointer<Void>> get pointer => _ptr;

  NSObjectRef() {
    _ptr = allocate<Pointer<Void>>();
    _ptr.value = nullptr;
    PointerWrapper wrapper = PointerWrapper(_dealloc);
    wrapper.value = _ptr.cast<Void>();
  }

  NSObjectRef.fromPointer(this._ptr);
  
  _dealloc() {
    _ptr = null;
  }
}
```

## 从 Out Parameter 取值

Dart 侧把一个指针传给 OC 后，OC 会创建另一个指针，并把后者赋值给前者指向的内存。还是拿 `NSError` 举例子：

```objc
- (void)fooWithError:(out NSError **)error {
    if (error) {
        *error = [NSError errorWithDomain:@"com.dartnative.test" code:-1 userInfo:nil];
    }
}
```

下一步是要将上例中 OC 的 `NSError` 对象转成 Dart 的对象，并赋值给 `NSObjectRef` 的 `value` 属性上。

### 建立泛型与初始化的映射

面对不同泛型的 `NSObjectRef` 声明，要转成其封装类型的对象。而 Flutter 禁用的 Dart 的反射，即不能通过 `NSObjectRef` 声明的泛型来初始化对应的类。我维护了个 `Map` 来建立起 `Type` 到初始化调用的映射，并提供注册方法：

```dart
typedef dynamic ConvertorFromPointer(Pointer<Void> ptr);

Map<String, ConvertorFromPointer> _convertorCache = {};

void registerTypeConvertor(String type, ConvertorFromPointer convertor) {
  if (_convertorCache[type] == null) {
    _convertorCache[type] = convertor;
  }
}
```

这样调用 `registerTypeConvertor` 函数就可以很方便地建立起 Native 封装类型到初始化闭包的映射：

```dart
registerTypeConvertor('NSString', (ptr) {
    return NSString.fromPointer(ptr);
});
```

接着实现 `convertFromPointer` 函数，用来调用之前注册的闭包，这样就实现用类名和指针来获取到对应的 Dart 对象了：

```
dynamic convertFromPointer(String type, dynamic arg) {
  Pointer<Void> ptr;
  if (arg is NSObject) {
    ptr = arg.pointer;
  } else if (arg is Pointer) {
    ptr = arg;
  } else {
    return arg;
  }

  if (ptr == nullptr) {
    return arg;
  }

  ConvertorFromPointer convertor = _convertorCache[type];
  if (convertor != null) {
    return convertor(ptr);
  } else if (arg is Pointer) {
    return NSObject.fromPointer(arg);
  }
  return arg;
}
```

最后在 `NSObjectRef` 里添加了个 `syncValue` 方法，将转换好的 Dart 对象赋值给 `value` 属性：

```dart
syncValue() {
    if (_ptr != null && _ptr.value != nullptr) {
        value = convertFromPointer(T.toString(), _ptr.value);
    }
}
```

### 自动生成注册代码

那么多 Native 类型，总不能手写代码一个个去调用 `registerTypeConvertor` 吧。[dart_native](https://github.com/dart-native/dart_native) 提供了 Annotation 用于自动生成这些注册代码，只需要在封装 Native 类的上面加一个 `@native` 即可：

```dart
@native
class NSString extends NSSubclass<String> {
  NSString.fromPointer(Pointer<Void> ptr) : super.fromPointer(ptr) {
    value = perform(SEL('UTF8String'));
  }
}
```

这样只需要在项目目录里运行下面的命令，所有加了 `@native` 的类都会在同一个 dart 文件中生成注册初始化闭包的代码：

```
flutter packages pub run build_runner build --delete-conflicting-outputs
```

建议在运行上面的 `build` 之前先 `clean` 下：

```
flutter packages pub run build_runner clean
```

这是 [dart_native](https://github.com/dart-native/dart_native) 里带的一份自动生成的文件 ``：

```
// GENERATED CODE - DO NOT MODIFY BY HAND

// **************************************************************************
// DartNativeGenerator
// **************************************************************************

import 'package:dart_native/dart_native.dart';
import 'package:dart_native/src/ios/foundation/collection/nsarray.dart';
import 'package:dart_native/src/ios/foundation/collection/nsdictionary.dart';
import 'package:dart_native/src/ios/foundation/collection/nsset.dart';
import 'package:dart_native/src/ios/foundation/nsvalue.dart';
import 'package:dart_native/src/ios/foundation/nsnumber.dart';
import 'package:dart_native/src/ios/foundation/notification.dart';
import 'package:dart_native/src/ios/foundation/nsstring.dart';

void runDartNative() {
  registerTypeConvertor('NSArray', (ptr) {
    return NSArray.fromPointer(ptr);
  });

  registerTypeConvertor('NSDictionary', (ptr) {
    return NSDictionary.fromPointer(ptr);
  });

  registerTypeConvertor('NSSet', (ptr) {
    return NSSet.fromPointer(ptr);
  });

  registerTypeConvertor('NSValue', (ptr) {
    return NSValue.fromPointer(ptr);
  });

  registerTypeConvertor('NSNumber', (ptr) {
    return NSNumber.fromPointer(ptr);
  });

  registerTypeConvertor('NSNotification', (ptr) {
    return NSNotification.fromPointer(ptr);
  });

  registerTypeConvertor('NSString', (ptr) {
    return NSString.fromPointer(ptr);
  });
}
```

考虑到 Flutter 的 plugin 和 App 都可能会用到 [dart_native](https://github.com/dart-native/dart_native)，那么各自的 Native 类就都要生成对应的注册代码。所以这里的入口函数名是根据 package 名生成的，不用担心重名问题。

利用 Annotation 自动生成代码的实现原理就不细说了，网上文章很多，可以参考闲鱼的 [annotation_route](https://github.com/alibaba-flutter/annotation_route)。我只是做了一点微小的优化工作，可能以后也不会单开一片文章来讲。

PS: 自动生成代码这块一开始是给 callback 功能用的，这里写下，只是蹭了蹭篇幅。

### 自动取值

`syncValue()` 方法实现后就比较简单了，下一步就只是找个合理的时机调用的问题了。这只需要在 [dart_native](https://github.com/dart-native/dart_native) 的 `msgSend` 方法中加入对参数类型的判断。如果是 `NSObjectRef` 类型，则需要在调用完 Native 侧的方法后再次调用它的 `syncValue()` 方法。

这里仅截取一段相关的实现代码：

```
// 省略部分逻辑
List<NSObjectRef> outRefArgs = [];
// 省略部分逻辑
if (args != null) {
    // 省略部分逻辑
    for (var i = 0; i < argCount; i++) {
      var arg = args[i];
      if (arg == null) {
        arg = nil;
      } else if (arg is NSObjectRef) {
        outRefArgs.add(arg);
      }
      // 省略部分逻辑
    }
}
outRefArgs.forEach((ref) => ref.syncValue());
```

[dart_native](https://github.com/dart-native/dart_native) 中的`msgSend` 方法顾名思义，虽然表面上是复刻 OC 的实现，实则接口和原理差很多。这里也不详细展开讲，感兴趣的可以直接去看代码。

## 后续

`NSObjectRef` 目前只考虑了对 `NSObject` 及其子类的 out parameter 的封装，理论上对其他基本类型和结构体也是可以支持的，不过使用场景可能没 `NSError **` 那么多，等遇到的时候再搞吧。

内行看门道，外行看热闹。我这么简单的内容都能水出一篇文章，跪求大佬们轻喷，不嘲笑就好。