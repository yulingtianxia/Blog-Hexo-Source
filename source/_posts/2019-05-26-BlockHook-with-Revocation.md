---
title: BlockHook with Revocation
date: 2019-05-26 17:20:10
tags:
- Objective-C
---

[BlockHook](https://github.com/yulingtianxia/BlockHook) 开创性地解决了 Objective-C 语言界 Hook Block 的问题，但也迎来了新的问题：

1. 如何知道某个 Block 对象被谁 Hook 过？
2. 多次 Hook 的先后顺序？
3. 如何处理好多次 Hook 同一个 Block 后对任意一次 Hook 的撤销？

这些问题也是开发者在使用时向我反馈过的问题，在这篇文章里，这些问题都将会解决。

关于 [BlockHook](https://github.com/yulingtianxia/BlockHook) 的原理，可以先阅读之前的文章：

- [Hook Objective-C Block with Libffi](http://yulingtianxia.com/blog/2018/02/28/Hook-Objective-C-Block-with-Libffi/)
- [BlockHook with Struct](http://yulingtianxia.com/blog/2019/04/27/BlockHook-with-Struct/)

<!--more-->

## 按顺序构造『虚拟的』 Hook 链表

首先要有一个链表来按先后顺序记录一个 Block 对象上所有的 Hook。这个链表的格式以及持有关系也需要考虑在内。

为此我构造了一个虚拟的链表来记录 Hook 的先后关系，而不是单独创建一个链表显式的记录。首先介绍下 Block 与 token 之间的引用关系：

![](https://raw.githubusercontent.com/yulingtianxia/Blog-Hexo-Source/master/source/resources/BlockHook/BlockHook Token List.png)

可以看出每个 `BHToken` 记录了原始和替换后的 `invoke` 函数指针，那么先后两次 Hook 就靠 `invoke` 函数指针来关联了：**每个 tokne 的 `originalInvoke` 就是上一次 Hook 的 token 的 `replacementInvoke`**。而拿到 token 又是靠 Block 对象上的 `AssociatedObject`，且 key 为 `replacementInvoke`。这样就构造了一条虚拟的链表：想要获得上次 Hook 的 token，只需在 Hook 的 Block 对象上使用 `originalInvoke` 作为 key 即可。

下面的代码展示了获取下个 token 的 `next` 实现。因为链表可能会有新的插入和删除节点操作，所以需确保线程安全。

```
- (BHToken *)next
{
    BHLock *lock = [self.block bh_lockForKey:@selector(next)];
    [lock lock];
    if (!_next) {
        _next = objc_getAssociatedObject(self.block, self.originInvoke);
    }
    BHToken *result = _next;
    [lock unlock];
    return result;
}
```

这里使用 `replacementInvoke` 来作为 `AssociatedObject` 的 key 真是**一举多得**：

1. 将 token 的生命周期绑定到 Block 对象上，实现 self-managed
2. 因为函数指针地址是唯一的，确保 Block 上关联每个 token 的 key 不会冲突
3. Block 的 `invoke` 指针作为 key，可以找到最后一次 Hook 的 token。进而按 Hook 先后顺序遍历出所有的 token。

下面的代码展示了如何获取最后一次 Hook 的 token。在读取 `invoke` 函数指针的时候，注意保证线程安全。

```
- (BHToken *)block_currentHookToken
{
    if (![self block_checkValid]) {
        return nil;
    }
    void *invoke = [self block_currentInvokeFunction];
    return objc_getAssociatedObject(self, invoke);
}

- (void *)block_currentInvokeFunction
{
    struct _BHBlock *bh_block = (__bridge void *)self;
    BHLock *lock = [self bh_lockForKey:_cmd];
    [lock lock];
    void *invoke = bh_block->invoke;
    [lock unlock];
    return invoke;
}
```

## 撤销 Hook

俗话说『请神容易送神难』。好多 Hook 框架只解决的如何 Hook，但是却无法撤销恢复原样，留下一堆烂摊子。

在搭建了 Hook 链表的基础上，多次 Hook 的链表可以简化成 `invoke` 函数指针之间的关系：

![](https://raw.githubusercontent.com/yulingtianxia/Blog-Hexo-Source/master/source/resources/BlockHook/BlockHook invoke call.png)

那么撤销 Hook 就可以从链表头部开始遍历，找到当前要 `remove` 的 token。接着链表上删除这个 token，而这又可以分为两个子问题：

1. 移除最后一次 Hook：需要将 Block 的 `invoke` 指针指向 token 的 `originalInvoke`。
2. 移除*非*最后一次 Hook：需要将上一次 Hook token 的 `originalInvoke` 指向当前 token 的 `originalInvoke`。

最后肯定还要解除 Block 对象对 token 的持有。

这部分逻辑的实现代码如下，在操作 Block 的 `invoke` 指针时依然需要注意线程安全问题：

```
- (BOOL)remove
{
    if (self.isStackBlock) {
        NSLog(@"Can't remove token for StackBlock!");
        return NO;
    }
    self.deadBlock = nil;
    if (self.originInvoke) {
        if (self.block) {
            BHToken *current = [self.block block_currentHookToken];
            BHToken *last = nil;
            while (current) {
                if (current == self) {
                    if (last) { // remove middle token
                        last.originInvoke = self.originInvoke;
                        last.next = nil;
                    }
                    else { // remove head(current) token
                        BHLock *lock = [self.block bh_lockForKey:@selector(block_currentInvokeFunction)];
                        [lock lock];
                        ((__bridge struct _BHBlock *)self.block)->invoke = self.originInvoke;
                        [lock unlock];
                    }
                    break;
                }
                last = current;
                current = [current next];
            }
        }
        self.originInvoke = NULL;
        objc_setAssociatedObject(self.block, _replacementInvoke, nil, OBJC_ASSOCIATION_RETAIN);
        return YES;
    }
    return NO;
}
```

## 总结

[BlockHook](https://github.com/yulingtianxia/BlockHook) 还在不断完善每一个细节，尽可能做到有始有终，至善尽美。