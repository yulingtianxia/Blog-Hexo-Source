---
title: Threading Programming Guide(3)
date: 2017-10-08 17:03:54
tags:
- 翻译
---

[Threading Programming Guide](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Multithreading/ThreadSafety/ThreadSafety.html#//apple_ref/doc/uid/10000057i-CH8-SW1) 的学习笔记&翻译，第三部分。关于同步的内容。

- [Threading Programming Guide(1)](http://yulingtianxia.com/blog/2017/08/28/Threading-Programming-Guide-1/)
- [Threading Programming Guide(2)](http://yulingtianxia.com/blog/2017/09/17/Threading-Programming-Guide-2/)

<!-- more -->

## 同步

两个线程同时修改同一个资源可能会不小心干扰到对方，多线程存取资源带来了潜在的线程安全问题。比如，一个线程可能会覆盖了另一个线程的修改，或者使应用置于未知混乱状态。如果幸运的话，错乱的资源可能会导致明显的性能问题或 crash 这类相对容易复现和解决的 bug；如果不太走运，面临的就是短时间难以重现的 bug 和对代码的全面排查。

为了线程安全，要尽量避免共享资源并减少线程间交互。即便有必须交互的地方，也需要使用同步工具来确保安全。

macOS 和 iOS 提供了许多同步工具，范围涵盖互斥操作工具到应用中的序列化事件。下面会介绍这些工具的使用方法。

### 同步工具

完全避免同步问题是理想方案，但并不现实。下面介绍几类基本的同步工具。

#### 原子操作

原子操作是对简单数据类型同步的一种简易形式。优点是不会阻塞竞争的线程。对于简单的操作，比如增加计数器变量的值，原子操作比锁拥有更好的性能。

macOS 和 iOS 包含许多基本的数学和逻辑运算的操作，可以在 32 位和 64 位上执行。其中就有 compare-and-swap, test-and-set 和 test-and-clear 操作的原子版本。 详见 `/usr/include/libkern/OSAtomic.h` 头文件，或 `atomic` man page。

#### 内存屏障和 `Volatile` 变量

编译器为了让性能达到最佳，会经常重排序汇编指令，这就有可能导致存取内存的顺序跟着变化，进而产生错误数据，影响到一些看似各自独立的变量。由于编译器优化造成对变量错误的更新顺序，产生了潜在的错误结果。

内存屏障（Memory Barrier）是一种非阻塞的同步工具，用来确保以正确的顺序操作内存。Memory Barrier 就像栅栏一样，强制处理器在栅栏之前的所有读写操作都执行后才可以开始执行栅栏之后的操作。内存屏障知识详见维基百科 [Memory Barrier](https://en.wikipedia.org/wiki/Memory_barrier)。可以在代码中调用 `OSMemoryBarrier` 函数添加内存屏障，详见 `OSMemoryBarrier` man page。

Volatile 关键字对单独的变量应用了另一种内存约束。编译器为了优化代码，会将变量的值加载到寄存器中。对于局部变量这没毛病，如果这个变量由别的线程更新了的话，将出现不一致的现象。Volatile 关键字可以用来提醒编译器它后面所定义的变量随时有可能改变，因此编译后的程序每次需要存储或读取这个变量的时候，都会直接从变量地址中读取数据。 如果一个变量可能在任何时候被外部资源修改，而编译器可能无法察觉，那么可以将其声明为 [volatile 变量](https://zh.wikipedia.org/wiki/Volatile变量)。

由于内存屏障和 volatile 变量都降低了编译器对代码的优化，除非万不得已，需慎用。

#### 锁

锁是最常用的同步工具之一，可以用它保护代码中的临界区域（critical section）。临界区域中的代码只允许同时被一个线程访问。其他线程对这块代码的修改都会被拒绝，因为会影响其正确性。

下表列出了程序员最常用的一些锁。macOS 和 iOS 提供了大部分锁的实现，那些没实现的锁也会有说明。

| 锁 | 描述 |
| --- | --- |
| Mutex | 互斥锁（Mutual exclusion，缩写Mutex）是多线程编程中一种对资源的保护机制，避免多个线程同时访问。如果互斥锁正在使用，其他线程需要等到它被释放后才能获取到。在同一时间只能有一个线程使用互斥锁。 |
| Recursive lock | 也叫重入锁或递归锁，是互斥锁的变种。重入锁允许同一条线程多次获得同一个锁，但也释放锁时也要释放对应的次数。重入锁主要用于递归程序或者多个方法都需要获得锁的场景。 |
| Read-write lock | 读写锁可以认为是一种共享版的互斥锁。如果对一个临界区大部分是读操作而只有少量的写操作，在大规模操作上应用读写锁可以显著降低线程互斥产生的代价。正常操作数据时，可以同时有多个读操作。线程想要做写操作时，需要等到所有的读操作完成并释放锁之后，然后写操作会获取锁并更新数据。在写操作线程阻塞等待锁被释放时，新来的读操作线程在写操作完成前会一直阻塞。系统只支持 POSIX 线程中使用读写锁。关于如何使用这些锁，详见 `pthread` man page。 |
| Distributed lock | 提供进程级别的互斥锁，但并不会真的阻塞进程，只是简单地向进程汇报锁正被占用，并让进程自己决定如何处理。 |
| Spin lock | 自旋锁会重复查询锁的条件，直到为 true。因为自旋锁属于在『死等』，它最常用在多核处理器系统上，且锁的等待时间很短，时间短到轮询比阻塞线程的开销还小（因为需要阻塞线程切换上下文和更新线程数据结构）。因为它的轮询性质，系统没有提供自旋锁的任何实现，在特定场景下可以自己实现。内核中实现自旋锁详见 [Kernel Programming Guide](https://developer.apple.com/library/content/documentation/Darwin/Conceptual/KernelProgramming/About/About.html#//apple_ref/doc/uid/TP30000905) |
| Double-checked lock | 双重检查锁试图减少并发系统中竞争和同步的开销。由于双重检查锁潜在地不安全性，系统不提供直接支持，不鼓励使用。 |

注意：大部分的锁也会纳入内存屏障来确保进入临界区域前的加载和存储指令已经完成。

#### 条件变量

Condition 是信号量的另一种类型，它允许线程在某个条件为 true 的时候，向其他线程发信号（signal）。通常用于标示资源的可用性或确保任务以特定的顺序执行。在进入临界区域时如果检查条件变量不为 true，线程会一直阻塞，直到某个其他线程 signal。与互斥锁的不同点在于 condition 允许被多个线程同时访问，它更像是个用某个特定标准筛查线程的门卫。

一种使用场景是管理即将发生的事件池。当队列中有事件到来时，使用条件变量对发信号（signal）。于是一个被唤醒的线程就可以从队列中获取并处理事件。如果有两个事件大致同时到达队列，会对 condition 发两次信号唤醒两个线程。

系统用几种不同的技术对 condition 提供支持。写这块代码需要谨慎，后面会给出示例。

#### Perform Selector 

Cocoa 提供了向一个活跃线程异步分发消息的便捷方式，也就是 `NSObject` 类的 `performSelector...` 系列方法。使用这些方法向线程发送的执行 `selector` 的请求会被目标线程的 run loop 按接收顺序执行。

详见 [Cocoa Perform Selector Sources](http://yulingtianxia.com/blog/2017/09/17/Threading-Programming-Guide-2/#Cocoa-Perform-Selector-Sources)。

### 同步开销与性能

同步机制在帮助确保代码正确性的同时也造成了性能代价。即便没有竞争，使用同步工具也会引发延迟。锁和原子操作为了确保充分保护代码，通常会需要使用内存屏障和内核级同步。如果存在对锁的竞争，线程会阻塞，经历甚至更久的延迟。

下表列出了非竞争场景下互斥锁和原子操作的一些大致开销。这些测量值取自几千个样本的均值。时间开销会随着处理器负荷、计算机速度以及系统程序的可用内存数量产生巨幅波动。

| 项目 | 大约的开销 | 注释 |
| --- | --- | --- |
| Mutex acquisition time | 大约 0.2 ms | 无竞争场景下获取锁的时间。如果锁已经被其他线程持有，获取锁的耗时还会更长。结果取自对均值和中位数的分析，运行系统为 macOS 10.5，配备基于Intel 2 GHz Core Duo 处理器和 1 GB RAM 的 iMac。 |
| Atomic compare-and-swap | 大约 0.05 ms | 无竞争场景下的 compare-and-swap 时间。运行环境同上。 |

设计并发任务的时候，最重要的因素永远是正确性，但是也应该考虑到性能因素。总不能一味追求正确性而导致多线程执行的代码比单线程还慢吧。

如果是在单线程应用的基础上进行多线程的改装，应该分别测量下关键任务在单线程和多线程下执行的性能，比对结果后再决定是否使用多线程。

关于性能和指标采集工具详见 [Performance Overview](https://developer.apple.com/library/content/documentation/Performance/Conceptual/PerformanceOverview/Introduction/Introduction.html#//apple_ref/doc/uid/TP40001410)

### 线程安全和信号

信号(Signal) 是一种底层 BSD 机制，用于向进程传递信息或以某种方式操作进程。有些程序使用信号来监测某些事件，比如子进程终止。系统使用信号来终止失控的进程和传达其他类型的信息。

在多线程应用中，信号可能被发送到任何线程。所以实现 signal handler 的首要原则就是不要假定handler 会运行在某个特定线程。也就是说，假如在 A 线程设置 signal handler，信号被发送到 B 线程，A 和 B 不一定相同。

设置 signal handler 的细节可以查看 `signal` 和 `sigaction` man page。

### 线程安全设计技巧

同步工具是把双刃剑，能让代码线程安全，但使用过多也会带来性能问题。能平衡好二者利弊靠的是经验，下面会提供一些技巧。

#### 完全避免同步

最佳解决方案是从代码和数据结构设计上避免需要同步。同步工具很管用但也影响性能，能从设计根源上避免当然是最好的了。比如实现并发的时候要减少任务之间的相互作用和依赖。如果每个任务都在自己的私有数据集上操作，就不需要使用锁保护数据了。即便在两个任务共享一分公共数据集的情况下，可以考虑分割数据集或为每个任务提供一份数据拷贝。当然拷贝数据集也会有成本，这就需要提前权衡下拷贝成本高还是同步成本高。

#### 理解同步的限制

同步工具只有在应用中所有线程都持续使用才能生效。如果创建了互斥锁来限制对某个资源的存取，那么所有线程在试图操作此资源前都必须获得这个的互斥锁。如果做不到这些，互斥锁提供的保护就会失效，这是程序员的错。

#### 清楚代码正确性的风险

使用锁和内存屏障时需要认真些，要在代码中加对地方才行。你甚至觉得自己加锁的地方是对的，其实只是错觉。下面一系列例子试图阐述这个问题。表面上看似没毛病的代码，也能挑出瑕疵。基础假设是有一个可变数组，包含了一组不可变的对象。如果想要执行数组中第一个对象的方法，可以用下面代码实现：

```
NSLock* arrayLock = GetArrayLock();
NSMutableArray* myArray = GetSharedArray();
id anObject;
 
[arrayLock lock];
anObject = [myArray objectAtIndex:0];
[arrayLock unlock];
 
[anObject doSomething];
```

因为数组是可变的，在获取数组第一个元素之前，锁会组织其他线程修改数组。又因为元素对象本身是不可变的，不用对 `doSomething` 方法加锁。

不过上面的例子存在问题：在锁释放后 `doSomething` 执行前，如果另一个线程将数组中所有对象都移除会发生什么呢？`anObject` 野指针！解决问题的办法也很简单，重新整理下代码顺序，在 `doSomething` 执行后再释放锁：

```
NSLock* arrayLock = GetArrayLock();
NSMutableArray* myArray = GetSharedArray();
id anObject;
 
[arrayLock lock];
anObject = [myArray objectAtIndex:0];
[anObject doSomething];
[arrayLock unlock];
```

把调用 `doSomething` 的代码挪到锁里面保证了对象依然有效，但如果 `doSomething` 执行时间过长又会导致锁也会被占用很久，造成性能瓶颈。

代码的毛病不是临界区域不清晰，真正的问题在于其他线程插了一脚触发的内存管理问题。因为其他线程释放了 `anObject`，更好的解决方案是在锁释放前 `retain` 它。此解决方案不仅对症下药，而且无潜在的性能问题。

```
NSLock* arrayLock = GetArrayLock();
NSMutableArray* myArray = GetSharedArray();
id anObject;
 
[arrayLock lock];
anObject = [myArray objectAtIndex:0];
[anObject retain];
[arrayLock unlock];
 
[anObject doSomething];
[anObject release];
```

尽管上面的例子非常简单，但抓到重点了。要透过表面看本质。要预先考虑到一些问题，比如内存管理和其他方面的设计可能会受多线程的影响。除此之外，在安全问题上要对编辑器的行为做最坏的打算。小心谨慎方能避灾。

#### 提防死锁和活锁

如果线程在同一时刻持有不止一个锁，随时都有发生死锁的可能。当两个不同的线程分别持有一个锁，并且尝试获取对方持有的锁，[死锁](https://zh.wikipedia.org/wiki/死锁)就发生了。因为每个线程永远都获取不到另一个锁，结果就是永久阻塞。

活锁跟死锁很像，死锁是获取不到另一个锁就死等，而活锁是获取不到就释放已经持有的锁和资源，然后重试。活锁把时间都花在释放锁和尝试获取其他锁上面了，并没啥干活儿。

避免死锁和活锁的最好方法就是一次只获取一个锁。如果一次必须获取不止一个锁，那就应该确保其他线程别这么做。

#### 正确地使用 `Volatile` 变量

如果已经对一段代码用互斥锁保护了，就不要自动假定需要对这段代码中的重要变量用 `volatile` 关键字再保护一次。互斥锁包含了内存屏障，确保加载和存储操作的顺序正确。添加 `volatile` 关键字会强制访问变量时每次都从内存加载。可能在特殊情况下有必要将这两种同步技术混合使用，但也会导致严重降低性能。如果只用互斥锁保护变量就够了，删掉 `volatile` 关键字吧。

不要用 `volatile` 变量试图替代使用互斥锁。互斥锁和其他同步机制通常比 `volatile` 变量能更好地保护数据结构的完整性。`volatile` 关键字只是确保变量从内存加载而不是存在寄存器中。它无法确保代码可以正确地访问变量。

### 使用原子操作

无阻塞同步可以执行一些操作并避免锁的开销。虽然用锁可以有效地同步两个线程，但即便在无竞争情况下获取锁的代价相对较高。相反，许多同步操作花一小部分时间就能完成，而且跟锁一样管用。

可以用原子操作在 32 位或 64 位数值上做些简单的数学和逻辑操作。为了确保在原子操作完成后才可再次访问受影响的内存，这些操作依赖专门的硬件指令（和可选的内存屏障）。在多线程情况下为确保内存被正确地同步，应该始终使用纳入内存屏障版本的原子操作（带有 `Barrier` 后缀）。

下标列出了可用的数学和逻辑原子操作以及相关函数名。这些函数都声明在 `/usr/include/libkern/OSAtomic.h` 头文件中，它包含了完整语法。这些函数的 64 位版本仅在 64 位处理器中可用。



| 操作 | 函数名 | 描述 |
| --- | --- | --- |
| Add |  OSAtomicAdd32 OSAtomicAdd32Barrier OSAtomicAdd64 OSAtomicAdd64Barrier | 将两个整数相加并将结果存在其中一个指定的变量中 |
| Increment | OSAtomicIncrement32 OSAtomicIncrement32Barrier OSAtomicIncrement64 OSAtomicIncrement64Barrier  | 将指定的整数值加一 |
| Decrement | OSAtomicDecrement32 OSAtomicDecrement32Barrier OSAtomicDecrement64 OSAtomicDecrement64Barrier  | 将指定的整数值减一 |
| Logical OR | OSAtomicOr32 OSAtomicOr32Barrier  | 在指定的 32 位数值和掩码之间做逻辑或 |
| Logical AND | OSAtomicAnd32 OSAtomicAnd32Barrier  | 在指定的 32 位数值和掩码之间做逻辑与 |
| Logical XOR | OSAtomicXor32 OSAtomicXor32Barrier  | 在指定的 32 位数值和掩码之间做逻辑异或 |
| Compare and swap | OSAtomicCompareAndSwap32 OSAtomicCompareAndSwap32Barrier OSAtomicCompareAndSwap64 OSAtomicCompareAndSwap64Barrier OSAtomicCompareAndSwapPtr OSAtomicCompareAndSwapPtrBarrier OSAtomicCompareAndSwapInt OSAtomicCompareAndSwapIntBarrier OSAtomicCompareAndSwapLong OSAtomicCompareAndSwapLongBarrier  | 函数有三个参数：oldValue, newValue, theValue 指针。如果 oldValue 跟 theValue 指针的内容相等，则把 newValue 赋给 theValue 指针的内容。否则啥都不干。比较和赋值会以一个原子操作完成。返回值表明是否发生了交换。 |
| Test and set | OSAtomicTestAndSet OSAtomicTestAndSetBarrier  | 将指定变量第 n 位设为 1，并将旧值以 bool 形式返回。注意这里会将变量按 8 位分块，每块的内容是逆序的。所以如果想要设置 0 位的值，n 需要传入 7。 |
| Test and clear | OSAtomicTestAndClear OSAtomicTestAndClearBarrier  | 将指定变量第 n 位设为 0，并将旧值以 bool 形式返回。注意这里会将变量按 8 位分块，每块的内容是逆序的。所以如果想要设置 0 位的值，n 需要传入 7。 |

大多数原子函数的行为都会是相对简单且能预料到的。下面的示例代码使用了 `OSAtomicTestAndSet` 和 `OSAtomicCompareAndSwap32` 函数，结果可能跟你预想的不太一样。这些函数在无竞争情况下被调用，且没有其他线程同时操作。

```
int32_t  theValue = 0;
OSAtomicTestAndSet(0, &theValue);
// theValue is now 128.
 
theValue = 0;
OSAtomicTestAndSet(7, &theValue);
// theValue is now 1.
 
theValue = 0;
OSAtomicTestAndSet(15, &theValue)
// theValue is now 256.
 
OSAtomicCompareAndSwap32(256, 512, &theValue);
// theValue is now 512.
 
OSAtomicCompareAndSwap32(256, 1024, &theValue);
// theValue is still 512.
```

关于原子操作可以看看 `atomic` man page 和 `/usr/include/libkern/OSAtomic.h` 头文件。

### 使用锁

锁是多线程编程中的一个基础同步工具，macOS 和 iOS 都提供了基础的互斥锁。Foundation 框架定义了几种用于特别场景的互斥锁作为补充。

#### POSIX 互斥锁

POSIX 互斥锁贼好用。用 `pthread_mutex_t` 结构体声明一个互斥锁变量，将其传入 `pthread_mutex_init` 函数初始化，然后用 `pthread_mutex_lock` 和 `pthread_mutex_unlock` 函数获取和释放锁就行了。等到不需要用锁了，调用 `pthread_mutex_destroy` 函数析构锁的数据结构。下面是简化后的代码，实际使用时要考虑到错误处理等细节：

```
pthread_mutex_t mutex;
void MyInitFunction()
{
    pthread_mutex_init(&mutex, NULL);
}
 
void MyLockingFunction()
{
    pthread_mutex_lock(&mutex);
    // Do work.
    pthread_mutex_unlock(&mutex);
}
```

#### `NSLock`

`NSLock` 实现了 Cocoa 中基本的互斥锁。包括 `NSLock` 的所有锁的接口实际上都由 `NSLocking` 协议定义，也就是 `lock` 和 `unlock` 这俩方法，对应功能是获取和释放锁。

除此之外，`NSLock` 类还提供了 `tryLock` 和 `lockBeforeDate:` 方法。`tryLock` 方法尝试获取锁，但如果锁不可用，并不会阻塞，只是返回 `NO` 而已。`lockBeforeDate:` 方法尝试获取锁，并一直阻塞线程，直到获取到锁（返回 `YES`）或达到限定的时间（返回 `NO`）。

下面的示例代码展示了如何使用 `NSLock` 在多个线程计算要被显示的数据时，即便获取不到锁的情况下依然可以继续运算。

```
BOOL moreToDo = YES;
NSLock *theLock = [[NSLock alloc] init];
...
while (moreToDo) {
    /* Do another increment of calculation */
    /* until there’s no more to do. */
    if ([theLock tryLock]) {
        /* Update display used by all threads. */
        [theLock unlock];
    }
}
```

#### `@synchronized`

可以用 `@synchronized` 指令很方便地在 Objective-C 代码中飞快地写个互斥锁。它的作用跟互斥锁一样，但不用创建锁，只需要把一个 Objective-C 对象当做锁的 token 即可：

```
- (void)myMethod:(id)anObj
{
    @synchronized(anObj)
    {
        // Everything between the braces is protected by the @synchronized directive.
    }
}
```

传给 `@synchronized` 的对象是区分被保护的代码块的唯一标识。如果两个线程都执行上面的 `myMethod:` 方法，传入的对象如果不同，则不会有阻塞；传入的对象相同，则一个线程先获取锁，另一个线程在临界区域执行完成之前会一直阻塞。

使用 `@synchronized` 的前提是工程开启了 Objective-C exception handling 选项。因为 `@synchronized` 的 block 为了保护代码，预防措施是隐式加入 exception handler。handler 在异常抛出时会自动释放互斥锁。

[关于 @synchronized，这儿比你想知道的还要多](http://yulingtianxia.com/blog/2015/11/01/More-than-you-want-to-know-about-synchronized/)

#### 使用其他 Cocoa 框架的锁

##### `NSRecursiveLock`

`NSRecursiveLock` 类也就是递归锁，可以被同一线程获取多次而不会导致死锁。当然 `lock` 多少次，也要相应地 `unlock` 多少次，这样锁才会被真正释放，其他线程才能获取锁。

递归锁通常用于递归函数中来避免死锁线程。也可以用于非递归的场景下。这有个使用 `NSRecursiveLock` 的例子：

```
NSRecursiveLock *theLock = [[NSRecursiveLock alloc] init];
 
void MyRecursiveFunction(int value)
{
    [theLock lock];
    if (value != 0)
    {
        --value;
        MyRecursiveFunction(value);
    }
    [theLock unlock];
}
 
MyRecursiveFunction(5);
```

注意：因为递归锁需要 `lock` 和 `unlock` 次数相等才能释放，应该小心权衡。可以重写代码来避免递归，或避免使用递归锁，这样可以获取更好的性能。

##### `NSConditionLock`

`NSConditionLock` 定义了可以用特定值来 `lock` 和 `unlock` 的互斥锁，但别跟条件变量搞混了。虽然行为差不多但实现很不一样。

`NSConditionLock` 一般用于线程需要以特定的顺序执行任务时，例如生产者消费者问题。当生产者执行时，消费者需要使用程序中特定的条件变量来获取锁。所谓的条件变量其实就是个程序员定义的整型数。当生产者完成后，它会 `unlock` 并更新条件变量，进而唤醒了消费者线程。消费者线程继续处理数据。

`NSConditionLock` 的加锁和解锁方法可以任意组合使用。比如可以用 `lock` 跟 `unlockWithCondition:` 搭配，或用 `lockWhenCondition:` 跟 `unlock` 搭配。当然第二种搭配没有在解锁后设置 `condition` 属性的值，其他一些等待特定条件变量的线程可能还会阻塞。

下面的例子展示了如何使用条件锁处理生产者-消费者问题。摄像应用含有一个数据队列，生产者线程向队列添加数据，消费者线程从队列取数据。生产者不需要等特定的条件，但是必须等锁可用的时候才能安全地向队列添加数据。

```
id condLock = [[NSConditionLock alloc] initWithCondition:NO_DATA];
 
while(true)
{
    [condLock lock];
    /* Add data to the queue. */
    [condLock unlockWithCondition:HAS_DATA];
}
```

由于锁的初始条件被设置成 `NO_DATA`，生产者线程起初会顺利地获取锁。它向队列填充数据并将条件设置为 `HAS_DATA`。在接下来的迭代中，不管队列是否为空，生产者线程总能添加新数据。它只有消费者线程从队列中获取数据的时候才会阻塞。

由于消费者线程必须有数据去处理，它会用一个特定的条件等待着队列。当生产者网队列中放数据时，消费者线程会活跃起来并获取锁。然后它可能从队列获取一些数据并更新队列状态。下面的例子展示了消费者线程循环程序的基本结构。

```
while (true)
{
    [condLock lockWhenCondition:HAS_DATA];
    /* Remove data from the queue. */
    [condLock unlockWithCondition:(isEmpty ? NO_DATA : HAS_DATA)];
 
    // Process the data locally.
}
```

##### `NSDistributedLock`

`NSDistributedLock` 可以用于多个应用拥有并访问某个共享资源（例如文件）的临界区。它实际上是使用文件系统的文件或目录等实现的互斥锁。所有使用 `NSDistributedLock` 对象的应用必须对其可写入。这通常意味着将其放入一个所有运行此应用的计算机都能访问的文件系统。

`NSDistributedLock` **不**像其他锁一样遵从 `NSLocking` 协议，没有 `lock` 方法。`lock` 方法会阻塞进程的执行并需要系统以预定的速率查询锁。与其在代码上强制损耗性能，不如用 `NSDistributedLock` 提供的 `tryLock` 方法来让程序员决定是否去查询锁。

由于 `NSDistributedLock` 使用文件系统实现，它只有在拥有者显式释放它时才会跟着释放。如果应用 crash 时还持有一个 `NSDistributedLock` 对象，其他 client 将不能访问被保护的资源。在这种情况下，可以使用 `breakLock` 方法打破已经存在的锁，这样就能获取到它了。通常应该避免打破锁，除非你确信拥有锁的进程挂了，无法释放锁。

`NSDistributedLock` 跟其他锁一样，调用 `unlock` 方法释放它。

### 使用条件（Condition）

Condition 是一种特殊类型的锁，它可以让操作必须以正确的顺序进行。它跟互斥锁有细微的差别。等待 condition 的线程会保持阻塞，直到 condition 被其他线程显式发信号。

由于牵扯到操作系统实现的细节，条件锁在即使没被发信号的情况下被允许伪造成功返回。为了避免这种站不住脚的发信号导致的问题，应该总是把断言跟条件锁结合起来使用。断言是一个决定线程是否能安全进行的更具体的方式。在发信号的线程设置断言前，condition 会让你的线程保持睡眠。

下面展示如何在代码中使用 condition。

#### `NSCondition`

`NSCondition` 是对 POSIX Condition 语法的封装，而且将锁和 condition 数据结构包含在一个对象里。这使得可以用一个对象既能当做互斥锁 `lock`，又能像 Condition 一样继续 `wait`。

下面的代码中 `cocoaCondition` 变量是一个 `NSCondition` 对象，`timeToDoWork` 变量是一个整型数，用作断言。其他线程会在向 condition 发信号之前立刻增加 `timeToDoWork` 的值。

```
[cocoaCondition lock];
while (timeToDoWork <= 0)
    [cocoaCondition wait];
 
timeToDoWork--;
 
// Do real work here.
 
[cocoaCondition unlock];
```

然后就是增加断言的值，并向 condition 发信号。当然这些操作要加锁：

```
[cocoaCondition lock];
timeToDoWork++;
[cocoaCondition signal];
[cocoaCondition unlock];
```

#### POSIX Condition

POSIX 线程条件锁需要将 condition 数据结构和互斥锁一起使用。尽管两个锁结构是分开的，但是互斥锁在运行时会被紧紧地捆到 condition 结构上。等待发信号的线程应该始终将相同的互斥锁和 condition 结构一起使用。改变配对会导致错误。

下面的代码展示了 condition 和断言基本的初始化和使用。在初始化 condition 和互斥锁后，线程进入了一个使用 `ready_to_go` 变量作为断言的 `while` 循环。只有断言设置好并且 condition 接着被发信号后，等待着的线程才会被唤醒，并开始工作。

```
pthread_mutex_t mutex;
pthread_cond_t condition;
Boolean     ready_to_go = true;
 
void MyCondInitFunction()
{
    pthread_mutex_init(&mutex);
    pthread_cond_init(&condition, NULL);
}
 
void MyWaitOnConditionFunction()
{
    // Lock the mutex.
    pthread_mutex_lock(&mutex);
 
    // If the predicate is already set, then the while loop is bypassed;
    // otherwise, the thread sleeps until the predicate is set.
    while(ready_to_go == false)
    {
        pthread_cond_wait(&condition, &mutex);
    }
 
    // Do work. (The mutex should stay locked.)
 
    // Reset the predicate and release the mutex.
    ready_to_go = false;
    pthread_mutex_unlock(&mutex);
}
```

发信号的线程负责设置断言并向条件锁发信号。下面的代码展示了它的实现。为了避免线程之间等待 condition 而发生竞态条件，发信号的操作要在互斥锁里面进行。因为是简化过后的例子，代码中没包含错误处理的代码，只展示基础用法。

```
void SignalThreadUsingCondition()
{
    // At this point, there should be work for the other thread to do.
    pthread_mutex_lock(&mutex);
    ready_to_go = true;
 
    // Signal the other thread to begin work.
    pthread_cond_signal(&condition);
 
    pthread_mutex_unlock(&mutex);
}
```


