---
title: Let's Talk About project.pbxproj
date: 2016-09-28 22:58:19
tags:
- Xcode
- macOS

---

project.pbxproj 文件被包含于 Xcode 工程文件 *.xcodeproj 之中，存储着 Xcode 工程的各项配置参数。它本质上是一种旧风格的 Property List 文件，历史可追溯到 NeXT 的 OpenStep。其可读性不如 xml 和 json，苹果却一直沿用至今，作为一家以创新闻名的公司可能这里剩下的就是情怀吧。

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

project.pbxproj 使用 UUID 作为索引，保证每个配置信息对象的唯一性。因为 UUID 根据机器硬件和时间戳生成，避免了多人在同一时间段操作修改工程文件带来的问题。也就是说工程中每项配置对象都有个唯一的 UUID，然后其他配置对象想引用某个配置对象直接使用它的 UUID 即可。这就跟我们编程时使用指针指向某个对象的地址一样，其他对象的属性想引用它，只需要给属性传个指针地址就行了。



## Reference

https://en.wikipedia.org/wiki/Property_list
http://www.monobjc.net/xcode-project-file-format.html
http://stackoverflow.com/questions/1452707/library-to-read-write-pbxproj-xcodeproj-files
