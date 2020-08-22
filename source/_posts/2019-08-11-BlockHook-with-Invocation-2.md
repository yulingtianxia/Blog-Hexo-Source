---
title: BlockHook with Invocation(2)
date: 2019-08-11 22:18:51
tags:
- Objective-C
- Runtime
- BlockHook
---

[上一篇文章](http://yulingtianxia.com/blog/2019/07/27/BlockHook-with-Invocation/) 简单介绍了下 `retainArguments` 和 `block_interceptor` 实现的思路，本文会详细讲解下 `BHInvocation` 的接口设计与实现，并与系统的 `NSInvocation` 作对比。

<!--more-->

## 接口设计

`BHInvocation` 相当于是参照 `NSInvocation` 的接口并改造了下，以承载 [BlockHook](https://github.com/yulingtianxia/BlockHook) 的一些元数据。

```
@interface BHInvocation : NSObject

@property (nonatomic, readonly, weak) BHToken *token;
@property (nonatomic, readonly) BlockHookMode mode;
@property (nonatomic, getter=isArgumentsRetained, readonly) BOOL argumentsRetained;
@property (nonatomic, strong, readonly) NSMethodSignature *methodSignature;
- (void)invokeOriginalBlock; // 替代 invoke 和 invokeWithTarget:
- (void)retainArguments;
- (void)getReturnValue:(void *)retLoc;
- (void)setReturnValue:(void *)retLoc;
- (void)getArgument:(void *)argumentLocation atIndex:(NSInteger)idx;
- (void)setArgument:(void *)argumentLocation atIndex:(NSInteger)idx;

@end
```

### BlockHook 相关的接口

为了存储 Hook 相关的信息，需要在 `NSInvocation` 的接口基础上新增 `token` 属性和 `mode` 属性。不过 `BHToken` 其实已经存储了 `BlockHookMode`，为何还要再在 `BHInvocation` 中加一个 `mode` 呢？

`BHToken` 存储的是一次 Hook 行为的元数据；`BHInvocation` 存储的是 Hook 后 Block 执行时的元数据。`BHToken` 存储的 `mode` 是 Hook 的模式，可能包含了多种模式；而 `BHInvocation` 存储的 `mode` 则是当前这次 Hook 执行回调所处的时机。

例如同时 Hook Block 执行的前后，此时传入的 `mode` 值为 `BlockHookModeBefore|BlockHookModeAfter`，生成的 `BHToken` 的值也是一样。而 Block 执行前后会有两次回调，传入的 `BHInvocation` 参数内容却不太一样：其 `mode` 分别为 `BlockHookModeBefore` 和 `BlockHookModeAfter`。但这两次传入的 `BHInvocation` 中的 `token` 确是完全一样。

`BHToken` 也是初始化 `BHInvocation` 所用到的唯一参数。

由于是 Hook，所以执行 Block 时需要注意是调用原始实现还是新的实现。 加入了 `invokeOriginalBlock` 接口来调用原始实现，这也是所有 AOP 工具的必要设计。

### `NSInvocation` 相关的接口

为了降低使用者的学习成本，[BlockHook](https://github.com/yulingtianxia/BlockHook) 的接口设计上会尽量参照一些已有的 AOP 工具。在 Invocation 这块，能参照的最好的例子就是系统提供的 `NSInvocation`。其提供了**读、写和 `retian` 参数列表/返回值**的接口，以及方法签名等。

而 `NSInvocation` 有些接口在 [BlockHook](https://github.com/yulingtianxia/BlockHook) 中是用不到的，比如 `selector` 属性没什么意义，再比如 `invoke` 和 `invokeWithTarget:` 这两个接口在 AOP 场景下也不必存在。

## 接口实现

在[上一篇文章](http://yulingtianxia.com/blog/2019/07/27/BlockHook-with-Invocation/)中介绍了过了 `retainArguments` 的实现思路，针对每个指向参数或返回值的指针都需要经历 "Copy" 和 "Retain" 两步：

![](http://yulingtianxia.com/resources/BlockHook/retainArguments.png)

### Copy Pointer

无论 `pointer` 指向的内容是一个 `struct` 还是 `NSObject *`，都需要将 `pointer` 的内容拷贝，防止原始内存被修改或者释放。在拷贝前需要开辟新的内存，其生命周期与 `BHInvocation` 绑定在一起。

```
- (void *)_copyPointer:(void **)pointer encode:(const char *)encode key:(NSNumber *)key
{
    NSUInteger pointerSize;
    NSGetSizeAndAlignment(encode, &pointerSize, NULL);
    NSMutableData *pointerData = [NSMutableData dataWithLength:pointerSize];
    self.mallocMap[key] = pointerData;
    void *pointerBuf = pointerData.mutableBytes;
    memcpy(pointerBuf, pointer, pointerSize);
    return pointerBuf;
}
```

### Retain Pointer

如果 `pointer` 指向的内容依然是个指针，比如 `NSObject *` 或 `char *`，还需要防止其内容提前被释放，产生野指针。这里相当于是对 Objective-C 对象和 C-String 的特殊处理，以参数和返回值的 index 作为 key，利用字典 `retainMap` 强引用 Objective-C 对象；对于 Block 对象还需调用 `copy` 方法，将栈上的 Block 拷贝到堆上防止被提早释放；对于 C-String 则是开辟新内存并拷贝字符串内容，然后放入 `retainMap` 中；

```
- (void)_retainPointer:(void **)pointer encode:(const char *)encode key:(NSNumber *)key
{
    void *p = *pointer;
    if (!p) {
        return;
    }
    if (encode[0] == '@') {
        id arg = (__bridge id)p;
        if (strcmp(encode, "@?") == 0) {
            self.retainMap[key] = [arg copy];
        }
        else {
            self.retainMap[key] = arg;
        }
    }
    else if (encode[0] == '*') {
        char *arg = p;
        NSMutableData *data = [NSMutableData dataWithLength:sizeof(char) * strlen(arg)];
        self.retainMap[key] = data;
        char *str = data.mutableBytes;
        strcpy(str, arg);
        *pointer = str;
    }
}
```

### 读写参数和返回值

[上一篇文章](http://yulingtianxia.com/blog/2019/07/27/BlockHook-with-Invocation/)讲述了 `BHInvocation` 存储参数列表和返回值上的一些处理策略，这里来讲讲如何读写。

在实现读写参数列表和返回值接口时，不仅仅是对 `args` 和 `retValue` 指针的读写操作，还要考虑到 Copy Pointer 和 Retain Pointer。

Copy Pointer 这步无需自行开辟内存了，原因是写入时 `retainArguments` 的时候已经开辟好了，读取时直接使用传入的指针。

Retain Pointer 接口使用 `idx` 作为 key，写入新的值时会替换字典 `retainMap` 中的旧值。这样既可以释放旧值，也能重新 retain 新值。

```
- (void)getArgument:(void *)argumentLocation atIndex:(NSInteger)idx
{
    if (!argumentLocation || !self.args || !self.args[idx]) {
        return;
    }
    void *arg = self.args[idx];
    const char *type = [self.methodSignature getArgumentTypeAtIndex:idx];
    NSUInteger argSize;
    NSGetSizeAndAlignment(type, &argSize, NULL);
    memcpy(argumentLocation, arg, argSize);
}

- (void)setArgument:(void *)argumentLocation atIndex:(NSInteger)idx
{
    if (!argumentLocation || !self.args || !self.args[idx]) {
        return;
    }
    void *arg = self.args[idx];
    const char *type = [self.methodSignature getArgumentTypeAtIndex:idx];
    NSUInteger argSize;
    NSGetSizeAndAlignment(type, &argSize, NULL);
    if (self.isArgumentsRetained) {
        [self _retainPointer:argumentLocation encode:type key:@(idx)];
    }
    memcpy(arg, argumentLocation, argSize);
}
```

在 ARC 下从 `NSInvocation` 读取参数或返回值时，如果类型为 Objective-C 对象，则需要避免默认的强引用。[Stack Overflow](https://stackoverflow.com/questions/16928299/get-block-argument-from-nsinvocation-with-arc) 上有具体解决方案，其中的一种方案如下：

```
NSObject * __unsafe_unretained arg;
[invocation getArgument:&arg atIndex:1];
```

`BHInvocation` 由于高仿了 `NSInvocation` 的接口和实现，所以也需要注意此问题。究其原因在于 `memcpy` 只是内存拷贝，不是直接向 `strong` 类型变量赋值，并不会参与到 ARC 的引用计数中。而出了作用域后 ARC 会自动对 `strong` 类型 `release` 一次，导致读取到的对象过度释放，导致 crash。（PS：ARC 真实的实现机制会更复杂些，为了描述方便这里对原理进行了简化）

其实还有一种更好的方式读参数，那就是直接在 `aspectBlock` 中取参数。`aspectBlock` 中的参数是可以随意写的，但需要跟 Block 的参数列表对应上。写法可以参照下面这个测试用例，直接获取参数，然后修改参数：

```
- (void)testObjectArg {
    NSObject *argOrig = [NSObject new];
    NSObject *argFixed = [NSObject new];
    void (^ObjectArgBlock)(NSObject *) = ^(NSObject *test)
    {
        NSAssert(test == argFixed, @"Modify struct member failed!");
    };
    
    [ObjectArgBlock block_hookWithMode:BlockHookModeBefore usingBlock:^(BHInvocation *invocation, NSObject *test){
        NSAssert(test == argOrig, @"Wrong arg!");
        // Hook 改参数
        [invocation setArgument:(void *)&argFixed atIndex:1];
    }];
    
    ObjectArgBlock(argOrig);
}
```

## 总结

最初 `BHInvocation` 还不够完善时，读写 Block 的参数/返回值只能用二级指针之类的晦涩语法直接操作 `args` 和 `retValue`，门槛较高而且还不够安全。`BHInvocation` 接口设计和实现上尽量参考已有的成熟案例，降低开发者学习成本，快速上手。