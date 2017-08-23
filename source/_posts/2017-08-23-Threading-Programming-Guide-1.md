---
title: Threading Programming Guide(1)
date: 2017-08-23 16:20:24
tags:
- 翻译
---

[Threading Programming Guide](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Multithreading/Introduction/Introduction.html#//apple_ref/doc/uid/10000057i-CH1-SW1) 的学习笔记&翻译，第一部分。

其实苹果建议使用对线程的高级封装，比如 operation objects and Grand Central Dispatch，它们使用方便更加高效，可以参考 [Concurrency Programming Guide](https://developer.apple.com/library/content/documentation/General/Conceptual/ConcurrencyProgrammingGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40008091)。

但了解更底层一些的内容其实更有趣，难道不是么？

<!-- more -->

## 线程相关概念

### 概要和术语

线程的概念在计算机组成原理中学过，在各个系统中的实现和行为也都大同小异。多线程编程有利也有弊：在提升程序运行效率和用户体验的同时也带来了线程间同步的种种问题。现在大多出 CPU 都是多核的，所以很多程序都是并发执行来提升性能。多线程编程的代码更复杂，尤其是在存取同一个数据时更需要注意。这里讲一讲 macOS 和 iOS 提供的有关线程的 API 以及同步机制。

如果把进程(process)理解为一个运行着多个线程(thread)的程序，线程运算调度一条独立路径的代码。任务(work)可以理解成需要被执行的代码块或函数之类的抽象概念。

### 替代技术

亲自去创建底层意义上的线程很难操作，也很容易出问题。创建一个新的线程会消耗很多 CPU 和内存资源，所以尽可能先考虑下是否真的有必要创建线程。对于直接手动创建线程执行任务来说，可以替代的技术还有很多：

- Operation objects: 封装了一套在辅助线程执行任务的 API，只关注提交的任务即可，线程管理的底层工作交给系统。
- Grand Central Dispatch: 也是基于任务的 API，功能更强大，队列的使用更加灵活，强烈推荐。
- Idle-time notifications: 如果一项任务较轻且优先级较低，可以趁着不忙的时候执行。使用通知中心的 `postNotification:` 方法可以立即抛通知，这是个同步执行的方法。其实通知会先进入一个先入先出的通知队列中，出列后才会被分发到通知中心。可以使用 `NSNotificationQueue` 的 [`enqueueNotification:postingStyle:`](https://developer.apple.com/documentation/foundation/notificationqueue/1416340-enqueue) 方法异步发送通知，postingStyle 设为 [`NSPostWhenIdle`](https://developer.apple.com/documentation/foundation/notificationqueue.postingstyle/1418001-whenidle) 即可在 Runloop 空闲时发送通知。
- Asynchronous functions: 使用系统自带的异步函数，把线程创建和管理的工作交给系统。
- Timers: 使用定时器在主线程做一些微小的周期性任务，而无需手动创建线程。
- Separate processes: 如果任务跟应用关联不紧密、占用大量内存或是需要 root 权限，可以创建进程，而非线程。使用 `fork` 函数创建进程后记得调用 `exec`。

### 苹果系统的支持

macOS 和 iOS 提供了几种创建线程的技术，以及对线程之间管理和同步任务的支持。

#### 对线程的封装 

线程的底层实现是在 Mach 层的，虽然它提供了抢占式多任务处理模型和线程调度能力，但我们常用的还是 POSIX API 及其衍生出来的 API：

1. Cocoa 线程: `NSThread` 类以及 `NSObject` 提供的线程 API。
2. POSIX 线程: C 语言接口，比如创建线程的函数 `pthread_create`。 `pthread_t` 为线程句柄。
3. Multiprocessing Services: 远古产物，弃用

不同系统中线程的生命周期都差不多，在线程退出之前，会在运行(running)、阻塞(blocked)、准备(ready)状态之间切换。创建线程需要指定其入口函数，入口函数 `return` 后会终止线程，线程会被系统回收。创建线程会占内存和 CPU 资源，所以在入口函数里执行比较重的任务才值当。或者可以用 Runloop 做一些循环的任务。

#### Run Loops

run loop 管理了线程接收的事件。它监听事件 source，有事件发生时，系统会唤起线程并将事件发送给 run loop，然后调用事件对应的 handler 函数。没有事件发生时会让线程休眠。

如果没有 run loop，线程的入口函数 `return` 后就会终止线程。run loop 可以让线程保活的同时消耗最少的资源。它在没有事件发生时会让线程休眠，而不是让 CPU 空转。run loop 与线程是一对一的关系，线程创建时默认是没有 run loop 的。

系统的主线程自动配置好了 run loop，可以通过 `CFRunLoopGetMain()` 获得。其他线程可以使用 `CFRunLoopGetCurrent()` 获得对应的 run loop 对象，在第一次执行 `CFRunLoopGetCurrent()` 时，线程才会创建它的 run loop。获得 run loop 对象后，可以配置其事件处理函数，并运行 run loop。

run loop 对应的 API 有两种：`NSRunLoop` 和 `CFRunLoop`：

- `NSRunLoop` Cocoa 的 API,非线程安全，必须在当前线程上下文中调用。它是对 `CFRunLoop` 的封装。
- `CFRunLoop` 为 `Core Foundation` 框架的 C 语言 API，线程安全。使用 `CFRunLoopRef` 引用 run loop 对象。

#### 同步工具

多线程操作同一资源时要注意同步的问题，可以使用加锁、Conditions、原子操作等技术进行同步。

加锁可以确保一段代码在某一时刻只能在一个线程中执行，最基本的是互斥锁(mutex, mutual exclusion)。Cocoa 提供了很多种锁来满足各种场景。

当两个线程竞争同一资源时，如果对资源的访问顺序敏感，就称存在竞态条件。Conditions 通过阻塞线程的方式确保了任务按正确的顺序执行，POSIX 层和 Foundation 框架都有 Conditions 对应的 API。此外，Cocoa 提供的 operation objects 也能设置任务执行的顺序。

原子操作适合同步多线程对标量数据类型的数学和逻辑运算，它跟锁相比，采用硬件指令优化，是一种轻量级同步工具。

#### 跨线程通信

因为线程之间共用它们所属进程的相同空间，所以跨线程通信的方法有很多。它们各有优劣，按复杂度从低到高排列如下：

- 直接发消息: `performSelector:onThread:withObject:waitUntilDone:modes:` 等方法。
- 全局变量，共用内存和对象: 相比直接发消息更快更容易，但也更脆弱。需要加锁之类的同步机制来确保代码的正确性，否则可能会导致竞态条件、错乱数据和crash。
- Conditions: 之前说过它也是一种线程同步工具，只有当符合某个条件时才让线程执行下去，相当于守门员的作用。
- Run loop sources: run loop input sources 有两种：port-based和 custom。这里说的是使用 custom run loop source 在某个线程上接收应用特定的消息。整个事件分发机制需要自己实现，包括设置 handler 函数，为 custom run loop source 提供数据，并手动将其 signal。
- 端口和套接字: 基于端口的跨线程通信技术更复杂但也更可靠。更重要的是端口和套接字也可以与外部实体通信，比如其他进程和服务。为了高效，端口使用 port-based run loop sources 实现。
- 消息队列: 古老的 Multiprocessing Services 定义了一个简单方便的 FIFO 队列来管理数据进出，但没其他跨线程通信技术效率高。
- Cocoa distributed objects: 对端口通信进行高级封装的 Cocoa API，其开销之大更适合跨进程通信。不建议用于跨线程通信，杀鸡用牛刀。

### 设计秘籍

这些建议和经验可以帮助开发者确保代码逻辑正确，性能更佳。

#### 避免直接创建线程

手动创建线程很蛋疼还容易出错，所以要用其他 API 隐式实现并发，之前也提到了一些替代技术。建议使用 GCD 和 operation objects，可以根据当前系统负载自动调整活跃线程数量。

#### 让线程占用率适当

手动创建管理线程时要注意线程消耗宝贵的系统资源，要做到物尽其所用，不能杀鸡用牛刀。更要毫不犹豫地终止大部分时间处于空闲状态的线程。线程占用的大量内存中有一部分是联动(wired)内存，所以释放那些使用率低的线程不仅可以减少应用的内存占用，也会为其他系统进程的运行释放更多物理内存。

科普下苹果的内存使用相关术语：

- Wired(联动): 系统核心占用的，一直存在 RAM 上，永远不会被挪到硬盘中。联动内存占用跟使用的应用有关。
- Active(活跃): 表示这些内存数据正在使用中，或者刚被使用过。
- Inactive(非活跃): 表示这些内存中的数据是有效的，但是最近没有被使用。如果打开一个应用再退出，其所占用内存会变为非活跃内存，再次打开这个应用时如果那块内存没被其他应用使用，那么会那块非活跃内存会变为活跃内存（无需从硬盘加载），使得应用打开速度更快。
- Free(可用空间): RAM 中没被使用的空间。

在终止线程前需要记录下当前的性能指标，并在终止线程之后再次记录，参照对比下是否真的提升了性能。

#### 避免共用数据结构

避免线程相关资源冲突最简单的方法是每个线程都拷贝一份需要用的数据。线程之间通讯越少越好。

即便对所有多线程场景下的共用数据加锁，就算再怎么仔细，代码可能依然在语义上不安全。比如代码逻辑要求用特定的顺序修改公用的数据结构，否则就会出问题。使用基于事务模型的代码可以弥补这个缺陷，但会进而抵消了多线程的性能优势。将资源竞争消灭在萌芽之中才会让方案更简单，性能更出众。

#### 线程与用户界面

建议在接受跟用户相关的事件和更新界面时使用主线程。因为 Cocoa 跟 UI 相关的 API 使用了一些全局变量，如果在其他线程去更新 UI 或者处理用户事件，就会发生一些同步问题。

当然这个『在主线程更新界面』的规则也有些例外，比如在次级线程进行图像处理可以显著地提升性能。如果拿不准主意，那就干脆全在主线程去做吧。这样代码逻辑简单，易维护。

Cocoa 图形绘制可以参考 [Cocoa Drawing Guide](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/CocoaDrawingGuide/Introduction/Introduction.html#//apple_ref/doc/uid/TP40003290)。

#### 退出应用时注意线程的行为

POSIX 线程按照资源释放方式分两种：joinable(non-detached) 和 detached。

detached 类型的线程结束之后系统会自动回收其资源。假如在 A 线程中使用 `pthread_create` 创建线程 B，不传入线程属性的话默认是 joinable 类型的线程。需要在线程 A 调用 `pthread_join` 来连接，这样才会在线程 B 结束后回收其资源。

默认情况下只有主线程是 joinable 的，当所有 joinable 线程都结束了，它们所属的进程也就终止执行了。因为系统会认为 detached 线程做的都是可选的任务，所以当用户退出了一个应用时，通常会立刻结束所有的 detached 线程。

如果想让线程在后台做一些诸如保存数据到磁盘之类的重要工作，需要使用 joinable 类型的线程，以防止应用退出时数据丢失。但大多数的对线程高层封装的 API 不会默认创建 joinable 线程，所以需要使用 POSIX API 的 `pthread_create` 创建 joinable 线程。

在使用 Cocoa API 时，`applicationShouldTerminate:` delegate 方法可以延迟一阵子退出应用或取消退出。如果需要延迟退出程序，还要在所有关键线程完成任务之后调用 `applicationShouldTerminate:` 方法告诉 `NSApplication` 对象是否可以真的退出了。

#### 处理异常

每个线程都负责捕获和处理其调用栈上抛出的异常，任何线程上没被捕获的异常都能终止其所属进程。不能将没捕获的线程抛给其他线程处理。

如果想要通知其他线程有异常，应该先捕获异常，然后给其他线程发消息。异常被捕获后可能会继续执行，或者等待命令，或者退出。

Cocoa 的 `NSException` 被捕获后可以在线程之间传递。

`@synchronized` 会自动捕获和处理异常。


#### 干净利落地终止线程

最好是让线程运行结束后自动退出，如果万不得已非要立刻终止线程，会导致线程没有释放和清理它占用的资源，比如：创建的内存、打开的文件以及获得的其他资源。无法回收这些资源意味着内存泄露和其他潜在的问题。

#### Library 中的线程安全

开发第三方库的时候必须假设调用方随时都会处于多线程环境中，代码中的关键部分一定要加锁。虽然可以监听 `NSWillBecomeMultiThreadedNotification` 通知来获知应用处于多线程，但可能 library 被调用之前就已经发过通知了。别指望当调用方处于多线程环境时才创建锁，而是需要在调用初始化 library 的方法中就提前创建好锁对象。但如果在 library 的静态初始化中创建锁会延长 library 的加载时间，影响性能。

互斥锁的加锁和解锁操作要成对出现，不要指望调用方提供一个线程安全的环境，对数据结构该用锁就用。

## 线程管理

每个进程都至少有一个线程，每个线程代表了一条执行代码的独立路径。应用从一个线程的 `main` 函数开始运行，然后产生新的线程。每个线程在进程内部都是独立的实体，具有自己的调用栈，并由内核做时分调度。线程可以与其他线程和进程通信，执行 I/O 操作等。一个应用进程内部的所有现场共享虚拟内存空间，并与进程拥有相同的访问权限。

### 线程成本

使用线程对应用和系统来说都是有成本的，具体体现在内存使用和性能上。每个线程需要占用内核内存空间和程序内存空间。内核会使用联动(wired)内存为线程创建用于管理线程和协调调度的数据结构。线程的栈空间和数据存储在程序的内存空间中。这些数据结构大部分会在创建线程的时候初始化，进程也因与内核有必要的交互而成本变得相对更高。

| 成本项 | 大致成本 | 注释 |
| --- | --- | --- |
| 内核数据结构 | 大约 1 KB |  用于存储线程数据结构和属性的内存，很多都是联动（wired）内存，所以不能在磁盘上分页 |
| 栈空间 | 次级线程：512 KB ; macOS 主线程：8 MB ; iOS 主线程：1 MB |  次级线程的栈空间最小为 16 KB，且必须是 4 KB 的整数倍。创建线程的时候可以设置栈空间的大小，但是只有在需要用它的时候才会创建真的分页内存。 |
| 创建时间 | 大约 90 微秒（macOS 10.5，2 GHz Core Duo CPU，1 GB RAM） | 从开始创建线程到线程入口函数开始执行的耗时，是个粗略的估值。处理器负载、计算机速度、系统和程序可用内存都会对创建时间造成较大的影响。 |

由于底层内核的支持，operation objects 经常可以更快地创建线程。它使用内核线程池中已经存在的线程来节省创建时间，而不是每次都从零开始创建线程。

写线程相关代码也是一种生产成本。设计多线程程序又是需要对应用数据结构的组织方式进行彻底的改变。避免使用同步，因为它在设计较差的应用上会严重降低性能。设计数据结构和 debug 线程相关代码都会增加开发成本。

### 创建线程

创建线程需要指定入口主函数，并可设置一些线程的配置项。最后调用运行线程的方法。下面介绍几种创建线程的技术。

#### 使用 `NSThread`

使用 `NSThread` 创建线程有两种方式：

1. 使用 `detachNewThreadSelector:toTarget:withObject:` 类方法产生新的线程
2. 创建一个新的 `NSThread` 对象，并调用它的 `start` 方法。仅支持 iOS 和 macOS 10.5 以后的版本。

这两种方法都会创建一个 detached 线程，它退出后系统会自动回收其资源，无需手动 join 操作。

下面两种创建线程的代码是等效的，但是推荐使用第二种方式。因为它支持在运行线程之前设置各种线程属性，不像第一种方式那样创建线程的时候必须立刻运行。

```
// 方式 1
[NSThread detachNewThreadSelector:@selector(myThreadMainMethod:) toTarget:self withObject:nil];

// 方式 2
NSThread* myThread = [[NSThread alloc] initWithTarget:self
                                        selector:@selector(myThreadMainMethod:)
                                        object:nil];
[myThread start];  // Actually create the thread
```

如果不想使用 `initWithTarget:selector:object:` 方法传入线程的入口函数，也可以继承 `NSThread`，并覆写子类的 `main` 方法（不用调用 `super` 方法）。

`performSelector:onThread:withObject:waitUntilDone:` 方法可以在正在运行的线程发送消息，前提是这个线程必须有运行中的 run loop，因为消息会在线程的 run loop 日常处理过程中被执行。注意使用此方法进行跨线程通信时需要有同步机制。此方法并不适合用于实现时间紧要和频繁的跨线程通信。

#### 使用 POSIX 线程

iOS 和 macOS 提供了基于 C 语言的 POSIX 线程 API 来创建线程，优点是跨平台。创建线程的函数是 `pthread_create`，默认创建的是 joinable 线程，所以需要设置线程属性来将其创建为 detached 线程，这样当线程退出的时候其资源就会立刻被系统回收利用了：

```
#include <assert.h>
#include <pthread.h>
// 线程入口主程序
void* PosixThreadMainRoutine(void* data)
{
    // 在这里加代码.
 
    return NULL;
}
// 创建线程
void LaunchThread()
{
    // Create the thread using POSIX routines.
    pthread_attr_t  attr;
    pthread_t       posixThreadID;
    int             returnVal;
 
    returnVal = pthread_attr_init(&attr);
    assert(!returnVal);
    returnVal = pthread_attr_setdetachstate(&attr, PTHREAD_CREATE_DETACHED);
    assert(!returnVal);
 // 因为 PosixThreadMainRoutine 函数没有参数，所以 pthread_create 最后一个参数传 NULL
    int     threadError = pthread_create(&posixThreadID, &attr, &PosixThreadMainRoutine, NULL);
 
    returnVal = pthread_attr_destroy(&attr);
    assert(!returnVal);
    if (threadError != 0)
    {
         // Report an error.
    }
}
```

对于 C 语言的应用，可以使用端口、conditions 或共用内存来跨线程通信。跨线程通信有便于主线程检查其他线程的状态，在应用退出时做一些操作。

关于 POSIX 线程函数可以翻阅 pthread man page。

#### 使用 `NSObject` 产生线程

iOS 和 macOS 10.5 之后 `NSObject` 提供了`performSelectorInBackground:withObject:` 方法，可以让所有对象都创建 detached 线程，并传入 `selector` 作为入口函数。跟它等效的方法是 `NSThread` 的 `detachNewThreadSelector:toTarget:withObject:`。在 `selector` 方法里可以继续配置线程，比如添加 `autoreleasepool` 和 run loop。

#### 在 Cocoa 应用中使用 POSIX 线程

在 Cocoa 中使用 POSIX 线程需要注意它们之间的交互，并遵守以下原则。

##### 保护 Cocoa 框架

Cocoa 框架使用加锁之类的同步机制来确保多线程工作正常，但只有在第一次使用 `NSThread` 产生新线程的时候才会真的创建锁。这可以避免单线程情况下加锁会降低性能。但如果只使用 POSIX API 来产生新线程，Cocoa 就不会收到应用转换为多线程的通知，进而导致应用不稳定，甚至 crash。可以用 `NSThread` 创建一个新线程，入口函数啥都不做，这样线程就会立刻退出。这样 Cocoa 就知道应用处于多线程了，加锁也会生效。PS：这么抖机灵的做法当然也会产生创建线程的开销，有些违背之前说的不要随意创建线程的原则。

`NSThread` 的 `isMultiThreaded` 方法可以检查应用是否是多线程。

##### 混合使用 POSIX 和 Cocoa 锁

在一个应用中混合使用 POSIX 和 Cocoa 两套 API 的锁是安全的，因为后者实质上只是对前者的封装。但不能用一种 API 的方法操作另一种 API 创建的锁。比如不能使用 `NSLock` 对象操作 `pthread_mutex_init` 函数创建的互斥锁，反之亦然。

### 配置线程属性

#### 配置线程的栈尺寸

创建线程后系统会为其创建一块内存作为栈空间，开发者可以在创建线程前配置这块空间的尺寸。所有的线程技术都会提供某种设置栈尺寸的方法，但 `NSThread` 只有在 iOS 和 macOS 10.5 之后支持设置栈的尺寸。

| 技术 | 选项 |
| --- | --- |
| Cocoa | 前提是不要使用 `detachNewThreadSelector:toTarget:withObject:` 创建线程。创建线程对象后，在调用线程对象的 `start` 方法之前，使用 `setStackSize:` 方法指定栈的大小。 |
| POSIX | 创建 `pthread_attr_t` 栈属性结构体并使用 `pthread_attr_setstacksize` 函数修改默认的栈尺寸。在使用 `pthread_create` 函数创建线程时将属性结构体传入。 |
| Multiprocessing Services | 使用 `MPCreateTask` 函数创建线程时可以传入栈尺寸。 |

#### 配置 TLS(Thread-Local Storage)

每个线程都维护了一个存储键值对的字典，在线程内随处都能存取。可以用它记录一些贯穿于线程执行过程中的信息，比如 run loop 迭代次数。

Cocoa 与 POSIX 存储线程字典的方式不同，所以两种技术的 API 不能混用。只要你始终用其中一种技术，最后结果都差不多。具体方式如下：

Cocoa: `NSThread` 的 `threadDictionary` 方法获取 `NSMutableDictionary` 字典对象，然后进行存取。
POSIX: 直接用 `pthread_setspecific` 和 `pthread_getspecific` 函数存取字典。

#### 设置线程的 Detached 状态

大部分高级线程技术创建的线程默认都是 detached 状态，这是因为大部分场景下都需要系统在线程执行完成后立刻回收资源。好处是代码干净，是否获取线程执行结果可以自行决定。

joinable 线程需要其他线程调用 `pthread_join` 函数对其进行 join 操作之后才能被系统回收资源。joinable 线程可以向 `pthread_exit` 函数传入数据，其他线程可以在调用 `pthread_join` 函数的时候获得此数据。参考 [pthread_join() and pthread_exit()](https://stackoverflow.com/questions/8513894/pthread-join-and-pthread-exit)。

应用退出时，detached 线程可以立刻结束，但是 joinable 线程必须全都被 join 后进程才能退出。因此 joinable 线程适用于执行不能中断的重要工作，比如向磁盘写入数据。

只能用 POSIX API 来创建 joinable 线程，如果不设置线程属性，默认就是 joinable 线程。可以在创建线程之前调用 `pthread_attr_setdetachstate` 函数修改线程 detached 状态。在线程开始运行之后，可以调用 `pthread_detach` 函数将一个 joinable 线程变成 detached 线程。

#### 设置线程优先级

任何新创建的线程都有个默认优先级。内核的调度算法在决定运行哪个线程的时候都会考虑到线程优先级，优先级越高越可能先运行。拥有更高优先级的线程并不保证有特定的运行时间，只是在与低优先级线程比较时更容易被调度算法选中罢了。

最好让你创建的线程保持默认优先级。提升一些线程的优先级也会提升低优先级线程饥饿的可能性。如果高优先级线程和低优先级线程之间有交互，低优先级线程饥饿可能会阻塞其他线程，并造成性能瓶颈。

设置线程优先级的方式如下：

Cocoa: `NSThread` 的 `setThreadPriority:` 类方法可以设置当前线程的优先级。
POSIX: `pthread_setschedparam` 函数设置优先级。

### 编写线程入口程序

各平台上的线程入口函数结构都差不多，一般都会初始化数据结构，执行一些工作，或者使用 run loop 保活，最后在工作完成后清理占用的资源。这里讲一下编写线程入口程序需要做的一些额外步骤。

#### 创建自动释放池

使用 Objective-C 框架的应用必须确保每条线程至少有一个自动释放池。如果开启垃圾回收机制，自动释放池会失效。PS: 垃圾回收很早就被苹果弃用了。

使用 `@autoreleasepool` 创建自动释放池比 `NSAutoreleasePool` 更方便。而且 `NSAutoreleasePool` 不能在 ARC 下使用。

```
- (void)myThreadMainRoutine
{
    @autoreleasepool {
	    // Do thread work here.
    }
}
```

有时需要创建更多的自动释放池，比如在循环内部使用自动释放池降低内存开销。

关于自动释放池的使用，不再赘述。

#### 设置 Exception Handler

没被捕获的异常会导致应用崩溃，虽然最好应该在异常发生的地方进行异常处理，但是在线程的入口函数再加上个 try/catch 比较好。

更多内容参考 [Exception Programming Topics](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Exceptions/Exceptions.html#//apple_ref/doc/uid/10000012i)。

#### 设置 Run Loop

编写线程上运行的代码有两种选择：1. 代码简单粗暴，任务执行完线程就退出了；2. 设置线程的 run loop，处理不断到来的请求。

macOS 和 iOS 内置了 run loop 的实现，应用的主线程自动开启 run loop。开发者创建的次级线程需要手动配置和开启 run loop。

### 终止线程

建议让线程的入口函数正常退出。虽然 Cocoa，POSIX 和 Multiprocessing Services 提供了直接杀线程的方法，但强烈不建议使用。强杀线程会导致无法回收资源，可能导致内存泄露、资源没被正确清理，进而导致后续的隐患。

如果预料到需要中途结束线程，设计线程之初就应该响应到取消或退出的消息。带有 run loop 这种周期操作的线程可以每次查看是否收到退出的消息。如果需要退出线程，则可以清理线程资源后退出；否则继续处理其他工作。

run loop 可以使用 input source 接受其他线程发的消息，但需要为 `NSRunLoop` 配置 `CFRunLoopSourceRef`，假设这部分代码在 `myInstallCustomInputSource` 已经实现好了。下面的代码还省略了自动释放池和 `while` 主循环中做的实际工作。将标记是否需要退出线程的局部变量 `exitNow` 的值放在 TLS 中同步是为了方便 input source 的事件处理函数对 `exitNow` 的存取，因为事件处理是在另外一个函数，不能直接存取 `exitNow`，需要经过 TLS。当 input source 收到退出消息后，对应的事件处理函数便可以清理线程的资源，准备退出。

```
- (void)threadMainRoutine
{
    BOOL moreWorkToDo = YES;
    BOOL exitNow = NO;
    NSRunLoop* runLoop = [NSRunLoop currentRunLoop];
 
    // Add the exitNow BOOL to the thread dictionary.
    NSMutableDictionary* threadDict = [[NSThread currentThread] threadDictionary];
    [threadDict setValue:[NSNumber numberWithBool:exitNow] forKey:@"ThreadShouldExitNow"];
 
    // Install an input source.
    [self myInstallCustomInputSource];
 
    while (moreWorkToDo && !exitNow)
    {
        // Do one chunk of a larger body of work here.
        // Change the value of the moreWorkToDo Boolean when done.
 
        // Run the run loop but timeout immediately if the input source isn't waiting to fire.
        [runLoop runUntilDate:[NSDate date]];
 
        // Check to see if an input source handler changed the exitNow value.
        exitNow = [[threadDict valueForKey:@"ThreadShouldExitNow"] boolValue];
    }
}
```

