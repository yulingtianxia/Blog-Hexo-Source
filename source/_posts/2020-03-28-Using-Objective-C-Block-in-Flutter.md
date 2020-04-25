---
title: 在 Flutter 中玩转 Objective-C Block
date: 2020-03-28 15:57:55
tags:
- Dart
- Flutter
- Objective-C
---

[dart_native](https://github.com/dart-native/dart_native) 作为一条比 Channel 性能更高开发成本更低的超级通道，通过 C++ 调用 Native 的 API，深入底层且考虑全面。很多 Objective-C 接口的参数和返回值是 Block，所以这就需要支持用 Dart 语言创建和调用 Objective-C Block。

<!--more-->

## Dart 调用 Objective-C 带 Block 的 API

Dart 语言支持协程，这样就无需传递闭包来作为异步调用的回调。而 Objective-C 大量 API 都使用 Block 作为回调，当 Dart 调用这类异步 API 的时候，就需要 Dart 侧创建 Block 并传递给 Objective-C。

Dart 语言中的 Function 可以当做闭包，可以实现下面这样的效果：

```dart
stub.fooBlock((NSObject a) {
    print('hello block! ${a.toString()}');
    return a;
});
```

而对应的 Objective-C 接口如下：

```objc
typedef NSObject *(^BarBlock)(NSObject *a);
- (void)fooBlock:(BarBlock)block;
```

下面就讲下 [dart_native](https://github.com/dart-native/dart_native) 是如何做到把 Dart Function 当做 Block 传给 Objective-C 的。

### 函数签名

首先要确保的是 Dart Function 的签名跟 Objective-C Block 是一致的，这样二者才能转换。在 Dart 里一切皆为对象，Function 也不例外。那么拿到 Function 的 `runtimeType` 即可，然后解析其内容。不过 `runtimeType` 的内容都是 Dart 类名，如何能与 Objective-C 类型对应上呢？[dart_native](https://github.com/dart-native/dart_native) 的策略是提供与 Native 同名的类，这样使用这些同名类定义 Dart Function，就可以把函数签名映射到 Native 上了。

列举一些 Dart 声明的基础类型：

```dart
class unsigned_char = char with _ToAlias;
class short = NativeBox<int> with _ToAlias;
class unsigned_short = NativeBox<int> with _ToAlias;
class unsigned_int = NativeBox<int> with _ToAlias;
class long = NativeBox<int> with _ToAlias;
class unsigned_long = NativeBox<int> with _ToAlias;
class long_long = NativeBox<int> with _ToAlias;
class unsigned_long_long = NativeBox<int> with _ToAlias;
class size_t = NativeBox<int> with _ToAlias;
class NSInteger = NativeBox<int> with _ToAlias;
class NSUInteger = NativeBox<int> with _ToAlias;
class float = NativeBox<double> with _ToAlias;
class CGFloat = NativeBox<double> with _ToAlias;
class CString = NativeBox<String> with _ToAlias;
```

### 动态创建 Block

有了函数签名，如何构造对应的 Block 对象呢？首先要知道 Block 是什么，而这是就又个老生常谈的话题了。我十分建议你先了解下 [BlockHook](https://github.com/yulingtianxia/BlockHook) 及其相关文章，这样会对理解这部分内容有很大帮助。

废话不多说，上硬核：

```objc
- (void)initBlock {
    const char *typeString = self.typeString.UTF8String;
    int32_t flags = (BLOCK_HAS_COPY_DISPOSE | BLOCK_HAS_SIGNATURE);
    // Struct return value on x86(32&64) MUST be put into pointer.(On heap)
    if (typeString[0] == '{' && (TARGET_CPU_X86 || TARGET_CPU_X86_64)) {
        flags |= BLOCK_HAS_STRET;
    }
    // Check block encoding types valid.
    NSUInteger numberOfArguments = [self _prepCIF:&_cif withEncodeString:typeString flags:flags];
    if (numberOfArguments == -1) { // Unknown encode.
        return;
    }
    self.numberOfArguments = numberOfArguments;
    if (self.hasStret) {
        self.numberOfArguments--;
    }
    
    _closure = ffi_closure_alloc(sizeof(ffi_closure), (void **)&_blockIMP);
    
    ffi_status status = ffi_prep_closure_loc(_closure, &_cif, DNFFIBlockClosureFunc, (__bridge void *)(self), _blockIMP);
    if (status != FFI_OK) {
        NSLog(@"ffi_prep_closure returned %d", (int)status);
        abort();
    }

    struct _DNBlockDescriptor descriptor = {
        0,
        sizeof(struct _DNBlock),
        (void (*)(void *dst, const void *src))copy_helper,
        (void (*)(const void *src))dispose_helper,
        typeString
    };
    
    _descriptor = malloc(sizeof(struct _DNBlockDescriptor));
    memcpy(_descriptor, &descriptor, sizeof(struct _DNBlockDescriptor));

    struct _DNBlock simulateBlock = {
        &_NSConcreteStackBlock,
        flags,
        0,
        _blockIMP,
        _descriptor,
        (__bridge void*)self
    };
    _signature = [NSMethodSignature signatureWithObjCTypes:typeString];
    _block = (__bridge id)Block_copy(&simulateBlock);
    SEL selector = NSSelectorFromString(@"autorelease");
    #pragma clang diagnostic push
    #pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    _block = [_block performSelector:selector];
    #pragma clang diagnostic pop
}
```

简单来说，动态创建 Block 的流程封装在了一个 Wrapper 类中，步骤如下：

1. 用 libffi 动态创建相同签名的函数，
2. 准备好创建 Block 需要的 `flag`、`description`、`signature` 和 `wrapper` 对象等
3. 根据 Block 的内存模型创建对应的结构体（栈上）
4. 把 Block 对象 `copy` 到堆上，并发送 `autorelease` 消息

这上面每一步其实都不简单，单独拆出来都能写一段。但因为 [bang 大佬已经写过文章](http://blog.cnbang.net/tech/3332/)介绍过了，我这里就不再赘述了。我只是站在巨人的肩膀上，增加了一些改进和对 Dart 的适配（如支持结构体、`x86` 兼容等）。很惭愧，就做了一点微小的工作。

### 映射 Block 和 Dart Function

Block 对象创建好了，需要跟 Dart Function 映射起来，然后当 Block 被执行的时候才会调用到对应的 Dart 逻辑。

关于回调这块，我在 Dart 侧维护一个 `Map` 来管理 Native 到 Dart 的回调映射。基本思路是，Key 为 Native 对象的地址，Value 为 Dart 侧的 Block 类。

Dart 版的 `Block` 类构造方法里会将映射建立起来：

```dart
factory Block(Function function) {
    List<String> dartTypes = _dartTypeStringForFunction(function);
    List<String> nativeTypes = _nativeTypeStringForDart(dartTypes);
    Pointer<Utf8> typeStringPtr = Utf8.toUtf8(nativeTypes.join(', '));
    NSObject blockWrapper =
        NSObject.fromPointer(blockCreate(typeStringPtr, _callbackPtr));
    int blockAddr = blockWrapper.perform(SEL('blockAddress'));
    Block result = Block._internal(Pointer.fromAddress(blockAddr));
    free(typeStringPtr);
    result.types = dartTypes;
    result._wrapper = blockWrapper;
    result.function = function;
    _blockForAddress[result.pointer.address] = result;
    return result;
}
```

在 `Block` 类的 `dealloc` 方法里会移除映射，防止造成 Dart 版的『野指针』。

```dart
dealloc() {
    _wrapper = null;
    _blockForAddress.remove(pointer.address);
    super.dealloc();
}
```

## Dart 调用 Objective-C 返回的 Block

结合对 Block 的理解以及实践过 Dart 调用 OC 方法的经验，很容易在 Dart 版的 `Block` 中实现个 `invoke` 方法：

```dart
dynamic invoke([List args]) {
    if (pointer == nullptr) {
      return null;
    }
    Pointer<Utf8> typesEncodingsPtr = _blockTypeEncodeString(pointer);
    Pointer<Int32> countPtr = allocate<Int32>();
    Pointer<Pointer<Utf8>> typesPtrPtr =
        nativeTypesEncoding(typesEncodingsPtr, countPtr, 0);
    int count = countPtr.value;
    free(countPtr);
    // typesPtrPtr contains return type and block itself.
    if (count != (args?.length ?? 0) + 2) {
      throw 'Args Count NOT match';
    }

    Pointer<Pointer<Void>> argsPtrPtr = nullptr.cast();
    if (args != null) {
      argsPtrPtr = allocate<Pointer<Void>>(count: args.length);
      for (var i = 0; i < args.length; i++) {
        var arg = args[i];
        if (arg == null) {
          arg = nil;
        }
        String encoding = Utf8.fromUtf8(typesPtrPtr.elementAt(i + 2).value);
        storeValueToPointer(arg, argsPtrPtr.elementAt(i), encoding);
      }
    }
    Pointer<Void> resultPtr = blockInvoke(pointer, argsPtrPtr);
    if (argsPtrPtr != nullptr.cast()) {
      free(argsPtrPtr);
    }
    String encoding = Utf8.fromUtf8(typesPtrPtr.elementAt(0).value);
    dynamic result = loadValueFromPointer(resultPtr, encoding);
    return result;
  }
}
```

简单来说上面的实现做了如下几步：

1. 获取 Block 的函数签名
2. 校验 Dart 测传入的参数列表是否符合函数签名
3. 将 Dart 参数转为 Native 对应的类型，写入堆中
4. 调用 C 函数 `blockInvoke`，将 Block 指针和参数列表二级指针传过去
5. 释放二级指针（其指向的对象类型和堆上的结构体会自动释放）
6. 将 `blockInvoke` 返回的指针内容转为 Dart 对象

## 后续

关于 Block 这块其实还有很多技术细节没有叙述完整，包括 `copy` 方法的实现，回调映射的细节，类型自动转换的细节等。因为篇幅原因，感兴趣的可以直接看源码：https://github.com/dart-native/dart_native

其实我期望的是使用 Dart 的协程来完成处理异步回调，这样更现代更优雅。日后会基于此方案再次封装上层接口，支持协程。

[dart_native](https://github.com/dart-native/dart_native) 作为一条深入底层且考虑全面的 Dart 到 Native 超级通道，未来还要做的事情还有很多。