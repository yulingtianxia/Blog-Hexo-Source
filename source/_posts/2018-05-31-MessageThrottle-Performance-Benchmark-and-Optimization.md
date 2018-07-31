---
title: MessageThrottle Performance Benchmark and Optimization
date: 2018-05-31 02:01:50
tags:
- Objective-C
---


[MessageThrottle](https://github.com/yulingtianxia/MessageThrottle) 是我开发的Objective-C 节流限频组件，其原理基于 Hook 消息转发流程，所以相比直接调用方法，会有一些性能上的损耗。本篇文章记录了对其性能进行测试的结果，并通过使用 `NSMapTable` 改进存储结构和缓存来对性能进行大幅度的优化。

这是你从未体验过的船新版本。

<!-- more -->

关于 [MessageThrottle](https://github.com/yulingtianxia/MessageThrottle) 最初的实现原理可以参考 [Objective-C Message Throttle and Debounce](http://yulingtianxia.com/blog/2017/11/05/Objective-C-Message-Throttle-and-Debounce/)。

## Benchmark

Xcode 自带的单元测试框架可以很方便的测量一个方法的执行效率，`measureBlock` 里的代码会被执行十次，测试结束后会得到每次执行耗时，以及平均数和方差。

```
- (void)testPerformanceExample {
    // This is an example of a performance test case.
    NSDate *date = [NSDate date];
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
        for (int i = 0; i < 1000; i ++) {
            @autoreleasepool {
                [self.sstub foo:date];
            }
        }
    }];
}
```

性能损耗大多发生在消息转发流程上的处理，为了能够校准基线，需要让每次消息发送都执行。MessageThrottle 1.2.0 刚刚支持了让某些条件下消息永远执行的特性：

```
- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
    self.sstub = [SuperStub new];
    MTRule *rule = [self.sstub mt_limitSelector:@selector(foo:) oncePerDuration:0.01 usingMode:MTPerformModeDebounce];
    rule.alwaysInvokeBlock =  ^(MTRule *rule, NSDate *date) {
        return YES; // 让消息永远都执行
    };
}
```

通过调整 `foo:` 方法的耗时来得到调用不同耗时函数的测试结果。

```
- (void)foo:(NSDate *)arg {
    [NSThread sleepForTimeInterval:0.0001];
}
```

最终得到一组数据，测试机器为 iPhone 8 plus。


| 执行模式\被调用方法耗时 | 0.0001 | 0.001 |
| --- | --- | --- |
| 不使用 MT  | 0.118(baseline) | 1.17(baseline) |
| MT 立即执行 | 0.135(14.4%worse) | 1.33(13.8%worse) |
| MT debounce 0.01s | 0.0281(76.2%better) | 0.0279(97.6%better) |

1. 测试的基准数据为不使用 MessageThottle，直接调用方法。
2. 使用 MessageThottle 后，消息转发流程会带来多余的耗时会导致性能下降，而且被调用方法耗时越少，性能下降得越明显（比较两列数据）。
3. 如果加了消息限频，会忽略掉一部分调用，这样当出现大量频繁调用时，方法真正执行的次数很少，性能反而大大提升了（第三行数据）

## Optimization

通过性能优化，将消息转发流程产生的耗时降低了将近 50%。并加强了线程安全。

| 执行模式\被调用方法耗时 | 0.0001 | 0.001 |
| --- | --- | --- |
| 不使用 MT  | 0.118(baseline) | 1.17(baseline) |
| MT 立即执行 | 0.135(14.4%worse) | 1.33(13.8%worse) |
| 性能优化后 | 0.126(6.88%worse) | 1.25(6.93%worse) |

为了方便管理和查看所有的 `MTRule`，使用了 `MTEngine` 单例进行中心化的管理。获取一个 `MTRule` 之前，需要先用 `target` 和 `selector` 生成一个描述字符串，然后用这个字符串作为 Key 在 `MTEngine` 的字典里查询对应的 `MTRule` 对象。每次应用和废除规则、消息发送时都要频繁从 `MTEngine` 获取 `MTRule` 对象，由此也产生了大量开销。这里的性能瓶颈主要有两点：

1. 生成描述字符串造成的开销。
2. 从 `MTEngine` 加锁的字典获取 `MTRule` 的等待开销。

应用和废除规则的时候，这两点开销并不明显。但当所有应用规则的消息发送都要经过这两步的时候，这俨然成了拥堵的重灾区。当然治理方案也是相对的：

1. 改进 `MTEngine` 中字典的存储结构，使用 `NSMapTable` 替换 `NSMutableDictionary`。因为 `NSMapTable` 支持将任意指针作为 Key 且无需持有，可以将 `target` 作为 Key，Value 为这个 `target` 对应的 `selector` 集合。`MTEngine` 不再持有 `MTRule` 对象，而只是存储了所有应用规则的 `target` 及其 `selector`。而 `MTRule` 对象改为由其 `target` 通过 AssociatedObject 的方式持有，可以很方便通过 `selector` 存取。当 `target` 销毁后，它关联的 `MTRule` 对象也会被销毁，`NSMapTable` 也会自动移除那些键或值为 `nil` 的数据。下面是 `MTEngine` 封装了 `NSMapTable` 字典对应的便捷方法。

	```
	// 初始化
	_targetSELs = [NSMapTable weakToStrongObjectsMapTable];
	
	...
	
	//添加 target-selector 记录
	- (void)addSelector:(SEL)selector onTarget:(id)target
	{
	    if (!target) {
	        return;
	    }
	    NSMutableSet *selectors = [self.targetSELs objectForKey:target];
	    if (!selectors) {
	        selectors = [NSMutableSet set];
	    }
	    [selectors addObject:NSStringFromSelector(selector)];
	    [self.targetSELs setObject:selectors forKey:target];
	}
	//移除 target-selector 记录
	- (void)removeSelector:(SEL)selector onTarget:(id)target
	{
	    if (!target) {
	        return;
	    }
	    NSMutableSet *selectors = [self.targetSELs objectForKey:target];
	    if (!selectors) {
	        selectors = [NSMutableSet set];
	    }
	    [selectors removeObject:NSStringFromSelector(selector)];
	    [self.targetSELs setObject:selectors forKey:target];
	}
	//是否存在 target-selector 记录
	- (BOOL)containsSelector:(SEL)selector onTarget:(id)target
	{
	    return [[self.targetSELs objectForKey:target] containsObject:NSStringFromSelector(selector)];
	}
	//是否存在 target-selector 记录，未指定具体 target，但 target 的类型为 cls 即可
	- (BOOL)containsSelector:(SEL)selector onTargetsOfClass:(Class)cls
	{
	    for (id target in [[self.targetSELs keyEnumerator] allObjects]) {
	        if (!mt_object_isClass(target) &&
	            [target isMemberOfClass:cls] &&
	            [[self.targetSELs objectForKey:target] containsObject:NSStringFromSelector(selector)]) {
	            return YES;
	        }
	    }
	    return NO;
	}
	```

2. 每个 `MTRule` 有自己独立的递归锁，这样避免了在 `forwardInvocation` 里千军万马过独木桥的拥堵，且不妨碍递归调用的场景。存取 `MTEngine` 的字典依然使用普通的互斥锁。这两个锁都使用性能较好的 `pthread_mutex_t` 实现。

	```
    // 初始化递归锁
    pthread_mutexattr_t attr;
    pthread_mutexattr_init(&attr);
    pthread_mutexattr_settype(&attr, PTHREAD_MUTEX_RECURSIVE);
    pthread_mutex_t mutex = mtDealloc.invokeLock;
    pthread_mutex_init(&mutex, &attr);
    objc_setAssociatedObject(rule.target, rule.selector, mtDealloc, OBJC_ASSOCIATION_RETAIN);
        
   ...
   
    // 消息转发时保证线程安全
    static void mt_forwardInvocation(__unsafe_unretained id assignSlf, SEL selector, NSInvocation *invocation)
    {
        SEL originalSelector = invocation.selector;
        SEL fixedOriginalSelector = mt_aliasForSelector(originalSelector);
        if (![assignSlf respondsToSelector:fixedOriginalSelector]) {
            mt_executeOrigForwardInvocation(assignSlf, selector, invocation);
            return;
        }
        MTDealloc *mtDealloc = objc_getAssociatedObject(invocation.target, selector);
        pthread_mutex_t mutex = mtDealloc.invokeLock;
        pthread_mutex_lock(&mutex);
        mt_handleInvocation(invocation, fixedOriginalSelector);
        pthread_mutex_unlock(&mutex);
    }
	```

`MTEngine` 中字典的存储结构的改进不仅提高了性能，还让设计思路更清晰。在添加或废除规则的时候，旧方案需要遍历所有的 `MTRule` 对象，然后通过检查 `target` 和 `selector` 来判断规则是否相互干扰；新方案直接存储了 `target` 和对应的 `selector` 数组，声明如下：

```
NSMapTable<id, NSMutableSet<NSString *> *> *targetSELs;
```

这样的存储方式可以更高效地找到某个对象或类的某个方法是否被限频了，增删规则也更快。

在 Hook 某个方法的时候，会给它生成一个新的方法名，这就又涉及到字符串拼接的开销。解决方案是使用缓存来映射两个 `SEL` 指针，又要用到 `NSMapTable` 大显神威了。这又将节省 6% 左右的 CPU 耗时！需要注意的是创建 `NSMapTable` 时的选项，以及存取时的类型强转：

```
// 初始化 NSMapTable 缓存
_aliasSelectorCache = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSMapTableObjectPointerPersonality valueOptions:NSPointerFunctionsOpaqueMemory | NSMapTableObjectPointerPersonality];

...

// 在方法内部使用缓存优化性能
static SEL mt_aliasForSelector(SEL selector)
{
    pthread_mutex_lock(&alias_selector_mutex);
    SEL aliasSelector = (__bridge void *)[MTEngine.defaultEngine.aliasSelectorCache objectForKey:(__bridge id)(void *)selector];
    if (!aliasSelector) {
        NSString *selectorName = NSStringFromSelector(selector);
        aliasSelector = NSSelectorFromString([NSString stringWithFormat:@"__mt_%@", selectorName]);
        [MTEngine.defaultEngine.aliasSelectorCache setObject:(__bridge id)(void *)aliasSelector forKey:(__bridge id)(void *)selector];
    }
    pthread_mutex_unlock(&alias_selector_mutex);
    return aliasSelector;
}
```

可能有人会担心直接缓存 `SEL` 指针会不会命中率很低。因为所有名字相同的方法都拥有同一个唯一的 `SEL`，所以可以很快速地用直接指针地址判等。可以参考[这里](https://stackoverflow.com/questions/11051528/understanding-uniqueness-of-selectors-in-objective-c?utm_medium=organic&utm_source=google_rich_qa&utm_campaign=google_rich_qa)。

## 总结

更新 [MessageThrottle](https://github.com/yulingtianxia/MessageThrottle) 到最新版即可获取到更快更强更安全的 Objective 消息节流限频功能，一行代码搞定频繁调用的问题。

新版本在废除消息的时候，也增强了对合法性和安全性的检查。（说白了就是改 bug）

理论上我的另一个组件 [BlockTracker](https://github.com/yulingtianxia/BlockTracker) 也可以按照本文的方案优化性能了，嘿嘿，有时间搞下。


