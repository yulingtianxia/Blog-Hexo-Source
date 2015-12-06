title: Objective-C 引用计数原理
date: 2015-12-06 16:32:07
tags:
- Objective-C
- Runtime

---

- 本文所使用的源码为 objc4-647 和 CF-1153.18
- 实际上这是我本周实习周报的一部分，写的比较仓促，如有差错还请多多指正。
- 不讲用法，只说原理。

<!--more-->

#引用计数如何存储

有些对象如果支持使用 TaggedPointer，苹果会直接将其指针值作为引用计数返回；如果当前设备是 64 位环境并且使用 Objective-C 2.0，那么“一些”对象会使用其 `isa` 指针的一部分空间来存储它的引用计数；否则 Runtime 会使用一张散列表来管理引用计数。

其实还有一种情况会改变引用计数的存储策略，那就是是否使用垃圾回收（用`UseGC`属性判断），但这种早已弃用的东西就不要管了，而且初始化垃圾回收机制的 `void gc_init(BOOL wantsGC)` 方法一直被传入 `NO`。

## TaggedPointer

判断当前对象是否在使用 TaggedPointer 是看标志位是否为 1 ：

```
#if SUPPORT_MSB_TAGGED_POINTERS
#   define TAG_MASK (1ULL<<63)
#else
#   define TAG_MASK 1

inline bool 
objc_object::isTaggedPointer() 
{
#if SUPPORT_TAGGED_POINTERS
    return ((uintptr_t)this & TAG_MASK);
#else
    return false;
#endif
}
```

`id` 其实就是 `objc_object *` 的简写（`typedef struct objc_object *id;
`），它的 `isTaggedPointer()` 方法经常会在操作引用计数时用到，因为这决定了存储引用计数的策略。

## isa 指针（NONPOINTER_ISA）

用 64 bit 存储一个内存地址显然是种浪费，毕竟很少有那么大内存的设备。于是可以优化存储方案，用一部分额外空间存储其他内容。`isa` 指针第一位为 1 即表示使用优化的 `isa` 指针，这里列出不同架构下的 64 位环境中 `isa` 指针结构：


```
union isa_t 
{
    isa_t() { }
    isa_t(uintptr_t value) : bits(value) { }

    Class cls;
    uintptr_t bits;

#if SUPPORT_NONPOINTER_ISA
# if __arm64__
#   define ISA_MASK        0x00000001fffffff8ULL
#   define ISA_MAGIC_MASK  0x000003fe00000001ULL
#   define ISA_MAGIC_VALUE 0x000001a400000001ULL
    struct {
        uintptr_t indexed           : 1;
        uintptr_t has_assoc         : 1;
        uintptr_t has_cxx_dtor      : 1;
        uintptr_t shiftcls          : 30; // MACH_VM_MAX_ADDRESS 0x1a0000000
        uintptr_t magic             : 9;
        uintptr_t weakly_referenced : 1;
        uintptr_t deallocating      : 1;
        uintptr_t has_sidetable_rc  : 1;
        uintptr_t extra_rc          : 19;
#       define RC_ONE   (1ULL<<45)
#       define RC_HALF  (1ULL<<18)
    };

# elif __x86_64__
#   define ISA_MASK        0x00007ffffffffff8ULL
#   define ISA_MAGIC_MASK  0x0000000000000001ULL
#   define ISA_MAGIC_VALUE 0x0000000000000001ULL
    struct {
        uintptr_t indexed           : 1;
        uintptr_t has_assoc         : 1;
        uintptr_t has_cxx_dtor      : 1;
        uintptr_t shiftcls          : 44; // MACH_VM_MAX_ADDRESS 0x7fffffe00000
        uintptr_t weakly_referenced : 1;
        uintptr_t deallocating      : 1;
        uintptr_t has_sidetable_rc  : 1;
        uintptr_t extra_rc          : 14;
#       define RC_ONE   (1ULL<<50)
#       define RC_HALF  (1ULL<<13)
    };

# else
    // Available bits in isa field are architecture-specific.
#   error unknown architecture
# endif

// SUPPORT_NONPOINTER_ISA
#endif

};
```

