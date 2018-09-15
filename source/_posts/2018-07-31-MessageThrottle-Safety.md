---
title: MessageThrottle Safety
date: 2018-07-31 00:50:24
tags:
- Objective-C
---
[MessageThrottle](https://github.com/yulingtianxia/MessageThrottle) 是我开发的Objective-C 节流限频组件，其原理基于 Hook 消息转发流程，在运行时应用了一套节流限频的规则。

新版本再次提升性能的同时，确保了 hook 流程、多线程操作、规则管理的安全性，支持了持久化规则，并对 KVO 等场景进行兼容。[MessageThrottle](https://github.com/yulingtianxia/MessageThrottle) 的代码测试覆盖率在 80% 以上，在编写测试用例的同时也发现了一些安全隐患，有些甚至是业界知名开源库都没有发现和解决的。

本文是关于 [MessageThrottle](https://github.com/yulingtianxia/MessageThrottle) 的第四篇文章。前三篇如下：
- [Objective-C Message Throttle and Debounce](http://yulingtianxia.com/blog/2017/11/05/Objective-C-Message-Throttle-and-Debounce/)
- [Associated Object 与 Dealloc](http://yulingtianxia.com/blog/2017/12/15/Associated-Object-and-Dealloc/)
- [MessageThrottle Performance Benchmark and Optimization](http://yulingtianxia.com/blog/2018/05/31/MessageThrottle-Performance-Benchmark-and-Optimization/)

<!--more-->

主要类的关系如下图，虚线为 `weak` 属性。

![](http://yulingtianxia.com/resources/MessageThrottle1.png)

## 继承链消息转发缺陷

由于是在消息转发流程搞事情，把所有消息都经由一个统一的路由函数 `mt_forwardInvocation` 进行处理。子类和父类不能同时 Hook 同一个方法，原因是如果子类的方法调用了父类方法，那么父类的方法调用走到统一路由函数 `mt_forwardInvocation` 的时候，『调用父类方法』这一信息早已经丢失了，接着会转发给子类的方法实现，从而造成死循环。最后 crash。

解决方法就是在 Hook 之前判断关系链，如果已经有子类或者父类被 Hook 了就报错，无法继续 Hook。

在消息转发流程将所有消息通过统一的路由函数处理并转发这件事的缺陷就是丢失了类的信息，因为全都『统一』到同一个函数处理了，而不是在各自类的内部处理。诸如 Aspects 等业界知名开源库也有此问题。

![](http://yulingtianxia.com/resources/MessageThrottle2.png)

## 兼容 KVO、其他 Hook 框架

首先先了解下 KVO 的原理：当监听类型为 `A` 的对象 `a` 时，会动态创建 `A` 的子类 `NSKVONotifying_A`，并把 `a` 的类型改成 `NSKVONotifying_A`。`NSKVONotifying_A` 会覆写监听的属性村粗方法，以及 `class` 方法，让外部以为 `a` 的类型依然是 `A`。

其余开源框架在 hook 一个对象的时候，也是通过加前缀或后缀动态创建子类，然后覆写相关方法。继承链总有先来后到，这时候问题就来了。

使用 `class` 方法获取到的类型可能是被『篡改过』的类，使用 `objc_getClass()` 函数获取到的才是真正的类。KVO 的做法是在用 `objc_getClass()` 获取到真正的类之后，直接创建带 `NSKVONotifying_` 前缀的子类。

![](http://yulingtianxia.com/resources/MessageThrottle3.png)

如图所示，MessageThrottle 在 hook 一个对象的时候也会动态创建带前缀 `MTSubclassPrefix` 的子类，但是不会像 KVO 那样无脑创建，而是先判断通过 `class` 与 `objc_getClass()` 获取到的类是否相同。如果不同，则说明已经有现成的子类了，直接在 `objc_getClass()` 获取的类中 hook 就行了。这里是借鉴了 Aspects 的做法。

```
Class cls;
Class statedClass = [target class];
Class baseClass = object_getClass(target);
NSString *className = NSStringFromClass(baseClass);
    
if ([className hasPrefix:MTSubclassPrefix]) {
   cls = baseClass;
}
else if (mt_object_isClass(target)) {
   cls = target;
}
else if (statedClass != baseClass) {
   cls = baseClass;
}
else {
   const char *subclassName = [MTSubclassPrefix stringByAppendingString:className].UTF8String;
   Class subclass = objc_getClass(subclassName);
   
   if (subclass == nil) {
       subclass = objc_allocateClassPair(baseClass, subclassName, 0);
       if (subclass == nil) {
           NSLog(@"objc_allocateClassPair failed to allocate class %s.", subclassName);
           return NO;
       }
       mt_hookedGetClass(subclass, statedClass);
       mt_hookedGetClass(object_getClass(subclass), statedClass);
       objc_registerClassPair(subclass);
   }
   object_setClass(target, subclass);
   cls = subclass;
}
```

有来就有回，如果要 remove KVO 或 hook 呢？肯定无法确保各个框架或 KVO add 和 remove『先入后出』的顺序，所以必然要做兼容处理。

在 revert hook 的时候需要判断真实类型的前缀是否是 `MTSubclassPrefix`。如果是，则将实例对象的类型还原回去。最后会判断是否还有其他相同类型的对象也被 hook 了，如果没有，则可以对这个类 revert hook。

添加 KVO 和应用限频规则有先后顺序，移除 KVO 和废除限频规则也有先后顺序，那么可以排列组合出四种结果：

| 初始类为 A | 先添加 KVO |  先应用限频规则 |
| --- | --- | --- |
| **先移除 KVO** | `A` | `A` |
| **先废除限频规则** | `A` | `_MessageThrottle_A` |

PS: `MTSubclassPrefix` 常量内容就是 `_MessageThrottle_`。

因为通过 `MTDealloc` 记录了 hook 的类，所以 revert hook 的时候使用的是当初 hook 的类，而不是当前实例对象真实的类。这主要是针对上面表格中的 『先应用限频规则，先废除限频规则』的情况。在废除规则的时候，真实的类为 `NSKVONotifying__MessageThrottle_A`，而当初应用规则时 hook 的类为 `_MessageThrottle_A`。这里要注意区分处理下。

```
static BOOL mt_recoverMethod(id target, SEL selector, SEL aliasSelector)
{
    Class cls;
    if (mt_object_isClass(target)) {
        cls = target;
        if ([MTEngine.defaultEngine containsSelector:selector onTargetsOfClass:cls]) {
            return NO;
        }
    }
    else {
        MTDealloc *mtDealloc = objc_getAssociatedObject(target, selector);
        // get class when apply rule on target.
        cls = mtDealloc.cls;
        // target current real class name
        NSString *className = NSStringFromClass(object_getClass(target));
        if ([className hasPrefix:MTSubclassPrefix]) {
            Class originalClass = NSClassFromString([className stringByReplacingOccurrencesOfString:MTSubclassPrefix withString:@""]);
            NSCAssert(originalClass != nil, @"Original class must exist");
            if (originalClass) {
                object_setClass(target, originalClass);
            }
        }
        if ([MTEngine.defaultEngine containsSelector:selector onTarget:cls] ||
            [MTEngine.defaultEngine containsSelector:selector onTargetsOfClass:cls]) {
            return NO;
        }
    }
    mt_revertHook(cls, selector, aliasSelector);
    return YES;
}
```

## Revert Hook 的缺陷

前提：子类和父类都实现了同一个方法，并且子类的方法会调用 `super` 的方法。

在 Aspects 中有两种异常场景：

### 先 Hook 父类，然后 revert，接着 Hook 子类。最后调用子类实例对象方法。

结果是只执行了父类的方法，子类的方法没执行到。

原因是当子类没有对应的方法和实现时，`instancesRespondToSelector:` 会判断在继承链上查找是否有父类实现了方法。在 hook 某个方法前如果只通过 `instancesRespondToSelector:` 来判断是否已经添加过 `aliasSelector` 的话，是不够严谨的。父类 hook 后会添加 `aliasSelector` 方法，revert 后这个方法还在。hook 子类的时候因为判断出已经有 `aliasSelector` 方法了就没给子类添加该方法，实际上子类是继承的父类的实现，结果就是只执行了父类的方法实现。

MessageThrottle 的解决方案是通过比较父类和子类的 `Method` 是否相同。如果 `instancesRespondToSelector:` 方法返回 `YES` 并且父类和子类的 `Method` 相同，那么就说明子类的 Method 是来自父类的，仍然需要为子类添加 `aliasSelector` 对应的方法。

```
const char *typeEncoding = method_getTypeEncoding(targetMethod);
Method targetAliasMethod = class_getInstanceMethod(cls, aliasSelector);
Method targetAliasMethodSuper = class_getInstanceMethod(superCls, aliasSelector);
if (![cls instancesRespondToSelector:aliasSelector] || targetAliasMethod == targetAliasMethodSuper) {
  __unused BOOL addedAlias = class_addMethod(cls, aliasSelector, method_getImplementation(targetMethod), typeEncoding);
  NSCAssert(addedAlias, @"Original implementation for %@ is already copied to %@ on %@", NSStringFromSelector(selector), NSStringFromSelector(aliasSelector), cls);
}
class_replaceMethod(cls, selector, mt_getMsgForwardIMP(statedClass, selector), typeEncoding);
```

测试了下 Aspects 的表现，果然是只调用了父类的实现，这是一个很大的漏洞。


### 先 Hook 子类，然后 revert，接着 Hook 父类。最后调用子类实例对象方法。

结果是 crash。

因为 Objective-C Runtime 没有提供移除方法的 API，所以在 revert hook 的时候，无法将 hook 过的 `forwardInvocation:` 方法彻底复原，只能塞入 `NSObject` 的默认实现（IMP）。

1. 当子类的方法调用 `super` 方法时，因为父类的方法被 hook 了（通过替换 `IMP` 为 `_objc_msgForward`），会触发调用 `forwardInvocation:` 方法。但是子类的 `forwardInvocation:` 方法曾经被 Hook 过，所以此时不再是直接调用父类的实现，而是调用子类自己的实现，那么结果就是找不到方法，抛异常。

2. 如果子类没被 hook 过，子类是没有 `forwardInvocation:` 方法的，会调用父类的方法实现。因为父类被 hook 了，所以会走 MessageThrottle 的消息转发流程，所以是不会出问题的。

两者差别在于，调用 `forwardInvocation:` 方法时，已经 Hook 过的类会调用自己的实现，而不会调用父类的实现。

MessageThrottle 解决方案是记录所有 Hook 过的类，在 Hook 其他类之前先判断下是否已经有子类被 Hook 过。如果有，则作降级处理，打 Log 报错，不能继续 Hook。

这个方案虽然不完美，但总比抛异常 crash 好。连 Aspects 也没有注意到这点，亲测会 crash。

## 规则持久化

如果限频规则只存在于内存中，那么其实是很不安全的。

有些场景下限频的周期很长，比如为了减少某条协议请求后台的次数，要求客户端一小时内最多请求一次。如果在一小时内 App 进程杀掉了然后又打开 App，这样就需要限频规则信息能够持久化存储，下次打开 App 读取并应用上次保存的规则。

对于 `target` 为类或元类、`MTPerformModeFirstly` 模式下且限频周期大于 5 秒的规则，MessageThrottle 会自动将其标记为持久化规则。

可以通过设置 `MTRule` 的 `persistent` 属性为 `YES`，来标记规则为需要持久化。对于 `target` 为实例对象的规则持久化是无意义的，因为进程杀掉后，实例对象的生命周期也就结束了，规则也就自动失效了。

`MTRule` 中只有一部分数据能够持久化，一些动态的内容无法持久化，比如队列、block 等。需要注意区分类对象和元类。

可以使用 `savePersistentRules` 方法来保存持久化规则。对于 iOS、macOS 和 tvOS，会在收到 Terminate 通知时自动调用 `savePersistentRules` 方法。


## 线程安全

每个 `MTRule` 都对应着一个递归锁，保证了此规则上的方法调用是线程安全的。
存储所有 target-selector 映射关系的 `MTEngine` 添加和废除规则涉及到对 `NSMapTable` 和 `NSMutableSet` 的操作，使用一个互斥锁来保证 `apply`、`discard` 和 `allRules` 等方法的线程安全。当一个 `MTRule` 在多个线程被频繁 `apply` 和 `discard` 的同时也可能会有这个 `MTRule` 的方法在多个线程频繁调用，所以还需要在 `apply` 和 `discard` 方法里也加一层 `MTRule` 的递归锁。

当然，如果在 hook 或 revert 的过程中调用了方法，但是没有走 MessageThrottle 的转发逻辑的话，还是有可能出现多线程问题。但这样的概率很低，我用下面类似的代码进行测试是 OK 的：

```
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
   for (int i = 0; i < 10000; i ++) {
       dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
           [rule apply];
       });
   }
});
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
   for (int i = 0; i < 10000; i ++) {
       dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
           [self.stub foo:[NSDate date]];
       });
   }
});
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
   for (int i = 0; i < 10000; i ++) {
       dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
           [rule discard];
       });
   }
});
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
   for (int i = 0; i < 10000; i ++) {
       dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
           [self.stub foo:[NSDate date]];
       });
   }
});
```

因为 `MTPerformModeLast` 和 `MTPerformModeDebounce` 都是延时执行模式，所以有可能在延时的过程中，规则已经被废弃了，但是依然会调用到 `[invocation invoke]`，而此时需要注意 `invocation` 的 `selector`。如果规则已经被废弃了，需要使用原始的 `selector`，而不是 `aliasSelector`。
