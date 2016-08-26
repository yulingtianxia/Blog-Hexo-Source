title: 自制一款 Mac 平台 URL 辅助工具
date: 2016-02-27 00:35:53
tags:

- Algorithm
- macOS
- Swift
- AppleScript
---

工作时经常会收到同事发来的一些链接，有的带空格的链接会断开，不能直接点击查看，需要手动复制完整链接并粘贴查看。所以我做了个 Mac 系统上的 URL 辅助工具，在复制 URL 时自动将其打开。还实现缓存常用链接、自动/手动连接切换、登录时启动等功能。开发语言为 Swift 和 AppleScript。

<!--more-->

因为在腾讯大部分资源都在 TFS（Tencent File System）上，所以我针对 TFS 格式的链接做了些特殊处理。因为 TFS 本质是基于 Windows 上的分布式文件存储系统，从 Mac 上访问其共享的文件需要将 URL 处理成 SMB （服务信息块）协议，然后才能打开。因为是针对 TFS 而做了特殊逻辑处理，我将其命名为 [TFSHelper](https://github.com/yulingtianxia/TFSHelper)。可以在 https://github.com/yulingtianxia/TFSHelper/releases 下载 TFSHelper 最新的 Release 版本。

# 实现原理

我的思路是先将剪贴板中的 URL 处理后再写入剪贴板，然后用 AppleScript 模拟键盘事件，利用快捷键将剪贴板内容粘贴到 Finder 的连接服务器地址栏，然后模拟按下回车，实现自动连接。其实理论上也可以使用 AppleScript 直接通过 URL 连接到服务器，但是一直都出现 error，只好用这个歪招曲线救国。缓存常用链接使用 LRU 策略，登录时启动其实玩的依旧是套路，这个后面再讲。

## 替换剪贴板内容

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

## 模拟键盘事件

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

常用链接会记录最近打开的 5 个 TFS 链接，因为 `NSCache` 不是很符合我的要求，所以我自己手动写了个 LRU Cache。相比于 Cocoa 提供的 `NSCache`，我写的这个 LRU Cache 支持遍历 key 值，并根据场景需求做了一些定制，比如 get 操作并不会算作使用频次。用法很简单，既可以将其当为数组来获取 key，也能当成字典使用，通过 key 获取 value。因为我让它兼容了两套协议，并实现 `SequenceType` 协议能够使用 `for...in` 遍历，这些特性都是 `NSCache` 所没有的。

首先解决**既可以将其当为数组来获取 key，也能当成字典使用，通过 key 获取 value**这个问题。在 `LRUCache` 内部维护一个字典和一个数组，对外暴漏 `subscript` 接口即可：

```
class LRUCache <K:Hashable, V> : NSObject, NSCoding, SequenceType {
    
    private var _cache = [K:V]()
    private var _keys = [K]()
    
    var countLimit:Int = 0
    
    override init() {
        
    }
    
    subscript(index:Int) -> K {
        get {
            return _keys[index]
        }
    }
    
    subscript(key:K) -> V? {
        get {
            return _cache[key]
        }
        set(obj) {
            if obj == nil {
                _cache.removeValueForKey(key)
            }
            else {
                useKey(key)
                _cache[key] = obj
            }
        }
    }
    
    private func useKey(key: K) {
        if let index = _keys.indexOf(key) {// key 已存在数组中，只需要将其挪至 index 0
            _keys.insert(_keys.removeAtIndex(index), atIndex: 0)
        }
        else {// key 不存在数组中，需要将其插入 index 0，并在超出缓存大小阈值时移走最后面的元素
            if _keys.count >= countLimit {
                _cache.removeValueForKey(_keys.last!)
                _keys.removeLast()
            }
            _keys.insert(key, atIndex: 0)
        }
    }  
    
    func cleanCache() {
        _cache.removeAll()
        _keys.removeAll()
    }
}
```

LRU 策略主要体现在维护 `_keys` 数组的排序上。每当需要记录某个键被使用时，就调用 `useKey:` 方法对 `_keys` 和 `_cache` 更新。具体策略是：如果缓存中已经有这个 key 了，那就将其移到 `_keys` 数组最前面；如果这个 key 本不存在，那么需要查看当前缓存空间是否已经填满，如果没有剩余空间就需要删除 `_keys` 数组最后一个元素，并连带删除对应 `_cache` 中对应的键值对，最后将新的 key 插入到 `_keys` 数组最前面。

因为我只想在给 `LRUCache` 作为字典赋值的时候才算作一次“使用”，所以只在 `set` 方法中调用了 `useKey:`。如果给 `LRUCache` 赋空值并不算做一次“使用”。而对 `LRUCache` 所有的取值行为都不算做“使用”，因为为了更新界面等因素，经常会从缓存中取值，这些并不是用户自身的操作。只有当用户真正打开某个 URL 时才算做一次“使用”，而此时刚好是对 `LRUCache` 赋值。

为了能够使用 `for...in` 遍历 `LRUCache`，需要让其实现 `SequenceType` 协议：

```
typealias Generator = CacheGenerator<K>
    
func generate() -> Generator {
   return CacheGenerator(keys:_keys)
}
```

因为我们遍历的内容是“键”，所以初始化 `CacheGenerator` 时传入 `_keys`，并在 `CacheGenerator` 内部维护一个计数器 `counter`，在 `next` 方法中以正序返回数组中的键：

```
class CacheGenerator<T:Hashable> : GeneratorType {
    
    typealias Element = T
    
    var counter: Int
    let array:[T]
    
    init(keys:[T]) {
        counter = 0
        array = keys
    }
    
    func next() -> Element? {
        return counter < array.count ? array[counter++] : nil
    }
}
```

当然也可以通过改变 `counter` 的变化规则来实现逆序、乱序遍历。

最后，为了能让 `LRUCache` 通过 `NSUserDefaults` 持久化写入本地，还需要实现 `NSCoding` 协议：

```
// NSCoding
@objc required init?(coder aDecoder: NSCoder) {
   _keys = aDecoder.decodeObjectForKey("keys") as! [K]
   _cache = aDecoder.decodeObjectForKey("cache") as! [K:V]
}
    
@objc func encodeWithCoder(aCoder: NSCoder) {
   aCoder.encodeObject(_keys as! AnyObject as! NSArray, forKey: "keys")
   aCoder.encodeObject(_cache as! AnyObject as! NSDictionary, forKey: "cache")
}
```

由此看出 Swift 的蛋疼之处，还是逃不了 Cocoa 的黑历史，自带的库支持不到位啊！

## 登陆时启动

Mac 开发开机启动有好几种方式，可以参考[Mac OSX的开机启动配置](http://www.tanhao.me/talk/1287.html/)

不过对于 Swift 开发 Mac App，我更推荐[这篇文章](https://theswiftdev.com/2015/09/17/first-os-x-tutorial-how-to-launch-an-os-x-app-at-login/)，其策略是将 App 添加为启动项。原理是通过 `SMLoginItemSetEnabled` 方法在主应用的 `Contents/Library/LoginItems` 文件夹建立一个后台辅助应用来启动主应用，如果主应用已启动后就会终止后台应用。

## UI

为了让这个 App 皮实耐操，我决定还是不画主页面，让其附着在菜单栏吧：

![](https://raw.githubusercontent.com/yulingtianxia/TFSHelper/master/image/screenshot.png)

将 plist 文件中 `Application is background only` 设为 `YES` 就不会让应用出现在 Dock 上了。

这里添加菜单很容易没啥好说的，需要注意的逻辑是在菜单显示前先验证剪贴板链接是否符合要求，然后决定是否显示“打开链接”按钮。

所有开关设置都会通过 `NSUserDefaults` 持久化写入本地，第一次加载应用需要从本地读取，然后更新界面。

“常用链接”里面的“清空列表”按钮在没有链接缓存的时候需要设为不可用。

## 自动 VS 手动

在设计产品时曾经纠结是应该自动打开链接还是让用户每次手动打开。每种选择都有自己的理由，但如果用户仅是想复制某个 TFS 链接发给别人，自动打开链接体验会很糟糕；如果每次都需要手动点击“打开链接”按钮，又极为不便。为了折衷，便提供了个开关。

自动打开链接的原理很简单，就是用定时器循环处理剪贴板内容：

```
NSTimer.scheduledTimerWithTimeInterval(0.25, target: self, selector: "pollPasteboard:", userInfo: nil, repeats: true)

func pollPasteboard(timer: NSTimer) {
   if !autoCatch {
       return
   }
   let currentChangeCount = NSPasteboard.generalPasteboard().changeCount
   if currentChangeCount == previousChangeCount {
       return
   }
   handlePasteboard()
}
```

为了避免剪贴板内容不变时的重复处理，`handlePasteboard` 函数记录了上次的 `changeCount`，每次剪贴板被更新时它会递增，初始为 0。这样每次判断下 `changeCount` 是否跟上次有变化即可：

```
func handlePasteboard() {
    if let result = catchTFSLocation() {
        recentUseLinks[result] = NSURL(fileURLWithPath: result).pathComponents?.last
        writePasteboard(result)
        simulateKeys()
    }
    previousChangeCount = NSPasteboard.generalPasteboard().changeCount
}
```

手动打开链接更简单了，直接调用 `handlePasteboard` 即可。

# 总结

诸如 UI 上一些细节实现就不叙述了，比如在显示常用链接时我只显示了路径的最后一段文字，方便查看，否则链接过长影像体验。因为我是为 TFS 格式量身定制的，所以你也可以通过修改我源码中的匹配规则来为你自己所用。Github 链接：https://github.com/yulingtianxia/TFSHelper