`SUPPORT_NONPOINTER_ISA` 用于标记是否支持优化的 `isa` 指针，其字面含义意思是 `isa` 的内容不再是类的指针了，而是包含了更多信息，比如引用计数，析构状态，被其他 weak 变量引用情况。判断方法也是根据设备类型：

```
// Define SUPPORT_NONPOINTER_ISA=1 to enable extra data in the isa field.
#if !__LP64__  ||  TARGET_OS_WIN32  ||  TARGET_IPHONE_SIMULATOR  ||  __x86_64__
#   define SUPPORT_NONPOINTER_ISA 0
#else
#   define SUPPORT_NONPOINTER_ISA 1
#endif
```

综合看来目前只有 arm64 架构的设备支持，下面列出了 `isa` 指针中变量对应的含义：

| 变量名  | 含义|
| ------------- | ------------- |
| indexed  | 0 表示普通的 `isa` 指针，1 表示使用优化，存储引用计数  |
| has_assoc  | 表示该对象是否包含 associated object，如果没有，则析构时会更快 |
| has_cxx_dtor | 表示该对象是否有 C++ 或 ARC 的析构函数，如果没有，则析构时更快|
| shiftcls | 类的指针 |
| magic | 固定值为 0xd2，用于在调试时分辨对象是否未完成初始化。
| weakly_referenced | 表示该对象是否有过 `weak` 对象，如果没有，则析构时更快 |
| deallocating | 表示该对象是否正在析构 |
| has_sidetable_rc | 表示该对象的引用计数值是否过大无法存储在 `isa` 指针 |
| extra_rc | 存储引用计数值减一后的结果 |

在 64 位环境下，优化的 `isa` 指针并不是就一定会存储引用计数，毕竟用 19bit （iOS 系统）保存引用计数不一定够。需要注意的是这 19 位保存的是**引用计数的值减一**。`has_sidetable_rc` 的值如果为 1，那么引用计数会存储在一个叫 `SideTable` 的类的属性中，后面会详细讲。

## 散列表

散列表来存储引用计数具体是用 `DenseMap` 类来实现，这个类中包含好多映射实例到其引用计数的键值对，并支持用 `DenseMapIterator` 迭代器快速查找遍历这些键值对。接着说键值对的格式：键的类型为 `DisguisedPtr<objc_object>`，`DisguisedPtr` 类是对 `objc_object *` 指针及其一些操作进行的封装，目的就是为了让它给人看起来不会有内存泄露的样子（真是心机裱），其内容可以理解为对象的内存地址；值的类型为 `__darwin_size_t`，在 darwin 内核一般等同于 `unsigned long`。其实这里保存的值也是等于**引用计数减一**。使用散列表保存引用计数的设计很好，即使出现故障导致对象的内存块损坏，只要引用计数表没有被破坏，依然可以顺藤摸瓜找到内存块的位置。

之前说引用计数表是个散列表，这里简要说下散列的方法。有个专门处理键的 `DenseMapInfo` 结构体，它针对 `DisguisedPtr` 做了些优化匹配键值速度的方法：

```
struct DenseMapInfo<DisguisedPtr<T>> {
  static inline DisguisedPtr<T> getEmptyKey() {
    return DisguisedPtr<T>((T*)(uintptr_t)-1);
  }
  static inline DisguisedPtr<T> getTombstoneKey() {
    return DisguisedPtr<T>((T*)(uintptr_t)-2);
  }
  static unsigned getHashValue(const T *PtrVal) {
      return ptr_hash((uintptr_t)PtrVal);
  }
  static bool isEqual(const DisguisedPtr<T> &LHS, const DisguisedPtr<T> &RHS) {
      return LHS == RHS; 
  }
};
```

当然这里的哈希算法会根据是否为 64 位平台来进行优化，算法具体细节就不深究了，我总觉得苹果在这里的 hardcode 是随便写的：

