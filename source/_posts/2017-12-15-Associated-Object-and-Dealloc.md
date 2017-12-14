---
title: Associated Object 与 Dealloc
date: 2017-12-15 00:19:21
tags:
- Objective-C
- Runtime
---

我的 Objective-C 消息节流防抖库 [MessageThrottle](https://github.com/yulingtianxia/MessageThrottle) 需要实现一个特性：当 `MTRule` 的 `target` 释放后，自动调用 `MTRule` 的 `discard` 方法。后来使用了业界很早就已有的方案：Associated Object，在这里整理下相关的知识点。

<!-- more -->

## 问题的由来

起初的思路是考虑到 `MTRule` 的 `target` 属性是 `weak` 的，想在其释放之前，也就是 `target` 变成 `nil` 之前调用 `MTRule` 对象的 `discard`  方法。然而 `target` 被释放赋值为 `nil` 的操作并不能通过 KVO 之类来监听，因为其并不是在外部通过 set 方法，这涉及到 `weak` 的实现原理（PS: 可以查看源码中 `weak_clear_no_lock()` 函数的实现）。于是问题转而变成了『在对象销毁前得到通知』。

接着我在 MacRumors 上找到了一篇 2005 年的[贴子](https://forums.macrumors.com/threads/getting-notified-when-an-object-instance-is-deallocated.976309/)。大概内容就是讲通过 KVO 监听 `retainCount` 属性纯属失了智，众所周知 `retainCount` 不能真实反映对象内存管理的情况，即便 `retainCount` 为 `1` 的时候收到了 `release` 消息，也会直接 `dealloc` 掉，并不会变成 `0`。接着又有人说干脆 hook 下 `dealloc` 方法，然后抛通知，但是这样不安全。直到 2008 年 DenNukem 回帖说他直到咋办啦，用 Associated Object！

## 实现原理

当一个对象（Host）释放后，其关联的对象（Associated Object）也会被解除。可以在 Host 对象上添加 Associated Object，策略用 `OBJC_ASSOCIATION_RETAIN`。由于只有 Host 持有了这个 Associated Object，当 Host 释放后 Associated Object 也会被释放。在 Associated Object 的 `dealloc` 方法中告知外界其 Host 对象已经释放。Perfect！

**`dealloc` 方法的调用顺序是从子类到父类直至 `NSObject` 的，`NSObject` 的 `dealloc` 会调用 `object_dispose()` 函数，进而移除 Associated Object。**具体的实现如下:

```
id 
object_dispose(id obj)
{
    if (!obj) return nil;
	// 销毁对象
    objc_destructInstance(obj);    
  // 释放内存
    free(obj);

    return nil;
}

void *objc_destructInstance(id obj) 
{
    if (obj) {
        // Read all of the flags at once for performance.
        bool cxx = obj->hasCxxDtor();
        bool assoc = obj->hasAssociatedObjects();

        // This order is important.
        // C++ 析构
        if (cxx) object_cxxDestruct(obj);
        // 移除 Associated Object
        if (assoc) _object_remove_assocations(obj);
        // ARC 下调用实例变量的 release 方法，移除 weak 引用
        obj->clearDeallocating();
    }

    return obj;
}
```

**也就是说 Associated Object 的 `dealloc` 调用时 Host 已经释放了，无法拿到关于 Host 对象的任何信息了。但这其实对于大部分场景已经足够了，给外界一个 block/delegate callback，甚至是抛通知都 OK 的。**实现起来很简单，代码很少，网上也可以找到一些 [MRC](https://blog.slaunchaman.com/2011/04/11/fun-with-the-objective-c-runtime-run-code-at-deallocation-of-any-object/) 或 [ARC](https://github.com/ChenYilong/CYLDeallocBlockExecutor) 下实现的示例代码。

虽说 Runtime 帮我们自动移除了 Associated Object，但对我这种平常几乎一直写 MRC 代码的人来说还真有点不适应，毕竟脑子里时刻警惕着：每一次 `retain` 都要配套来一次 `release` 或 `autorelease`。

## MessageThrottle 的特殊定制

好，又回归到文章最开头的问题。现在解决了『`MTRule` 的 `target` 释放后，自动调用 `MTRule` 的 `discard` 方法』的问题。但是，要注意到此时 `target` 属性都释放了，于是就无法提供 `discard` 方法正确执行做需要的信息。所以需要在 Associated Object 中加入一些属性来保存一些执行 `discard` 时所需必要的信息。

```
@interface MTDealloc : NSObject
// 这三个属性就是 discardRule:whenTargetDealloc: 方法将要用到的信息。这个方法会把 rule 从 MTEngine 列表中移除，并按需要还原之前的 hook 操作。这些细节不是重点，重点就是调用 discard 需要这仨属性。
@property (nonatomic, weak) MTRule *rule;
@property (nonatomic, copy) NSString *methodDescription;
@property (nonatomic) Class cls;

@end

@implementation MTDealloc

- (void)dealloc
{
// 我只是觉得这样写代码就没警告了，而且还骚
    SEL selector = NSSelectorFromString(@"discardRule:whenTargetDealloc:");
    ((void (*)(id, SEL, MTRule *, MTDealloc *))[MTEngine.defaultEngine methodForSelector:selector])(MTEngine.defaultEngine, selector, self.rule, self);
}

@end
```

然后只需要在 `applyRule` 的时候初始化和配置好 `MTDealloc` 对象，并将其关联到 `target` 上即可：

```
// applyRule 时调用这个方法
static void mt_configureTargetDealloc(MTRule *rule)
{
    if (mt_object_isClass(rule.target)) {
        return;
    }
    else {
        Class cls = object_getClass(rule.target);
        MTDealloc *mtDealloc = objc_getAssociatedObject(rule.target, rule.selector);
        if (!mtDealloc) {
            mtDealloc = [MTDealloc new];
            mtDealloc.rule = rule;
            mtDealloc.methodDescription = mt_methodDescription(rule.target, rule.selector);
            mtDealloc.cls = cls;
            objc_setAssociatedObject(rule.target, rule.selector, mtDealloc, OBJC_ASSOCIATION_RETAIN);
        }
    }
}
```

使用 `rule.selector` 作为 Key 的目的就是让 `target` 对象上的每一个方法都对应一个关联对象，不会搞混。

感兴趣的可以查看 [MessageThrottle](https://github.com/yulingtianxia/MessageThrottle) 的源码，或者阅读我的上一篇文章 [Objective-C Message Throttle and Debounce](http://yulingtianxia.com/blog/2017/11/05/Objective-C-Message-Throttle-and-Debounce/)，更详细地讲述了 Objective-C 消息节流防抖的实现原理。这里只是对其实现自动 `discard` 原理的补充。

## Reference

- [Getting notified when an object instance is deallocated](https://forums.macrumors.com/threads/getting-notified-when-an-object-instance-is-deallocated.976309/)
- [Fun With the Objective-C Runtime: Run Code at Deallocation of Any Object](https://blog.slaunchaman.com/2011/04/11/fun-with-the-objective-c-runtime-run-code-at-deallocation-of-any-object/)
- [Will An Associated Object Be Released Automatically?](https://stackoverflow.com/questions/10842829/will-an-associated-object-be-released-automatically/10843510#10843510)
- [CYLDeallocBlockExecutor](https://github.com/ChenYilong/CYLDeallocBlockExecutor)
- [objc4-723](https://opensource.apple.com/source/objc4/objc4-723/)

