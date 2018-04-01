---
title: 追踪 Objective-C 方法中的 Block 参数对象
date: 2018-03-31 23:44:39
tags:
- Objective-C
---

很多方法最后一个参数是类似于 `completionBlock` 这种回调，然而有些 API 实现一些异常逻辑时会忘记调用传入的 Block 参数（当然这肯定是 bug 啦），或者存在多次调用。在调试的时候可能会碰到这种大坑，需要追踪下 Block 参数何时调用了，甚至是否调用过。如果不方便直接在 Block 实现中加代码，或者没有源码的情况下，就需要无侵入式地追踪 Block 参数对象。

[BlockTracker](https://github.com/yulingtianxia/BlockTracker) 可以追踪方法调用时传入的 Block 类型的参数的执行和销毁。基于 [BlockHook](https://github.com/yulingtianxia/BlockHook) 实现。本文讲述了它的使用方法和实现原理。

<!-- more -->

## 使用方法

只需要调用 `bt_trackBlockArgOfSelector:callback:` 方法，就能在对应方法执行传入的 block 参数被调用和销毁的时候得到回调。回调中的内容包含了 `block` 对象，回调类型，`block` 已经执行的次数，执行 `block` 的参数、返回值，堆栈信息。

```
BTTracker *tracker = [self bt_trackBlockArgOfSelector:@selector(performBlock:) callback:^(id  _Nullable block, BlockTrackerCallbackType type, NSInteger invokeCount, void * _Nullable * _Null_unspecified args, void * _Nullable result, NSArray<NSString *> * _Nonnull callStackSymbols) {
   NSLog(@"%@ invoke count = %ld", BlockTrackerCallbackTypeInvoke == type ? @"BlockTrackerCallBackTypeInvoke" : @"BlockTrackerCallBackTypeDead", (long)invokeCount);
}];
```

当你不想追踪这个方法执行时传入的 block 参数时，也可以停止追踪：

```
[tracker stop];
```

举个栗子，现在有个方法叫 `performBlock:`，只是简单地调用了 `block` 参数：

```
- (void)performBlock:(void(^)(void))block {
    block();
}
```

调用两次这个方法，每次都传入不同的 block 实现：

```
__block NSString *word = @"I'm a block";
[self performBlock:^{
   NSLog(@"add '!!!' to word");
   word = [word stringByAppendingString:@"!!!"];
}];
[self performBlock:^{
   NSLog(@"%@", word);
}];
```

因为执行两次方法传入的是两个不同的 block 对象，所以会追踪两个 block 对象的执行和销毁，打印的 log 如下：

```
add '!!!' to word
BlockTrackerCallBackTypeInvoke invoke count = 1
I'm a block!!!
BlockTrackerCallBackTypeInvoke invoke count = 1
BlockTrackerCallBackTypeDead invoke count = 1
BlockTrackerCallBackTypeDead invoke count = 1
```

在 block 对象销毁的时候
你可以尝试着把 `performBlock:` 的实现改成这样试试：

```
- (void)performBlock:(void(^)(void))block {
    block();
    block();
    block();
}
```

## 实现原理

原理很简单，就是 Hook 方法后再 Hook 下 Block，流程大致如下：

1. 利用 Objective-C Runtime 机制 Hook 某个方法，参考 [MessageThrottle](https://github.com/yulingtianxia/MessageThrottle) 的实现原理。
2. 在方法真正执行前，使用 [BlockHook](https://github.com/yulingtianxia/BlockHook) 先 Hook 所有 Block 类型的参数。Hook 模式为 `BlockHookModeAfter` 和 `BlockHookModeDead`。
3. 在 Block 执行后更新执行次数，并将相关信息回调给 Tracker。销毁后也会回调给 Tracker。

流程大概很简单，复用以前代码。这里主要讲下 Track 的逻辑。

### 过滤方法的 Block 参数

在 `bt_trackBlockArgOfSelector:callback:` 里获取方法的 Type Encoding 后判断是否含有 Block 类型的参数，并将 Block 参数的 Index 保存到 `BTTracker` 的 `blockArgIndex` 属性。

```
- (nullable BTTracker *)bt_trackBlockArgOfSelector:(SEL)selector callback:(BlockTrackerCallbackBlock)callback
{
    Class cls = bt_classOfTarget(self);
    
    Method originMethod = class_getInstanceMethod(cls, selector);
    if (!originMethod) {
        return nil;
    }
    const char *originType = (char *)method_getTypeEncoding(originMethod);
    if (![[NSString stringWithUTF8String:originType] containsString:@"@?"]) {
        return nil;
    }
    NSMutableArray *blockArgIndex = [NSMutableArray array];
    int argIndex = 0; // return type is the first one
    while(originType && *originType)
    {
        originType = BHSizeAndAlignment(originType, NULL, NULL, NULL);
        if ([[NSString stringWithUTF8String:originType] hasPrefix:@"@?"]) {
            [blockArgIndex addObject:@(argIndex)];
        }
        argIndex++;
    }

    BTTracker *tracker = BTEngine.defaultEngine.trackers[bt_methodDescription(self, selector)];
    if (!tracker) {
        tracker = [[BTTracker alloc] initWithTarget:self selector:selector];
        tracker.callback = callback;
        tracker.blockArgIndex = [blockArgIndex copy];
    }
    return [tracker apply] ? tracker : nil;
}
```

`bt_trackBlockArgOfSelector:callback:` 方法返回的 `BTTracker` 对象也保存了 `callback` 回调。

### 执行 Callback

遍历之前保存的 Block 参数 Index 列表 `blockArgIndex`，从 `NSInvocation` 中取到 Block 参数后，就可以 Hook 了。Block 的执行次数保存到了 `BHToken` 上，每次执行都会累加。在 Block 执行或销毁后都会调用 `callback`，只是传的参数稍有不同。

```
for (NSNumber *index in tracker.blockArgIndex) {
   if (index.integerValue < invocation.methodSignature.numberOfArguments) {
       __unsafe_unretained id block;
       [invocation getArgument:&block atIndex:index.integerValue];
       __weak typeof(block) weakBlock = block;
       __weak typeof(tracker) weakTracker = tracker;
       BHToken *tokenAfter = [block block_hookWithMode:BlockHookModeAfter usingBlock:^(BHToken *token) {
           __strong typeof(weakBlock) strongBlock = weakBlock;
           __strong typeof(weakTracker) strongTracker = weakTracker;
           NSNumber *invokeCount = objc_getAssociatedObject(token, NSSelectorFromString(@"invokeCount"));
           if (!invokeCount) {
               invokeCount = @(1);
           }
           else {
               invokeCount = [NSNumber numberWithInt:invokeCount.intValue + 1];
           }
           objc_setAssociatedObject(token, NSSelectorFromString(@"invokeCount"), invokeCount, OBJC_ASSOCIATION_RETAIN);
           if (strongTracker.callback) {
               strongTracker.callback(strongBlock, BlockTrackerCallbackTypeInvoke, invokeCount.intValue, token.args, token.retValue, [NSThread callStackSymbols]);
           }
       }];

       [block block_hookWithMode:BlockHookModeDead usingBlock:^(BHToken *token) {
           __strong typeof(weakTracker) strongTracker = weakTracker;
           NSNumber *invokeCount = objc_getAssociatedObject(tokenAfter, NSSelectorFromString(@"invokeCount"));
           if (strongTracker.callback) {
               strongTracker.callback(nil, BlockTrackerCallbackTypeDead, invokeCount.intValue, nil, nil, [NSThread callStackSymbols]);
           }
       }];
   }
}
```

### 对 NSInvocation 的一点探索

在从 `NSInvocation` 对象获取参数时，需要先调用 `retainArguments` 方法让 `NSInvocation` 将 Block 参数 `copy`。因为有些 Block 参数类型是 `__NSStackBlock__`，需要拷贝到堆上，否则从 `NSInvocation` 获取的 Block 不会销毁。

`getArgument:atIndex:` 方法只是将第 `index` 个参数指针的值拷贝到 `buffer` 中，而 `retainArguments` 才是真的对 C 字符串和 Block 拷贝。

我还为此做了个小实验。一个类外部声明并调用了 `test:` 方法，但其实内部实现的是 `foo:` 方法。通过实现 `methodSignatureForSelector:` 让消息转发流程走到 `forwardInvocation:` 方法中。然后向 Block 参数关联 `BTDealloc` 对象，在 `test:` 方法执行后，`BTDealloc` 类的 `dealloc` 方法并没有执行。也就是说通过 `NSInvocation` 获取的 Block 参数没销毁；如果先调用了 `retainArguments` 就会销毁。

```
- (void)test:(void(^)(void))block;

- (void)foo: (void(^)(void)) block {
    block();
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    return [NSMethodSignature signatureWithObjCTypes:"v@:@?"];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
//    [anInvocation retainArguments];
    void **invocationFrame = ((__bridge struct BTInvocaton *)anInvocation)->frame;
    void *blockFromFrame = invocationFrame[2];
    void *block;
    [anInvocation getArgument:&block atIndex:2];
    BTDealloc *btDealloc = [BTDealloc new];
    objc_setAssociatedObject((__bridge id)block, @selector(foo:), btDealloc, OBJC_ASSOCIATION_RETAIN);
    anInvocation.selector = @selector(foo:);
    [anInvocation invoke];
}
```

通过对 `NSInvocation` 对象的解析，我发现 `NSInvocation` 的参数存储于一个私有成员变量 `_frame` 中，试着将其强转为二级指针，也就是指针数组。拿到对应 index 的值 `blockFromFrame` 跟 `block` 作比较，发现是一样的。这里获取 `_frame` 需要强转下，`NSInvocation` 的内存模型如下：

```
struct BTInvocaton {
    void *isa;
    void *frame;
    void *retdata;
    void *signature;
    void *container;
    uint8_t retainedArgs;
    uint8_t reserved[15];
};
```

## 总结

由于 Hook Method 的逻辑是在消息转发流程搞事情，所以跟 Aspects 一样不能同时 Hook 父类和子类类相同方法。因为如果子类调用父类的实现，就会死循环。如果 Hook 方法这部分使用 [Method Swizzling](http://yulingtianxia.com/blog/2017/04/17/Objective-C-Method-Swizzling/) 等交换 IMP 的方式实现，也会有着严重依赖 Hook 顺序导致调用错乱的问题。还是基于桥的 Hook 牛逼，汇编跳板，我这辈子是看不懂了。

老子终于在这个月最后一天快结束的时候憋出来一篇大水文！搬砖累死了没时间研究技术，你们尽管喷！