```
#if __LP64__
static inline uint32_t ptr_hash(uint64_t key)
{
    key ^= key >> 4;
    key *= 0x8a970be7488fda55;
    key ^= __builtin_bswap64(key);
    return (uint32_t)key;
}
#else
static inline uint32_t ptr_hash(uint32_t key)
{
    key ^= key >> 4;
    key *= 0x5052acdb;
    key ^= __builtin_bswap32(key);
    return key;
}
#endif
```

再介绍下 `SideTable` 这个类，它用于管理引用计数表和后面将要提到的 `weak` 表，并使用 `spinlock_lock` 自旋锁来防止操作表结构时可能的竞态条件。

#获取引用计数

在非 ARC 环境可以使用 `retainCount` 方法获取某个对象的引用计数，其会调用 `objc_object` 的 `rootRetainCount()` 方法：

```
- (NSUInteger)retainCount {
    return ((id)self)->rootRetainCount();
}
```

在 ARC 时代除了使用 Core Foundation 库的 `CFGetRetainCount()` 方法，也可以使用 Runtime 的 `_objc_rootRetainCount(id obj)` 方法来获取引用计数，此时需要引入 `<objc/runtime.h>` 头文件。这个函数也是调用 `objc_object` 的 `rootRetainCount()` 方法：

```
inline uintptr_t 
objc_object::rootRetainCount()
{
    assert(!UseGC);
    if (isTaggedPointer()) return (uintptr_t)this;

    sidetable_lock();
    isa_t bits = LoadExclusive(&isa.bits);
    if (bits.indexed) {
        uintptr_t rc = 1 + bits.extra_rc;
        if (bits.has_sidetable_rc) {
            rc += sidetable_getExtraRC_nolock();
        }
        sidetable_unlock();
        return rc;
    }

    sidetable_unlock();
    return sidetable_retainCount();
}
```

`rootRetainCount()` 方法对引用计数存储逻辑进行了判断，因为 TaggedPointer 前面已经说过了，可以直接获取引用计数；64 位环境优化的 `isa` 指针前面也说过了，所以这里的重头戏是在 TaggedPointer 无法使用时调用的 `sidetable_retainCount()` 方法：

```
uintptr_t
objc_object::sidetable_retainCount()
{
    SideTable *table = SideTable::tableForPointer(this);

    size_t refcnt_result = 1;
    
    spinlock_lock(&table->slock);
    RefcountMap::iterator it = table->refcnts.find(this);
    if (it != table->refcnts.end()) {
        // this is valid for SIDE_TABLE_RC_PINNED too
        refcnt_result += it->second >> SIDE_TABLE_RC_SHIFT;
    }
    spinlock_unlock(&table->slock);
    return refcnt_result;
}
```

`sidetable_retainCount()` 方法的逻辑就是先从 `SideTable` 的静态方法获取当前实例对应的 `SideTable` 对象，其 `refcnts` 属性就是之前说的存储引用计数的散列表，这里将其类型简写为 `RefcountMap`：

```
typedef objc::DenseMap<DisguisedPtr<objc_object>,size_t,true> RefcountMap;
```

然后在引用计数表中用迭代器查找当前实例对应的键值对，获取引用计数值，并在此基础上 **+1** 并将结果返回。这也就是为什么之前说**引用计数表存储的值为实际引用计数减一**。

需要注意的是为什么这里把键值对的值做了向右移位操作（`it->second >> SIDE_TABLE_RC_SHIFT`）:

```
#ifdef __LP64__
#   define WORD_BITS 64
#else
#   define WORD_BITS 32
#endif

// The order of these bits is important.
#define SIDE_TABLE_WEAKLY_REFERENCED (1UL<<0)
#define SIDE_TABLE_DEALLOCATING      (1UL<<1)  // MSB-ward of weak bit
#define SIDE_TABLE_RC_ONE            (1UL<<2)  // MSB-ward of deallocating bit
#define SIDE_TABLE_RC_PINNED         (1UL<<(WORD_BITS-1))

#define SIDE_TABLE_RC_SHIFT 2
#define SIDE_TABLE_FLAG_MASK (SIDE_TABLE_RC_ONE-1)RefcountMap
```

