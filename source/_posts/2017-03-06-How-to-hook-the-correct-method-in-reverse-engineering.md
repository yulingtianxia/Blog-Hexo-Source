---
title: 如何在逆向工程中 Hook 得更准 - 微信屏蔽好友&群消息实战
date: 2017-03-06 00:06:51
tags:
---

在逆向工程中往往需要针对想要做的功能 Hook 到相应的方法和属性，小白面对 `class-dump` 后的大量头文件表示只能靠『猜』。这里我分享下逆向微信实现屏蔽群消息和好友消息的实战经验，适用于**非越狱机**，项目 GitHub 地址: [FishChat](https://github.com/yulingtianxia/FishChat)。

<!--more-->

## 从 UI 猜

先用 `Cycript` 或 Reveal 获取视图层级信息，然后从 `View` 和 `ViewController` 的头文件中寻找信息。然后就凭编程经验去猜了，比如一些方法属性的命名，一些常用的代码设计等等套路。

比如现在我想在群信息页面和个人聊天详情页面增加个屏蔽消息的开关，先找到对应的 `ViewController` 类，然后到头文件中去找信息。因为这都是两个列表 UI，这种信息页面的列表 Cell 一般不需要重用的，直接数据配置即可。然后很容易发现这两个 `ViewController` 都有 `m_tableViewInfo` 这个属性，类型为 `MMTableViewInfo`。接着顺藤摸瓜，发现其与 `MMTableViewSectionInfo` 和 `MMTableViewCellInfo` 这两个类构成了整个列表的数据。Table-Section-Cell 这三个层级的的数据对应着 UI，熟悉 iOS 的很容易看懂。进而使用这三个类的方法来修改 `m_tableViewInfo` 中的数据，实现修改 UI 的目的。因为是列表数据，凭经验应该是 reloadData 的时候去做修改。恰好这两个 `ViewController` 中都有 `reloadTableData` 方法，Hook 后果然生效，效果如图：

<img src="https://github.com/yulingtianxia/FishChat/blob/master/Images/weichat_ignore_chatroom.PNG?raw=true" width="50%" height="50%">

<img src="https://github.com/yulingtianxia/FishChat/blob/master/Images/wechat_ignore_somone.PNG?raw=true" width="50%" height="50%">

逆向的时候需要处处为对方着想，换位思考。如果仅想着 Hook 系统的 API 来修改 UI，在这个例子里显然要多走些弯路。

剩下的就是获取好友 ID 和群 ID，用一个字典或数组存储是否屏蔽的标记。

## 关联相关类一起猜

在我之前写的 [Make WeChat Great Again](http://yulingtianxia.com/blog/2017/02/28/Make-WeChat-Great-Again/) 里有提到 `CMessageMgr` 这个类，它是个管理消息的单例，而消息被包装成 `CMessageWrap` 对象来传递。在 `CMessageMgr` 中搜索 getmsg 会发现有好几个方法。因为 `CMessageWrap` 中包含 `m_uiMesLocalID` 和 `m_n64MesSvrID` 属性，所以锁定目标为 `- (id)GetMsg:n64SvrID:` 和 `- (id)GetMsg:LocalID:`，经过验证后发现获取消息时调用的是后者。PS：进入聊天窗口时其实还调用了 `- (id)GetMsgByCreateTime:FromID:FromCreateTime:Limit:LeftCount:FromSequence:` 方法。

不过，Hook `- (id)GetMsg:LocalID:` 之后发现即便不调用原始方法的实现，直接返回 `nil`，也依然不能屏蔽消息。这时需要找到调用它的上层方法，然后继续寻找真正处理消息的逻辑。

## 逆向工程绝不仅仅靠猜

初步思路是获取到方法的调用栈，然后查找上一层的方法，并将方法调用的地址换算成 Hopper 反汇编后的地址，这样就能获取到方法名了，然后进行 Hook。

### 获取方法的 IMP

如果是越狱手机，直接 ssh 到手机执行 `debugserver`，然后就可以像平时 debug 那样用 lldb 尽情调戏程序了。而我这里因为是非越狱机，只能打 Log 了。

WeChat 可执行文件和我注入的 FishChat.dylib 文件加载的地址是随机的，而且我打的 Log 都是在 FishChat.dylib 中已经 Hook 过的方法中。熟悉 image 加载过程和 Hook 概念很重要，后面会用到。可以参考这篇文章：[优化 App 的启动时间](http://yulingtianxia.com/blog/2016/10/30/Optimizing-App-Startup-Time/)。

如果是自己用 Method Swizzling 写的 Hook 逻辑，很容易拿到原始方法的 `IMP`。但这里是使用 `CaptainHook`，是对 Method Swizzling 的宏定义封装而已，创建了很多内联函数。所谓的 Method Swizzling 其实也就是 [Objective-C Runtime](http://yulingtianxia.com/blog/2014/11/05/objective-c-runtime/) 的一种应用而已。

那么该如何找到 `CaptainHook` 为我们保存的原始的方法 IMP 呢？

首先先新建一个 `hook.m` 文件，内容如下：

```
#import "CaptainHook.h"
CHDeclareMethod2(id, CMessageMgr, GetMsg, id, arg1, LocalID, unsigned int, arg2)
```

用 `clang -E hook.m -o hook.c` 命令将宏展开，因为文件内容很多，只截取其中比较有意义的部分：

```
static id (*$CMessageMgr_GetMsg$LocalID$_super)(CMessageMgr * self, SEL _cmd, id arg1, unsigned int arg2);
static id $CMessageMgr_GetMsg$LocalID$_closure(CMessageMgr * self, SEL _cmd, id arg1, unsigned int arg2) {
    typedef id (*supType)(CMessageMgr *, SEL, id arg1, unsigned int arg2);
    supType supFn = (supType)class_getMethodImplementation(CMessageMgr$.superClass_, _cmd);
    return supFn (self, _cmd, arg1, arg2);
}

static id $CMessageMgr_GetMsg$LocalID$_method(CMessageMgr * self, SEL _cmd, id arg1, unsigned int arg2);

__attribute__((always_inline)) static inline void $CMessageMgr_GetMsg$LocalID$_register() {
    Method method = class_getInstanceMethod(CMessageMgr$.class_, @selector(GetMsg:LocalID:));
    if (method) {
        $CMessageMgr_GetMsg$LocalID$_super = (__typeof__($CMessageMgr_GetMsg$LocalID$_super))method_getImplementation(method);
        if (class_addMethod(CMessageMgr$.class_, @selector(GetMsg:LocalID:), (IMP)&$CMessageMgr_GetMsg$LocalID$_method, method_getTypeEncoding(method))) {
            $CMessageMgr_GetMsg$LocalID$_super = &$CMessageMgr_GetMsg$LocalID$_closure;
        } else {
            method_setImplementation(method, (IMP)&$CMessageMgr_GetMsg$LocalID$_method);
        }
    }
    else {
        // 省略
    }
}
```
结合 `CaptainHook.h` 中的宏定义，不难找出 `$CMessageMgr_GetMsg$LocalID$_super` 就是原始方法对应实现的函数指针，也就是 `IMP`。`$CMessageMgr_GetMsg$LocalID$_method` 是 Hook 过后方法的函数指针。

这里真的不是靠猜，纯粹 [Objective-C Runtime](http://yulingtianxia.com/blog/2014/11/05/objective-c-runtime/) 玩的熟。理解 [Objective-C Runtime](http://yulingtianxia.com/blog/2014/11/05/objective-c-runtime/) 的一些概念和常用函数后很容易判断 Hook 的原始方法和新的方法。

所以最后的代码如下。这里打印了方法传入的参数、原始方法的 `IMP` 和方法调用栈。

```
CHDeclareMethod2(id, CMessageMgr, GetMsg, id, arg1, LocalID, unsigned int, arg2)
{
    NSLog(@"GetMsg:%@ LocalID:%d",arg1,arg2);
    NSLog(@"originalIMP:%p",$CMessageMgr_GetMsg$LocalID$_super);
    NSLog(@"%@",[NSThread callStackSymbols]);
    return CHSuper2(CMessageMgr, GetMsg, arg1, LocalID, arg2);
}
```

打印结果如下：

```
Mar  2 00:37:36 yangxiaoyude-iPhone WeChat(FishChat.dylib)[22880] <Notice>: GetMsg:weixin LocalID:2
Mar  2 00:37:36 yangxiaoyude-iPhone WeChat(FishChat.dylib)[22880] <Notice>: originalIMP:0x1028821d4
Mar  2 00:37:36 yangxiaoyude-iPhone WeChat(FishChat.dylib)[22880] <Notice>: (
	0   FishChat.dylib                      0x000000010437dd08 _ZL35$CMessageMgr_GetMsg$LocalID$_methodP11CMessageMgrP13objc_selectorP11objc_objectj + 224
	1   WeChat                              0x0000000102afb960 _ZN16ClearSessionItem7compareERKNSt3__110shared_ptrIS_EES4_ + 1218052
	2   WeChat                              0x0000000102afe4b8 _ZN16ClearSessionItem7compareERKNSt3__110shared_ptrIS_EES4_ + 1229148
	3   WeChat                              0x00000001029f1554 _ZN16ClearSessionItem7compareERKNSt3__110shared_ptrIS_EES4_ + 127480
	4   WeChat                              0x0000000102a47390 _ZN16ClearSessionItem7compareERKNSt3__110shared_ptrIS_EES4_ + 479284
	5   WeChat                              0x0000000102ad4d64 _ZN16ClearSessionItem7compareERKNSt3__110shared_ptrIS_EES4_ + 1059336
	6   WeChat                              0x0000000102a52050 _ZN16ClearSessionItem7compareERKNSt3__110shared_ptrIS_EES4_ + 523508
	7   Foundation                          0x0000000194125048 <redacted> + 340
	8   CoreFounda
```

### 将地址翻译成 Selector

这里分详细和快速两种方法来讲述如何通过内存地址找到对应的 `Selector`。分步骤计算适合对操作系统原理不太熟悉的新手，老司机可以直接进入『快速计算方法』。

#### 分步详细剖析计算方法

1. 反汇编得出方法相对地址

记得在选择 FAT 架构时选择跟手机 CPU 相匹配的架构，有 armv7 和 aarch64 两种可选。我这里以 aarch64 为例。

`-[CMessageMgr GetMsg:LocalID:]` 在 Hopper 中的地址 `0x000000010280e1d4`：

![](http://7ni3rk.com1.z0.glb.clouddn.com/reverse%20engineering/original_method_address@2x.png)

WeChat Mach-O 在 Hopper 中的基地址 `0x0000000100000000`：

![](http://7ni3rk.com1.z0.glb.clouddn.com/reverse%20engineering/wechat_base_address@2x.png)

得出 `-[CMessageMgr GetMsg:LocalID:]` 在 WeChat 中的相对地址为 `0x280E1D4`：

`0x000000010280e1d4 - 0x0000000100000000 = 0x280E1D4 `

2. 计算 Mach-O 文件加载的随机地址

之前打印 `-[CMessageMgr GetMsg:LocalID:]` 原始实现的 `IMP` 为 `0x1028821d4`

WeChat 文件在手机中加载的随机地址为 **『原始 IMP 的地址 - 方法相对地址』**，结果为 `0x100074000`：

`0x1028821d4 - 0x280E1D4 = 0x100074000`

3. 还原调用栈为相对地址

将之前打印出调用栈上的地址转换成相对地址，再加上 Hopper 上的基地址 `0x0000000100000000`，公式为 **『调用栈上的地址 - WeChat 随机地址 + `0x0000000100000000`』**，结果如下：

```
	1   WeChat                              0x102A87960 _ZN16ClearSessionItem7compareERKNSt3__110shared_ptrIS_EES4_ + 1218052
	2   WeChat                              0x102A8A4B8 _ZN16ClearSessionItem7compareERKNSt3__110shared_ptrIS_EES4_ + 1229148
	3   WeChat                              0x10297D554 _ZN16ClearSessionItem7compareERKNSt3__110shared_ptrIS_EES4_ + 127480
	4   WeChat                              0x1029D3390 _ZN16ClearSessionItem7compareERKNSt3__110shared_ptrIS_EES4_ + 479284
	5   WeChat                              0x102A60D64 _ZN16ClearSessionItem7compareERKNSt3__110shared_ptrIS_EES4_ + 1059336
	6   WeChat                              0x1029DE050 _ZN16ClearSessionItem7compareERKNSt3__110shared_ptrIS_EES4_ + 523508
```

#### 快速计算方法

已知条件：

1. `-[CMessageMgr GetMsg:LocalID:]` 在 Hopper 反汇编后的地址 `0x10280e1d4`
2. `-[CMessageMgr GetMsg:LocalID:]` 方法内存地址为 `0x1028821d4`
3. `-[CMessageMgr GetMsg:LocalID:]` 在内存中 `0x102afb960` 处被调用

求 `0x102afb960` 对应 Hopper 反汇编后的地址？

因为方法间的相对地址是不变的，所以：

A 方法反汇编地址 - B 方法反汇编地址 = A 方法真实地址 - B 方法真实地址

所以结果为 `0x102A87960`：

`0x102afb960 - 0x1028821d4 + 0x10280e1d4 = 0x102A87960`

跟之前的分步骤计算结果一样。

#### 还原 Selector

根据反汇编地址在 Hopper 中定位方法名，快捷键 `G`。

最终得到的方法调用栈如下：

```
-[CSyncBaseEvent BatchAddMsg:ShowPush:]
-[CSyncBaseEvent HandleBatch:ShowPush:]
-[NewSyncHandler HandleSyncResp:Push:ShowPush:ContinueFlag:Scene:syncKeyMd5:]
-[NewSyncService HandleSyncResp:Push:ShowPush:Scene:]
-[CNewSyncPrtl HandleResp:]
-[EventService HandleRespThread:]
```

## 从汇编代码继续猜

虽然可以锁定添加消息的实现逻辑在 `-[CSyncBaseEvent BatchAddMsg:ShowPush:]` 方法里，但是查找头文件发现它的两个参数和一个返回值竟然都是 `BOOL` 类型，可以肯定的是在其内部通过单例或者类方法获取和处理了消息对象，然后才调用的 `-[CMessageMgr GetMsg:LocalID:]` 方法。

在不能反编译的情况下，只能浏览下方法的汇编代码中调用到什么其他方法。消息被封装成 `CMessageWrap` 类，所以要格外注意这个类的一些属性名，或者 `MsgWrap` 这个词。进而找到 `BatchAddMsgInfo` 这个类有一些汇编中出现的消息处理的标志位（`isInsertNew`,`isNeedChangeDisplay`,`isNotify`,`isCanAddDB`） 和 `CMessageWrap`。又在汇编里找到 `MsgHelper` 的类，其类方法中带 `BatchAddMsgInfo` 中那些标志位的有两个，虽然按理说应该 Hook 参数更多的方法，但这里我为了偷懒，选的较短的 `+ AddMessageToDB:MsgWrap:Des:DB:Lock:GetChangeDisplay:InsertNew:`。PS：这也不短啊！

拿到 `CMessageWrap` 就很好判断是否需要屏蔽消息了：

```
CHDeclareClassMethod7(BOOL, MsgHelper, AddMessageToDB, id, arg1, MsgWrap, id, arg2, Des, unsigned int, arg3, DB, id, arg4, Lock, id, arg5, GetChangeDisplay, BOOL *, arg6, InsertNew, BOOL *, arg7)
{
    Ivar nsFromUsrIvar = class_getInstanceVariable(objc_getClass("CMessageWrap"), "m_nsFromUsr");
    NSString *m_nsFromUsr = object_getIvar(arg2, nsFromUsrIvar);
    BOOL result = !([FishConfigurationCenter sharedInstance].chatIgnoreInfo[m_nsFromUsr].boolValue);
    if (result) {
        CHSuper7(MsgHelper, AddMessageToDB, arg1, MsgWrap, arg2, Des, arg3, DB, arg4, Lock, arg5, GetChangeDisplay, arg6, InsertNew, arg7);
    }
    *arg6 = result;
    *arg7 = result;
    return result;
}
```
