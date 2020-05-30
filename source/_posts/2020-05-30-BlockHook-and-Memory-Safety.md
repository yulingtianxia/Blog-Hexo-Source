---
title: BlockHook and Memory Safety
date: 2020-05-30 17:25:58
tags:
- Objective-C
- Runtime
- BlockHook
---

[BlockHook](https://github.com/yulingtianxia/BlockHook) 最近修复了一些内存安全方面的问题，记录下这些问题的解决思路：

1. 微信项目使用 BlockHook 时的 MRC 兼容问题
2. GlobalBlock 在某些场景下的 VM Protection 没有写权限
3. 如何检测带有 Private Data 的 block

<!--more-->

## 修复 BlockHook 在 MRC 上的问题

ARC 下将 StackBlock 赋值时，会自动 copy 成 MallocBlock。不过这个编译器帮我们做的隐式行为的前提是代码里显示声明为 Block 类型。而 [BlockHook](https://github.com/yulingtianxia/BlockHook) 为了能够传入各种签名的 `aspectBlock`，恰恰用的是 `id`：

```
- (nullable BHToken *)block_hookWithMode:(BlockHookMode)mode
                              usingBlock:(id)aspectBlock;
```

如果调用方用的是 MRC，即便 [BlockHook](https://github.com/yulingtianxia/BlockHook) 是用 ARC 实现的，那么拿到的 `aspectBlock` 依然是 StackBlock。当被 Hook 的 Block 异步执行时，`aspectBlock` 也需要异步执行，但它早已经在栈上被释放，进而由于野指针而 crash。

这就是在微信项目里使用 [BlockHook](https://github.com/yulingtianxia/BlockHook) 时遇到的问题。当劳动节的下午我正出门去吃饭路上，微信的同事在企业微信上找到了我反馈了这个 bug。我由于路上匆忙没仔细看手机，一开始以为是我另一个同事找我。看问题截图上 Xcode 工程名我还以为他逆向调试微信用了 [BlockHook](https://github.com/yulingtianxia/BlockHook) 干啥坏事嘞，于是回了一句『你是真的牛逼』。再定神一看我擦是微信巨佬，虽然贼尴尬但只好装作没事一样继续看问题。。。扯远了。。。

微信巨佬果然是巨佬，还给了我解决方案。我照着巨佬给的思路，`copy` 了传入的 `aspectBlock`：

```
// If aspectBlock is a NSStackBlock and invoked asynchronously, it will cause a wild pointer. We copy it.
_aspectBlock = [aspectBlock copy];
```

## 解决 GlobalBlock 没有写权限的问题

用 Xcode 11 编译时，将 Deployment Info 中的 target 选择 iOS 13 后，GlobalBlock 对象所占的内存是只读的，这就导致 Hook 过程中无法对 `invoke` 函数指针做写操作，直接 crash。

首先需要判断下 `invoke` 指针对应的地址有没有写权限，如果没有写权限则需要提权。这涉及到 VM Region 和 Protection 的一些操作，在获取内存地址的基本信息时也要注意区分下 64 位和 32 位：

```
static vm_prot_t ProtectInvokeVMIfNeed(void *address) {
    vm_address_t addr = (vm_address_t)address;
    vm_size_t vmsize = 0;
    mach_port_t object = 0;
#if defined(__LP64__) && __LP64__
    vm_region_basic_info_data_64_t info;
    mach_msg_type_number_t infoCnt = VM_REGION_BASIC_INFO_COUNT_64;
    kern_return_t ret = vm_region_64(mach_task_self(), &addr, &vmsize, VM_REGION_BASIC_INFO, (vm_region_info_t)&info, &infoCnt, &object);
#else
    vm_region_basic_info_data_t info;
    mach_msg_type_number_t infoCnt = VM_REGION_BASIC_INFO_COUNT;
    kern_return_t ret = vm_region(mach_task_self(), &addr, &vmsize, VM_REGION_BASIC_INFO, (vm_region_info_t)&info, &infoCnt, &object);
#endif
    if (ret != KERN_SUCCESS) {
        NSLog(@"vm_region block invoke pointer failed! ret:%d, addr:%p", ret, address);
        return VM_PROT_NONE;
    }
    vm_prot_t protection = info.protection;
    if ((protection&VM_PROT_WRITE) == 0) {
        ret = vm_protect(mach_task_self(), (vm_address_t)address, sizeof(address), false, protection|VM_PROT_WRITE);
        if (ret != KERN_SUCCESS) {
            NSLog(@"vm_protect block invoke pointer VM_PROT_WRITE failed! ret:%d, addr:%p", ret, address);
            return VM_PROT_NONE;
        }
    }
    return protection;
}
```

在修改 `invoke` 指针后，还需要恢复原来的权限。相当于我只是在需要替换 `invoke` 指针的时候临时开了写权限：

```
static BOOL ReplaceBlockInvoke(struct _BHBlock *block, void *replacement) {
    void *address = &(block->invoke);
    vm_prot_t origProtection = ProtectInvokeVMIfNeed(address);
    if (origProtection == VM_PROT_NONE) {
        return NO;
    }
    block->invoke = replacement;
    if ((origProtection&VM_PROT_WRITE) == 0) {
        kern_return_t ret = vm_protect(mach_task_self(), (vm_address_t)address, sizeof(address), false, origProtection);
        if (ret != KERN_SUCCESS) {
            NSLog(@"vm_protect block invoke pointer REVERT failed! ret:%d, addr:%p", ret, address);
        }
    }
    return YES;
}
```

虽然我还没花时间去追查苹果爸爸为啥要在 Xcode 11 上 iOS 13 target 编译时给 GlobalBlock 只读权限，但理论上我的这个操作并不是对非法内存地址的提权，应该是被允许的，毕竟线上检测是否越狱等功能也会用到这些 API。但我还是不放心，请教了页面仔大佬后，答复是可以上架，终于安心了，也期待下个版本可以试试。

如果有大佬知道苹果爸爸为何会这样做，或者有更优雅更安全的方案，请给小弟赐教，欢迎指出缺陷，一起开源共建。

## 优化 BlockHook 检测 Private Data 的方式

在 [BlockHook with Private Data](http://yulingtianxia.com/blog/2019/06/19/BlockHook-with-Private-Data/) 这篇文章里我曾经介绍过一种『骨骼惊奇』的 Block，不能直接替换 `invoke` 函数指针来 Hook。当时判断这类带有 Private Data 的 Block 的依据是直接用 Private Data 中的 `dbpd_magic` 字段与 `DISPATCH_BLOCK_PRIVATE_DATA_MAGIC` 判等：

```
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

我知道这种暴力 Memory Overflow 的行为有潜在隐患，而且[调试时开启了 Address Sanitizer 后会必现 crash](https://github.com/yulingtianxia/BlockHook/issues/11)。当时这么做的原因我也在[文章](http://yulingtianxia.com/blog/2019/06/19/BlockHook-with-Private-Data/)里写了，GCD 源码中会检查 Block 的 `invoke` 指针是否为 `_dispatch_block_special_invoke`，以此判断 Block 是否包含 Private Data。而这个标志位指针是私有的，我无法在没有符号表的场景下获取到。现在想想当时的自己真是个 SB，当初这么简单的问题，其实现在换个思路不就解决了：

```
DISPATCH_ALWAYS_INLINE
static inline dispatch_block_private_data_t
bh_dispatch_block_get_private_data(struct _BHBlock *block) {
    if (!blockWithPrivateData) {
        blockWithPrivateData = dispatch_block_create(0, ^{});
    }
    if (block->invoke != ((__bridge struct _BHBlock *)blockWithPrivateData)->invoke) {
        return nil;
    }
    // Keep in sync with _dispatch_block_create implementation
    uint8_t *privateData = (uint8_t *)block;
    // privateData points to base of struct Block_layout
    privateData += sizeof(struct _BHBlock);
    // privateData points to base of captured dispatch_block_private_data_s object
    dispatch_block_private_data_t dbpd = (dispatch_block_private_data_t)privateData;
    if (dbpd->dbpd_magic != DISPATCH_BLOCK_PRIVATE_DATA_MAGIC) {
        return nil;
    }
    return dbpd;
}
```

既然无法直接拿到 `_dispatch_block_special_invoke` 指针，那我干脆创建一个带有 Private Data 的 Block 然后取它的 `invoke` 指针不就搞定了吗！现在看看当初的自己好傻啊。

## 最后谈谈 BlockHook

其实 [BlockHook](https://github.com/yulingtianxia/BlockHook) 的诞生纯属偶然，起初是我本想做些其他关于 Block 的事情，但技术太菜一直没搞成。一顿瞎折腾失败后，剩余的代码就是 [BlockHook](https://github.com/yulingtianxia/BlockHook) 的雏形。然后业余时间不断踩坑和填坑，收到用户反馈后不断打磨，最终搞出了个能用的版本。有时候兴趣带来的动力真的远超 KPI 的压力，让人干劲十足，哈哈。

我曾经吹牛说 [BlockHook](https://github.com/yulingtianxia/BlockHook) 『（应该是）填补了 Objective-C 业界在 Hook Block 技术领域的空白』，这件事也一直被五子棋嘲讽。后来他跟我说之前肯定有人做过这件事，不过记不清是哪个项目了。我也很想知道在这之前是否有人 Hook 过 Objective-C 的 Block，也跪求打脸并虚心接受。但我对 Hook 的理解并不是局限于替换个函数指针 IMP 就可以了，我个人觉得能配得上是 Hook/AOP 的框架，至少要满足下面几个要求中的大部分吧：

1. 用同一个 Hook 框架多次 Hook，能够有完整的 Hook 调用链。甚至能兼容其他框架。
2. 兼容 90% 以上的使用场景，经得住大规模验证（不一定线上，也可以是作为测试工具）。
3. 不能为了『轻量级』和高性能而去牺牲兼容性、鲁棒性和易用性，否则就是实现度不够。
4. 支持 Revert Hook，最好能 Revert Hook 链的中间节点，甚至能完美还原现场。

其实替换个函数指针并用 libffi 调用任意函数之类的事情随便找个人都会很快上手，如果就只做了这点事情我个人是不敢称其为 Hook/AOP 框架的。[BlockHook](https://github.com/yulingtianxia/BlockHook) 的大部分内容都是解决上面所列出的几点要求，并且自认为解决的还算不错。所以 [BlockHook](https://github.com/yulingtianxia/BlockHook) 是否填补了业界空白，就看大佬们如何看待 Hook 这件事情的定义了。PS: 可能会误伤一些人，千万别对号入座啊。我也曾经搞过『轻量级』的轮子，性能也牛逼，其实问题一堆实现度很低。我其实在吐槽我自己。。。

我本以为 [BlockHook](https://github.com/yulingtianxia/BlockHook) 打磨了这么久，应该没啥大问题了，然而还是不断有新的问题和挑战出现。毕竟自己曾经吹下了牛皮，含着泪也要继续打磨下去。