可以看出值的第一个 bit 表示该对象是否有过 `weak` 对象，如果没有，在析构释放内存时可以更快；第二个 bit 表示该对象是否正在析构。从第三个 bit 开始才是存储引用计数数值的地方。所以这里要做向右移两位的操作，而对引用计数的 +1 和 -1 可以使用 `SIDE_TABLE_RC_ONE`,还可以用 `SIDE_TABLE_RC_PINNED` 来判断是否引用计数值有可能溢出。

当然不能够完全信任这个 `_objc_rootRetainCount(id obj)` 函数，对于已释放的对象以及不正确的对象地址，有时也返回 “1”。它所返回的引用计数只是某个给定时间点上的值，该方法并未考虑到系统稍后会把自动释放吃池清空，因而不会将后续的释放操作从返回值里减去。clang 会尽可能把 `NSString` 实现成单例对象，其引用计数会很大。如果使用了 TaggedPointer，`NSNumber` 的内容**有可能**就不再放到堆中，而是直接写在宽敞的64位栈指针值里。其看上去和真正的 `NSNumber` 对象一样，只是使用 TaggedPointer 优化了下，但其引用计数可能不准确。

#修改引用计数

## retain 和 release

在非 ARC 环境下可以使用 `retain` 和 `release` 方法对引用计数进行加一减一操作，它们分别调用了 `_objc_rootRetain(id obj)` 和 `_objc_rootRelease(id obj)` 函数，不过后两者在 ARC 环境下也可使用。最后这两个函数又会调用 `objc_object` 的下面两个方法：

```
inline id 
objc_object::rootRetain()
{
    assert(!UseGC);

    if (isTaggedPointer()) return (id)this;
    return sidetable_retain();
}

inline bool 
objc_object::rootRelease()
{
    assert(!UseGC);

    if (isTaggedPointer()) return false;
    return sidetable_release(true);
}
```

这样的实现跟获取引用计数类似，先是看是否支持 TaggedPointer（毕竟数据存在栈指针而不是堆中，栈的管理本来就是自动的），否则去操作 `SideTable` 中的 `refcnts` 属性，这与获取引用计数策略类似。`sidetable_retain()` 将 引用计数加一后返回对象，`sidetable_release()` 返回是否要执行 `dealloc` 方法：

```
bool 
objc_object::sidetable_release(bool performDealloc)
{
#if SUPPORT_NONPOINTER_ISA
    assert(!isa.indexed);
#endif
    SideTable *table = SideTable::tableForPointer(this);

    bool do_dealloc = false;

    if (spinlock_trylock(&table->slock)) {
        RefcountMap::iterator it = table->refcnts.find(this);
        if (it == table->refcnts.end()) {
            do_dealloc = true;
            table->refcnts[this] = SIDE_TABLE_DEALLOCATING;
        } else if (it->second < SIDE_TABLE_DEALLOCATING) {
            // SIDE_TABLE_WEAKLY_REFERENCED may be set. Don't change it.
            do_dealloc = true;
            it->second |= SIDE_TABLE_DEALLOCATING;
        } else if (! (it->second & SIDE_TABLE_RC_PINNED)) {
            it->second -= SIDE_TABLE_RC_ONE;
        }
        spinlock_unlock(&table->slock);
        if (do_dealloc  &&  performDealloc) {
            ((void(*)(objc_object *, SEL))objc_msgSend)(this, SEL_dealloc);
        }
        return do_dealloc;
    }

    return sidetable_release_slow(table, performDealloc);
}
```

看到这里知道为什么在存储引用计数时**总是真正的引用计数值减一**了吧。因为 release 本来是要将引用计数减一，所以存储引用计数时先预留了个“一”，在减一之前先看看存储的引用计数值是否为 0 （`it->second < SIDE_TABLE_DEALLOCATING`），如果是，那就将对象标记为“正在析构”（`it->second |= SIDE_TABLE_DEALLOCATING`）,并发送 `dealloc` 消息，返回 `YES`；否则就将引用计数减一（`it->second -= SIDE_TABLE_RC_ONE`）。这样做避免了负数的产生。

