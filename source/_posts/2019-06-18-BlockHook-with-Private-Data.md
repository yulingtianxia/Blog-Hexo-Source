---
title: BlockHook with Private Data
date: 2019-06-18 17:00:39
tags:
---

在使用 [BlockHook](https://github.com/yulingtianxia/BlockHook) Hook 所有 Block 对象时，发现有些 Block 被 Hook 后会 Crash。究其原因发现是它们骨骼惊奇，夹带了很多『私货』，不能直接 Hook！本文讲述 [BlockHook](https://github.com/yulingtianxia/BlockHook) 在处理这种 Block 时的技术原理，解开含有 Private Data 的 Block 的神秘面纱。

<!--more-->

其实我完全可以当回标题党，把这篇文章的标题叫做『你真的了解 Block 么？』或者『这才是 Hook Block 的正确姿势』之类的。想想还是算了吧，怕被大佬们嘲笑称又『改变业界』了啊。

## Block 为何会有 Private Data

首先来看一段代码：

```
dispatch_block_t block = dispatch_block_create(0, ^{
    NSLog(@"I'm dispatch_block_t");
});
```

用 `dispatch_block_create` 创建的 Block 都很特殊，返回的 Block 包含了参数里传入的 Block。此时 `dispatch_block_t` 虽然表面上是一种普通的 Block，但它的构造暗藏玄机，含有 Private Data，下面会详细解读。

### 特殊的 invoke 函数

这种 Block 的 `invoke` 函数指针是固定的，函数名为 `___dispatch_block_create_block_invoke`。在 linux 系统下，函数名为 `__dispatch_block_create_block_invoke`，嗯少了个下划线。这个函数的定义来自 libdispatch.dylib，也就是我们常用的 GCD。

```
extern "C" {
// The compiler hides the name of the function it generates, and changes it if
// we try to reference it directly, but the linker still sees it.
extern void DISPATCH_BLOCK_SPECIAL_INVOKE(void *)
#ifdef __linux__
		asm("___dispatch_block_create_block_invoke");
#else
		asm("____dispatch_block_create_block_invoke");
#endif
void (*const _dispatch_block_special_invoke)(void*) = DISPATCH_BLOCK_SPECIAL_INVOKE;
}
```

libdispatch 会通过判断 Block 的 `invoke` 指针是否为 `_dispatch_block_special_invoke`，来知道这个 Block 是否含有 Private Data。

```
DISPATCH_ALWAYS_INLINE
static inline bool
_dispatch_block_has_private_data(const dispatch_block_t block)
{
	return (_dispatch_Block_invoke(block) == _dispatch_block_special_invoke);
}
```

不幸的是，`_dispatch_block_special_invoke` 是私有的。在非调试场景下是无法通过 `dladdr` 等方式来获取它的函数名的。也就无法用类似上面的代码来判断 Block 是否含有 Private Data 了。

### 获取 Private Data

使用 `dispatch_block_create` 创建的 `dispatch_block_t` 只是个『壳』，真正执行的是其内部包含的 Block。再加上 GCD 所需的一些数据（queue，group，thread，priority 等），这些数据都需要作为 Private Data 追加在 Block 上。对实现 BlockHook 来说最需要关注的就是 `dbpd_magic` 和 `dbpd_block`。

```
OS_OBJECT_DECL_CLASS(voucher);

struct dispatch_block_private_data_s {
    unsigned long dbpd_magic;
    dispatch_block_flags_t dbpd_flags;
    unsigned int volatile dbpd_atomic_flags;
    int volatile dbpd_performed;
    unsigned long dbpd_priority;
    voucher_t dbpd_voucher;
    dispatch_block_t dbpd_block;
    dispatch_group_t dbpd_group;
    dispatch_queue_t dbpd_queue;
    mach_port_t dbpd_thread;
};
typedef struct dispatch_block_private_data_s *dispatch_block_private_data_t;
```

既然无法用 `_dispatch_block_special_invoke` 来判断 Block 是否含有 Private Data，可以使用 `dbpd_magic` 魔数来判断。当其值为 `0xD159B10C` 时（DisBloc 的意思），则表明含有 Private Data。

```
#define DISPATCH_BLOCK_PRIVATE_DATA_MAGIC 0xD159B10C // 0xDISPatch_BLOCk

DISPATCH_ALWAYS_INLINE
static inline dispatch_block_private_data_t
bh_dispatch_block_get_private_data(struct _BHBlock *block)
{
    // Keep in sync with _dispatch_block_create implementation
    uint8_t *x = (uint8_t *)block;
    // x points to base of struct Block_layout
    x += sizeof(struct _BHBlock);
    // x points to base of captured dispatch_block_private_data_s object
    dispatch_block_private_data_t dbpd = (dispatch_block_private_data_t)x;
    if (dbpd->dbpd_magic != DISPATCH_BLOCK_PRIVATE_DATA_MAGIC) {
        return nil;
    }
    return dbpd;
}
```

最后真正执行的其实是 `dbpd_block` 这个 Block，`dispatch_block_t` 只是个保存各种元数据的壳。

## 适配 BlockHook

### Hook 真正的 Block

既然 `dbpd_block` 才是真正要执行的 Block，那么 Hook 的时候需要先获取 Private Data，然后对其 `dbpd_block` 进行 Hook:

```
- (BHToken *)block_hookWithMode:(BlockHookMode)mode
                     usingBlock:(id)aspectBlock
{
    if (!aspectBlock || ![self block_checkValid]) {
        return nil;
    }
    struct _BHBlock *bh_block = (__bridge void *)self;
    if (!_bh_Block_descriptor_3(bh_block)) {
        NSLog(@"Block has no signature! Required ABI.2010.3.16. %@", self);
        return nil;
    }
    // Handle blocks have private data.
    dispatch_block_private_data_t dbpd = bh_dispatch_block_get_private_data(bh_block);
    if (dbpd && dbpd->dbpd_block) {
        return [dbpd->dbpd_block block_hookWithMode:mode usingBlock:aspectBlock];
    }
    return [[BHToken alloc] initWithBlock:self mode:mode aspectBlockBlock:aspectBlock];
}
```

### 获取当前 Hook Token

因为 Hook 的是 `dbpd_block`，所以获取 Token 的时候也需要额外处理下。要在 `dbpd_block` 上通过 AssociatedObject 来获取 Token，而不是 `dispatch_block_t` 上。

```
- (BHToken *)block_currentHookToken
{
    if (![self block_checkValid]) {
        return nil;
    }
    dispatch_block_private_data_t dbpd = bh_dispatch_block_get_private_data((__bridge struct _BHBlock *)(self));
    if (dbpd && dbpd->dbpd_block) {
        return [dbpd->dbpd_block block_currentHookToken];
    }
    void *invoke = [self block_currentInvokeFunction];
    return objc_getAssociatedObject(self, invoke);
}
```

## 总结

一图以蔽之。

![](https://github.com/yulingtianxia/Blog-Hexo-Source/blob/master/source/resources/BlockHook/BlockHook%20PrivateData.png?raw=true)