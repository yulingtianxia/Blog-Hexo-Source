---
title: BlockHook with Invocation(1)
date: 2019-07-27 17:14:27
tags:
- Objective-C
- Runtime
- BlockHook
---

[BlockHook](https://github.com/yulingtianxia/BlockHook) 在业界已经率先解决了在**同步**调用场景下对 Objective-C Block 的 AOP 问题。但也有很多场景是需要先调用一段自己的逻辑，然后再**异步延时**执行 Block。

比如从外部跳转到 App 某个页面前需要检查下登录态，如果未登录则需要走完登录流程后才能继续跳转页面，而几乎所有基于 Block callback 的路由组件都没提供路由拦截器的功能。不同的路由组件内部实现不同，想要实现拦截器就需要针对不同的内部实现来修改路由组件源码。

因此我实现了 [BlockHook](https://github.com/yulingtianxia/BlockHook) 的异步拦截功能，所有基于 Block 的路由组件就都有了通用的路由拦截器！

当然，Block 拦截器的应用场景不仅于此。只要是需要『同步改异步执行』 Block 的场景都可以用到。

让子弹再飞一会儿！

<!--more-->

## 使用方法

[BlockHook](https://github.com/yulingtianxia/BlockHook) 拦截器用法很简单，在已有 `BHInvocation` 参数的基础上，增加了一个 `completion` 回调。当拦截器的逻辑异步执行完后，调用 `completion` 即可继续执行原来的 Block。如果拦截器的逻辑是同步的，也依然可以用这个接口，只是没必要罢了，推荐直接用原来的 `block_hookWithMode:usingBlock:` 接口。

```objc
typedef void(^IntercepterCompletion)(void);

/**
 Interceptor for blocks. When your interceptor completed, call `completion` callback.
 You can call `completion` asynchronously!

 @param interceptor You **MUST** call `completion` callback in interceptor, unless you want to cancel invocation.
 @return BHToken instance.
 */
- (BHToken *)block_interceptor:(void (^)(BHInvocation *invocation, IntercepterCompletion completion))interceptor;
```

举个例子，拦截时修改传入的参数，并延迟 0.5 秒再执行 Block：

```objc
NSObject *testArg = [NSObject new];
NSObject *testArg1 = [NSObject new];
    
NSObject *(^testblock)(NSObject *) = ^(NSObject *a) {
    return [NSObject new];
};
    
[testblock block_interceptor:^(BHInvocation *invocation, IntercepterCompletion  _Nonnull completion) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        *(void **)(invocation.args[1]) = (__bridge void *)(testArg1);
        completion();
    });
}];
    
testblock(testArg);
```

## 实现原理

首先想想如果要延迟一个 Objective-C 方法的执行，需要怎么做？

答案是利用消息转发机制，`NSInvocation` 调用 `retainArguments` 将方法执行所需的上下文持有，这样才能保证方法执行时所需的参数、`target` 等不会被释放。

对于 Block 来说，虽然也能通过 `NSInvocation` 来进行调用，但是经过 Hook 过后已经不再适用。因为 `NSInvocation` 的实现机制以及生命周期管理是个黑盒，且无法承载 Hook 相关的信息，需要自己来实现个 `BHInvocation`。

![](http://yulingtianxia.com/resources/BlockHook/BlockInterceptor.png)

### BHInvocation 结构

我之前的 [BlockHook with Struct](http://yulingtianxia.com/blog/2019/04/27/BlockHook-with-Struct/) 这篇文章提到了个技术点：在 x86 架构下，当 Block 返回值是大于 16 Byte 的 `struct` 时，参数列表有些变化：

![](http://yulingtianxia.com/resources/BlockHook/realArgs.png)

为了兼容这种情况，需要两套 `args` 和 `retValue`。一套『真的』用于传给 libffi 调用原始函数指针，另一套『假的』提供给使用方读写参数和返回值。这样使用方无需关心底层特殊逻辑，直接用就行了。

`BHInvocation` 主要结构如下：

![](http://yulingtianxia.com/resources/BlockHook/BHInvocation.png)

PS：`BHInvocation` 与 `NSInvocation` 的场景和用法有些不同，所以实现上也会有差异。`NSInvocation` 没有公开源码，想了解原理的可以看看 mikeash 的实现： [MAInvocation](https://github.com/mikeash/MAInvocation)。但我并没有参考过 mikeash 的源码，因为等我写完了才发现它。。。

### `retainArguments` 实现

`retainArguments` 实现策略：
1. 拷贝 `void **args` 指针数组和返回值指针
2. `retain` 指针内容类型为 Objective-C 对象的参数
3. 如果参数中也有其他 Block 对象，则 `copy` 过来
4. 如果参数中有 C-string，则 `strcpy` 过来


![](http://yulingtianxia.com/resources/BlockHook/retainArguments.png)

需要注意的是这里依然要考虑两套 `args` 和 `retValue` 的问题。代码就不贴了，有兴趣的可以自己去看。

### `block_interceptor` 实现

解决了 `retainArguments` 的实现，一切都好说了。只要基于原有的 `block_hookWithMode:usingBlock:` 接口稍加改装即可：

```
- (BHToken *)block_interceptor:(void (^)(BHInvocation *invocation, IntercepterCompletion completion))interceptor {
    return [self block_hookWithMode:BlockHookModeInstead usingBlock:^(BHInvocation *invocation) {
        if (interceptor) {
            IntercepterCompletion completion = ^() {
                [invocation invokeOriginalBlock];
            };
            interceptor(invocation, completion);
            [invocation retainArguments];
        }
    }];
}
```

## 后记

写了这么多关于 [BlockHook](https://github.com/yulingtianxia/BlockHook) 的文章，我越来越发现自己在苹果爸爸面前所表现出的无知。几乎每一步都要去踩很多坑，看很多源码。而这次是看着苹果爸爸的文档脑补如何实现，业界也没有能参考的先例。

这种感觉犹如自己在黑暗中不断探索，并享受着这种孤独。

标题暗示着，这篇文章可能会有后续的。