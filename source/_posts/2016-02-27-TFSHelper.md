title: 自制一款 Mac 平台 URL 辅助工具
date: 2016-02-27 00:35:53
tags:

- Algorithm
- Mac OS X
---

工作时经常会收到同事发来的一些链接，有的带空格的链接会断开，不能直接点击查看，需要手动复制完整链接并粘贴查看。所以我做了个 Mac 系统上的 URL 辅助工具，在复制 URL 时自动将其打开。还实现缓存常用链接、自动/手动连接切换、登录时启动等功能。开发语言为 Swift 和 AppleScript。

<!--more-->

因为在腾讯大部分资源都在 TFS（Tencent File System）上，所以我针对 TFS 格式的链接做了些特殊处理。因为 TFS 本质是基于 Windows 上的分布式文件存储系统，从 Mac 上访问其共享的文件需要将 URL 处理成 SMB （服务信息块）协议，然后才能打开。因为是针对 TFS 而做了特殊逻辑处理，我将其命名为 [TFSHelper](https://github.com/yulingtianxia/TFSHelper)。

#实现原理

我的思路是先将剪贴板中的 URL 处理后再写入剪贴板，然后用 AppleScript 模拟键盘事件，利用快捷键将剪贴板内容粘贴到 Finder 的连接服务器地址栏，然后模拟按下回车，实现自动连接。其实理论上也可以使用 AppleScript 直接通过 URL 连接到服务器，但是一直都出现 error，只好用这个歪招曲线救国。缓存常用链接使用 LRU 策略，登录时启动其实玩的依旧是套路，这个后面再讲。

##替换剪贴板内容

如果剪贴板中的文字内容含有符合 TFS 规则的 URL，那就将其提取并使用 `convert:` 函数将其处理成 SMB 协议格式；如果已经含有 SMB 协议的 URL，那就提取出来：

```
func catchTFSLocation() -> String? {
    if let texts = NSPasteboard.generalPasteboard().readObjectsForClasses([NSString.self as AnyClass], options: nil) as? [String] {
        for var text in texts {
            if let range = text.rangeOfString("\\\\tencent") {
                text = convert(text.substringFromIndex(range.startIndex))
            }
            if let range = text.rangeOfString("smb://") {
                text = text.substringFromIndex(range.startIndex)
                return text
            }
        }
    }
    return nil
}
```
然后将处理后的 URL 写入剪贴板，注意这里写入剪贴板的类型为 `NSStringPboardType`：

```
func writePasteboard(location: String) {
    NSPasteboard.generalPasteboard().declareTypes([NSStringPboardType], owner: nil)
    NSPasteboard.generalPasteboard().setString(location, forType: NSStringPboardType)
}
```

##模拟键盘事件

用 Cocoa 执行脚本最常用的方法就是通过 `NSTask` 类，屡试不爽：

```
func simulateKeys() {
    let task = NSTask()
    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["\(NSBundle.mainBundle().resourcePath!)/simulateKeys.scpt"]
    task.launch()
}
```

其中 `launchPath` 是能够执行脚本文件的程序路径，也就是解释器咯。参数数组的第 0 个是脚本文件的路径，也可以是脚本内容字符串。这与正常在 terminal 中敲命令是一样的。因为我们的脚本不涉及到数据的输入输出，所以代码比较简单。 这里使用 AppleScript 的好处是方便快捷通俗易懂，其拟人化的语法很是生动：

```
tell application "Finder"	activateend telltell application "System Events"	tell process "Finder"		set frontmost to true	end tell		key down command	keystroke "k"	keystroke "v"	key up command	keystroke return	delay 0.5	set the clipboard to nullend tell
```

我来翻译下哈：告诉 Finder 起来嗨，站到最前面！按住 command 别撒手，敲个 k 再敲个 v，动次大次！撒手回车等半秒，最后清空剪贴板。

在写这段脚本前我的确就是照着这个节拍一次次打开设计妹子和产品妹子发来的 TFS 链接的！（当然汉子发的我也得打开，就是节拍慢了许多）关键是得先手动把 URL 格式改了然后再动次大次，别提有多痛苦了~

## 缓存常用链接

唉卧槽这么简单的事儿一个 `NSCache` 不就搞定了么？

。。。

本节完。。。

。。。

那我还写它干嘛？！

常用链接会记录最近打开的 5 个 TFS 链接，因为 `NSCache` 不是很符合我的要求，所以我自己手动写了个 LRU Cache。相比于 Cocoa 提供的 `NSCache`，我写的这个 LRU Cache 支持遍历 key 值，并根据场景需求做了一些定制，比如 get 操作并不会算作使用频次。用法很简单，可以将其当为数组来获取 key，也能当成字典使用，通过 key 获取 value。因为我让它兼容了两套协议，并实现 `SequenceType` 协议能够使用 `for...in` 遍历，这些特性都是 `NSCache` 所没有的。



