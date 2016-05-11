title: 关于 @synchronized，这儿比你想知道的还要多
date: 2015-11-01 11:58:23
tags:
- 翻译
- Objective-C

---
本文翻译自 [Ryan Kaplan](http://rykap.com/about/) 的 [More than you want to know about @synchronized](http://rykap.com/objective-c/2015/05/09/synchronized.html)  

因为原文一些内容写的不太准确，我按照我的理解做出了批注和补充。

<!--more-->

如果你已经使用 Objective-C 编写过任何并发程序，那么想必是见过 `@synchronized` 这货了。`@synchronized` 结构所做的事情跟锁（lock）类似：它防止不同的线程同时执行同一段代码。但在某些情况下，相比于使用 `NSLock` 创建锁对象、加锁和解锁来说，`@synchronized` 用着更方便，可读性更高。

> 译者注：这与苹果官方文档对 `@synchronized` 的介绍有少许出入，但意思差不多。苹果官方文档更强调它“防止不同的线程同时获取相同的锁”，因为文档在集中介绍多线程编程各种锁的作用，所以更强调“相同的锁”而不是“同一段代码”。

如果你之前没用过 `@synchronized`，接下来有个使用它的例子。这篇文章实质上是谈谈有关我对 `@synchronized` 实现原理的一个简短研究。

## 用到 @synchronized 的例子

假设我们正在用 Objective-C 实现一个线程安全的队列，我们一开始可能会这么干：

```
@implementation ThreadSafeQueue
{
    NSMutableArray *_elements;
    NSLock *_lock;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _elements = [NSMutableArray array];
        _lock = [[NSLock alloc] init];
    }
    return self;
}

- (void)push:(id)element
{
    [_lock lock];
    [_elements addObject:element];
    [_lock unlock];
}

@end
```

上面的 `ThreadSafeQueue` 类有个 `init` 方法，它初始化了一个 `_elements` 数组和一个 `NSLock` 实例。这个类还有个 `push:` 方法，它先获取锁、然后向数组中插入元素、最终释放锁。可能会有许多线程同时调用 `push:` 方法，但是 `[_elements addObject:element]` 这行代码在任何时候将只会在一个线程上运行。步骤如下：

1. 线程 A 调用 `push:` 方法
2. 线程 B 调用 `push:` 方法
3. 线程 B 调用 `[_lock lock]` - 因为当前没有其他线程持有锁，线程 B 获得了锁
4. 线程 A 调用 `[_lock lock]`，但是锁已经被线程 B 占了所以方法调用并没有返回-这会暂停线程 A 的执行
5. 线程 B 向 `_elements` 添加元素后调用 `[_lock unlock]`。当这些发生时，线程 A 的 `[_lock lock]` 方法返回，并继续将自己的元素插入 `_elements`。

我们可以用 `@synchronized` 结构更简要地实现这些：

```
@implementation ThreadSafeQueue
{
    NSMutableArray *_elements;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _elements = [NSMutableArray array];
    }
    return self;
}

- (void)increment
{
    @synchronized (self) {
        [_elements addObject:element];
    }
}

@end
```

在前面的例子中，"synchronized block" 与 `[_lock lock]` 和 `[_lock unlock]` 效果相同。你可以把它当成是锁住 `self`，仿佛 `self` 就是个 `NSLock`。锁在左括号 `{` 后面的任何代码运行之前被获取到，在右括号 `}` 后面的任何代码运行之前被释放掉。这爽就爽在妈妈再也不用担心我忘记调用 `unlock` 了！

你可以给任何 Objective-C 对象上加个 `@synchronized`。那么我们也可以在上面的例子中用 `@synchronized(_elements)` 来替代 `@synchronized(self)`，效果是相同的。

## 回到研究上来

我对 `@synchronized` 的实现十分好奇并搜了一些它的细节。我[找到了](http://stackoverflow.com/questions/1215330/how-does-synchronized-lock-unlock-in-objective-c)[一些](http://stackoverflow.com/questions/1215765/changing-the-locking-object-insde-synchronized-section)[答案](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Multithreading/ThreadSafety/ThreadSafety.html#//apple_ref/doc/uid/10000057i-CH8-SW3)，但这些解释都没有达到我想要的深度。锁是如何与你传入 `@synchronized` 的对象关联上的？`@synchronized`会保持（retain，增加引用计数）被锁住的对象么？假如你传入 `@synchronized` 的对象在 `@synchronized` 的 block 里面被释放或者被赋值为 `nil` 将会怎么样？这些全都是我想回答的问题。而我这次的收获，会要你好看😏。

`@synchronized` 的[文档](https://developer.apple.com/library/mac/documentation/Cocoa/Conceptual/Multithreading/ThreadSafety/ThreadSafety.html#//apple_ref/doc/uid/10000057i-CH8-SW3)告诉我们 `@synchronized` block 在被保护的代码上暗中添加了一个异常处理。为的是同步某对象时如若抛出异常，锁会被释放掉。

[SO 上的这篇帖子](http://stackoverflow.com/questions/1215330/how-does-synchronized-lock-unlock-in-objective-c/6047218#6047218) 说 `@synchronized` block 会变成 `objc_sync_enter` 和 `objc_sync_exit` 的成对儿调用。我们不知道这些函数是干啥的，但基于这些事实我们可以认为编译器将这样的代码：

```
@synchronized(obj) {
    // do work
}
```

转化成这样的东东：

```
@try {
    objc_sync_enter(obj);
    // do work
} @finally {
    objc_sync_exit(obj);    
}
```

`objc_sync_enter` 和 `objc_sync_exit` 是什么鬼？它们是如何实现的？在 Xcode 中按住 Command 键单击它们，然后进到了 `<objc/objc-sync.h>`，里面有我们感兴趣的这两个函数：

```
/** 
 * Begin synchronizing on 'obj'.  
 * Allocates recursive pthread_mutex associated with 'obj' if needed.
 * 
 * @param obj The object to begin synchronizing on.
 * 
 * @return OBJC_SYNC_SUCCESS once lock is acquired.  
 */
OBJC_EXPORT  int objc_sync_enter(id obj)
    __OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_2_0);

/** 
 * End synchronizing on 'obj'. 
 * 
 * @param obj The objet to end synchronizing on.
 * 
 * @return OBJC_SYNC_SUCCESS or OBJC_SYNC_NOT_OWNING_THREAD_ERROR
 */
OBJC_EXPORT  int objc_sync_exit(id obj)
    __OSX_AVAILABLE_STARTING(__MAC_10_3, __IPHONE_2_0);
```

文件底部的一句话提醒着我们：苹果工程师也是人啊哈哈

```
// The wait/notify functions have never worked correctly and no longer exist.
OBJC_EXPORT  int objc_sync_wait(id obj, long long milliSecondsMaxWait) 
    UNAVAILABLE_ATTRIBUTE;
OBJC_EXPORT  int objc_sync_notify(id obj) 
    UNAVAILABLE_ATTRIBUTE;
OBJC_EXPORT  int objc_sync_notifyAll(id obj) 
    UNAVAILABLE_ATTRIBUTE;
```

> 译者注: 此处原文摘抄的源码较旧，所以我替换上了最新的头文件源码。

不过，`objc_sync_enter` 的文档告诉我们一些新东西： `@synchronized` 结构在工作时为传入的对象分配了一个递归锁。分配工作何时发生，如何发生呢？它怎样处理 `nil`？幸运的是 Objective-C runtime 是开源的，所以我们可以马上阅读源码并找到答案！

注：递归锁在被同一线程重复获取时不会产生死锁。你可以在[这](https://en.wikipedia.org/wiki/Reentrant_mutex#Example)找到一个它工作原理的精巧案例。有个叫做 `NSRecursiveLock` 的现成的类也是这样的，你可以试试。

你可以在[这里](http://www.opensource.apple.com/source/objc4/objc4-646/runtime/objc-sync.mm)找到 `objc-sync` 的全部源码，但我要带着你看源码，让你屌的飞起。我们先从文件顶部的数据结构开始看。在代码块的下方我将立刻做出解释，所以尝试理解代码时别花太长时间哦。

```
typedef struct SyncData {
    id object;
    recursive_mutex_t mutex;
    struct SyncData* nextData;
    int threadCount;
} SyncData;

typedef struct SyncList {
    SyncData *data;
    spinlock_t lock;
} SyncList;

// Use multiple parallel lists to decrease contention among unrelated objects.
#define COUNT 16
#define HASH(obj) ((((uintptr_t)(obj)) >> 5) & (COUNT - 1))
#define LOCK_FOR_OBJ(obj) sDataLists[HASH(obj)].lock
#define LIST_FOR_OBJ(obj) sDataLists[HASH(obj)].data
static SyncList sDataLists[COUNT];
```

一开始，我们有一个 `struct SyncData` 的定义。这个结构体包含一个 `object`（嗯就是我们给 `@synchronized` 传入的那个对象）和一个有关联的 `recursive_mutex_t`，它就是那个跟 `object` 关联在一起的锁。每个 `SyncData` 也包含一个指向另一个 `SyncData` 对象的指针，叫做 `nextData`，所以你可以把每个 `SyncData` 结构体看做是链表中的一个元素。最后，每个 `SyncData` 包含一个 `threadCount`，这个 `SyncData` 对象中的锁会被一些线程使用或等待，`threadCount` 就是此时这些线程的数量。它很有用处，因为 `SyncData` 结构体会被缓存，`threadCount==0` 就暗示了这个 `SyncData` 实例可以被复用。

下面是 `struct SyncList` 的定义。正如我在上面提过，你可以把 `SyncData` 当做是链表中的节点。每个 `SyncList` 结构体都有个指向 `SyncData` 节点链表头部的指针，也有一个用于防止多个线程对此列表做并发修改的锁。

上面代码块的最后一行是 `sDataLists` 的声明 - 一个 `SyncList` 结构体数组，大小为16。通过定义的一个哈希算法将传入对象映射到数组上的一个下标。值得注意的是这个哈希算法设计的很巧妙，是将对象指针在内存的地址转化为无符号整型并右移五位，再跟 `0xF` 做按位与运算，这样结果不会超出数组大小。 `LOCK_FOR_OBJ(obj)` 和 `LIST_FOR_OBJ(obj)` 这俩宏就更好理解了，先是哈希出对象的数组下标，然后取出数组对应元素的 `lock` 或 `data`。一切都是这么顺理成章哈。

当你调用 `objc_sync_enter(obj)` 时，它用 `obj` 内存地址的哈希值查找合适的 `SyncData`，然后将其上锁。当你调用 `objc_sync_exit(obj)` 时，它查找合适的 `SyncData` 并将其解锁。

> 译者注：上面的源码和几段解释有些原文解释不清和疏漏的地方，我看了源码后按照自己的理解进行了补充和修正。

噢耶！现在我们知道了 `@synchronized` 如何将一个锁和你正在同步的对象关联起来，我希望聊聊当一个对象在 `@synchronized` block 当中被释放或设为 `nil` 时会发生什么。

如果你看了源码，你会注意到 `objc_sync_enter` 里面没有 `retain` 和 `release`。所以它要么没有保持传递给它的对象，要么或是在 ARC 下被编译。我们可以用下面的代码来做个测试：

```
NSDate *test = [NSDate date];
// This should always be `1`
NSLog(@"%@", @([test retainCount]));

@synchronized (test) {

    // This will be `2` if `@synchronized` somehow
    // retains `test`
    NSLog(@"%@", @([test retainCount]));
}
```

两次输出结果都是 `1`。那么 `objc_sync_enter` 貌似是没保持被传入的对象啊。这就有趣了。如果你正在同步的对象被释放了，然后有可能另一个新的对象在此处（被释放对象的内存地址）被分配内存。有可能某个其他的线程试着去同步那个新的对象（就是那个在被释放的旧对象的内存地址上刚刚新创建的对象）。在这种情况下，另一个线程将会阻塞，直到当前线程结束它的同步 block。这看起来并不是很糟。这听起来像是这种事情实现者早就知道并予以接受。我没有遇到过任何好的替代方案。

假如对象在 "synchronized block" 中被设成 `nil` 呢？我们回顾下我们“拿衣服（naive）”的实现吧：

```
NSString *test = @"test";
@try {
    // Allocates a lock for test and locks it
    objc_sync_enter(test);
    test = nil;
} @finally {
    // Passed `nil`, so the lock allocated in `objc_sync_enter`
    // above is never unlocked or deallocated
    objc_sync_exit(test);   
}
```

`objc_sync_enter` 被调用时传入的是 `test` 而 `objc_sync_exit` 被调用时传入的是 `nil`。而传入 `nil` 的时候 `objc_sync_exit` 是个空操作，所以将不会有人释放锁。这真操蛋！

如果 `Objective-C` 容易受这种情况的影响，我们知道么？下面的代码调用 `@synchronized` 并在 `@synchronized` block 中将一个指针设为 `nil`。然后在后台线程对指向同一个对象的指针调用 `@synchronized`。如果在 `@synchronized` block 中设置一个对象为 `nil` 会让锁死锁，那么在第二个 `@synchronized` 中的代码将永远不会执行。我们将不会在控制台中看见任何东西打印出来。

```
NSNumber *number = @(1);
NSNumber *thisPtrWillGoToNil = number;

@synchronized (thisPtrWillGoToNil) {
    /**
     * Here we set the thing that we're synchronizing on to `nil`. If
     * implemented naively, the object would be passed to `objc_sync_enter`
     * and `nil` would be passed to `objc_sync_exit`, causing a lock to
     * never be released.
     */
    thisPtrWillGoToNil = nil;
}

dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^ {

    NSCAssert(![NSThread isMainThread], @"Must be run on background thread");

    /**
     * If, as mentioned in the comment above, the synchronized lock is never
     * released, then we expect to wait forever below as we try to acquire
     * the lock associated with `number`.
     *
     * This doesn't happen, so we conclude that `@synchronized` must deal
     * with this correctly.
     */
    @synchronized (number) {
        NSLog(@"This line does indeed get printed to stdout");
    }

});
```

 当我们执行上面的代码时，那行代码**确实**打印到控制台了！所以 Objective-C 很好地处理了这种情形。我打赌是编译器做了类似下面的事情来解决这事儿的。
 
```
NSString *test = @"test";
id synchronizeTarget = (id)test;
@try {
    objc_sync_enter(synchronizeTarget);
    test = nil;
} @finally {
    objc_sync_exit(synchronizeTarget);   
}
```

用这种方式实现的话，传递给 `objc_sync_enter` 和 `objc_sync_exit` 总是相同的对象。他们在传入 `nil` 时都是空操作。这带来了个棘手的 debug 场景：如果你向 `@synchronized` 传递 `nil`，那么你就不会得到任何锁而且你的代码将不会是线程安全的！如果你想知道为什么你正收到出乎意料的竞态（race），确保你没向你的 `@synchronized` 传入 `nil`。你可以在 `objc_sync_nil` 上设置一个符号断点来达到此目的。`objc_sync_nil` 是一个空方法，当 `objc_sync_enter` 函数被传入 `nil` 时会被调用，折让 debug 更容易些。

> 译者注：下面是 `objc_sync_enter` 的源码，主要逻辑很容易看懂，加深理解 `objc_sync_nil`：
```
int objc_sync_enter(id obj)
{
    int result = OBJC_SYNC_SUCCESS;

    if (obj) {
        SyncData* data = id2data(obj, ACQUIRE);
        require_action_string(data != NULL, done, result = OBJC_SYNC_NOT_INITIALIZED, "id2data failed");
	
        result = recursive_mutex_lock(&data->mutex);
        require_noerr_string(result, done, "mutex_lock failed");
    } else {
        // @synchronized(nil) does nothing
        if (DebugNilSync) {
            _objc_inform("NIL SYNC DEBUG: @synchronized(nil); set a breakpoint on objc_sync_nil to debug");
        }
        objc_sync_nil();
    }

done: 
    return result;
}
```

这回答了我眼下的问题。

1. 你调用 `sychronized` 的每个对象，Objective-C runtime 都会为其分配一个递归锁并存储在哈希表中。
2. 如果在 `sychronized` 内部对象被释放或被设为 `nil` 看起来都 OK。不过这没在文档中说明，所以我不会再生产代码中依赖这条。
3. 注意不要向你的 `sychronized` block 传入 `nil`！这将会从代码中移走线程安全。你可以通过在 `objc_sync_nil` 上加断点来查看是否发生了这样的事情。

研究的下一步将是研究下 "synchronized block" 输出的汇编，看看它是否跟我上面的例子相似。我打赌 `@synchronized` block 的汇编输出不会跟任何我们设计的 Objective-C 代码相同，上面的代码充其量是 `@synchronized` 的工作模型。你能想到更好的模型么？我的模型在哪些情形下会有瑕疵么？告诉我吧！