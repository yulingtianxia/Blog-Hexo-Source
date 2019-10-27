---
title: App 二进制文件重排已经被玩坏了
date: 2019-09-01 00:47:39
tags:
- 瞎折腾
---

『二进制文件重排优化启动速度』本是一项上古 PC 时代就玩过的东东，前一阵子借助某宇宙大厂重新火了一把。不过令我惊讶的是：这么简单个事情竟然搞得如此复杂，而且还声称『开拓性的探索、在没有业界经验可供参考』。。。

~~说真话可能会得罪人，但是我怕过吗？~~ 我怂了，这段掐了。

其实二进制文件重排很简单啊，重点在于生成 order 文件。我基于 Clang SanitizerCoverage 和业界已有的经验，整了个 [AppOrderFiles](https://github.com/yulingtianxia/AppOrderFiles)，一个调用搞定！Enjoy it！

```objc
AppOrderFiles(^(NSString *orderFilePath) {
    NSLog(@"OrderFilePath:%@", orderFilePath);
});
```

<!--more-->

## 苹果官方文档的古老方案

苹果的官方文档很早就给了二进制文件重排的方案：[Improving Locality of Reference](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/CodeFootprint/Articles/ImprovingLocality.html#//apple_ref/doc/uid/20001862-117091-BCIBJEBH)，『早』到甚至被苹果提示这份文档已经年久失修，部分工具和链接失效了。文档的过时不仅体现在还是 GCC 时代，连工具链比如像 `gprof` 也不能用了，不过 Google 也给出了 macOS 上的替代品，有兴趣的可以去研究下。

## Facebook 的 hfsort

需要先用 hf-prod-collect.sh 收集数据，然后塞给 [hfsort](https://github.com/facebook/hhvm/tree/master/hphp/tools/hfsort) 生成 hotfuncs.txt 文件。很好很强大，不过对于编程小白来说有一定的使用成本。

PS：此方案来自于我写了这篇文章后，jmpews 大神丢给我了个链接，受益匪浅。（其实我啥都看不懂）

## 基于 Clang SanitizerCoverage 的方案

在 [Clang 10 documentation](https://clang.llvm.org/docs/SanitizerCoverage.html#tracing-pcs) 中可以看到 LLVM 官方对 SanitizerCoverage 的详细介绍，包含了示例代码。

简单来说 SanitizerCoverage 是 Clang 内置的一个代码覆盖工具。它把一系列以 `__sanitizer_cov_trace_pc_` 为前缀的函数调用插入到用户定义的函数里，借此实现了全局 AOP 的大杀器。其覆盖之广，包含 Swift/Objective-C/C/C++ 等语言，Method/Function/Block 全支持。

开启 SanitizerCoverage 的方法是：在 build settings 里的 "Other C Flags" 中添加 `-fsanitize-coverage=func,trace-pc-guard`。如果含有 Swift 代码的话，还需要在 "Other Swift Flags" 中加入 `-sanitize-coverage=func` 和 `-sanitize=undefined`。所有链接到 App 中的二进制都需要开启 SanitizerCoverage，这样才能完全覆盖到所有调用。

基于 Clang SanitizerCoverage 我写了个工具 AppOrderFiles。CocoaPods 接入，一行调用生成 Order File。啥也不说了，全在 GayHub 里了：https://github.com/yulingtianxia/AppOrderFiles

当然这也不完全是我的原创，对照着 Clang 文档的同时，还参考了 [Improving App Performance with Order Files](https://medium.com/@michael.eisel/improving-app-performance-with-order-files-c7fff549907f) 这篇文章的代码。人家这篇文章虽然早就给出了，不过还是有一些 bug 和优化空间的。

原理就是在 SanitizerCoverage 的回调函数里将地址先收集到队列里，调用 `AppOrderFiles()` 后会停止收集，并将队列中的 PC 地址依次翻译符号，最后去重。反正代码也不多，直接贴核心代码：

```
static OSQueueHead queue = OS_ATOMIC_QUEUE_INIT;

static BOOL collectFinished = NO;

typedef struct {
    void *pc;
    void *next;
} PCNode;

// The guards are [start, stop).
// This function will be called at least once per DSO and may be called
// more than once with the same values of start/stop.
void __sanitizer_cov_trace_pc_guard_init(uint32_t *start,
                                         uint32_t *stop) {
    static uint32_t N;  // Counter for the guards.
    if (start == stop || *start) return;  // Initialize only once.
    printf("INIT: %p %p\n", start, stop);
    for (uint32_t *x = start; x < stop; x++)
        *x = ++N;  // Guards should start from 1.
}

// This callback is inserted by the compiler on every edge in the
// control flow (some optimizations apply).
// Typically, the compiler will emit the code like this:
//    if(*guard)
//      __sanitizer_cov_trace_pc_guard(guard);
// But for large functions it will emit a simple call:
//    __sanitizer_cov_trace_pc_guard(guard);
void __sanitizer_cov_trace_pc_guard(uint32_t *guard) {
    if (!*guard) return;  // Duplicate the guard check.
    if (collectFinished) {
        return;
    }
    // If you set *guard to 0 this code will not be called again for this edge.
    // Now you can get the PC and do whatever you want:
    //   store it somewhere or symbolize it and print right away.
    // The values of `*guard` are as you set them in
    // __sanitizer_cov_trace_pc_guard_init and so you can make them consecutive
    // and use them to dereference an array or a bit vector.
    *guard = 0;
    void *PC = __builtin_return_address(0);
    PCNode *node = malloc(sizeof(PCNode));
    *node = (PCNode){PC, NULL};
    OSAtomicEnqueue(&queue, node, offsetof(PCNode, next));
}
```

## 后记

苹果官方也提供了 PGO 的详细文档，而且操作很简单。不过它跟二进制文件重排还是有区别的，这里不展开讲了。毕竟相对于对业务代码加载优先级的优化来说，PGO 对启动优化性价比没那么高，应该就是高频调用函数内联之类的（这句纯属瞎扯）。

我为啥过了这么久才发此文呢？猜猜原因是啥：

A. 不爱蹭热度
B. 喜欢炒冷饭
C. 忙准备答辩
D. 8 月已经发过文章了，这篇得等到 9 月发，这样才不浪费

碰到不会的题，我一般三短一长选最长。