除此之外，Core Foundation 库中也提供了增减引用计数的方法。比如在使用 Toll-Free Bridge 转换时使用的 `CFBridgingRetain` 和 `CFBridgingRelease` 方法，其本质是使用 `__bridge_retained` 和 `__bridge_transfer` 告诉编译器此处需要如何修改引用计数：

```
NS_INLINE CF_RETURNS_RETAINED CFTypeRef __nullable CFBridgingRetain(id __nullable X) {
    return (__bridge_retained CFTypeRef)X;
}

NS_INLINE id __nullable CFBridgingRelease(CFTypeRef CF_CONSUMED __nullable X) {
    return (__bridge_transfer id)X;
}
```

此外 Objective-C 很多实现是靠 Core Foundation Runtime 来实现， Objective-C Runtime 源码中有些地方明确注明："`// Replaced by CF`"，那就是意思说这块任务被 Core Foundation 库接管了。当然 Core Foundation 有一部分是开源的。还有一些 Objective-C Runtime 函数的实现被诸如 `ObjectAlloc` 和 `NSZombie` 这样的内存管理工具所替代：

```
// Replaced by ObjectAlloc
+ (id)allocWithZone:(struct _NSZone *)zone {
    return _objc_rootAllocWithZone(self, (malloc_zone_t *)zone);
}

// Replaced by CF (throws an NSException)
+ (id)init {
    return (id)self;
}

// Replaced by NSZombies
- (void)dealloc {
    _objc_rootDealloc(self);
}
```

## alloc, new, copy, mutableCopy

根据编译器的约定，这以这四个单词开头的方法都会使引用计数加一。而 `new` 相当于调用 `alloc` 后再调用 `init`：

```
id
_objc_rootAlloc(Class cls)
{
    return callAlloc(cls, false/*checkNil*/, true/*allocWithZone*/);
}
+ (id)alloc {
    return _objc_rootAlloc(self);
}
+ (id)new {
    return [callAlloc(self, false/*checkNil*/) init];
}
```

可以看出 `alloc` 和 `new` 最终都会调用 `callAlloc`，默认使用 Objective-C 2.0 且忽视垃圾回收和 NSZone，那么后续的调用顺序依次是为：

```
class_createInstance()
_class_createInstanceFromZone()
calloc()
```

`calloc()` 函数相比于 `malloc()` 函数的优点是它将分配的内存区域初始化为0，相当于 `malloc()` 后再用 `memset()` 方法初始化一遍。

`copy` 和 `mutableCopy` 都是基于 `NSCopying` 和 `NSMutableCopying` 方法约定，分别调用各类自己实现的 `copyWithZone:` 和 `mutableCopyWithZone:` 方法。这些方法无论实现方式是深拷贝还是浅拷贝，都会增加引用计数。（有些类的策略是懒拷贝，只增加引用计数但并不真的拷贝，等对象内容发生变化时再拷贝一份出来，比如 `NSArray`）。

在 `retain` 方法加符号断点会发现 `alloc`, `new`, `copy`, `mutableCopy` 这四个方法都会通过 Core Foundation 的 `CFBasicHashAddValue()` 函数来调用 `retain` 方法。其实 CF 有个修改和查看引用计数的入口函数 `__CFDoExternRefOperation`，在 `CFRuntime.c` 文件中实现。

## autorelease

本想贴上一堆 Runtime 中关于自动释放池的源码然后说上一大堆，然后发现了太阳神的这篇[黑幕背后的Autorelease](http://blog.sunnyxx.com/2014/10/15/behind-autorelease/)把我想说的都说了，把我不知道的也说了，简直太屌了。

其实通过看源码可以知道好多细节，没事点进去各种宏定义往往会得到惊喜：哇，原来是这么回事，XX 就是 XX 之类。。。

# Reference

http://www.sealiesoftware.com/blog/archive/2013/09/24/objc_explain_Non-pointer_isa.html

http://www.opensource.apple.com