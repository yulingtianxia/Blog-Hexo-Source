---
title: Class written in Swift
date: 2018-10-28 01:13:46
tags:
- Swift
- Runtime

---

之前 [TBUIAutoTest](https://github.com/yulingtianxia/TBUIAutoTest) 有个 [issue](https://github.com/yulingtianxia/TBUIAutoTest/issues/7)，我发现原因跟 Swift 有关，在解决问题时顺带稍微研究了下 Swift 编写的类。

<!--more-->

## Swift Class 与 Ivar

纯粹的 Swift 类（没继承自 `NSObject`）在 Runtime 上有很大的坑。虽然 Runtime 的接口都能调用，但因为 `Class` 实现和构成有很大差异，所以需要谨慎对待。比如 Swift 没有 `Ivar` 的概念，相应的 Runtime 接口也只是尽可能的封装，不保证返回的内容正确。Swift 将成员变量和属性统一起来，并统一存储和管理。

其实如果 Swift 类的属性类型是继承自 `NSObject` 的话，还是可以通过 `Ivar` 相关 Runtime 函数获取到内容的。这也是 [TBUIAutoTest](https://github.com/yulingtianxia/TBUIAutoTest) 能够兼容 Swift 的原因。有些 Objective-C 类型在 Swift 有对应的替代，比如 `NSString` 与 `String`。编译器会自动转换接口和类型，但在这些类型上的属性获取 Ivar 依然有些问题。比如使用 [object_getIvar](https://github.com/opensource-apple/objc4/blob/881b875d7aada4cbfc154e022e1297c9526de747/runtime/objc-class.mm#L360) 就会 `BAD_ACCESS`。

## Swift Class Runtime Name

在比较早的 Swift 版本，debug 时我们看到的 Swift 的类名都是一串很长很乱的字符串，其实那是经过 Objective-C Runtime Mangle 后的产物。大概的规则如下：

1. 前缀是 "_Tt"
2. 如果是 Class，还会再加一个 "C"，Protocol 会跟着一个 "P"
3. Module名连着类名，并在每个名字前面标记字符串长度。

如今 Swift 正酝酿着一套新的 Mangle 规则，但要等 Objective-C Runtime 那边实现好新的 Demangle 后才能实施！有兴趣可以看下 [mangleObjCRuntimeName](https://github.com/apple/swift/blob/1982d024a93b3246edecf6bf42530a835ffc479f/lib/AST/ASTMangler.cpp#L419) 函数的实现。

现在 lldb 中打印 Swift 类型更加友好了，但是底层还是会生成一个 Runtime Name。在 `$(SWIFT_MODULE_NAME)-Swift.h` 文件中可以看到 Swift AST 对应 Objective-C 的头文件，里面就有 Swift Runtime Name。Swift 源码里有个 [PrintAsObjC.cpp](https://github.com/apple/swift/blob/master/lib/PrintAsObjC/PrintAsObjC.cpp) 文件，它的作用就是生成 Swift AST 头文件。

举个栗子：使用 `NSClassFromString(@"_TtC19ClassWrittenInSwift11AppDelegate")` 获取到的类是 `ClassWrittenInSwift` Module 中的 `AppDelegate` 类。

## Swift Class Check

如何判断一个类是否用 Swift 写的呢？Runtime 中 `Class` 是有标志位的，只是没对外暴露接口而已。映射到 Runtime 源码中 `Class` 的内存模型，将标志位取出即可，关键代码如下。

```
struct yxy_objc_object {
    yxy_isa_t isa;
};

// class is a Swift class
#define FAST_IS_SWIFT         (1UL<<0)

struct yxy_class_data_bits_t {
    // Values are the FAST_ flags above.
    uintptr_t bits;
    bool getBit(uintptr_t bit)
    {
        return bits & bit;
    }
    bool isSwift() {
        return getBit(FAST_IS_SWIFT);
    }
};

struct yxy_objc_class : yxy_objc_object {
    // Class ISA;
    Class superclass;
    yxy_cache_t cache;             // formerly cache pointer and vtable
    yxy_class_data_bits_t bits;    // class_rw_t * plus custom rr/alloc flags
};

BOOL isWrittenInSwift(Class cls)
{
    if (!cls || !object_isClass(cls)) {
        return NO;
    }
    struct yxy_objc_class *objc_cls = (__bridge struct yxy_objc_class *)cls;
    bool isSwift = objc_cls->bits.isSwift();
    return isSwift;
}
```

实现很简单，封装了下：[ClassWrittenInSwift](https://github.com/yulingtianxia/ClassWrittenInSwift/blob/master/ClassWrittenInSwiftKit/Source/ClassWrittenInSwift.mm)

哎，自己的 Repo 真是越来越水了。

## Swift Class Lazy Property

Swift 类的 `lazy` 属性的存储比较特殊，毕竟是懒加载。它的属性名有个后缀 ".storage"，所以在 Runtime 里获取属性名时要注意，使用时是要过滤掉后缀的。

写了个简单的接口获取 Swift 类中的 `lazy` 属性名列表，代码同样放在 [ClassWrittenInSwift](https://github.com/yulingtianxia/ClassWrittenInSwift/blob/master/ClassWrittenInSwiftKit/Source/ClassWrittenInSwift.mm) 里面了。



