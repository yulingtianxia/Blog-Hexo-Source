---
title: Hook Objective-C Block with Libffi
date: 2018-02-28 19:05:24
tags:
- Objective-C
---

本文通过参照 `MABlockClosure` 的实现和 `Aspects` 的 API 设计，基于 libffi 实现了对 Objective-C Block 的 hook。GitHub 地址：https://github.com/yulingtianxia/BlockHook

什么场景下需要 hook block 呢？在有源码的情况下，大部分程序员会选择直接在 block 中插代码。假如方法 A 的入参是个 block 对象，方法 A 将 block 传给方法 B,C...等。如果只有方法 A 的源码，上层传入的 block 和下层方法实现都是黑盒的话，想追踪 block 调用的时机，打印些 log，就得 hook 这个 block 对象了。

<!-- more -->

## 如何使用

虽然 Github 上已经给了例子，用过 Aspects 的人一看就懂，但为了凑篇幅，还是多 BB 几句吧。

API 虽然清奇，但是需要在 block 对象上用哦，在其他类型的对象上用是无效的！

```
- (BHToken *)block_hookWithMode:(BlockHookMode)mode
                     usingBlock:(id)block
```

四种 hook 模式任你选择，可以对同一个 block 对象 hook 多次，但是要注意自己控制好顺序问题！hook 后会返回一个 `BHToken` 对象，可以调用它的 `remove` 方法来让 hook 失效。切记 `remove` 的时候要按照 hook 时的逆序！（以后可以搞个栈优化下用户体验，暂时懒的弄）

```
[super viewDidLoad];
// Do any additional setup after loading the view, typically from a nib.
NSObject *z = NSObject.new;
int (^block)(int, int) = ^(int x, int y) {
   int result = x + y;
   NSLog(@"%d + %d = %d, z is a NSObject: %p", x, y, result, z);
   return result;
};
    
    
BHToken *tokenInstead = [block block_hookWithMode:BlockHookModeInstead usingBlock:^(BHToken *token, int x, int y){
   [token invokeOriginalBlock];
   NSLog(@"let me see original result: %d", *(int *)(token.retValue));
   // change the block imp and result
   *(int *)(token.retValue) = x * y;
   NSLog(@"hook instead: '+' -> '*'");
}];

BHToken *tokenAfter = [block block_hookWithMode:BlockHookModeAfter usingBlock:^(BHToken *token, int x, int y){
   // print args and result
   NSLog(@"hook after block! %d * %d = %d", x, y, *(int *)(token.retValue));
}];

BHToken *tokenBefore = [block block_hookWithMode:BlockHookModeBefore usingBlock:^(id token){
   // BHToken has to be the first arg.
   NSLog(@"hook before block! token:%@", token);
}];
    
BHToken *tokenDead = [block block_hookWithMode:BlockHookModeDead usingBlock:^(id token){
   // BHToken is the only arg.
   NSLog(@"block dead! token:%@", token);
}];
    
dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
   NSLog(@"hooked block");
   int ret = block(3, 5);
   NSLog(@"hooked result:%d", ret);
   // remove all tokens when you don't need.
   // reversed order of hook.
   [tokenBefore remove];
   [tokenAfter remove];
   [tokenInstead remove];
   NSLog(@"remove tokens, original block");
   ret = block(3, 5);
   NSLog(@"original result:%d", ret);
//        [tokenDead remove];
});
```

可以通过设置 `BHToken` 的 `retValue` 属性来修改 block 的返回值。`usingBlock:` 的参数内容是自定义的，跟 Aspects 一样，用户自己填上对应的参数列表。完整参数列表的内容就是 `BHToken`（第一个参数）+ 原始 block 参数列表。看上面的例子应该很容易看懂。可以在 hook 的 block 中获取参数和修改返回值，打log，做些有(wei)趣(suo)的事情。

上面代码执行后的 log 结果如下：

```
hooked block
hook before block! token:<BHToken: 0x1d00f0d80>
3 + 5 = 8, z is a NSObject: 0x1d00172b0
let me see original result: 8
hook instead: '+' -> '*'
hook after block! 3 * 5 = 15
hooked result:15
remove tokens, original block
3 + 5 = 8, z is a NSObject: 0x1d00172b0
original result:8
block dead! token:<BHToken: 0x1d00f9900>
```

老铁稳。

因为需要动态定义和运行函数，用到了 libffi，所以还需要引入对应架构的静态库，自己去官网下个编译好，在工程中引入 libffi.a 和包含头文件的 include 文件夹就行。示例程序 BlockHookSample 使用的是 arm64 架构。具体做法是在 Build Settings 中的 Other Link Flags 加入 libffi.a 的路径，在 Header Search Paths 加入 include 文件夹路径。

