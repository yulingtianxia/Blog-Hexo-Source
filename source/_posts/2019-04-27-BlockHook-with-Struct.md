---
title: BlockHook with Struct
date: 2019-04-27 21:26:55
tags:
- Objective-C
---

一年前，我开发了 [BlockHook](https://github.com/yulingtianxia/BlockHook)，（貌似）填补了 Objective-C 在 Hook Block 的空白。但是对于 Block 的参数和返回值有限制，仅定制了 `CGRect`, `CGSize`, `CGPoint` 等结构体，不支持自定义 struct。这次就把这个坑给填上。

至此，[BlockHook](https://github.com/yulingtianxia/BlockHook) 已支持 macOS 和 iOS 平台全架构、tvOS 和 watchOS 模拟器，`BlockHook.m` 测试覆盖率达到 92% 以上。

<!--more-->

关于 [BlockHook](https://github.com/yulingtianxia/BlockHook) 的实现原理，可以先阅读 [Hook Objective-C Block with Libffi](http://yulingtianxia.com/blog/2018/02/28/Hook-Objective-C-Block-with-Libffi/)。

## Struct Encode

要想解析自定义结构体的类型，并转换为 `ffi_type`，首先要从 Block 的 signature 入手。从中提取出 struct 的 encode，并继续解析其内容。

比如下面这个结构体，encode 是 "{TestStruct=idfc^i^{CGRect}}"。编码规则可以查看 [Type Encodings](https://nshipster.cn/type-encodings/)。

```
struct TestStruct {
    int32_t a;
    double b;
    float c;
    char d;
    int *e;
    CGRect *f;
};
```

基本可以把结构体当做基本类型的组合嵌套了，那么在原有解析方法的基础上，针对 "{name=type}" 这种范式来个递归遍历就行了。`_ffiTypeForStructEncode` 方法将截取 signature 字符串前面的 struct，并得到结构体的 `size`、 `alignment` 和 encode 长度 `length`。构建 `ffi_type`，并截取 `=` 后面的内容调用 `_typesWithEncodeString` 递归处理，得到结构体元素数组。

```
- (ffi_type *)_ffiTypeForStructEncode:(const char *)str
{
    NSUInteger size, align;
    long length;
    BHSizeAndAlignment(str, &size, &align, &length);
    ffi_type *structType = [self _allocate:size];
    structType->type = FFI_TYPE_STRUCT;
    structType->size = size;
    structType->alignment = align;
    
    const char *temp = [[[NSString stringWithUTF8String:str] substringWithRange:NSMakeRange(0, length)] UTF8String];
    
    // cut "struct="
    while (temp && *temp && *temp != '=') {
        temp++;
    }
    ffi_type **elements = [self _typesWithEncodeString:temp + 1];
    structType->elements = elements;
    
    return structType;
}
```

`BHSizeAndAlignment` 处理了字符串中的 encode，跳过了无用的 "}" 和数字。这里面的数字其实是内存地址偏移量。

```
static const char *BHSizeAndAlignment(const char *str, NSUInteger *sizep, NSUInteger *alignp, long *lenp)
{
    const char *out = NSGetSizeAndAlignment(str, sizep, alignp);
    if (lenp) {
        *lenp = out - str;
    }
    while(*out == '}') {
        out++;
    }
    while(isdigit(*out)) {
        out++;
    }
    return out;
}
```

`_ffiTypeForEncode` 方法中对 struct 的处理也得到了简化，只需调用 `_ffiTypeForStructEncode` 即可。经测试，struct 之间的嵌套都 OK。

## Return Struct on x86

在 x86 架构下，当 Block 返回值是大于 16 Byte 的 struct 时，其实现函数 `invoke` 的参数列表会发生变化：第一个参数不再是 Block 对象自己，而是指向 struct 返回值的指针。其余参数依次往后挪一位。Block 结构中 `flags` 里有一个 bit 标记了这个『潜规则』：

```
BLOCK_HAS_STRET =         (1 << 29)
```

那么在使用 libffi 定义 Hook 函数的返回值和参数列表的时候就需要注意了，虽然 signature 还是正常的，但是参数列表顺序调整了啊！当 `BLOCK_HAS_STRET` 生效时，得特殊处理下。`_typesWithEncodeString` 方法负责解析 signature 字符串中的 Type Encoding 列表，支持加偏移量。而 `_argsWithEncodeString` 是调用了前者，`startIndex` 传入 `1`，略过了第一个返回值。

```
int argCount;
ffi_type **argTypes;
ffi_type *returnType;
struct _BHBlock *bh_block = (__bridge void *)self.block;
if ((bh_block->flags & BLOCK_HAS_STRET)) {
    argTypes = [self _typesWithEncodeString:str getCount:&argCount startIndex:0];
    argTypes[0] = &ffi_type_pointer;
    returnType = &ffi_type_void;
    self.stret = YES;
    NSLog(@"Block has stret!");
}
else {
    argTypes = [self _argsWithEncodeString:str getCount:&argCount];
    returnType = [self _ffiTypeForEncode:str];
}
```

在 Hook 的处理函数 `BHFFIClosureFunc` 中，可以获取到 Block 调用时传入的参数。为了让使用方对 `BLOCK_HAS_STRET` 无感知，需要将参数和返回值『纠正』回正常的顺序，并通过 `BHToken` 提供给使用者。这样就实现了动态修改 Block 任意参数和返回值的功能。

`args` 是个指针数组，其中第一个指针又是个指向结构体返回值指针的指针，而 `token.retValue` 本应该是指向结构体返回值的指针。虽然有点绕，但是不难懂。

然而真的调用 Block 原实现的时候，还是需要用真正的参数列表和范沪指，所以加了 `realRetValue` 和 `realArgs` 分开存储原始传入的 `args` 和 `ret`。

```
static void BHFFIClosureFunc(ffi_cif *cif, void *ret, void **args, void *userdata)
{
    BHToken *token = (__bridge BHToken *)(userdata);
    if (token.hasStret) {
        // The first arg contains address of a pointer of returned struct.
        token.retValue = *((void **)args[0]);
        // Other args move backwards.
        token.args = args + 1;
    }
    else {
        token.retValue = ret;
        token.args = args;
    }
    token.realRetValue = ret;
    token.realArgs = args;
    if (BlockHookModeBefore == token.mode) {
        [token invokeHookBlock];
    }
    if (!(BlockHookModeInstead == token.mode && [token invokeHookBlock])) {
        [token invokeOriginalBlock];
    }
    if (BlockHookModeAfter == token.mode) {
        [token invokeHookBlock];
    }
    token.retValue = NULL;
    token.args = NULL;
    token.realRetValue = NULL;
    token.realArgs = NULL;
}
```

## 后记

在测试用例 [BlockHookSample_iOSTests.m](https://github.com/yulingtianxia/BlockHook/blob/master/BlockHookSample%20iOSTests/BlockHookSample_iOSTests.m) 文件中包含了一些常用的使用示例，还有一些诸如改 Block 参数和返回值的骚操作。大家如果在使用中发现任何问题，或者有新的诉求，欢迎来提 issue：https://github.com/yulingtianxia/BlockHook/issues

哎这个月实在没啥写的了，又水了一篇文章。
有的大佬都不怎么更新博客了，导致 iOS 业界水平停滞不前，进而导致我还是一如既往的菜。