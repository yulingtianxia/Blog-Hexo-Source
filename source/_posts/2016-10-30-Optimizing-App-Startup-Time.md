---
title: 优化 App 的启动时间
date: 2016-10-30 13:11:10
tags:
- Runtime

---

这是一篇 WWDC 2016 Session 406 的学习笔记，从原理到实践讲述了如何优化 App 的启动时间。

<!--more-->

## App 运行理论

- `main()` 执行前发生的事
- Mach-O 格式
- 虚拟内存基础
- Mach-O 二进制的加载

### 理论速成

#### Mach-O 术语

Mach-O 是针对不同运行时可执行文件的文件类型。 

文件类型：

- Executable： 应用的主要二进制
- Dylib： 动态链接库（又称 DSO 或 DLL）
- Bundle： 不能被链接的 Dylib，只能在运行时使用 `dlopen()` 加载，可当做 macOS 的插件。

Image： executable，dylib 或 bundle
Framework： 包含 Dylib 以及资源文件和头文件的文件夹

#### Mach-O 镜像文件

Mach-O 被划分成一些 segement，每个 segement 又被划分成一些 section。

segment 的名字都是大写的，且空间大小为页的整数。页的大小跟硬件有关，在 arm64 架构一页是 16KB，其余为 4KB。

section 虽然没有整数倍页大小的限制，但是 section 之间不会有重叠。

几乎所有 Mach-O 都包含这三个段（segment）： `__TEXT`,`__DATA` 和 `__LINKEDIT`：

- `__TEXT` 包含 Mach header，被执行的代码和只读常量（如C 字符串）。只读可执行（r-x）。
- `__DATA` 包含全局变量，静态变量等。可读写（rw-）。
- `__LINKEDIT` 包含了加载程序的『元数据』，比如函数的名称和地址。只读（r--）。

#### Mach-O Universal 文件

