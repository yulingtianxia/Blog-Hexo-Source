title: 让你的微信不再被人撤回消息
date: 2016-05-06 18:24:04
tags:

- Reverse Engineering
- iOS
- macOS

---
处女座强迫症最讨厌别人发消息后撤回了，尤其是发的图片还没看清就被撤了，或者还没来得及看的消息就已经被撤回了。最近逆向工程很火，所以我也简单的逆向了一把微信 for Mac & iOS。

<!--more-->

# ~~为什么不对 iOS 动刀~~ Mac 和 iOS 双管齐下
~~iOS 上的微信 APP 不一定始终在前台运行着，如果别人在撤回消息时微信在后台甚至手机锁屏、断网，这时很可能没有调用撤回消息的方法，甚至当微信重新返回到前台时，从服务器根本不会接到原来消息的数据，而是只收到了一条『撤回』指令。基于以上猜测，我决定对微信 for Mac 下手，毕竟电脑上的微信只要开着就一直接收消息，Mac 版微信不会跑到后台。~~

PS：后来有人说 Web 版微信本来就不会撤回消息。。。可惜我从没用过；发送和撤回消息时 iOS 微信即使没运行，在之后接收服务器消息时依然会接到原消息内容。。。好吧是我高估了微信。。。

20160701 Update：

今天在家无聊顺手也吧 iOS 的微信搞定了，只是比 Mac 的稍微麻烦一点罢了。

# 脑洞和胆子都要大

之前看的一些逆向的教程里，感觉前期工作都是装软件配环境，噼里啪啦命令一顿敲，整的挺玄乎，其实都是用人家现成儿的工具做些事情，美其名曰『站在巨人的肩膀上』，这里不再赘述。在我看来第一个真正意义上有难度的事情就是一个字儿：『猜』！

想要凭 dump 出的头文件里面的一堆函数名类名来猜出想要动手脚的地方，的确是个技术活儿。不仅考验脑洞，有时候还得运气好。把应用程序中的微信拖到 Hopper 中，搜下 "revoke"。这不，我一下子就猜出在哪个方法里面处理撤回消息逻辑的了：