## 实现原理

先说下大致思路：

1. 根据 block 对象的签名，使用 `ffi_prep_cif` 构建 block->invoke 函数的模板 `cif`
2. 使用 `ffi_closure`，根据 cif 动态定义函数 `replacementInvoke`，并指定通用的实现函数为 `ClosureFunc`
3. 将 block->invoke 替换为 `replacementInvoke`，原始的 block->invoke 存放在 `originInvoke`
4. 在 `ClosureFunc` 中动态调用 `originInvoke` 函数和执行 hook 的逻辑。

对 libffi 的介绍和用法有很多文章可以参考，这里不再赘述。

再整理下代码设计思路：

- `BHToken`: 它实现了 hook 的逻辑，存储了相关的上下文。是最主要的类。
- `NSObject (BlockHook)`: 提供 hook 的接口，每次 hook block 对象都会创建一个 `BHToken`，并将其返回给用户。
- `BHCenter` 管理 `BHToken` 对象的中心，以后可以拓展更多玩法。

下面列举下 `BHToken` 中几个比较重要的逻辑。

### 通过 Block 创建函数模板

有关 Objective-C Block 内存模型这里不再赘述，Block ABI 可以在 [Clang 文档](https://clang.llvm.org/docs/Block-ABI-Apple.html) 查到。根据 block 的 flag 位掩码计算偏移拿到 Type Encoding 签名 signature。`BHBlockTypeEncodeString()` 函数实现了这些逻辑，代码不贴了。一个 block 的签名格式是：[返回值类型和偏移][@?0][参数0类型和偏移][参数1类型和偏移]...，比如 arm64 下 `int (^block)(int, int)` 的签名是 `i16@?0i8i12`。block 指针占 8 字节，参数和返回值 `int` 都是 4 字节。

然后需要把 signature 字符串处理分拆成参数类型列表，在 libffi 中使用 `ffi_type` 表示各种类型。`_argsWithEncodeString:getCount:` 方法会根据 Type Encoding 规则，将 signature 逐个字符处理，可以获取 `ffi_type *` 参数（返回值）数组和参数个数。`_ffiArgForEncode:` 方法负责将 Type Encoding 字符映射到对应的 `ffi_type` 上，这是个很长的方法。

有了参数类型列表，返回值类型，参数个数后，就可以调用 `ffi_prep_cif()` 函数创建 `ffi_cif` 了，也就是函数模板。`_prepCIF:withEncodeString:` 方法实现了这个逻辑。

```
- (int)_prepCIF:(ffi_cif *)cif withEncodeString:(const char *)str
{
    int argCount;
    ffi_type **argTypes = [self _argsWithEncodeString:str getCount:&argCount];
    
    ffi_status status = ffi_prep_cif(cif, FFI_DEFAULT_ABI, argCount, [self _ffiArgForEncode: str], argTypes);
    if(status != FFI_OK)
    {
        NSLog(@"Got result %ld from ffi_prep_cif", (long)status);
        abort();
    }
    return argCount;
}
```

### 创建闭包，替换 Block 的 `invoke`

可以使用函数模板（`ffi_cif`）和一个函数指针（`replacementInvoke`）创建闭包(`ffi_closure`)。

```
_closure = ffi_closure_alloc(sizeof(ffi_closure), &_replacementInvoke);
```

当 `replacementInvoke()` 函数被调用时，绑定到闭包上的函数 `void BHFFIClosureFunc(ffi_cif *cif, void *ret, void **args, void *userdata)` 会被调用。传给 `replacementInvoke()` 的参数及其返回值都会被传给 `BHFFIClosureFunc()`。`ffi_prep_closure_loc` 函数的倒数第二个参数是 `user_data`，也会被传给 `BHFFIClosureFunc()` 方法。

```
- (void)_prepClosure
{
    ffi_status status = ffi_prep_closure_loc(_closure, &_cif, BHFFIClosureFunc, (__bridge void *)(self), _replacementInvoke);
    if(status != FFI_OK)
    {
        NSLog(@"ffi_prep_closure returned %d", (int)status);
        abort();
    }
    // exchange invoke func imp
    _originInvoke = ((__bridge struct _BHBlock *)self.block)->invoke;
    ((__bridge struct _BHBlock *)self.block)->invoke = _replacementInvoke;
}
```

将函数指针 `_replacementInvoke` 和函数模板 `_cif` 绑定函数闭包之后，需要将 block 的 `invoke` 替换成 `_replacementInvoke`，并把原始的实现存到 `_originInvoke`。`invoke` 函数的模板跟 block 的签名内容是一致的。

这样当 block 调用时，实际上会调用 `_replacementInvoke` 函数，进而调用 `BHFFIClosureFunc` 通用函数。在这里面会实现 hook 的逻辑。

还原 Hook 的 `remove` 逻辑也很简单，将 `_originInvoke` 恢复到 `invoke` 即可：

```
((__bridge struct _BHBlock *)self.block)->invoke = _originInvoke;
```

### 实现通用 Hook 函数

所有被 hook 的 block 调用时都会走到 `BHFFIClosureFunc` 这里，可以拿到 block->invoke 的函数模板，返回值指针，参数列表。还有自定义的 `userdata`，传入的是 `BHToken` 对象。

使用 `ffi_call()` 动态调用 block 的原始实现 `_originInvoke`，并将参数列表和返回值指针传入。还需要传入函数模板，满足 Calling Convention。

```
static void BHFFIClosureFunc(ffi_cif *cif, void *ret, void **args, void *userdata)
{
    BHToken *token = (__bridge BHToken *)(userdata);
    token.retValue = ret;
    if (BlockHookModeBefore == token.mode) {
        [token invokeHookBlockWithArgs:args];
    }
    if (!(BlockHookModeInstead == token.mode && [token invokeHookBlockWithArgs:args])) {
        ffi_call(&token->_cif, token->_originInvoke, ret, args);
    }
    if (BlockHookModeAfter == token.mode) {
        [token invokeHookBlockWithArgs:args];
    }
}
```

根据 Hook mode，会在不同的时机调用 `invokeHookBlockWithArgs:` 方法执行 hook 的逻辑。


### 组装 `NSInvocation` 执行 Hook 逻辑

Hook 逻辑实现在 `self.hookBlock` 中，被 Hook 的 block 是 `self.block`，分别获取两者的签名，并拷贝后者的参数传给前者构造的 `blockInvocation`。这里要注意 `self.hookBlock` 的参数比 `self.block` 多一个 `token`，所以在二者参数比对和传递时需要特殊处理下。最后执行 `blockInvocation`，即调用了 `usingBlock:` 的参数。

```
- (BOOL)invokeHookBlockWithArgs:(void **)args
{
    if (!self.block || !self.hookBlock) {
        return NO;
    }
    NSMethodSignature *hookBlockSignature = [NSMethodSignature signatureWithObjCTypes:BHBlockTypeEncodeString(self.hookBlock)];
    NSMethodSignature *originalBlockSignature = [NSMethodSignature signatureWithObjCTypes:BHBlockTypeEncodeString(self.block)];
    NSInvocation *blockInvocation = [NSInvocation invocationWithMethodSignature:hookBlockSignature];
    
    // origin block invoke func arguments: block(self), ...
    // hook block signature arguments: block(self), token, ...
    
    if (hookBlockSignature.numberOfArguments > self.numberOfArguments + 1) {
        NSLog(@"Block has too many arguments. Not calling %@", self);
        return NO;
    }
    
    if (hookBlockSignature.numberOfArguments > 1) {
        [blockInvocation setArgument:(void *)&self atIndex:1];
    }

    void *argBuf = NULL;
    for (NSUInteger idx = 2; idx < hookBlockSignature.numberOfArguments; idx++) {
        const char *type = [originalBlockSignature getArgumentTypeAtIndex:idx - 1];
        NSUInteger argSize;
        NSGetSizeAndAlignment(type, &argSize, NULL);
        
        if (!(argBuf = reallocf(argBuf, argSize))) {
            NSLog(@"Failed to allocate memory for block invocation.");
            return NO;
        }
        memcpy(argBuf, args[idx - 1], argSize);
        [blockInvocation setArgument:argBuf atIndex:idx];
    }
    
    [blockInvocation invokeWithTarget:self.hookBlock];
    
    if (argBuf != NULL) {
        free(argBuf);
    }
    return YES;
}
```

因为用户传入的 `hookBlock` 签名是不确定的，所以需要针对参数数量判断临界条件。

## 总结

又是大水文一篇，总算是在月末憋出来了。因为只花了一天时间写代码，实在太仓促，肯定还有一堆 bug。目前不建议用到生产环境上，辅助 debug 还是可以的，以后会慢慢优化。也欢迎各位老铁们提 PR：https://github.com/yulingtianxia/BlockHook/pulls

代码大量参考了 [MABlockClosure](https://github.com/mikeash/MABlockClosure) 的一些工具函数，API 设计上致敬 [Aspects](https://github.com/steipete/Aspects)。技术上如有疏漏，还请各位大佬们多多指教。