[FAT 二进制](https://en.wikipedia.org/wiki/Fat_binary)文件，将多种架构的 Mach-O 文件合并而成。它通过 Fat Header 来记录不同架构在文件中的偏移量，Fat Header 占一页的空间。

按分页来存储这些 segement 和 header 会浪费空间，但这有利于虚拟内存的实现。

#### 虚拟内存

虚拟内存就是一层间接寻址（indirection）。软件工程中有句格言就是任何问题都能通过添加一个间接层来解决。虚拟内存解决的是管理所有进程使用物理 RAM 的问题。通过添加间接层来让每个进程使用逻辑地址空间，它可以映射到 RAM 上的某个物理页上。这种映射不是一对一的，逻辑地址可能映射不到 RAM 上，也可能有多个逻辑地址映射到同一个物理 RAM 上。针对第一种情况，当进程要存储逻辑地址内容时会触发 page fault；第二种情况就是多进程共享内存。

对于文件可以不用一次性读入整个文件，可以使用分页映射（`mmap()`）的方式读取。也就是把文件某个片段映射到进程逻辑内存的某个页上。当某个想要读取的页没有在内存中，就会触发 page fault，内核只会读入那一页，实现文件的懒加载。

也就是说 Mach-O 文件中的 `__TEXT` 段可以映射到多个进程，并可以懒加载，且进程之间共享内存。`__DATA` 段是可读写的。这里使用到了 Copy-On-Write 技术，简称 COW。也就是多个进程共享一页内存空间时，一旦有进程要做写操作，它会先将这页内存内容复制一份出来，然后重新映射逻辑地址到新的 RAM 页上。也就是这个进程自己拥有了那页内存的拷贝。这就涉及到了 clean/dirty page 的概念。dirty page 含有进程自己的信息，而 clean page 可以被内核重新生成（重新读磁盘）。所以 dirty page 的代价大于 clean page。

#### Mach-O 镜像 加载

所以在多个进程加载 Mach-O 镜像时 `__TEXT` 和  `__LINKEDIT` 因为只读，都是可以共享内存的。而 `__DATA` 因为可读写，就会产生 dirty page。当 dyld 执行结束后，`__LINKEDIT` 就没用了，对应的内存页会被回收。

#### 安全

ASLR（Address Space Layout Randomization）：地址空间布局随机化，镜像会在随机的地址上加载。这其实是一二十年前的旧技术了。

代码签名：可能我们认为 Xcode 会把整个文件都做加密 hash 并用做数字签名。其实为了在运行时验证 Mach-O 文件的签名，并不是每次重复读入整个文件，而是把每页内容都生成一个单独的加密散列值，并存储在 `__LINKEDIT` 中。这使得文件每页的内容都能及时被校验确并保不被篡改。

### 从 `exec()` 到 `main()`

`exec()` 是一个系统调用。系统内核把应用映射到新的地址空间，且每次起始位置都是随机的（因为使用 ASLR）。并将起始位置到 `0x000000` 这段范围的进程权限都标记为不可读写不可执行。如果是 32 位进程，这个范围**至少**是 4KB；对于 64 位进程则**至少**是 4GB。NULL 指针引用和指针截断误差都是会被它捕获。

### `dyld` 加载 dylib 文件

Unix 的前二十年很安逸，因为那时还没有发明动态链接库。有了动态链接库后，一个用于加载链接库的帮助程序被创建。在苹果的平台里是 `dyld`，其他 Unix 系统也有 [`ld.so`](https://zh.wikipedia.org/wiki/Ld.so)。 当内核完成映射进程的工作后会将名字为 `dyld` 的Mach-O 文件映射到进程中的随机地址，它将 PC 寄存器设为 `dyld` 的地址并运行。`dyld` 在应用进程中运行的工作是加载应用依赖的所有动态链接库，准备好运行所需的一切，它拥有的权限跟应用一样。

下面的步骤构成了 `dyld` 的时间线：

Load dylibs -> Rebase -> Bind -> ObjC -> Initializers

#### 加载 Dylib

从主执行文件的 header 获取到需要加载的所依赖动态库列表，而 header 早就被内核映射过。然后它需要找到每个 dylib，然后打开文件读取文件起始位置，确保它是 Mach-O 文件。接着会找到代码签名并将其注册到内核。然后在 dylib 文件的每个 segment 上调用 `mmap()`。应用所依赖的 dylib 文件可能会再依赖其他 dylib，所以 `dyld` 所需要加载的是动态库列表一个递归依赖的集合。一般应用会加载 100 到 400 个 dylib 文件，但大部分都是系统 dylib，它们会被预先计算和缓存起来，加载速度很快。

#### Fix-ups

在加载所有的动态链接库之后，它们只是处在相互独立的状态，需要将它们绑定起来，这就是 Fix-ups。代码签名使得我们不能修改指令，那样就不能让一个 dylib 的调用另一个 dylib。这时需要加很多间接层。

现代 code-gen 被叫做动态 PIC（Position Independent Code），意味着代码可以被加载到间接的地址上。当调用发生时，code-gen 实际上会在 `__DATA` 段中创建一个指向被调用者的指针，然后加载指针并跳转过去。

所以 `dyld` 做的事情就是修正（fix-up）指针和数据。Fix-up 有两种类型，rebasing 和 binding。

#### Rebasing 和 Binding

Rebasing：在镜像内部调整指针的指向
Binding：将指针指向镜像外部的内容

可以通过命令行查看 rebase 和 bind 等信息：

```
xcrun dyldinfo -rebase -bind -lazy_bind myapp.app/myapp
```

通过这个命令可以查看所有的 Fix-up。rebase，bind，weak_bind，lazy_bind 都存储在 `__LINKEDIT` 段中，并可通过 `LC_DYLD_INFO_ONLY` 查看各种信息的偏移量和大小。

建议用 MachOView 查看更加方便直观。

从 `dyld` 源码层面简要介绍下 Rebasing 和 Binding 的流程。

`ImageLoader` 是一个用于加载可执行文件的基类，它负责链接镜像，但不关心具体文件格式，因为这些都交给子类去实现。每个可执行文件都会对应一个 `ImageLoader` 实例。`ImageLoaderMachO` 是用于加载 Mach-O 格式文件的 `ImageLoader` 子类，而 `ImageLoaderMachOClassic` 和 `ImageLoaderMachOCompressed` 都继承于 `ImageLoaderMachO`，分别用于加载那些 `__LINKEDIT` 段为传统格式和压缩格式的 Mach-O 文件。

因为 dylib 之间有依赖关系，所以 `ImageLoader` 中的好多操作都是沿着依赖链递归操作的，Rebasing 和 Binding 也不例外，分别对应着 `recursiveBind()` 和 `recursiveBind()` 这两个方法。因为是递归，所以会自底向上地分别调用 `doRebase()` 和 `doBind()` 方法，这样被依赖的 dylib 总是先于依赖它的 dylib 执行 Rebasing 和 Binding。传入 `doRebase()` 和 `doBind()` 的参数包含一个 `LinkContext` 上下文，存储了可执行文件的一堆状态和相关的函数。

在 Rebasing 和 Binding 前会判断是否已经 Prebinding。如果已经进行过预绑定（Prebinding），那就不需要 Rebasing 和 Binding 这些 Fix-up 流程了，因为已经在预先绑定的地址加载好了。

`ImageLoaderMachO` 实例**不使用预绑**定会有四个原因：

1. Mach-O Header 中 `MH_PREBOUND` 标志位为 `0`
2. 镜像加载地址有偏移（这个后面会讲到）
3. 依赖的库有变化
4. 镜像使用 flat-namespace，预绑定的一部分会被忽略
5. `LinkContext` 的环境变量禁止了预绑定


`ImageLoaderMachO` 中 `doRebase()` 做的事情大致如下：

1. 如果使用预绑定，`fgImagesWithUsedPrebinding` 计数加一，并 `return`;否则进入第二步
2. 如果 `MH_PREBOUND` 标志位为 `1`（也就是可以预绑定但没使用），且镜像在共享内存中，重置上下文中所有的 lazy pointer。（如果镜像在共享内存中，稍后会在 Binding 过程中绑定，所以无需重置）
3. 如果镜像加载地址偏移量为0，则无需 Rebasing，直接 `return`；否则进入第四步
4. 调用 `rebase()` 方法，这才是真正做 Rebasing 工作的方法。如果开启 `TEXT_RELOC_SUPPORT` 宏，会允许 `rebase()` 方法对 `__TEXT` 段做写操作来对其进行 Fix-up。所以其实 `__TEXT` 只读属性并不是绝对的。

`ImageLoaderMachOClassic` 和 `ImageLoaderMachOCompressed` 分别实现了自己的 `doRebase()` 方法。实现逻辑大同小异，同样会判断是否使用预绑定，并在真正的 Binding 工作时判断 `TEXT_RELOC_SUPPORT` 宏来决定是否对 `__TEXT` 段做写操作。最后都会调用 `setupLazyPointerHandler` 在镜像中设置 `dyld` 的 entry point，放在最后调用是为了让主可执行文件设置好 `__dyld` 或 `__program_vars`。

#### Rebasing

在过去，会把 dylib 加载到指定地址，所有指针和数据对于代码来说都是对的，`dyld` 就无需做任何 fix-up 了。如今用了 ASLR 后悔将 dylib 加载到新的随机地址(actual_address)，这个随机的地址跟代码和数据指向的旧地址(preferred_address)会有偏差，`dyld` 需要修正这个偏差(slide)，做法就是将 dylib 内部的指针地址都加上这个偏移量，偏移量的计算方法如下：

Slide = actual_address - preferred_address

然后就是重复不断地对 `__DATA` 段中需要 rebase 的指针加上这个偏移量。这就又涉及到 page fault 和 COW。这可能会产生 I/O 瓶颈，但因为 rebase 的顺序是按地址排列的，所以从内核的角度来看这是个有次序的任务，它会预先读入数据，减少 I/O 消耗。

#### Binding

Binding 是处理那些指向 dylib 外部的指针，它们实际上被符号（symbol）名称绑定，也就是个字符串。之前提到 `__LINKEDIT` 段中也存储了需要 bind 的指针，以及指针需要指向的符号。`dyld` 需要找到 symbol 对应的实现，这需要很多计算，去符号表里查找。找到后会将内容存储到 `__DATA` 段中的那个指针中。Binding 看起来计算量比 Rebasing 更大，但其实需要的 I/O 操作很少，因为之前 Rebasing 已经替 Binding 做过了。

#### ObjC Runtime

Objective-C 中有很多数据结构都是靠 Rebasing 和 Binding 来修正（fix-up）的，比如 `Class` 中指向超类的指针和指向方法的指针。

ObjC 是个动态语言，可以用类的名字来实例化一个类的对象。这意味着 ObjC Runtime 需要维护一张映射类名与类的全局表。当加载一个 dylib 时，其定义的所有的类都需要被注册到这个全局表中。

C++ 中有个问题叫做易碎的基类（fragile base class）。ObjC 就没有这个问题，因为会在加载时通过 fix-up 动态类中改变实例变量的偏移量。

在 ObjC 中可以通过定义类别（Category）的方式改变一个类的方法。有时你想要添加方法的类在另一个 dylib 中，而不在你的镜像中（也就是对系统或别人的类动刀），这时也需要做些 fix-up。

ObjC 中的 selector 必须是唯一的。

#### Initializers

C++ 会为静态创建的对象生成初始化器。而在 ObjC 中有个叫 `+load` 的方法，然而它被废弃了，现在建议使用 `+initialize`。对比详见：http://stackoverflow.com/questions/13326435/nsobject-load-and-initialize-what-do-they-do

现在有了主执行文件，一堆 dylib，其依赖关系构成了一张巨大的有向图，那么执行初始化器的顺序是什么？自顶向上！按照依赖关系，先加载叶子节点，然后逐步向上加载中间节点，直至最后加载根节点。这种加载顺序确保了安全性，加载某个 dylib 前，其所依赖的其余 dylib 文件肯定已经被预先加载。

最后 `dyld` 会调用 `main()` 函数。`main()` 会调用 `UIApplicationMain()`。

## 改善启动时间

从点击 App 图标到加载 App 闪屏之间会有个动画，我们希望 App 启动速度比这个动画更快。虽然不同设备上 App 启动速度不一样，但启动时间最好控制在 400ms。需要注意的是启动时间一旦超过 20s，系统会认为发生了死循环并杀掉 App 进程。当然启动时间最好以 App 所支持的最低配置设备为准。直到 `applicationWillFinishLaunching` 被调动，App 才启动结束。

### 测量启动时间

Warm launch: App 和数据已经在内存中
Cold launch: App 不在内核缓冲存储器中

冷启动（Cold launch）耗时才是我们需要测量的重要数据，为了准确测量冷启动耗时，测量前需要重启设备。在 `main()` 方法执行前测量是很难的，好在 `dyld` 提供了内建的测量方法：在 Xcode 中 Edit scheme -> Run -> Auguments 将环境变量 `DYLD_PRINT_STATISTICS` 设为 `1`。控制台输出的内容如下：

```
Total pre-main time: 228.41 milliseconds (100.0%)
         dylib loading time:  82.35 milliseconds (36.0%)
        rebase/binding time:   6.12 milliseconds (2.6%)
            ObjC setup time:   7.82 milliseconds (3.4%)
           initializer time: 132.02 milliseconds (57.8%)
           slowest intializers :
             libSystem.B.dylib : 122.07 milliseconds (53.4%)
                CoreFoundation :   5.59 milliseconds (2.4%)
```

### 优化启动时间

可以针对 App 启动前的每个步骤进行相应的优化工作。

#### 加载 Dylib

之前提到过加载系统的 dylib 很快，因为有优化。但加载内嵌（embedded）的 dylib 文件很占时间，所以尽可能把多个内嵌 dylib 合并成一个来加载，或者使用 static archive。使用 `dlopen()` 来在运行时懒加载是不建议的，这么做可能会带来一些问题，并且总的开销更大。

#### Rebase/Binding

之前提过 Rebaing 消耗了大量时间在 I/O 上，而在之后的 Binding 就不怎么需要 I/O 了，而是将时间耗费在计算上。所以这两个步骤的耗时是混在一起的。

之前说过可以从查看 `__DATA` 段中需要修正（fix-up）的指针，所以减少指针数量才会减少这部分工作的耗时。对于 ObjC 来说就是减少 `Class`,`selector` 和 `category` 这些元数据的数量。从编码原则和设计模式之类的理论都会鼓励大家多写精致短小的类和方法，并将每部分方法独立出一个类别，其实这会增加启动时间。对于 C++ 来说需要减少虚方法，因为虚方法会创建 vtable，这也会在 `__DATA` 段中创建结构。虽然 C++ 虚方法对启动耗时的增加要比 ObjC 元数据要少，但依然不可忽视。最后推荐使用 Swift 结构体，它需要 fix-up 的内容较少。

#### ObjC Setup

针对这步所能事情很少，几乎都靠 Rebasing 和 Binding 步骤中减少所需 fix-up 内容。因为前面的工作也会使得这步耗时减少。

#### Initializer

**显式初始化**

- 使用 `+initialize` 来替代 `+load`
- 不要使用 `__atribute__((constructor))` 将方法显式标记为初始化器，而是让初始化方法调用时才执行。比如使用 `dispatch_once()`,`pthread_once()` 或 `std::once()`。也就是在第一次使用时才初始化，推迟了一部分工作耗时。

**隐式初始化**

对于带有[复杂（non-trivial）构造器](http://stackoverflow.com/questions/3899223/what-is-a-non-trivial-constructor-in-c)的 C++ 静态变量：

1. 在调用的地方使用初始化器。
2. 只用简单值类型赋值（POD:Plain Old Data），这样静态链接器会预先计算 `__DATA` 中的数据，无需再进行 fix-up 工作。
3. 使用编译器 warning 标志 `-Wglobal-constructors` 来发现隐式初始化代码。
4. 使用 Swift 重写代码，因为 Swift 已经预先处理好了，强力推荐。

不要在初始化方法中调用 `dlopen()`，对性能有影响。因为 `dyld` 在 App 开始前运行，由于此时是单线程运行所以系统会取消加锁，但 `dlopen()` 开启了多线程，系统不得不加锁，这就严重影响了性能，还可能会造成死锁以及产生未知的后果。所以也不要在初始化器中创建线程。

## Reference

https://developer.apple.com/videos/play/wwdc2016/406/
