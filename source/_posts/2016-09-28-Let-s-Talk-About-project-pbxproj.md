---
title: Let's Talk About project.pbxproj
date: 2016-09-28 22:58:19
tags:
- Xcode
- macOS

---

project.pbxproj 文件被包含于 Xcode 工程文件 *.xcodeproj 之中，存储着 Xcode 工程的各项配置参数。它本质上是一种旧风格的 Property List 文件，历史可追溯到 NeXT 的 OpenStep。其可读性不如 xml 和 json，苹果却一直沿用至今，作为一家以创新闻名的公司可能这里剩下的就是情怀吧。

本文谈了下 project.pbxproj 的知识，并总结了一些操作工程文件的优秀轮子，并在最后给出了自己的解决方案 [pbxprojHelper](https://github.com/yulingtianxia/pbxprojHelper)。

<!--more-->

## Property List 的历史

想了解 project.pbxproj 文件格式，就需要先了解 Property List。

Property List 有很多种表现方式，最古老的格式就是之前提到的 NeXTSTEP 所使用的格式。那时还算是可读性很强的，仍需要手动编辑。与 json 最明显的差别是：数组用小括号括起来并用逗号隔开元素；字典用大括号括起来并用分号隔开键值对，键值之间用等号连接；二进制数据用尖括号 `<>` 括起来：

数组：

```
( "1", "2", "3" )
```
字典：

```
{
    "key" = "value";
    ...
}
```

这也是 project.pbxproj 文件中所使用的格式。

后来出现的 GNUstep 沿用了 NeXTSTEP 格式，并添加了对 `NSValue` 和 `NSDate` 对象的支持。到了苹果的 Mac OS X 10.0 推出了新的 XML 格式，旧的 NeXTSTEP 被废弃，只支持读不支持写。这也是为什么使用 `plutil` 命令或者 Cocoa 的 `NSPropertyListSerialization` 写入 OpenStep 格式时会报错：*Property list format kCFProperty ListOpenStepFormat not supported for writing*

因为 XML 语法啰嗦很占空间，苹果在 Mac OS X 10.2 又推出了一种新格式，将 Property List 存储于二进制文件中。虽然在 Mac OS X 10.7 JSON 格式出现了，但是跟 Property List 不兼容。

于是乎 Property List 在苹果家族的历史上存在三种格式：OpenStep，XML 和 Binary。**除了 OpenStep 被废弃不支持写入以外，其余格式都提供 API 支持读写。**

## 操作 Property List 的途径

Unix 的 `plutil` 工具提供了处理 Property list 文件的能力。 比如将 Property list 文件转成 XML 格式: 

```
plutil -convert xml1 -s -r -o project.pbxproj.xml project.pbxproj
```

`-convert` 选项可以传入的参数有： xml1, binary1 和 json。

当然 Cocoa 的 `NSPropertyListSerialization` 也提供了类似的功能，更面向对象。其实 `plutil` 和 `NSPropertyListSerialization` 底层都是调用 `CoreFoundation` 的`CFPropertyList` 相关的 API，所以功能类似。

使用 `NSPropertyListSerialization` 读入 project.pbxproj 文件时，字典中键值对的顺序会跟文件中原始的顺序不一致。这是因为字典为了实现快速查找会将 key 按序存储（比如字典序或用红黑树排序）。用 `plutil` 命令将 project.pbxproj 文件转成 xml 或 json 也会如此。

此外，`plutil` 命令也支持对某个 `keypath` 的增、删、改操作。`NSPropertyListSerialization` 就更不用说了，在程序中随意搞。

之前提到过不支持 OpenStep 写入的问题，所以即便我们能在内存中操作 project.pbxproj 文件，依然不能直接保存。**如果自己动手写一个 OpenStep 格式生成程序，依然无法准确还原字典中键值对的顺序。**更何况 project.pbxproj 文件中还插入了大量增强 human-readable 的注释，这些注释的生成是有特殊逻辑的，这个在后面会讲。

## 简要解析 project.pbxproj 文件

既然表面上无法将修改过的工程文件数据还原为 OpenStep 格式，Xcode 又是如何『开挂』做到的呢？这就得从 project.pbxproj 文件内容说起了。

### 内容规则

project.pbxproj 使用 UUID 作为交叉引用的索引，保证每个配置信息对象的唯一性。因为 UUID 根据机器硬件和时间戳生成，避免了多人在同一时间段操作修改工程文件带来的问题。也就是说工程中每项配置对象都有个唯一的 UUID，然后其他配置对象想引用某个配置对象直接使用它的 UUID 即可。这就跟我们编程时使用指针指向某个对象的地址一样，其他对象的属性想引用它，只需要给属性传个指针地址就行了。

可以把整个文件的内容想象成一个字典，字典中的 Key 按照字典序来排列。字典的第一层级总共有 5 个键值对，Key 分别为：`archiveVersion`，`classes`，`objectVersion`，`objects` 和 `rootObject`。其中重要的 Key 是 `objects` 和 `rootObject`。

所有的配置对象都放在 `objects` 对应的 Value 中，包括跟对象（`rootObject`）。 `objects` 对应的 Value 也是一个字典，Key 都为 UUID，Value 依然是个字典。可以将 `rootObject` 的值（是一个 UUID）作为 Key 在 `objects` 对应的字典中找到根对象。这个根对象的 `isa` 属性为 `PBXProject`（`isa = PBXProject`）。**读懂 project.pbxproj 的最好方式就是顺着 `rootObject` 的各个属性对应的 UUID 在 `objects` 中找到对应的对象，然后一层层看下去。**这样整个文件的配置信息存放方式就慢慢摸清了。

**`objects` 中的键值对被分成了若干个 section，虽然 section 的顺序是 Xcode 私有 API 钦定的，但每个 section 内部的键值对会根据 Key 的字典序排列。**

**每个对象内部的属性（也是键值对）会把 `isa` 排在最前面，其余的按照字典序排列。**

数组内部的顺序完全按照元素内容的字典序排列。

下面是 `objects` 中 `PBXNativeTarget` section 的一个对象，感受一下格式：

```
/* Begin PBXNativeTarget section */
		A450185D1D9D68D60002869D /* projectTest */ = {
			isa = PBXNativeTarget;
			buildConfigurationList = A45018751D9D68D60002869D /* Build configuration list for PBXNativeTarget "projectTest" */;
			buildPhases = (
				A450185A1D9D68D60002869D /* Sources */,
				A450185B1D9D68D60002869D /* Frameworks */,
				A450185C1D9D68D60002869D /* Resources */,
			);
			buildRules = (
			);
			dependencies = (
			);
			name = projectTest;
			productName = projectTest;
			productReference = A450185E1D9D68D60002869D /* projectTest.app */;
			productType = "com.apple.product-type.application";
		};
/* End PBXNativeTarget section */
```

可以根据 `A45018751D9D68D60002869D` 找到对应的 `buildConfigurationList` 对象的内容，所以说 project.pbxproj 使用 UUID 作为交叉引用的索引。通过这种关系，可以递归构建一张有向图，每个对象都是一个节点。

### 内容类型

在 Xcode 中能看见所有的公共配置信息都存在于 project.pbxproj 中。主要包含跟文件相关的 BuildFile，Group 和 FileReference；跟编译相关的 BuildPhase 和 Build Configuration（List）；以及一些列 Target 和 TargetDependency。

`objects` 的键值对根据内容类型被分成了若干个 section，采用注释的方式分节也使得可读性更强。section 的数量跟工程有关，尤其是每个工程的 BuildPhase 和 Target 差别都很大。下面列出了一个section 列表（非完整）：

```
PBXBuildFile
PBXBuildPhase
PBXAppleScriptBuildPhase
PBXCopyFilesBuildPhase
PBXFrameworksBuildPhase
PBXHeadersBuildPhase
PBXResourcesBuildPhase
PBXShellScriptBuildPhase
PBXSourcesBuildPhase
PBXContainerItemProxy
PBXFileElement
PBXFileReference
PBXGroup
PBXVariantGroup
PBXTarget
PBXAggregateTarget
PBXLegacyTarget
PBXNativeTarget
PBXProject
PBXTargetDependency
XCBuildConfiguration
XCConfigurationList
```

每个 section 中的对象类型都是相同的，对象的类型是靠 `isa` 的值区分的。对象内部的属性类型以及含义可以参照这篇文章提供的对照表：[Xcode Project File Format](http://www.monobjc.net/xcode-project-file-format.html)

## 操作 project.pbxproj 文件

我收集了一些可以操作 project.pbxproj 文件的优秀轮子，原理大都是用 `plutil` 转成 json 或 xml 后进行处理，不仅功能非常局限，且都无法完美还原为 OpenStep 格式的内容：

- [Xcodeproj](https://github.com/CocoaPods/Xcodeproj) CocoaPods 写的 Ruby 解析库，用于修改引入 CocoaPods 的工程文件并保存为 XML 格式。CocoaPods 本身是很强大的，还可以用来操作 Xcode workspaces (.xcworkspace), configuration files (.xcconfig) 和 Xcode Scheme files (.xcscheme).
- [mod-pbxproj](https://github.com/kronenthaler/mod-pbxproj) 强大的 Python 解析库，支持一定的修改操作，可输出 OpenStep 格式，但是顺序和注释内容无法完美还原，有些鸡肋。
- [xUnique](https://github.com/truebit/xUnique) 用 Python 写的统一多设备生成的 UUID 的工具，主要用途是统一工程在多设备上生成的 UUID，避免工程文件冲突。
- [pbxplorer](https://github.com/mjmsmith/pbxplorer)  Ruby 写的解析库。
- [node-xcode](https://github.com/alunny/node-xcode) Cordova 基于它管理 Xcode 工程

不过 **Xcode 可以打开 XML 格式的 project.pbxproj，一旦在 Xcode 界面上修改工程配置就会重新将 project.pbxproj 转成 OpenStep 风格。解铃还须系铃人，经过多番对比之后发现最终还是 Xcode 自己才能将 XML 完美还原成原来的 OpenStep 格式，且 `diff` 对比毫无差错。**原因很简单，Xcode 使用的私有 API 的导出结果是个黑盒，外界无论怎么猜都会有瑕疵。所以还是导出为 XML 后手动在 Xcode 界面中触发下吧。既然这样的话，如果能够简单高效地生成出 XML 文件作为工程文件就好了。基于此想法我开发了一款叫做 [pbxprojHelper](https://github.com/yulingtianxia/pbxprojHelper) 的 Mac App：

![Main Window](https://github.com/yulingtianxia/pbxprojHelper/blob/master/images/MainWindow@2x.png?raw=true)

操作简单粗暴：
1. 选择一个工程文件然后内容会自动解析在下面的 Outline 列表中，Filter 输入框便于过滤查看内容。
2. 单击 Outline 列表中的文字即可复制内容到剪贴板，双击复制整个keypath！ 
3. 对 project.pbxproj 文件的增删改操作都配置在 json 文件中，每次想对工程进行修改只需选择对应的 json 配置文件然后点击 "Apply" 即可完成写入替换哦！
4. 不小心误操作的话还可以点 "Revert" 回滚到上个版本哦！
5. 什么？懒得写 json 配置文件？下面这个附带的 json 配置生成器可以帮你直接生成一个哦！使用 ⇧⌘0 快捷键即可召唤此神器！选择两个工程文件和 json 保存路径后轻轻一点 "Generate" 就搞定咯：

![Generator Window](https://github.com/yulingtianxia/pbxprojHelper/blob/master/images/GeneratorWindow@2x.png?raw=true)

所以处理工程文件的正确姿势是：

1. 拷贝出一份原始的 project.pbxproj 文件
2. 在 Xcode 界面上修改工程配置，比如修改编译选项，使用自己的证书等
3. 使用 pbxprojHelper 的 JSON Configuration Generator 来对比修改后的工程文件和原始的工程文件，自动生成 JSON 配置文件
4. 以后想要在工程文件上施加自己的修改时，只需要应用之前生成好的 JSON 配置文件即可

pbxprojHelper 的**优势在于可以自由地增删改查任意属性，原生 UI 降低了使用门槛。功能强大的同时人性化的设计使得更快捷浏览工程文件中的内容。无需写任何代码即可一键配置自己想要的工程文件**

你可以在 GitHub 上下载最新的 [Release](https://github.com/yulingtianxia/pbxprojHelper/releases) 版。

**本项目完全手撸，没依赖上面提到的任何轮子😃**

想了解更多信息请查看 GitHub 主页：https://github.com/yulingtianxia/pbxprojHelper

## Reference

https://en.wikipedia.org/wiki/Property_list
http://www.monobjc.net/xcode-project-file-format.html
http://stackoverflow.com/questions/1452707/library-to-read-write-pbxproj-xcodeproj-files
https://github.com/CocoaPods/Xcodeproj/issues/52