![](http://yulingtianxia.com/resources/WeChatReverseEngineeringwechat-findfuntion@2x.png)

我凭借直觉，认为 `-[MessageService onRevokeMsg:]` 就是我们要找的方法。事实也证明我是对的，一次成功！先看看这个方法的伪代码：

![](http://yulingtianxia.com/resources/WeChatReverseEngineeringwechat-pseudocode@2x.png)

伪代码里面包含着好多层复杂的 `if` 判断逻辑，想必是这里复杂的业务逻辑让微信的同事无比抓狂，不要怕，我们不想让后面的事情发生，直接来个 `return` 就万事大吉！按快捷键 『option+A』 或者选择 Hopper 菜单栏的 『Modify -> Assemble Instruction...』来修改第一行汇编语句：

![](http://yulingtianxia.com/resources/WeChatReverseEngineeringwechat-revokemsg@2x.png)

可能觉得这里直接 `return` 掉是不是胆子也太大了，其实我还是看了函数里这坨代码的。那么多的 `if` 判断伴随着的是各种出错场景下的数据上报，真正核心业务逻辑也就是下面这坨：

```
r12 = [[MessageData alloc] initWithMsgType:0x2710];
rax = [r12 isSendFromSelf];
rsi = @selector(toUsrName);
if (LOBYTE(rax) != 0x0) {
      rbx = [[r13 toUsrName] retain];
      [r12 setFromUsrName:rbx];
      [rbx release];
      rbx = [[r13 fromUsrName] retain];
      [r12 setToUsrName:rbx];
}
else {
      rbx = [[r13 toUsrName] retain];
      [r12 setFromUsrName:rbx];
      [rbx release];
      rbx = [[r13 fromUsrName] retain];
      [r12 setToUsrName:rbx];
}
[rbx release];
[r12 setMsgStatus:0x4];
[r12 setMsgContent:var_58];
[r12 setMsgCreateTime:LODWORD([r13 msgCreateTime])];
[r15 AddLocalMsg:var_50 msgData:r12];
rbx = [[NSArray arrayWithObject:r13] retain];
[r15 DelMsg:var_50 msgList:rbx isDelAll:0x0];
r15 = *objc_release;
[rbx release];
[r12 release];
```

这段代码先是判断下撤回消息的人是不是自己，然后分情况更新 UI，最后生成并更新数据。既然没有啥重要操作，那就放心地忽略吧哈哈。

现在需要将修改后的汇编重新生成新的可执行文件。选择 Hopper 菜单里的 『File -> Produce New Executable...』 后点 Yes：

![](http://yulingtianxia.com/resources/WeChatReverseEngineeringwechat-NewExecutable@2x.png)

最后将生成的可执行文件替换到 `/Applications/WeChat.app/Contents/MacOS/WeChat`

唯一让我不解的是无需对新的 `WeChat` 可执行文件进行代码签名微信依然可以正常运行。我是第一次玩逆向，还请前辈大神们指教。做了一系列撤回消息的尝试后，手机上面显示撤回，但 Mac 版微信的消息依然还在。一次猜中，成功！

# iOS 要稍微折腾一些

前提是有一个已经砸壳的 ipa，要么自己在越狱机中用 dumpdecrypted 砸壳，或者干脆从第三方工具下一个已经砸壳的（也就是给越狱机安装的）。我一开始从同步助手下的有点问题，后来从PP助手下的。

有了被砸壳的 ipa 就可以继续了，解压后找到里面的 WeChat.app ，注意用 `codesign -dvvv WeChat.app` 验证下签名。正版的 app 签名是腾讯的。。。

**第一步**，猜，嗯，是 ` -[CMessageMgr onRevokeMsg:]` 这个方法。类名换了而已。

**第二步**，改汇编代码。这里需要改的是 Thumb 指令集。其实它是较新的 ARM 处理器的一种模式。我们比较关心的是各种指令的含义，尤其是如何从 Thumb 切换回 ARM，没错，就是用 `bx`：

![](http://yulingtianxia.com/resources/WeChatReverseEngineering/wechat-ios.png)

这有一个[Thumb® 16 位指令集快速参考卡](http://infocenter.arm.com/help/topic/com.arm.doc.qrc0006ec/QRC0006_UAL16.pdf)

最后还是跟之前一样替换生成的可执行文件。

**第三步**，签名！建议先阅读 [代码签名探析](http://objccn.io/issue-17-2/)，了解下授权机制 (Entitlements) 和配置文件 (Provisioning)。这一步的前提是拥有一个合法证书，个人或企业都可以！

先随便新建个工程(我的叫 testUIImage，昨晚研究 UIImage 时建的)，一定要用证书签名，别选 None。。。target 架构选对（自己手机），编译后生成了个 ipa 文件。我们要的就是它里面的签名信息。

先用 `ldid` 工具在桌面上生成个授权文件（Entitlements.plist）：

```
ldid -e /Users/yangxiaoyu/Library/Developer/Xcode/DerivedData/testUIImage-aoqcifvynorulecqtwqqugleuktf/Build/Products/Debug-iphoneos/testUIImage.app/testUIImage > ~/Desktop/Entitlements.plist
```

PS：我是用 `homebrew` 安装的 `ldid`

然后把 testUIImage.app 中的配置文件 (Provisioning) **embedded.mobileprovision** 复制粘贴到我们的 WeChat.app 中。（右键显示包内容都会吧）

最后用 `codesign` 命令对 WeChat.app 签名，注意替换为你自己的证书『常用名称』：

```
codesign -f -s "iPhone Developer: xiaoyu yang (XXXXXXXXX)" --entitlements /Users/yangxiaoyu/Desktop/Entitlements.plist /Users/yangxiaoyu/Desktop/微信_v6.3.22/Payload/WeChat.app
```

**第四步**，也是最后一步，打包新的 WeChat.ipa：

```
xcrun -sdk iphoneos PackageApplication -v /Users/yangxiaoyu/Desktop/微信_v6.3.22/Payload/WeChat.app  -o ~/Desktop/WeChat.ipa
```

现在可以把新的 WeChat.ipa 安装到自己的手机上啦！

验证了下退出微信杀掉进程后，对方发消息并撤回，进入微信后依然可以收到撤回的消息。excited！

# 后记

其实逆向工程是门很有趣的学问，而任何学问都是入门简单深入难。本例看似容易，其实如果面对更加复杂的环境下，光靠我那点儿可怜的汇编知识肯定是不够的。如果是对 iOS 上的 APP 进行逆向，实则准备工作要麻烦得多。真正掌握了底层的原理和基础知识才是硬道理！

其实是利用 Security 框架在 app 内部验证签名防止被人修改的，当然在 Mac 上我们最方便的还是用 `codesign` 命令啦。苹果提供了[代码签名服务的文档](https://developer.apple.com/library/mac/documentation/Security/Reference/CodeSigningRef/index.html#//apple_ref/doc/uid/TP40008151-CH2-SW27)

老子终于也当了回标题党！啊哈！
