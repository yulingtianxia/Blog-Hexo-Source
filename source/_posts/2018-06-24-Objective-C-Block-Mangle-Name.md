---
title: 追踪 Objective-C Block 代码定义的位置
date: 2018-06-24 17:19:03
tags:
- Objective-C
---

之前写了一篇文章[《追踪 Objective-C 方法中的 Block 参数对象》](http://yulingtianxia.com/blog/2018/03/31/Track-Block-Arguments-of-Objective-C-Method/)，利用 [BlockHook](https://github.com/yulingtianxia/BlockHook) 和 Objective-C 的动态特性实现对 block 对象执行和销毁的追踪。本文在此基础上，通过 Mach-O 文件格式获取 Mangle Name 并根据 Clang 源码实现对其解析，探寻如何追踪 block 代码定义的位置。

主要代码已经整合到 [BlockHook](https://github.com/yulingtianxia/BlockHook) 1.0.2 版本中。

<!--more-->

## 解决思路

能想到的最直接的方法就是获取 block 内部 invoke 函数的内存地址，并找到这个地址对应的 image，然后根据对基地址的偏移量，利用 dYSM 文件存储的符号表查找到对应代码位置。这属于很常规的操作了，即便没有 dYSM 文件，用 Mach-O 反汇编也能知道 block 定义在哪个方法的大概位置。

本文完？？？

太水了！！！

如果只需要知道 block 定义在哪个方法里的话，其实有更简单的方法呀！在程序运行时就能知道的，不用那么多麻烦的后续操作。解决思路如下：

1. 通过读取每个 Mach-O 镜像文件的符号表，建立 block invoke 函数偏移地址到符号名的映射。
2. 获取到的符号名是经过 Clang 处理后的 mangle name，根据生成规则反推出 block invoke 函数实现代码位置。

## Mach-O 文件格式

网上关于 Mach-O 文件的介绍一大堆，这里不再赘述。其实就是个二进制文件格式定义，照着文档写代码读二进制内容罢了。苹果也提供了 Mach-O 文件数据结构的定义，直接用就行了。当二进制镜像被加载到虚拟内存中后，就可以通过计算各种偏移量来按图索骥了。下面的代码将 `_hunt_blocks_for_image` 注册为镜像加载后的回调函数，这行代码执行前已经加载的镜像也会回调此函数：

```
_dyld_register_func_for_add_image(_hunt_blocks_for_image);
```

`_hunt_blocks_for_image` 函数会读取一个 Mach-O 文件中的符号表。具体操作是先从遍历 Load Commands 入手，找到 `__LINKEDIT` 段的基地址以及符号表数据的偏移量及其字符串表的偏移量。然后遍历符号表，获取到符号地址和符号名的偏移量。如果符号名中包含 `_block_invoke` 则说明是 block 实现函数，然后用字典保存符号地址到符号名的映射。

遍历 Load Commands 时要注意，不同类型的 Load Command 数据类型也不一样，但是肯定会有 `cmd` 和 `cmdsize` 这两个字段。可以凭借 `cmd` 简单区分其数据结构。比如符号表的 `cmd` 是 `LC_SYMTAB`，其数据结构为 `symtab_command`。比如常见的 `cmd` 为 `LC_SEGMENT` 的『段』可以靠 `segname` 区分，类型有 `__PAGEZERO` `__TEXT` `__DATA` `__LINKEDIT` `__OBJC` 等等，有的『段』下面还有很多『节』(Section)。`__PAGEZERO` 段在可执行文件才有，大小跟架构有关，是虚拟内存基地址。符号表是一个 `nlist` 数组，保存着每个符号的一些信息，这里只用到了符号地址和符号名。

因为使用 `NSMapTable` 存储符号地址和符号名的映射，所以需要用 `pthread_mutex_t` 确保线程安全。

`_hunt_blocks_for_image` 函数实现如下。我觉得我思想解释的够明白了，对于看过 fishhook 源码的人来说应该很简单。实在看不懂就自己对照着 MachOView 和苹果文档，随便找个方法计算一遍偏移量就好了。

```
static NSMapTable *block_invoke_mangle_cache;
static pthread_mutex_t block_invoke_mangle_cache_mutex;

static void _hunt_blocks_for_image(const struct mach_header *header, intptr_t slide) {
    Dl_info info;
    if (dladdr(header, &info) == 0) {
        return;
    }
    segment_command_t *cur_seg_cmd;
    segment_command_t *linkedit_segment = NULL;
    segment_command_t *pagezero_segment = NULL;
    struct symtab_command* symtab_cmd = NULL;
    
    uintptr_t cur = (uintptr_t)header + sizeof(mach_header_t);
    for (uint i = 0; i < header->ncmds; i++, cur += cur_seg_cmd->cmdsize) {
        cur_seg_cmd = (segment_command_t *)cur;
        if (cur_seg_cmd->cmd == LC_SEGMENT_ARCH_DEPENDENT) {
            if (strcmp(cur_seg_cmd->segname, SEG_LINKEDIT) == 0) {
                linkedit_segment = cur_seg_cmd;
            }
            else if (strcmp(SEG_PAGEZERO, cur_seg_cmd->segname) == 0) {
                pagezero_segment = (segment_command_t*)cur_seg_cmd;
            }
        } else if (cur_seg_cmd->cmd == LC_SYMTAB) {
            symtab_cmd = (struct symtab_command*)cur_seg_cmd;
        }
    }
    
    if (!symtab_cmd || !linkedit_segment ) {
        return;
    }
    
    uintptr_t linkedit_base = (uintptr_t)slide + linkedit_segment->vmaddr - linkedit_segment->fileoff;
    nlist_t *symtab = (nlist_t *)(linkedit_base + symtab_cmd->symoff);
    char *strtab = (char *)(linkedit_base + symtab_cmd->stroff);
    
    pthread_mutex_lock(&block_invoke_mangle_cache_mutex);
    
    if (!block_invoke_mangle_cache) {
        block_invoke_mangle_cache = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsOpaqueMemory | NSMapTableObjectPointerPersonality valueOptions:NSPointerFunctionsCopyIn];
    }
    
    for (uint i = 0; i < symtab_cmd->nsyms; i++) {
        uint32_t strtab_offset = symtab[i].n_un.n_strx;
        char *symbol_name = strtab + strtab_offset;
        bool symbol_name_longer_than_1 = symbol_name[0] && symbol_name[1];
        if (!symbol_name_longer_than_1) {
            continue;
        }
        uintptr_t block_addr = (uintptr_t)info.dli_fbase + symtab[i].n_value - (pagezero_segment ? pagezero_segment->vmsize : 0);
        NSString *symbolName = [NSString stringWithUTF8String:&symbol_name[1]];
        NSRange range = [symbolName rangeOfString:@"_block_invoke"];
        if (range.location != NSNotFound && range.location > 0) {
            [block_invoke_mangle_cache setObject:symbolName forKey:(__bridge id)(void *)block_addr];
        }
    }
    
    pthread_mutex_unlock(&block_invoke_mangle_cache_mutex);
}
```

## Block Mangle Name

Clang 7.0.0 源码的 [Mangle.cpp](https://clang.llvm.org/doxygen/Mangle_8cpp_source.html#l00060) 文件实现了 Objective-C 和 block 的 mangle name。只需要看 `mangleBlock` 和 `mangleGlobalBlock` 两个函数即可大概了解 block mangle name 的生成规则。

1. 全局 block：block 变量名 + `_block_invoke` + `discriminator`。详见 `mangleGlobalBlock` 函数实现。
2. 其他 block：`__` + block 代码所处的函数或方法的 mangle name + `_block_invoke` + `discriminator`。详见 `mangleBlock` 函数实现。

需要注意的是 `discriminator` 是从第二个才开始显示的。比如在 `Foo` 类的 `bar` 方法中定义了两个 block，那么这两个 block 的 mangle name 就是 `__10_-[Foo bar]_block_invoke` 和 `__10_-[Foo bar]_block_invoke_2`。在 gcc 里稍有区别，第一个 block 的 mangle name 也会显示 `discriminator`。前面的 "10" 是方法名 `-[Foo bar]` 的字符串长度。这部分属于 Objective-C 方法名的 mangle name 规则，C++ 函数也有类似的规则，不仅用数字保存字符串长度，还有其他字母表示方法类型和参数类型等。这里不展开细讲了，看源码都能找到。

于是只要能拿到 mangle name，就能推断出定义 block 代码所处的位置咯。不带 `__` 的就是全局 block 咯？我并没有打算写代码来解析下 mangle name 的规则，还是交给调用方去使用吧。

[BlockHook](https://github.com/yulingtianxia/BlockHook) 的 `BHToken` 类新增了 `mangleName` 属性，只需要使用原始的 invoke 函数地址作为 Key 即可从字典里获得这个 block 对应的 `mangleName`:

```
- (NSString *)mangleName
{
    if (!_mangleName) {
        pthread_mutex_lock(&block_invoke_mangle_cache_mutex);
        if (_originInvoke) {
            _mangleName = [block_invoke_mangle_cache objectForKey:(__bridge id)_originInvoke];
        }
        pthread_mutex_unlock(&block_invoke_mangle_cache_mutex);
    }
    return _mangleName;
}
```

这里有个多次 hook 的问题。所谓的 `_originInvoke` 只是这次 hook 相对的原始实现函数，它可能处在多次 hook 中的一环，而不是最原始的 block 实现，此时是拿不到 `mangleName`。所以需要用第一次 hook block 的 token 来获取 `mangleName`。PS:想搞倒是可以搞，把 hook block 产生的 token 都保存起来，然后按照 `_originInvoke` 和 `_replacementInvoke` 顺藤摸瓜就行，不难，顺便还能解决 `remove` 操作的顺序问题。我懒的搞，目前场景太小意义不大。

想了解 [BlockHook](https://github.com/yulingtianxia/BlockHook) 原理的，可以看这篇文章：[Hook Objective-C Block with Libffi](http://yulingtianxia.com/blog/2018/02/28/Hook-Objective-C-Block-with-Libffi/)。（继续疯狂炒冷饭。。。）

## 总结

目前 [BlockHook](https://github.com/yulingtianxia/BlockHook) 和 [BlockTracker](https://github.com/yulingtianxia/BlockTracker) 都已经支持获取 block 的 mangle name 了。

不知道 dyld 3 强制应用后会不会对此有影响，我就是遍历这个二进制文件自己的符号表而已呀，动态重定向的我又不 care。反正 fishhook 到时候估计是 gg 了，因为 dyld 3 会在加载时解析所有符号表，也就是固定下来了，没跳板了。

然而我还是这么菜，赶在月底前写了个篇幅短小全是常识的大水文。。。

本文完。。。

太水了！！！

