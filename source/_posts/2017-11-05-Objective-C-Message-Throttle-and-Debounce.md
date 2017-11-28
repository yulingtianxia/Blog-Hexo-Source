---
title: Objective-C Message Throttle and Debounce
date: 2017-11-05 00:39:44
tags:
- Objective-C
- Runtime
- Message Forwarding
---

在实际项目中经常会遇到因方法调用频繁而导致的 UI 闪动问题和性能问题，这时用某种策略需要控制调用频率，以达到节流和防抖的效果。[MessageThrottle](https://github.com/yulingtianxia/MessageThrottle) 是我实现的一个 Objective-C 消息节流和防抖的轻量级工具库，使用便捷且业务无关。

<!-- more -->

读懂本文的前提是对 [Objective-C Runtime](http://yulingtianxia.com/blog/2014/11/05/objective-c-runtime/) 和 [Objective-C 消息发送与转发机制原理](http://yulingtianxia.com/blog/2016/06/15/Objective-C-Message-Sending-and-Forwarding/)有一定了解。

## 概念

函数节流（throttle）是一个很基础的概念，常常跟函数防抖（debounce）作比较。在处理连续事件时比较常用，可以通过[这个 Demo](http://demo.nimius.net/debounce_throttle/) 感受下二者区别。在 JS 中有较多的实现和应用案例，可以查看[这篇文章](https://blog.coding.net/blog/the-difference-between-throttle-and-debounce-in-underscorejs) 更直接地了解下。

虽然在开发 iOS 和 macOS 的时候不用过多关心连续事件的采样问题，但有时也需要避免某个方法被频繁调用。比如一个很复杂的页面可能会频繁请求网络，每次回包都需更新界面，这时就需要防抖，控制刷新频率。

在 Objective-C 中，方法调用其实就是消息发送，所以我改了个名字，叫消息节流和防抖。

## 使用姿势

假如我创建了一个 `Stub` 类的实例 `s`，我想限制它调用 `foo:` 方法的频率。先要创建并配置一个 `MTRule`，并将规则应用到 `MTEngine` 单例中：

```
Stub *s = [Stub new];
MTRule *rule = [MTRule new];
rule.target = s; // You can also assign `Stub.class` or `mt_metaClass(Stub.class)`
rule.selector = @selector(foo:);
rule.durationThreshold = 0.01;
[MTEngine.defaultEngine applyRule:rule]; // or use `[rule apply]`
```

`target` 可以是一个实例对象，也可以是一个类或元类。这样可以更灵活地控制限制策略，既可以只控制某个对象的消息发送频率，也可以控制某个类的实例方法和类方法的频率。当然，规则的 `target` 为实例对象的优先级比类更高，也不会发生冲突。

当然还有更简单的用法，跟上面那段代码作用相同：

```
[s limitSelector:@selector(foo:) oncePerDuration:0.01]; // returns MTRule instance
```

无论是节流还是防抖，都需要设定一个时间 `durationThreshold` 阈值来限制频率，都意味着方法在最后会延迟调用。`MTRule` 默认的模式是 `MTPerformModeDebounce`，也就是防抖模式，需要等消息不再连续频繁发送后才执行。`MTPerformModeLast` 和 `MTPerformModeFirstly` 对应着节流模式，也就是控制一定时间内只执行一次。区别在于前者执行的是这段时间内最后发送的消息，后者执行第一次发送的消息。

比如我想要控制界面上某个 Label 内容的更新频率，给用户更好的体验，这时候很适合使用 `MTPerformModeLast` 模式：

```
rule.mode = MTPerformModeLast;
```

当然所有规则都是可以动态调整的，也就是在应用规则以后，依然可以改变 `MTRule` 对象中各项配置，并会在下次消息发送时生效。如果调皮地将 `durationThreshold` 改成非正数，那么等同于立即执行方法，不会限制频率。

当使用 `MTPerformModeDebounce` 和 `MTPerformModeLast` 模式的时候，因为执行消息会有延迟，可以指定执行消息的队列 `messageQueue`，默认为主队列。

当想要废除某条规则时，使用一行代码即可：

```
[MTEngine.defaultEngine discardRule:rule]; // or use `[rule discard]`
```

应用和废除规则都是线程安全的。

## 实现原理

参照 [Aspects](https://github.com/steipete/Aspects) 和 [JSPatch](https://github.com/bang590/JSPatch) 中 Hook 的原理，将限制频率逻辑嵌入消息转发流程中：

1. 给类添加一个新的方法 `fixed_selector`，对应实现为 `rule.selector` 的 `IMP`。
2. 利用 [Objective-C runtime 消息转发机制](http://yulingtianxia.com/blog/2016/06/15/Objective-C-Message-Sending-and-Forwarding/)，将 `rule.selector` 对应的 `IMP` 改成 `_objc_msgForward` 从而触发调用 `forwardInvocation:` 方法。
3. 将 `forwardInvocation:` 的实现替换为自己实现的 `IMP`，并在自己实现的逻辑中将 `invocation.selector` 设为 `fixed_selector`。并限制 `[invocation invoke]` 的调用频率。

这种做法的缺陷是如果同时 hook 了基类和子类的同一个方法，且子类调用了基类的方法，就会导致循环调用。因为调用 `super` 方法时，传入的 `target` 还是 `self` 对象，导致调用了子类的方法。好在这里并不允许同时 hook 一条继承链上的两个类，因为子类和基类限制频率的规则会相互干扰，导致不易发现的 bug。

[MessageThrottle](https://github.com/yulingtianxia/MessageThrottle) 从设计上使用 `MTEngine` 单例这种中心化的的方式来管理所有规则。Aspects 是将 hook 的上下文插入到对应的 `target` 中，这样的好处是需要暴露的接口较少。而 [MessageThrottle](https://github.com/yulingtianxia/MessageThrottle) 需要提供当前所有的规则给使用方。因为方法调用频率的限制会影响其上游代码和下游代码的运行频率，所以中心化管理的做法很有必要。

由于配置规则的内容较多，如果使用逐个传参的方式，方法名会很长。所以这里用 `MTRule` 类封装了规则的上下文，并使用 `applyRule:` 和 `discardRule:` 方法应用和废除规则。

### 管理 `MTRule`

`MTEngine` 内部使用键值对存取 `MTRule`，这里使用 `target` 和 `selector` 的组合值作为 key。这里只要保证唯一性即可区分不同的规则，格式不固定：

```
static NSString * mt_methodDescription(id target, SEL selector)
{
    NSString *selectorName = NSStringFromSelector(selector);
    if (object_isClass(target)) {
        NSString *className = NSStringFromClass(target);
        return [NSString stringWithFormat:@"%@ [%@ %@]", class_isMetaClass(target) ? @"+" : @"-", className, selectorName];
    }
    else {
        return [NSString stringWithFormat:@"[%p %@]", target, selectorName];
    }
}
```

在应用和废除规则的时候，需要检查规则合法性。这里只是简单检查下库中涉及的类和方法，一些内存管理和runtime 的方法并没有做限制，毕竟用户想作死我也管不着：

```
static BOOL mt_checkRuleValid(MTRule *rule)
{
    if (rule.target && rule.selector && rule.durationThreshold > 0) {
        NSString *selectorName = NSStringFromSelector(rule.selector);
        if ([selectorName isEqualToString:@"forwardInvocation:"]) {
            return NO;
        }
        Class cls;
        if (object_isClass(rule.target)) {
            cls = rule.target;
        }
        else {
            cls = object_getClass(rule.target);
        }
        NSString *className = NSStringFromClass(cls);
        if ([className isEqualToString:@"MTRule"] || [className isEqualToString:@"MTEngine"]) {
            return NO;
        }
        return YES;
    }
    return NO;
}
```


### 处理 `NSInvocation`

在进入到消息转发流程调用 `forwardInvocation:` 方法时会进入到自定义的处理逻辑中，然后决定是否执行 `[invocation invoke]`。之前已经将原始 `selector` 的 IMP 替换成了 `fixedSelector`，所以调用 `[invocation invoke]` 之前需要调用 `invocation.selector = fixedSelector`。

下面的函数就是处理 `NSInvocation` 对象的逻辑。先用 `target` 和 `selector` 获取 `MTRule` 对象，进而根据不同的 `mode` 采取不同的策略。如果 `durationThreshold` 非正数就立即执行方法。

```
static void mt_handleInvocation(NSInvocation *invocation, SEL fixedSelector)
{
    NSString *methodDescriptionForInstance = mt_methodDescription(invocation.target, invocation.selector);
    NSString *methodDescriptionForClass = mt_methodDescription(object_getClass(invocation.target), invocation.selector);
    
    MTRule *rule = MTEngine.defaultEngine.rules[methodDescriptionForInstance];
    if (!rule) {
        rule = MTEngine.defaultEngine.rules[methodDescriptionForClass];
    }
    
    if (rule.durationThreshold <= 0) {
        [invocation setSelector:fixedSelector];
        [invocation invoke];
        return;
    }
    
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];

    switch (rule.mode) {
        case MTPerformModeFirstly:
            ...
            break;
        case MTPerformModeLast:
            ...
            break;
        case MTPerformModeDebounce:
            ...
            break;
    }
}
```

上面代码省略了不同 `mode` 的处理逻辑，下面会逐个讲解。


#### `MTPerformModeFirstly`

```
MTModePerformFirstly:
start                                                                end
|                           durationThreshold                          |
@-------------------------@----------@---------------@---------------->>
|                         |          |               |          
perform immediately       ignore     ignore          ignore     
```

最简单粗暴的实现方式，忽略第一次发送消息之后 `durationThreshold` 时间段内的所有消息。

```
if (now - rule.lastTimeRequest > rule.durationThreshold) {
	rule.lastTimeRequest = now;
	invocation.selector = fixedSelector;
	[invocation invoke];
	rule.lastInvocation = nil;
}
```

#### `MTPerformModeLast`

```
MTModePerformLast:
start                                                                end
|                           durationThreshold                          |
@-------------------------@----------@---------------@---------------->>
|                         |          |               |          
ignore                    ignore     ignore          will perform at end
```

在 `durationThreshold` 时间内不断更新 `lastInvocation` 的值，并在达到阈值 `durationThreshold` 后执行 `[lastInvocation invoke]`。这样保证了执行的是最后一次发送的消息。需要注意的是，`NSInvocation` 对象默认不会持有参数，在异步延迟执行 `invoke` 的时候参数可能已经被释放了，进而野指针 crash。所以需要调用 `retainArguments` 方法提前持有参数，防止之后被释放掉。如果实际传入的参数与参数类型不符，可能导致 `retainArguments` 方法 crash。我曾想过将参数列表保存到一个 `NSArray` 里，然后放到 `MTRule` 中，这样可以对参数类型做判断，避免 crash，也顺便持有了参数列表。但发现需要覆盖的类型太多，工作量和风险更多。我把这个半成品代码放在了 GitHubGist 上: [ConvertInvocationArguments.m](https://gist.github.com/yulingtianxia/1518fc7604ed65aa4ca98abdeee974e1)

```
if (now - rule.lastTimeRequest > rule.durationThreshold) {
	rule.lastTimeRequest = now;
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(rule.durationThreshold * NSEC_PER_SEC)), rule.messageQueue, ^{
		[rule.lastInvocation invoke];
		rule.lastInvocation = nil;
	});
}
else {
	invocation.selector = fixedSelector;
	rule.lastInvocation = invocation;
	[rule.lastInvocation retainArguments];
}
```

#### `MTPerformModeDebounce`

```
MTModePerformDebounce:
start                                        end
|           durationThreshold(old)             |
@----------------------@---------------------->>
|                      |                 
ignore                 will perform at end of new duration
                       |--------------------------------------------->>
                       |           durationThreshold(new)             |
                       start                                        end
```

虽然流程看上去复杂但其实实现起来也很简单。每次发送消息完再过 `durationThreshold` 时间后，检查下 `lastInvocation` 有没有变化。如果无变化，则说明这段时间内没有新的消息发送，则可以执行 `lastInvocation`。

```
invocation.selector = fixedSelector;
rule.lastInvocation = invocation;
[rule.lastInvocation retainArguments];
dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(rule.durationThreshold * NSEC_PER_SEC)), rule.messageQueue, ^{
	if (rule.lastInvocation == invocation) {
		[rule.lastInvocation invoke];
		rule.lastInvocation = nil;
	}
});
```

### 规则的应用与废除

在真正应用规则之前，需要检查下规则合法性，然后检查继承链上是否已经应用过规则了。如果有，则需要输出错误信息；否则应用规则。这里使用 POSIX 的互斥锁保证线程安全。`mt_overrideMethod()` 函数所作的事情就是开始提到的利用消息转发流程 hook 的三个步骤。

```
- (BOOL)applyRule:(MTRule *)rule
{
    pthread_mutex_lock(&mutex);
    __block BOOL shouldApply = YES;
    if (mt_checkRuleValid(rule)) {
        [self.rules enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull key, MTRule * _Nonnull obj, BOOL * _Nonnull stop) {
            if (rule.selector == obj.selector
                && object_isClass(rule.target)
                && object_isClass(obj.target)) {
                Class clsA = rule.target;
                Class clsB = obj.target;
                shouldApply = !([clsA isSubclassOfClass:clsB] || [clsB isSubclassOfClass:clsA]);
                *stop = shouldApply;
                NSString *errorDescription = [NSString stringWithFormat:@"Error: %@ already apply rule in %@. A message can only have one throttle per class hierarchy.", NSStringFromSelector(obj.selector), NSStringFromClass(clsB)];
                NSLog(@"%@", errorDescription);
            }
        }];
        
        if (shouldApply) {
            self.rules[mt_methodDescription(rule.target, rule.selector)] = rule;
            mt_overrideMethod(rule.target, rule.selector);
        }
    }
    pthread_mutex_unlock(&mutex);
    return shouldApply;
}
```

废除规则是执行相反的操作。如果 `target` 是个实例对象，`mt_recoverMethod()` 函数会判断是否有相同 `selector` 且 `target` 为这个实例对象的类的其他规则。如果有，那将不会移除 hook。

```
- (BOOL)discardRule:(MTRule *)rule
{
    pthread_mutex_lock(&mutex);
    BOOL shouldDiscard = NO;
    if (mt_checkRuleValid(rule)) {
        NSString *description = mt_methodDescription(rule.target, rule.selector);
        shouldDiscard = self.rules[description] != nil;
        if (shouldDiscard) {
            self.rules[description] = nil;
            mt_recoverMethod(rule.target, rule.selector);
        }
    }
    pthread_mutex_unlock(&mutex);
    return shouldDiscard;
}
```

## 后记

其实在开发过程中遇到需要限制方法调用频率的场景并不多，只是最近恰巧连续碰到几个刷新 UI 过频繁的问题，才想到应该去造个轮子。因为时间仓促，肯定还有考虑不周和一些 bug，待投入使用后慢慢完善和修复。

其实想在某个特定函数做节流很简单，但每次都需要做重复劳动，写脏代码，还不如抽象出一个工具类出来。尽量造与业务无关的轮子，锻炼技术，也受益整个业务发展。

好，装逼到此为止。Github : https://github.com/yulingtianxia/MessageThrottle


