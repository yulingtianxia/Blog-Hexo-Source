---
title: DartNative Struct
date: 2020-02-24 00:15:12
tags:
- Dart
- Flutter
---

[dart_native](https://github.com/dart-native/dart_native) 基于 Dart FFI，通过 C++ 调用 Native 的 API。很多 Objective-C 接口的参数和返回值都有 Struct，比如最常见的 `CGSize` 等。这就需要能够用 Dart 语言表示 Struct 类型，尤其是 Cocoa 内建的这些常用结构体。

<!--more-->

结构体的存储需要一段连续的内存，可以是栈也可以是堆上。而 Dart 与 Objective-C 跨语言调用时只能传递一个指针大小的数据，这就使得 [DartNative](https://github.com/dart-native/dart_native) 的结构体需要在堆上创建，并通过指针传递。

Dart FFI 虽然提供了构建结构体的 API，但是目前还不支持[结构体的嵌套](https://github.com/dart-lang/sdk/issues/37271)，所以像 `CGRect` 包含 `CGPoint` 和 `CGSize` 这种结构，还不能通过嵌套的方式复用实现代码。此外，`CGFloat` 和 `NSUInteger` 也可能有 32bit 和 64bit 两种情况，Dart 只能在运行时去区分该用哪种。这些原因导致目前使用 Dart FFI 构建 Struct 时不得不采用排列组合式的笨方法。

下面就以实现一个 `CGSize` 为例，看看这种方式有多笨。

首先 `CGSize` 是由两个 `CGFloat` 组成，而 `CGFloat` 又有可能是 32bit 或 64bit。所以现需要分别实现这两种情况，也就是 `CGFloat32x2` 和 `CGFloat64x2`，分别表示两个 `float` 和两个 `double`：

```dart
class CGFloat32x2 extends Struct {
  @Float()
  double a;
  @Float()
  double b;

  factory CGFloat32x2(double a, double b) => allocate<CGFloat32x2>().ref
    ..a = a
    ..b = b;

  factory CGFloat32x2.fromPointer(Pointer<CGFloat32x2> ptr) {
    return ptr.ref;
  }
}

class CGFloat64x2 extends Struct {
  @Double()
  double a;
  @Double()
  double b;

  factory CGFloat64x2(double a, double b) => allocate<CGFloat64x2>().ref
    ..a = a
    ..b = b;

  factory CGFloat64x2.fromPointer(Pointer<CGFloat64x2> ptr) {
    return ptr.ref;
  }
}
```

`CGFloat64x2` 初始化时会在堆上开辟内存，并填充数据。而使用 `fromPointer` 类方法初始化时则是传入一个指针，并将指针指向的内存按照内存模型映射到 Dart 这边的属性。而从 Native 那边传过来的指针肯定也是指向由 [DartNative](https://github.com/dart-native/dart_native) 开辟的内存，所以使用这两种初始化方法后，[DartNative](https://github.com/dart-native/dart_native) 都需要负责释放内存。

我也很想把这一长串代码合并下，可惜目前 Dart FFI 的语法还很弱，Dart 的类型安全编译检查也使得一些事情做不了。考虑到 Flutter 禁用了反射，所以只能按部就班写一坨一坨长得很像但又不完全一样的代码了。

基于两种情况之上再封装一层 `CGFloatx2Wrapper`，内部判断该用哪种。由于 Dart 不支持宏，无法在编译器静态判断是否是 64bit，所以封装了个 `LP64` 在运行时判断。

```dart
class CGFloatx2Wrapper extends NativeStruct {
  CGFloat32x2 _value32;
  CGFloat64x2 _value64;

  CGFloatx2Wrapper(double a, double b) {
    if (LP64) {
      _value64 = CGFloat64x2(a, b);
    } else {
      _value32 = CGFloat32x2(a, b);
    }
    wrapper;
  }

  Pointer get addressOf => LP64 ? _value64.addressOf : _value32.addressOf;

  CGFloatx2Wrapper.fromPointer(Pointer<Void> ptr) {
    if (LP64) {
      _value64 = CGFloat64x2.fromPointer(ptr.cast());
    } else {
      _value32 = CGFloat32x2.fromPointer(ptr.cast());
    }
  }
}
```

`CGFloatx2Wrapper` 继承了 `NativeStruct`，后者内部维护了一个 `PointerWrapper` 来实现 Struct 堆内存的自动释放。`PointerWrapper` 本质上只是包装了下指针，并在自己释放的时候 `free` 指针指向的内存。`NativeStruct` 提供 `retain` 和 `release` 方法，并在释放时回调 `dealloc` 接口，使得 Struct 在 Dart 上可以像对象类型一样使用。

```dart
abstract class NativeStruct {
  Pointer get addressOf;

  PointerWrapper _wrapper;
  PointerWrapper get wrapper {
    if (_wrapper == null) {
      _wrapper = PointerWrapper(dealloc);
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

  dealloc() {}
}
```

继续回到 `CGFloatx2Wrapper`，这层封装内部维护两个属性 `a` 和 `b` 及其存取方法，只是简单的透传而已:

```dart
  double get a => LP64 ? _value64.a : _value32.a;
  set a(double a) {
    if (LP64) {
      _value64.a = a;
    } else {
      _value32.a = a;
    }
  }

  double get b => LP64 ? _value64.b : _value32.b;
  set b(double b) {
    if (LP64) {
      _value64.b = b;
    } else {
      _value32.b = b;
    }
  }
```

`CGFloatx2Wrapper` 也通过重写操作符实现了 Struct 判等的功能，这样就不需要使用 Objective-C 里繁琐的 `CGSizeEqualToSize` 等函数了：

```dart
  bool operator ==(other) {
    if (other == null) return false;
    return a == other.a && b == other.b;
  }

  @override
  int get hashCode => a.hashCode ^ b.hashCode;
```

真不敢相信如此难堪的代码出自我之手，只能说各位大佬们有懂 Dart 的可以指点下小弟有没有更优雅的方式。最后基于这个 `CGFloatx2Wrapper` 就可以封装出 `CGSize`,`CGPoint`,`CGVector` 和 `UIOffset` 等 Struct 了，它们均由两个 `CGFloat` 组成。也就只有这一步复用代码了。

```dart
class CGSize extends CGFloatx2Wrapper {
  double get width => a;
  set width(double width) {
    a = width;
  }

  double get height => b;
  set height(double height) {
    b = height;
  }

  CGSize(double width, double height) : super(width, height);
  CGSize.fromPointer(Pointer<Void> ptr) : super.fromPointer(ptr);
}
```

还有其他类型需要封装，比如 `CGRect` 由 4 个 `CGFloat` 组成，且由于 Dart FFI 不支持 Struct 嵌套，所以无法复用 `CGPoint` 和 `CGSize` 这两个类的代码，只能重复上面的过程重起炉灶。就这样最终将 Objective-C Cocoa API 内建的 Struct 基本都包装成了 Dart 里的类。目前支持的类型有：`CGSize`,`CGPoint`,`CGVector`,`CGRect`,`NSRange`,`UIOffset`,`UIEdgeInsets`,`NSDirectionalEdgeInsets` 和 `CGAffineTransform`。
