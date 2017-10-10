---
title: Threading Programming Guide(2)
date: 2017-09-17 14:07:13
tags:
- 翻译
---

[Threading Programming Guide](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Multithreading/RunLoopManagement/RunLoopManagement.html#//apple_ref/doc/uid/10000057i-CH16-SW1) 的学习笔记&翻译，第二部分。关于 Run Loop 的内容。

- [Threading Programming Guide(1)](http://yulingtianxia.com/blog/2017/08/28/Threading-Programming-Guide-1/)
- [Threading Programming Guide(3)](http://yulingtianxia.com/blog/2017/10/08/Threading-Programming-Guide-3/)

<!-- more -->

## Run Loops

Run Loop 作为线程相关基础设施的一部分，充当着循环处理、调度事件/消息的角色。它使得线程不会执行完单个任务后就立刻结束，而是让线程在没有任务时保持休眠状态，在需要处理消息时被立刻唤醒。

Run Loop 其实是个对象，但不需要主动去创建它，而且每个线程都有对应的 run loop 对象。Run Loop 的管理机制并不完全是自动的，有时需要设计好 run loop 的运行时间和事件处理回调。次级线程需要开发者手动去配置并运行它的 run loop，在应用启动过程中主线程的 run loop 已经自动配置并运行了。

Run Loop 作为苹果提供的 [Event Loop](https://en.wikipedia.org/wiki/Event_loop) 机制的实现方案，在 Cocoa 和 Core Foundation 有两个对应的类：[`NSRunLoop`](https://developer.apple.com/documentation/foundation/runloop) 和 [`CFRunLoop`](https://developer.apple.com/documentation/corefoundation/cfrunloop)

### Run Loop 剖析

Run Loop 可能需要开发者自己写 `while` 或 `for` 循环，并在里面驱动 run loop 对象运行，每轮运行都会处理接收到事件的回调。

Run Loop 接收的事件来源 (source) 有两种。Input Source 传送来自其他应用或线程的异步事件/消息；Timer Source 传送的是基于定时器的同步事件，可以定时或重复发送。

下图展示了 run loop 与多种 source 的概念架构。运行 `NSRunLoop` 实例的方式有三种，`runUntilDate:` 方法是其中的一种，后面会讲。Input Source 发送的异步事件产生的回调会使 `runUntilDate:` 退出；Timer Source 则不会。

![Structure of a run loop and its sources](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Multithreading/Art/runloop.jpg)

Run Loop 的一些行为会发通知，开发者可以注册成为 run-loop 观察者 (observer)。

Input Source, Timer Source, Run Loop Observer 统称为 Mode Item，这里的 Mode 指的是 Run Loop Mode。一个 Run Loop 包含若干个 Mode，每个 Mode 又包含若干个 Item。Item 与 Mode 是多对多的关系，没有 Item 的 Model 会立刻退出。

下面几节会详细讲述上面提到的这些概念。

#### Run Loop Modes

Run Loop Mode 包含了需要被监听的 input source 和 timer 集合，以及需要接收通知的 observer 集合。Run loop 的每次运行都会处在某个特定模式下，而且只有这个模式所包含的 item 集合才会参与发送事件(被监听)和接收通知。

开发者使用 run loop mode 时直接指定名字就行，Cocoa 和 Core Foundation 定义了一些默认和常用的 Mode。Run Loop Mode 对应的类是 `CFRunLoopModeRef`，但是并没有作为公有 API 开放出来，但可以通过 Core Foundation 源码了解下:

```
typedef struct __CFRunLoopMode *CFRunLoopModeRef;

struct __CFRunLoopMode {
    CFRuntimeBase _base; // CF 的基石，遍地可见
    pthread_mutex_t _lock; // 确保 CF 中的 Run Loop 线程安全
    CFStringRef _name; // Mode 的名字，比如 kCFRunLoopDefaultMode
    Boolean _stopped; 
    char _padding[3];
    CFMutableSetRef _sources0; // Input Sources 中的 Custom Input Source 集合
    CFMutableSetRef _sources1; // Input Sources 中的 Port-Based Source 集合
    CFMutableArrayRef _observers; // Run Loop Observers 数组
    CFMutableArrayRef _timers; // Timer Sources 数组
    CFMutableDictionaryRef _portToV1SourceMap; // 端口(port)与 sources1 的映射表
    __CFPortSet _portSet; // 端口集合
... 省略后面源码
};
```

Core Foundation 中所有实例都以 `CFRuntimeBase` 开始，仅限于内部使用。通过它的结构可以看出这里面保存了一些基本信息，比如 isa 指针，retainCount 等。

```
typedef struct __CFRuntimeBase {
    uintptr_t _cfisa;
    uint8_t _cfinfo[4];
#if __LP64__
    uint32_t _rc;
#endif
} CFRuntimeBase;
```

不同 Mode 直接是靠事件的来源 (Source) 区分的，而不是事件的类型。比方说 Mode 不能只搭配鼠标点击事件或键盘事件，但可以让某个 Mode 监听一些端口、暂停 timer、修改 source 和 observer 等。

下面的表格列出了一些系统定义的 Mode，大多数情况下会使用 Default Mode。[iphonedevwiki](http://iphonedevwiki.net/index.php/CFRunLoop) 列出了 Core Foundation 中更多的 Mode，很多是系统私有的。使用不同的 Mode 可以过滤不同 Source 发出的事件，比如在要求时效性操作的场景下使用自定义 Mode 来阻止低优先级 Source 发送事件。


| Mode | 名称 | 描述 |
| --- | --- | --- |
| Default |  NSDefaultRunLoopMode (Cocoa), kCFRunLoopDefaultMode (Core Foundation) | 大多数操作下最常用的 Mode，运行 Run Loop 和配置 Source 的首选 |
| Connection | NSConnectionReplyMode (Cocoa) | Cocoa 中结合 NSConnection 使用，用于监听回复(Reply)，极少用到。(已弃用) |
| Modal | NSModalPanelRunLoopMode (Cocoa) | Cocoa 中 modal panel 使用它接收与之相关 Source 的事件 |
| Event tracking | NSEventTrackingRunLoopMode (Cocoa), UITrackingRunLoopMode (Cocoa Touch) | Cocoa 用它限定鼠标拖拽事件之类的用户交互轨迹 |
| Common modes | NSRunLoopCommonModes (Cocoa), kCFRunLoopCommonModes (Core Foundation) | 可配置的通用模式集合，将某个 Input Source 关联到此 Mode 也会将其关联到集合中所有 Mode。Cocoa 框架中的 Common modes 默认包含 Default, Modal, Event tracking 三种 Mode；CF 框架起初只包含 Default，可以使用 `CFRunLoopAddCommonMode`函数向集合中添加自定义 Mode。 |

#### Input Sources

Input Sources 有两种实现：基于端口(Port-based)和自定义(Custom)，它们都向线程异步分发事件，而唯一的不同就是被发信号（signal）的方式。基于端口的事件源会自动由内核发信号，自定义事件源需要被其他线程手动发信号。

Input Source 会被添加到一些 Mode 中，如果某个 input source 不在当前的 Mode 中，那么它生成的事件在 run loop 处于正确的 mode 之前会先被 hold 住。

##### Port-Based Sources(Source1)

Cocoa 和 Core Foundation 使用端口相关的对象和函数提供了对创建基于端口的事件源的内建支持。比如在 Cocoa 中，只需创建一个端口对象并使用 `NSPort` 的方法来向 run loop 添加端口。端口对象为你处理好了创建和配置 input source 的事情。

在 Core Foundation 中需要手动创建端口和 run loop source。涉及到的 API 有 `CFMachPortRef`, `CFMessagePortRef`, `CFSocketRef`。

##### Custom Input Sources(Source0)

只能使用 Core Foundation 中的 `CFRunLoopSourceRef` 相关函数来创建自定义事件源。在处理到来的事件、从 run loop 移除 source 后都会有函数回调，可以通过实现这些回调函数来配置 source。

除此之外还需定义事件分发机制。source 有一部分是在单独的线程运行的，负责为 input source 提供数据，并在数据准备好后对 source 发信号。事件分发机制取决于开发者，但别弄得太过复杂。

##### Cocoa Perform Selector Sources

Cocoa 定义了一种在任何线程执行 `selector` 的 custom input source。与机遇端口的事件源相同之处是在目标线程依次执行 `selector`，缓解了一条线程运行多个方法时可能发生的同步问题；不同之处在于 `selector` 执行后会将 source 从 run loop 挪走。

在任意线程 perform selector 的前置条件是线程必须有一个活跃的 run loop。对于自己创建的线程，`selector` 直到启动 run loop 之后才会运行；主线程会自动配置并运行 run loop，然而要在应用的 `applicationDidFinishLaunching:` delegate 方法调用后才生效。Run Loop 每次循环会处理队列中所有的 `selector`，而不是循环一次处理一个。

下表中列出了 `NSObject` 类提供的在任何线程执行 `selector` 的 API。在任何线程下，只要能拿到 Objective-C 对象就能使用下面的 API，包括 POSIX 线程。这些方法并不会为了执行 `selector` 真的去创建一个新线程。

| 方法 | 描述 |
| --- | --- |
| `performSelectorOnMainThread:withObject:waitUntilDone:`, `performSelectorOnMainThread:withObject:waitUntilDone:modes:` | 在应用主线程 run loop 的下次循环执行特定的 `selector`，并提供了选项可以在执行 `selector` 之前阻塞当前线程。 |
| `performSelector:onThread:withObject:waitUntilDone:`, `performSelector:onThread:withObject:waitUntilDone:modes:` | 在任意 `NSThread` 对象执行 `selector`，同上。 |
| `performSelector:withObject:afterDelay:`, `performSelector:withObject:afterDelay:inModes:` | 在当前线程 run loop 的下次循环延迟一段时间执行 `selector`。因为需要等到下次 run loop 循环才会依次执行队列中的 `selector`，所以本身就会有一点延时。 |
| `cancelPreviousPerformRequestsWithTarget:`, `cancelPreviousPerformRequestsWithTarget:selector:object:` | 取消 `performSelector:withObject:afterDelay:` 或 `performSelector:withObject:afterDelay:inModes:` 方法向当前线程发送的消息。 |


#### Timer Sources

Timer source 会在未来一个预定时间向线程同步分发事件。线程可以用 Timer 来通知自己做一些事情。比如用户在搜索栏输入一连串字符之后的某个时间自动搜索一次结果。正是因为有了个延时，才让用户有机会在自动搜索发生前尽可能打出想要的搜索字符串。

Timer 并不是实时的，会有误差。如果一个 timer 不在正在运行的 run loop 监控的 mode 中，需要一直等到 run loop 运行在一个支持这个 timer 的 mode 时，timer 才会触发。如果一个 timer 触发的时候恰巧 run loop 正忙于执行某个 handler 程序，这个 timer 的 handler 程序需要等到下次才会通过 run loop 执行。如果 run loop 根本不在运行，timer 永远都不会触发。

可以配置 timer 只生成一次或重复多次事件。重复的 timer 每次会根据已经编排的触发时间自动重新编排。如果实际的触发时间太过于延迟，甚至是晚了一个或多个周期，那么也只会触发一次，而非连续多次。之后会重新编排下次触发时间。

`NSTimer` 和 `CFRunLoopTimerRef` 是 toll-free bridged 的，设置好时间和回调函数后加到正在运行的 run loop 中即可。具体信息可以参考这两个类的 API 文档。

#### Run Loop Observers

不同于 source 在同步或异步事件发生时触发，observer 会在 run loop 运行期间的某些特殊地方触发。这些 run loop 中『特殊』的地方列举如下：

1. 进入 run loop
2. 当 run loop 即将处理一个 timer
3. 当 run loop 即将处理一个 input source
4. 当 run loop 即将休眠
5. 当 run loop 已经被唤醒，但在它处理唤醒它的事件之前
6. 退出 run loop

可以使用 Core Foundation 的 `CFRunLoopObserverRef` 类创建 run loop observer。`CFRunLoopObserverRef` 记录了回调函数和关注的事件类型（上面 6 种时间的掩码），它跟 timer 一样可以在创建的时候选择只触发一次或重复触发。

#### Run Loop 事件顺序

线程的 run loop 每次运行都会处理待决的事件，并为绑定的所有 observer 生成通知。次序如下：

1. 通知 observer 已经进入 run loop
2. 通知 observer 有 timer 将要触发
3. 通知 observer 有非基于端口的 input source 将要触发
4. 触发所有已就绪的非基于端口的 input source
5. 如果一个基于端口的 input source 已就绪并等待触发，立即处理事件，并转至**第 9 步**
6. 通知 observer 线程即将休眠
7. 让线程休眠，直到被以下条件唤醒：
	- 有基于端口的 input source 事件到达
	- timer 触发
	- run loop 设定的超时时间到了
	- run loop 被手动唤醒
8. 通知 observer 线程刚刚被唤醒
9. 处理待决事件
	- 如果用户定义的 timer 触发了，处理 timer 事件并重启 run loop，跳回到**第 2 步**
	- 如果 input source 触发了，分发事件
	- 如果 run loop 被唤醒且没有超时，重启 run loop，跳回到**第 2 步**
10. 通知 observer 已经退出 run loop

由于 timer 和 input source 对 observer 的通知是在事件真正发生前就已经发出，所以这之间会有时间间隔。如果对事件时间的掌控很严格，可以使用休眠和唤醒的通知帮你关联实际事件的时机。

由于 timer 和其他周期性事件是在运行 run loop 的时候发送的，绕过 loop 会打断这些事件的发送。典型的案例就是在实现鼠标追踪程序中写了个不断从应用请求事件的循环逻辑，按理说应该是让应用正常地分发这些事件，而不是主动抓取。这就导致 timer 被开发者写的循环逻辑阻塞而一直无法触发。

可以使用 run loop 对象将其手动唤醒，其他事件也可能导致 run loop 被唤醒。比如添加另一个非基于端口的 input source 唤醒 run loop，input source 就能立刻被处理，而不是一直等到其他事件发生。

### 该何时使用 Run Loop？

需要手动运行 run loop 的场景只有一个，那就是你创建次级线程的时候。应用主线程的 run loop 是基础设施中至关重要的部分。应用框架会把自动运行主线程 run loop 的程序写好，比如 `UIApplication` 或 `NSApplication` 中的 `run`。如果使用 Xcode 带的模板创建工程，千万不要去调用这些方法。

对于次级线程是否有必要手动开启 run loop，那要看实际情况了。比如使用线程执行一些预先设定好的运行时间较长的任务，可能就不需要开启 run loop 了。Run Loop 是为『想要与线程更多交互』的场景准备的，例如：

- 使用 input source 与其他线程通信
- 在线程中使用 timer
- 在 Cocoa 应用中使用任何 `performSelector...` 系列的方法
- 让线程执行周期性任务

如果选择使用 run loop，配置和启动是很简单的。可是就所有的线程编程来说，应该计划好在合适的场景下退出次级线程，总比强行退出要好。

### 使用 Run Loop 对象

Run Loop 对象提供了向 run loop 中添加 input source、timer 和 run-loop observer 的主要接口，并运行起来。每个线程都关联一个单独的 run loop。在 Cocoa 中，Run Loop 对象是个 ` NSRunLoop` 类的实例，在 Core Foundation 中是 `CFRunLoopRef` 指针。但它们不是 toll-free bridge 的。

#### 获取 Run Loop 对象

获取当前线程的 run loop 对象有两种方式：

- Cocoa 框架 `NSRunLoop` 的类方法 `currentRunLoop`
- `CFRunLoopGetCurrent` 函数

可以从 `NSRunLoop` 对象的 `getCFRunLoop` 方法获取到 `CFRunLoopRef`，这样就可以传给 Core Foundation 程序使用了。二者都指向同一个 run loop，所以可以混用。

#### 配置 Run Loop

在次级线程运行 run loop 之前，必须向其添加至少一个 input source 或 timer，否则 run loop 会因没有可监控的 source 而在运行后立刻退出。

除了用 source 外，还可以用 run loop observer 观察 run loop 的各种运行阶段。做法是创建一个 `CFRunLoopObserverRef` 类型的对象并用 `CFRunLoopAddObserver` 函数将其添加到 run loop 中。注意的是只能用 Core Foundation 创建 run loop observer，Cocoa 框架无能为力。

下面的示例代码在线程入口函数中创建了 run loop observer 并将其添加到 run loop 中。observer 监听了 run loop 所有的活动，并省略了回调函数 `myRunLoopObserver` 的实现。

```
- (void)threadMain
{
    // The application uses garbage collection, so no autorelease pool is needed.
    NSRunLoop* myRunLoop = [NSRunLoop currentRunLoop];
 
    // Create a run loop observer and attach it to the run loop.
    CFRunLoopObserverContext  context = {0, self, NULL, NULL, NULL};
    CFRunLoopObserverRef    observer = CFRunLoopObserverCreate(kCFAllocatorDefault,
            kCFRunLoopAllActivities, YES, 0, &myRunLoopObserver, &context);
 
    if (observer)
    {
        CFRunLoopRef    cfLoop = [myRunLoop getCFRunLoop];
        CFRunLoopAddObserver(cfLoop, observer, kCFRunLoopDefaultMode);
    }
 
    // Create and schedule the timer.
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self
                selector:@selector(doFireTimer:) userInfo:nil repeats:YES];
 
    NSInteger    loopCount = 10;
    do
    {
        // Run the run loop 10 times to let the timer fire.
        [myRunLoop runUntilDate:[NSDate dateWithTimeIntervalSinceNow:1]];
        loopCount--;
    }
    while (loopCount);
}
```

为了不让 run loop 刚运行就立刻退出，上面的代码向 run loop 添加了一个 timer。因为 timer 一旦触发就无效了，依然会导致 run loop 退出，所以这里 `repeats` 参数传入 `YES`。但这样会让 run loop 一直运行很久，并需要周期性触发 timer 来唤醒线程，这实际上是轮询的另一种形式罢了。相比之下，input source 等待事件发生后才唤醒线程，在这之前线程保持休眠。

`CFRunLoopObserverContext` 结构体定义如下，查文档可知第二个参数 `info` 会在回调函数被调用时当做参数传入，这里传入 `self`。

```
typedef struct {
    CFIndex	version;
    void *	info;
    const void *(*retain)(const void *info);
    void	(*release)(const void *info);
    CFStringRef	(*copyDescription)(const void *info);
} CFRunLoopObserverContext;
```

#### 启动 Run Loop

只有在应用的次级线程才需要启动 run loop，而且需要有至少一个 input source 或 timer，否则 run loop 启动后会立刻退出。

启动 run loop 的几种方式包括：

- 无条件：
- 设定时间限制
- 处于特定模式（Mode）

| 方式 | 方法名(NSRunLoop) | 解释 |
| --- | --- | --- |
| 无条件 |  run | 最简单但也最不可取的方案。会让线程进入无限循环，对 run loop 很难控制。可以添加和移除 input source 和 timer，但只能通过 kill 的方式停止 run loop。也无法在自定义模式下运行 run loop。 |
|  设定时间限制 | runUntilDate: | run loop 在收到事件或超时前会一直运行。run loop 结束后可以重启，并处理接下来的事情。比上一种方式更好，提供了时间限制。 |
| 处于特定模式 | runMode:beforeDate: | 相比上一种方式，增加了在特定模式下运行 run loop。 |

`run` 和 `runUntilDate:` 方法会使用 `NSDefaultRunLoopMode` 参数不断调用 `runMode:beforeDate:` 方法。

下面的代码展示了一个线程入口函数的大纲，主要是 run loop 的基本构成。本质上就是配置好 run loop 并运行后，每轮运行后不断检查是否需要退出线程。使用 Core Foundation 可以检查 run loop 每次运行的结果，并决定是否需要退出线程。当然也可以使用上面 `NSRunLoop` 提供的 API，而且无需检查每次运行的返回值。后面会有例子。

```
- (void)skeletonThreadMain
{
    // Set up an autorelease pool here if not using garbage collection.
    BOOL done = NO;
 
    // Add your sources or timers to the run loop and do any other setup.
 
    do
    {
        // Start the run loop but return after each source is handled.
        SInt32    result = CFRunLoopRunInMode(kCFRunLoopDefaultMode, 10, YES);
 
        // If a source explicitly stopped the run loop, or if there are no
        // sources or timers, go ahead and exit.
        if ((result == kCFRunLoopRunStopped) || (result == kCFRunLoopRunFinished))
            done = YES;
 
        // Check for any other exit conditions here and set the
        // done variable as needed.
    }
    while (!done);
 
    // Clean up code here. Be sure to release any allocated autorelease pools.
}
```

其实上面这段调用 `CFRunLoopRunInMode()` 的逻辑跟 `CFRunLoopRun()` 差不多。

可以递归启动 run loop。也就是说可以在 input source 或 timer 的回调处理函数中调用 `CFRunLoopRun`, `CFRunLoopRunInMode` 或上面提到的 `NSRunLoop` 的三个方法，而且嵌套的 run loop 可以在任意 Mode 下运行。

#### 退出 Run Loop

在 run loop 已经将事件处理之前有两种退出的方式：

1. 给 run loop 配置 timeout 值
2. 告诉 run loop 停止

推荐第一种方法，因为它会让 run loop 完成一切正常的处理，包括在退出前向 observer 发通知。

使用 `CFRunLoopStop` 函数停止 run loop 的结果跟第一种方式差不多，run loop 会把剩下的通知发出去，然后退出。不同点在于可以用这个函数停止以无条件方式（`run` 方法）启动的 run loop。要注意的是 `CFRunLoopStop` 只会停止对 `CFRunLoopRun` 和 `CFRunLoopRunInMode` 的调用，对于 Cocoa 框架相当于只停止一次 `runMode:beforeDate:` 的调用，而不是退出 run loop。stop 一次运行和 exit 整个 run loop 是不一样的。

虽然移除 run loop 的 input source 和 timer 也会导致其退出，但这种方法不可靠。因为有些系统程序会向 run loop 中添加 input source，开发者根本不知道有这回事，移除的时候就会漏掉，自然就不会导致 run loop 退出。

#### 线程安全和 Run Loop 对象

使用 Core Foundation 中的函数操作 run loop 对象一般都是线程安全的，可以在任何线程调用。如果要更改 run loop 的配置，尽可能在 run loop 自己的线程操作。

Cocoa 中对应的 `NSRunLoop` 内部并不是线程安全的，必须在 run loop 所在的线程修改它。向其他线程的 run loop 添加 input source 或 timer 都会导致 crash 或异常行为。

### 配置 Run Loop Source

主要演示使用 Cocoa 和 Core Foundation 设置各种类型的 source。

#### 定义 Custom Input Source

创建 custom input source 需要阐明如下内容：

- 想让 input source 处理的信息
- 用于让外部 client 获知如何联系 input source 的 scheduler 程序
- 执行任何 client 发出请求的 perform 程序
- 作废 input source 的 cancellation 程序

Custom Input Source 的配置是很灵活的，scheduler，perform 和 cancellation 这几个程序的实现才是关键。然而 input source 剩余的大部分行为都发生在这些程序的外部，需要开发者自己定义一个机制，用于向 input source 传递数据和暴漏 input source 给其他线程。

下图展示了一个配置 custom input source 的例子。主线程维护了对 input source 及其 custom command buffer 和 run loop 的引用。当主线程想要把一个任务切换到 worker 线程的时候，会向 command buffer 发送一条命令。这条命令包含了 worker 线程启动任务所需的任何信息。由于主线程和 worker 线程的 input source 都可以存取 command buffer，所以存取操作需要被同步。一旦命令发出，主线程对 input source 发信号，并唤醒 worker 线程的 run loop。Run Loop 一旦收到了唤醒命令，就会调用 input source 的 handler 程序，handler 会处理 command buffer 中的命令。

![](https://developer.apple.com/library/content/documentation/Cocoa/Conceptual/Multithreading/Art/custominputsource.jpg)

下面会解释上图中 custom input source 的实现，并展示需要实现的关键代码。

##### 定义 Input Source

需要用 Core Foundation 配置 run loop source，并将其加到 run loop 中。因为 handler 都是基于 C 的函数，所以需要将其封装成 Objective-C 的接口。下面的代码封装了两个 Objective-C 类：`RunLoopSource` 封装了 `CFRunLoopSourceRef`，并管理一个 command buffer，并使用 buffer 接收其他线程的消息。`RunLoopContext` 封装了 `CFRunLoopRef` 和 `RunLoopSource` 指针，用于向应用主线程传递 source 对象和 run loop 引用。

```
@interface RunLoopSource : NSObject
{
    CFRunLoopSourceRef runLoopSource;
    NSMutableArray* commands;
}
 
- (id)init;
- (void)addToCurrentRunLoop;
- (void)invalidate;
 
// Handler method
- (void)sourceFired;
 
// Client interface for registering commands to process
- (void)addCommand:(NSInteger)command withData:(id)data;
- (void)fireAllCommandsOnRunLoop:(CFRunLoopRef)runloop;
 
@end
 
// These are the CFRunLoopSourceRef callback functions.
void RunLoopSourceScheduleRoutine (void *info, CFRunLoopRef rl, CFStringRef mode);
void RunLoopSourcePerformRoutine (void *info);
void RunLoopSourceCancelRoutine (void *info, CFRunLoopRef rl, CFStringRef mode);
 
// RunLoopContext is a container object used during registration of the input source.
@interface RunLoopContext : NSObject
{
    CFRunLoopRef        runLoop;
    RunLoopSource*        source;
}
@property (readonly) CFRunLoopRef runLoop;
@property (readonly) RunLoopSource* source;
 
- (id)initWithSource:(RunLoopSource*)src andLoop:(CFRunLoopRef)loop;
@end
```

下面会分别列出 scheduler，handler 和 cancellation 三个 C 语言的回调函数的实现。

第一个被调用的函数是 scheduler，当你把 source 添加到 run loop 中时就会调用。按照之前的实例，我们的 input source 只有一个 client，也就是主线程。这里 scheduler 做的事情就是用 application delegate 的 `registerSource:` 方法将 `RunLoopContext` 对象中的信息传递过去，以便之后 application delegate 与 input source 通信时使用。

```
void RunLoopSourceScheduleRoutine (void *info, CFRunLoopRef rl, CFStringRef mode)
{
    RunLoopSource* obj = (__bridge RunLoopSource*)info;
    AppDelegate*   del = [AppDelegate sharedAppDelegate];
    RunLoopContext* theContext = [[RunLoopContext alloc] initWithSource:obj andLoop:rl];
 
    [del performSelectorOnMainThread:@selector(registerSource:)
                                withObject:theContext waitUntilDone:NO];
}
```

当 input source 被发信号（signal）的时候，用于处理数据的 perform 函数会被调用，它是最重要的回调之一。这里很简单地转发给了 `RunLoopSource` 的 `sourceFired` 方法。后面会列出 `sourceFired` 处理 command buffer 的逻辑。

```
void RunLoopSourcePerformRoutine (void *info)
{
    RunLoopSource*  obj = (__bridge RunLoopSource*)info;
    [obj sourceFired];
}
```

如果用调用 `CFRunLoopSourceInvalidate` 函数之类的方式将 input source 从它的 run loop 中移除，系统会调用 input source 的 cancellation 程序。可以在这个程序中告诉 client 可以移除对 input source 的引用了，因为它已经失效了。下面的 cancellation 回调函数将传入的 `RunLoopSource` 对象和 `CFRunLoopRef` 打包成一个 `RunLoopContext`，并传给 application delegate。

```
void RunLoopSourceCancelRoutine (void *info, CFRunLoopRef rl, CFStringRef mode)
{
    RunLoopSource* obj = (__bridge RunLoopSource*)info;
    AppDelegate* del = [AppDelegate sharedAppDelegate];
    RunLoopContext* theContext = [[RunLoopContext alloc] initWithSource:obj andLoop:rl];
 
    [del performSelectorOnMainThread:@selector(removeSource:)
                                withObject:theContext waitUntilDone:YES];
}
```

上面这三个回调函数中 application delegate 的 `registerSource:` 和 `removeSource:` 方法暂时省略，后面会列出。这三个回调函数会在创建 custom input source 的时候当做参数传入。

##### 在 Run Loop 上装载 Input Source

下面代码是 `RunLoopSource` 类的 `init` 和 `addToCurrentRunLoop` 方法。`init` 创建了一个 `CFRunLoopSourceRef`，这才是真正被添加到 run loop 中的类型。当 worker 线程调用 `addToCurrentRunLoop` 方法时，才会将 input source 装载到 run loop 中，并在此时调用 `RunLoopSourceScheduleRoutine` 回调函数。之后就可以启动 run loop 了。

```
- (id)init
{
    CFRunLoopSourceContext    context = {0, (__bridge void *)(self), NULL, NULL, NULL, NULL, NULL,
                                        &RunLoopSourceScheduleRoutine,
                                        &RunLoopSourceCancelRoutine,
                                        &RunLoopSourcePerformRoutine};
 
    runLoopSource = CFRunLoopSourceCreate(NULL, 0, &context);
    commands = [[NSMutableArray alloc] init];
 
    return self;
}
 
- (void)addToCurrentRunLoop
{
    CFRunLoopRef runLoop = CFRunLoopGetCurrent();
    CFRunLoopAddSource(runLoop, runLoopSource, kCFRunLoopDefaultMode);
}
```

`CFRunLoopSourceContext` 结构体描述了 custom input source（source0）的上下文，而 `CFRunLoopSourceContext1` 结构体描述了 port-based input source（source1）的上下文。看文档可知，`info` 用于向回调函数传入数据，`schedule`，`cancel` 和 `perform` 分别对应上面代码中传入的三个回调函数。将这些信息打包进上下文后，就可以用 `CFRunLoopSourceCreate` 函数创建 run loop 对象了。

```
typedef struct {
    CFIndex	version;
    void *	info;
    const void *(*retain)(const void *info);
    void	(*release)(const void *info);
    CFStringRef	(*copyDescription)(const void *info);
    Boolean	(*equal)(const void *info1, const void *info2);
    CFHashCode	(*hash)(const void *info);
    void	(*schedule)(void *info, CFRunLoopRef rl, CFRunLoopMode mode);
    void	(*cancel)(void *info, CFRunLoopRef rl, CFRunLoopMode mode);
    void	(*perform)(void *info);
} CFRunLoopSourceContext;

typedef struct {
    CFIndex	version;
    void *	info;
    const void *(*retain)(const void *info);
    void	(*release)(const void *info);
    CFStringRef	(*copyDescription)(const void *info);
    Boolean	(*equal)(const void *info1, const void *info2);
    CFHashCode	(*hash)(const void *info);
#if (TARGET_OS_MAC && !(TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)) || (TARGET_OS_EMBEDDED || TARGET_OS_IPHONE)
    mach_port_t	(*getPort)(void *info);
    void *	(*perform)(void *msg, CFIndex size, CFAllocatorRef allocator, void *info);
#else
    void *	(*getPort)(void *info);
    void	(*perform)(void *info);
#endif
} CFRunLoopSourceContext1;
```

两种 Context 的结构很相似，所以 `CFRunLoopSourceRef` 中使用 `union` 存储这两个互斥存在的结构体，内存占用上只差一个指针：

```
typedef struct __CFRunLoopSource * CFRunLoopSourceRef;
struct __CFRunLoopSource {
    CFRuntimeBase _base;
    uint32_t _bits;
    pthread_mutex_t _lock;
    CFIndex _order;			/* immutable */
    CFMutableBagRef _runLoops;
    union {
	CFRunLoopSourceContext version0;	/* immutable, except invalidation */
        CFRunLoopSourceContext1 version1;	/* immutable, except invalidation */
    } _context;
};
```

##### Input Source 与 Client 的协作

自定义的 input source 需要由其他线程手动发信号。重点是其线程在这之前会一直处于休眠状态，所以一定要让其他线程知道这个 input source，并能与之通信。

当 input source 第一次装载到 run loop 的时候，可以向 client 发送注册 input source 的请求。可以将一个 input source 直接或间接注册到多个 client 中。下面的代码展示了 application delegate 提供的注册方法 `registerSource:`，之前提到过回调函数 `RunLoopSourceScheduleRoutine` 的实现会调用 `registerSource:`。也就是说执行流程是 install(`addToCurrentRunLoop`) -> schedule(`RunLoopSourceScheduleRoutine`) -> register(`registerSource:`)。对应地，当 input source 从 run loop 中被移除，回调函数 `RunLoopSourceCancelRoutine` 中会调用 `removeSource:` 方法。

```
- (void)registerSource:(RunLoopContext*)sourceInfo;
{
    [sourcesToPing addObject:sourceInfo];
}
 
- (void)removeSource:(RunLoopContext*)sourceInfo
{
    id    objToRemove = nil;
 
    for (RunLoopContext* context in sourcesToPing)
    {
        if ([context isEqual:sourceInfo])
        {
            objToRemove = context;
            break;
        }
    }
 
    if (objToRemove)
        [sourcesToPing removeObject:objToRemove];
}
```

代码逻辑很简单，就是 application delegate 维护了一个存储 `RunLoopContext` 对象的可变数组 `sourcesToPing`，并提供了增加和移除数组元素的两个方法。

##### 给 Input Source 发信号(Signal) 

Client 在将数据传递给 input source 后，还需要给 source 发信号，并唤醒 run loop。发信号的作用是让 run loop 知道 input source 已经做好被处理的准备了。当信号发出时线程可能还在休眠，所以必须唤醒 run loop。否则可能会导致延迟处理 input source。

下面代码展示了 `RunLoopSource` 对象的 `fireCommandsOnRunLoop` 方法。当 Client 准备好让 source 处理 command buffer 中的命令时会调用这个方法。

```
- (void)fireCommandsOnRunLoop:(CFRunLoopRef)runloop
{
    CFRunLoopSourceSignal(runLoopSource);
    CFRunLoopWakeUp(runloop);
}
```

#### 配置 Timer Source

使用不同框架创建 timer 对象的方式略有差别：Cocoa 中使用 `NSTimer`，Core Foundation 中使用 `CFRunLoopTimerRef` 类型。二者是 toll-free bridged 的，但是 `NSTimer` 提供的 API 更便捷。比如可以用下面的方法马上创建并安排（schedule）好一个 timer：

```
scheduledTimerWithTimeInterval:target:selector:userInfo:repeats:
scheduledTimerWithTimeInterval:invocation:repeats:
```

上面这些方法会创建 timer 并添加到当前线程 run loop 的 Default Mode 中。也可以手动创建一个 `NSTimer` 对象并用 `NSRunLoop` 的 `addTimer:forMode:` 方法将其添加到 run loop 的指定 Mode 中。这些方法做的事情都差不多，只是对 timer 配置的掌控程度不同。下面的代码展示了两种添加 timer 的方式：第一个 timer 延迟 1 秒触发并每隔 0.1 秒重复触发，第二个 timer 延迟 0.2 秒触发然后每隔 0.2 秒重复触发。

```
NSRunLoop* myRunLoop = [NSRunLoop currentRunLoop];
 
// Create and schedule the first timer.
NSDate* futureDate = [NSDate dateWithTimeIntervalSinceNow:1.0];
NSTimer* myTimer = [[NSTimer alloc] initWithFireDate:futureDate
                        interval:0.1
                        target:self
                        selector:@selector(myDoFireTimer1:)
                        userInfo:nil
                        repeats:YES];
[myRunLoop addTimer:myTimer forMode:NSDefaultRunLoopMode];
 
// Create and schedule the second timer.
[NSTimer scheduledTimerWithTimeInterval:0.2
                        target:self
                        selector:@selector(myDoFireTimer2:)
                        userInfo:nil
                        repeats:YES];
```

下面的代码展示了如何使用 Core Foundation 函数配置 timer。虽然这个例子并没有在 `context` 结构体中传递任何用户定义的信息，但你可以用这个结构体传送 timer 所需的一切自定义信息。可以查看文档了解下 `CFRunLoopTimerRef`。

```
CFRunLoopRef runLoop = CFRunLoopGetCurrent();
CFRunLoopTimerContext context = {0, NULL, NULL, NULL, NULL};
CFRunLoopTimerRef timer = CFRunLoopTimerCreate(kCFAllocatorDefault, 0.1, 0.3, 0, 0,
                                        &myCFTimerCallback, &context);
 
CFRunLoopAddTimer(runLoop, timer, kCFRunLoopCommonModes);
```

#### 配置 Port-Based Input Source

Cocoa 和 Core Foundation 都提供了用于线程间或进程间通讯的基于端口（port-based）的对象。下面展示了如何用几种不同类型的端口来设置端口通信。

##### 配置 `NSMachPort` 对象

使用 `NSMachPort` 对象建立本地连接过程如下：创建 `NSMachPort` 对象并添加到主线程的 run loop 中。当启动次级线程时将这个 `NSMachPort` 对象传递给次级线程的入口函数。次级线程会用这个 `NSMachPort` 对象往主线程发消息。

###### 实现主线程代码

下面的代码展示了启动次级 worker 线程的主要代码。使用 Cocoa 框架写出的代码要比 Core Foundation 的少多了，但效果几乎一样。有个不同点是 Cocoa 直接传递 `NSPort` 对象，而 Core Foundation 传递端口名字符串。

```
- (void)launchThread
{
    NSPort* myPort = [NSMachPort port];
    if (myPort)
    {
        // This class handles incoming port messages.
        [myPort setDelegate:self];
 
        // Install the port as an input source on the current run loop.
        [[NSRunLoop currentRunLoop] addPort:myPort forMode:NSDefaultRunLoopMode];
 
        // Detach the thread. Let the worker release the port.
        [NSThread detachNewThreadSelector:@selector(LaunchThreadWithPort:)
               toTarget:[MyWorkerClass class] withObject:myPort];
    }
}
```

我们想要在次级线程启动一切正常后给主线程通过本地端口通信报个平安，下面的 `handlePortMessage:` 方法会在线程自己的本地端口收到数据后被调用。`NSPortMessage` 持有两个端口对象：发送端口和接收端口。`handlePortMessage:` 方法中使用 `[portMessage sendPort]` 获取到了发送端口对象，也就是次级线程拥有的本地端口。也就是次级线程启动后会给主线程发消息，告知自己的端口对象，主线程会将其存下来以备日后使用。`msgid` 标记了消息的唯一 ID。

```
#define kCheckinMessage 100
 
// Handle responses from the worker thread.
- (void)handlePortMessage:(NSPortMessage *)portMessage
{
    unsigned int message = [portMessage msgid];
    NSPort* distantPort = nil;
 
    if (message == kCheckinMessage)
    {
        // Get the worker thread’s communications port.
        distantPort = [portMessage sendPort];
 
        // Retain and save the worker port for later use.
        [self storeDistantPort:distantPort];
    }
    else
    {
        // Handle other messages.
    }
}
```

###### 实现次级线程代码

次级线程的入口函数会被传入主线程的端口对象，配置好次级线程后，使用主线程的端口对象来与主线程通信。下面代码中的 `MyWorkerClass` 是个辅助类，它的 `sendCheckinMessage:` 方法负责创建次级线程的本地端口，并发消息给主线程。

```
+ (void)LaunchThreadWithPort:(id)inData
{
    NSAutoreleasePool*  pool = [[NSAutoreleasePool alloc] init];
 
    // Set up the connection between this thread and the main thread.
    NSPort* distantPort = (NSPort*)inData;
 
    MyWorkerClass*  workerObj = [[self alloc] init];
    [workerObj sendCheckinMessage:distantPort];
    [distantPort release];
 
    // Let the run loop process things.
    do
    {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                            beforeDate:[NSDate distantFuture]];
    }
    while (![workerObj shouldExit]);
 
    [workerObj release];
    [pool release];
}t
```

在线程间的单向通信中，同一个 `NSMachPort` 对象既可以其所在线程的本地端口，又可以是其他线程的远程端口。也就是线程创建的本地端口对象对于其他现场来说是远程端口。下面的代码展示了 `sendCheckinMessage:` 方法的实现。它创建了次级线程的本地端口，并使用主线程从 `LaunchThreadWithPort:` 方法传来的端口对象，构建了 `NSPortMessage` 消息对象，设置好 `msgid` 后，然后立即发送出去。

```
// Worker thread check-in method
- (void)sendCheckinMessage:(NSPort*)outPort
{
    // Retain and save the remote port for future use.
    [self setRemotePort:outPort];
 
    // Create and configure the worker thread port.
    NSPort* myPort = [NSMachPort port];
    [myPort setDelegate:self];
    [[NSRunLoop currentRunLoop] addPort:myPort forMode:NSDefaultRunLoopMode];
 
    // Create the check-in message.
    NSPortMessage* messageObj = [[NSPortMessage alloc] initWithSendPort:outPort
                                         receivePort:myPort components:nil];
 
    if (messageObj)
    {
        // Finish configuring the message and send it immediately.
        [messageObj setMsgid:kCheckinMessage];
        [messageObj sendBeforeDate:[NSDate date]];
    }
}
```

##### 配置 `NSMessagePort` 对象

如果用 `NSMessagePort` 对象建立本地连接，不能在线程间简单地传递端口对象，而是必须要拿到端口名称。使用一个字符串作为键在 `NSMessagePortNameServer` 注册本地端口，并把这个字符串传给另外的线程，这样就能通过这个字符串获取到端口对象，接着用它通信。下面的代码展示了使用创建和注册 `NSMessagePort` 的过程。

```
NSPort* localPort = [[NSMessagePort alloc] init];
 
// Configure the object and add it to the current run loop.
[localPort setDelegate:self];
[[NSRunLoop currentRunLoop] addPort:localPort forMode:NSDefaultRunLoopMode];
 
// Register the port using a specific name. The name must be unique.
NSString* localPortName = [NSString stringWithFormat:@"MyPortName"];
[[NSMessagePortNameServer sharedInstance] registerPort:localPort
                     name:localPortName];
```

##### 使用 Core Foundation 配置基于端口的 Input Source

使用 Core Foundation 在主线程和其他线程之间建立一个双向通讯通道需要写更多的代码。

首先在主线程中发起一个 worker 线程，然后创建端口用于监听其他线程的消息。跟之前使用 Cocoa 不同在于这里是将一个唯一的端口名传给 worker 线程的入口函数，而不是端口对象。

官方文档中创建 `CFMessagePortRef ` 的相关方法在 iOS 7 之后已经失效了，而且使用 Cocoa 提供的 API 更加方便，这里不再贴出 Core Foundation 版本的示例代码。

所以不推荐使用 Core Foundation 建立线程端口通讯，但是 macOS 上建立进程间通讯还是可以尝试的。


