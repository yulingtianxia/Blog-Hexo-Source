---
title: Flutter 官方终于出手了，DartNative 将何去何从?
date: 2022-12-12 01:46:52
tags:
- Flutter
- DartNative
- Dart
---

2022 年 8 月底，Flutter 发布了 3.3 稳定版，随之发布的 Dart 2.18 宣布[支持 Dart 与 Objective-C 和 Swift 互调](https://flutter.cn/posts/dart-2-18#dart-与-objective-c-和-swift-互调)，而 [Java 与 Java/Kotlin 的互调也在开发中](https://github.com/dart-lang/sdk/issues/49674)。整体思路跟 DartNative 三年前的思路类似，走的也是跨语言 API 直接调用(但官方目前只支持同步)，然后通过工具链生成接口绑定。发布当天就有人给我提 Issue 了：[老哥，考虑一下这个库未来何去何从吧，官方有了](https://github.com/dart-native/dart_native/issues/105)，竟如此『不讲武德』

![](http://yulingtianxia.com/resources/DartNative/20221212-025211@2x.png)

联想到之前 5 月份 Flutter 3.0(Dart 2.17) 发布时官方支持了 Dart Finalizer，跟 DartNative 一年前就支持的 Finalizer 冲突了，看来是『有备而来』啊:

![](http://yulingtianxia.com/resources/DartNative/14035340227.png)

<!--more-->

## ffigen 与 DartNative 

Flutter 官方为了支持 Dart 与 Objective-C 和 Swift 互调，基于 ffigen 工具生成了大量的模板代码，缺点是可读性差，优点是性能好一些；DartNative 基于 Native Runtime 动态调用任意 Objective-C 和 Swift 方法，codegen 只是锦上添花，缺点是首次调用性能有所牺牲（有 cache），优点是动态性强且生成代码可读性高，即便手写代码也很少。

目前二者的实现细节差异也蛮大，比如官方的代码生成是基于 clang 的，比 DartNative codegen 基于的 antlr 更严谨一些，但是使用成本也高很多。官方的 ffigen 目前虽然从 Sample 示例上虽然还没看到对异步调用和回调等能力的支持，不过从整体上官方投入力度还是蛮大的，比我这种利用空闲时间断断续续搞的 sideproject 强多了，后续的能力补齐只是时间问题。

这三年来我曾一直怀疑 DartNative 的设计路线是否正确，现在官方亲自下场了，那说明这个思路还是有前瞻性的。不过在此之前我也一直在反思这个设计的缺点：把抹平各语言 API 的工作交给了 dart 这一层，需要写平台判断的代码，这与主流的 Channel 接口绑定方案使用上差异很大，增加了理解成本和门槛。为了补齐这块短板，我和另一位贡献者 [hui19](https://github.com/hui19) 参考了 JSI 等跨语言 bridge 接口绑定的设计，提出了开发 DartNative Interface（简称 DNI?），并在 2022 年 5 月份 DartNative 的 0.7.x 版本开始支持（比官方 8 月份发布 Dart 2.18 还要早哈哈）。

于是有意思的事情出现了：Channel/ffigen 和 DartNative 正在朝着对方的设计思路演进，但实现上却有很大差别。这里没有吹嘘 Flutter 官方是参考了 DartNative 的意思，毕竟这种只有不到 900 Star 的小项目根本不会受到 Google 官方关注，我相信这只是巧合罢了。而且 ffigen 和 DartNative 都是基于官方的 dart:ffi 实现的，所以 Google 永远都是爸爸。

## 什么是 DartNative Interface

DartNative Interface 实现了跨语言接口之间的绑定和双向调用。相比于 Channel，无需针对 method 写一堆 if-else，也不用把参数挤在一坨序列化和反序列化。DartNative Interface 会将参数列表和返回值自动转换，并支持同步调用和异步协程（这 Channel 它能比吗？它不可以）。iOS/macOS/Android 目前支持的数据类型：num/String/List/Map/Set/NativeByte/NativeObject，支持双向互相调用。iOS/macOS 额外支持 Function/Pointer，支持 Swift。

相比于 DartNative 之前的设计，接口绑定意味着减少了对 native 调用的动态性，但也提供了抹平多端接口差异的标准化方案。继承了 DartNative 强大的类型转换和生命周期管理能力，更加易用。

![](https://github.com/dart-native/dart_native/blob/master/images/dartnative.png?raw=true)

### 使用示例

#### Dart 调用 Native 

Dart 代码：

```dart
final interface = Interface("MyFirstInterface");
// Example for string type.
String helloWorld() {
    return interface.invokeMethodSync('hello', args: ['world']);
}
// Example for num type.
Future<int> sum(int a, int b) {
    return interface.invokeMethod('sum', args: [a, b]);
}
```

对应的 Objective-C 代码：

```objc
@implementation DNInterfaceDemo

// Register interface name.
InterfaceEntry(MyFirstInterface)

// Register method "hello".
InterfaceMethod(hello, myHello:(NSString *)str) {
    return [NSString stringWithFormat:@"hello %@!", str];
}

// Register method "sum".
InterfaceMethod(sum, addA:(int32_t)a withB:(int32_t)b) {
    return @(a + b);
}

@end
```

对应的 Java 代码：

```java
// load libdart_native.so
DartNativePlugin.loadSo();

@InterfaceEntry(name = "MyFirstInterface")
public class InterfaceDemo extends DartNativeInterface {

    @InterfaceMethod(name = "hello")
    public String hello(String str) {
        return "hello " + str;
    }

    @InterfaceMethod(name = "sum")
    public int sum(int a, int b) {
        return a + b;
    }
}
```

#### Native 调用 Dart

Dart 代码：
 
```dart
interface.setMethodCallHandler('totalCost',
        (double unitCost, int count, List list) async {
    return {'totalCost: ${unitCost * count}': list};
});
```

对应的 Objective-C 代码：

```objc
[self invokeMethod:@"totalCost"
         arguments:@[@0.123456789, @10, @[@"testArray"]]
            result:^(id _Nullable result, NSError * _Nullable error) {
    NSLog(@"%@", result);
}];
```

对应的 Java 代码：

```java
invokeMethod("totalCost", new Object[]{0.123456789, 10, Arrays.asList("hello", "world")},
             new DartNativeResult() {
                @Override
                public void onResult(@Nullable Object result) {
                    Map retMap = (Map) result;
                    // do something
                }

                @Override
                public void error(@Nullable String errorMessage) {
                    // do something
                }
              }
);
```

#### Dart Finalizer

Flutter 3.0(Dart 2.17) 开始支持 Dart Finalizer，但是使用 DartNative，只需要 Flutter 2.2(Dart 2.13) 就可以了：

```dart
final foo = Bar(); // A custom instance.
unitTest.addFinalizer(() { // register a finalizer callback.
  print('The instance of \'foo\' has been destroyed!'); // When `foo` is destroyed by GC, this line of code will be executed.
});
``` 

如果想在 Native 监听一个 Dart 对象被销毁，做法是 Dart 从 Native 获取一个对象，并作为另一个想要被监听的 Dart 对象的属性：

```dart
class DartLifecycleObject {
  late final dynamic finalizer;
  DartLifecycleObject() {
    finalizer = interface.invokeMethodSync('finalizer');
  }
}
```

这里以 OC 语言为例，可以返回一个自定义类（DNDartFinalizer）的对象：

```objc
InterfaceMethod(finalizer, finalizerObject) {
    return [[DNDartFinalizer alloc] init];
}
```

当 Dart 对象（DartLifecycleObject）被释放后，DNDartFinalizer 对象也会被释放，所以在 dealloc 方法中可以监听到：

```objc
@implementation DNDartFinalizer
- (void)dealloc {
    NSLog(@"DartLifecycleObject dead!");
}
@end
```

## 何去何从?

DartNative 的最近一次技术分享是在 2021 年底的 GMTC 深圳站：[Flutter 自研通道 DartNative 的探索与实现](https://gmtc.infoq.cn/2021/shenzhen/presentation/4010)。不过那次分享的内容有所保留，不仅没有提到 DartNative 的 Interface 开发计划，连当时已经做了的一些新特性都没有讲，比如支持 Swift 和 macOS、适配 Dart nullsafety、支持 muti-isolates、支持 OC 方法和 block 返回 Future 给 Dart 等。原因是篇幅要精简，况且总得攒点东西留着后续分享不是嘛？

当时我还是 Flutter 专题的出品人，title 长度虽然比不过龙妈，但依然被黑惨了：

![](http://yulingtianxia.com/resources/DartNative/IMG_4853.JPG)

接下来的故事比较有意思，手 Q 后来下掉了 Flutter，业务就缺乏了落地验证场景（iOS App 是否使用 Flutter 并不是机密，扒一下安装包就看得出来，网上也有人统计过各大 App 使用 Flutter 的情况）。考虑到腾讯 Flutter Oteam 未来的发展需要落地到具体业务，于是我把 Oteam 负责人的职位交接给了其他大佬。DartNative 依旧在修修补补，毕竟公司还有其他的 App 在使用，GitHub 也偶尔有提 Issue。下掉 Flutter 后我又接手了小程序，之前有用 Flutter 写的业务如今运行在了小程序上。缘，妙不可言。

最后就是官方宣布 ffigen 支持直接调用 Objective-C/Swift 之后，Java/Kotlin 也在进行中。我估计再给 Flutter 官方一年时间，ffigen 应该可以补齐能力。剩下的就是 Channel 与 DartNative Interface 的差异了，我只能抽业余时间尽量缝缝补补吧，也期待官方能力不断拓展，毕竟总有那么一天的。目前 DartNative 的硬伤是不支持 Windows，如果有 Windows 大佬欢迎共建。我是肝不动了，否则博客能断更两年么（手动狗头）？