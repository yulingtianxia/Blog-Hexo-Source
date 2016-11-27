---
title: pbxprojHelper--Xcode工程文件助手
date: 2016-11-23 00:03:08
tags:
- macOS
- Xcode
- Swift

---

[pbxprojHelper](https://github.com/yulingtianxia/pbxprojHelper) 可以帮你快速配置 Xcode 工程文件，省去麻烦的人工手动操作。项目开源，使用 Swift 开发，详细介绍请见[使用说明](https://github.com/yulingtianxia/pbxprojHelper/blob/master/Documentation/README_ZH.md)。除了 Mac App 外还提供了命令行工具 [`pbxproj`](https://github.com/yulingtianxia/pbxprojHelper/releases/download/1.1.3/pbxproj)，它集成了 [pbxprojHelper](https://github.com/yulingtianxia/pbxprojHelper) 的核心功能，同样简易实用。

<!--more-->

因为 [README_ZH](https://github.com/yulingtianxia/pbxprojHelper/blob/master/Documentation/README_ZH.md) 中对使用方法已经讲得很详细了，这里重点说的是产品方案和技术实现。

## 产品方案

### 为什么造这个工具？

在开发公司的项目时，check out 代码到本地后需要修改工程文件。比如更改证书和 Bundle Identifier、删除一些编译不过的 Target，修改 Build Settings 等配置。重复手动修改这些配置的场景很多：

1. 第一次 check out 新的分支，需要使用自己的配置。
2. 增删代码文件前会先 revert project.pbxproj 文件，修改完成后再 commit。此时本地工程文件需要重新配置。
3. 没有增删代码文件但 project.pbxproj 文件有冲突（conflict），需要先 revert 后重新配置工程文件。
4. 一些自动化流程（比如 CI）每次执行都需要特定的编译选项和证书来编包。

而我本人最常遇到的场景是 1 和 2，因为不能用公司的证书配置来编译，一些跟苹果开发者账号相关的功能导致一些 target 编译不过，还有些 debug 模式下需要设置的编译选项。所以每次都需要手动修改 Xcode 工程配置，很是麻烦。

### 需求！

可以说开发这个工具一开始完全就是为了解决我个人的痛点的，基本没考虑做成功能强大的通用工具。虽然做的事情比较小众，但也能满足一批苹果开发者的需求了。我把需求分为以下几点：

1. 将程序员对工程文件做出的配置修改记录下来，并保存成 JSON 文件
2. 下次使用时直接导入 JSON 文件，将配置修改应用到当前的工程文件上
3. 支持回滚操作
4. 支持工程文件内容的预览、过滤
5. 快速切换最近使用的工程
6. 提供命令行工具

可以说 1 和 2 是刚需，也是常用功能。3、4 和 5 是辅助功能，6 是附加需求。我平时最常碰到的需求点就是 2 和 5 了。

## 技术实现

关于 Xcode 工程文件的介绍，请参考我之前写的 [Let's Talk About project.pbxproj](http://yulingtianxia.com/blog/2016/09/28/Let-s-Talk-About-project-pbxproj/)。本篇文章可以算作是它的续集。

我把工程文件相关的底层方法都封装在 `PropertyListHandler` 类中，它们跟界面无关。还有一些工具类和方法写到 `Utils` 文件中。

### 对比工程文件

想要记录工程文件的修改是很难的，所以只能是比较下两个工程文件的差异。这里不是对比文件那种简单的 `diff` 操作，而是要记录具体针对哪个配置项做了『增删改』。

**工程文件的内容可以比作一颗多叉树，的根节点是字典，其余中间节点都是字典的键。数组的元素肯定是字符串（叶子节点），字典的键值对则可能继续拓展出子树，也可能是叶子节点。**在拿到两个工程文件的数据后，就需要对两棵树的每个层级进行对比。对比两颗树的差异算法不难实现，核心思想是：**在对比中间节点时，如果内容相同那就递归比较下一层，否则就记为『增』或『删』**。

而比较同一层级中间节点的差异，直接用 `Set` 是最方便的了。我将两棵树的差异保存在字典 `difference` 中，在内嵌方法中又实现了个尾递归。递归过程中需要记录中间节点作为路径，因为生成的路径需要保存到对比结果中。

```
/// 将 project 与 other project 做比较
///
/// - parameter project1: 作为比较的 project
/// - parameter project2: 被参照的 project
///
/// - returns: project1 相对于 project2 的变化
class func compare(project project1: [String: Any], withOtherProject project2: [String: Any]) -> Any {
    
    var difference = ["insert": [String: Any](), "remove": [String: Any](), "modify": [String: Any]()]
    
    /// 将两个数据对象作递归比较，将最深层次节点的差异保存到 difference 中。
    ///
    /// - Parameters:
    ///   - data1: 第一个数据对象，数组或字典
    ///   - data2: 第二个数据对象，数组或字典
    ///   - parentKeyPath: 父路径
    func compare(data data1: Any?, withOtherData data2: Any?, parentKeyPath: String) {
        if let dictionary1 = data1 as? [String: Any], let dictionary2 = data2 as? [String: Any] {
            let set1 = Set(dictionary1.keys)
            let set2 = Set(dictionary2.keys)
            for key in set1.subtracting(set2) {
                if let value = dictionary1[key], difference["insert"]?[parentKeyPath] == nil {
                    difference["insert"]?[parentKeyPath] = [key: value]
                }
                else if let value = dictionary1[key], var insertDictionary = difference["insert"]?[parentKeyPath] as? [String: Any] {
                    insertDictionary[key] = value
                    difference["insert"]?[parentKeyPath] = insertDictionary
                }
            }
            for key in set2.subtracting(set1) {
                if difference["remove"]?[parentKeyPath] == nil {
                    difference["remove"]?[parentKeyPath] = [key]
                }
                else if var removeArray = difference["remove"]?[parentKeyPath] as? [Any] {
                    removeArray.append(key)
                    difference["remove"]?[parentKeyPath] = removeArray
                }
            }
            for key in set1.intersection(set2) {
                let keyPath = parentKeyPath == "" ? key : "\(parentKeyPath).\(key)"
                // values are both String, leaf node
                if let str1 = dictionary1[key] as? String,
                    let str2 = dictionary2[key] as? String {
                    if str1 != str2 {
                        difference["modify"]?[keyPath] = str1
                    }
                }
                else { // continue compare subtrees
                    compare(data: dictionary1[key], withOtherData: dictionary2[key], parentKeyPath: keyPath)
                }
            }
        }
        if let array1 = data1 as? [String], let array2 = data2 as? [String] {
            let set1 = Set(array1)
            let set2 = Set(array2)
            for element in set1.subtracting(set2) {
                if difference["insert"]?[parentKeyPath] == nil {
                    difference["insert"]?[parentKeyPath] = [element]
                }
                else if var insertArray = difference["insert"]?[parentKeyPath] as? [Any] {
                    insertArray.append(element)
                    difference["insert"]?[parentKeyPath] = insertArray
                }
            }
            for element in set2.subtracting(set1) {
                if difference["remove"]?[parentKeyPath] == nil {
                    difference["remove"]?[parentKeyPath] = [element]
                }
                else if var removeArray = difference["remove"]?[parentKeyPath] as? [Any] {
                    removeArray.append(element)
                    difference["remove"]?[parentKeyPath] = removeArray
                }
            }
        }
    }
    compare(data: project1, withOtherData: project2, parentKeyPath: "")
    return difference
}
```

这段看似很长的代码其实逻辑超级简单，就是分别针对字典和数组两种情况进行比较而已，弱智的一逼。需要注意的是数组内容作为叶子节点，只存在『增』和『删』两种情况。

每次递归都将 `parentKeyPath` 与当前节点的值 `key` 用 `.` 拼接在一起。也就是说最后得到的路径是 `A.B.C` 这种格式。

可以看出生成的对比结果是个字典，包含三个键值对，键分别是 `insert`、`remove` 和 `modify`，值为字典。

### 应用 JSON 配置

因为生成的 JSON 配置文件具有一定格式，所以必须按照格式规则来应用这些配置到工程文件中。最关键的是在上一步中生成的路径格式为 `A.B.C`，且路径内容是未知的，需要实时处理。所以我写了个方法来解析路径，步入到路径最底层后提供闭包来对路径的值进行修改。假设 `keyPath` 为路径字符串内容，方法实现如下：

```
let keys = keyPath.components(separatedBy: ".")
                
/// 假如 command 为 "modify" keyPath 为 "A.B.C"，目的是让 value[A][B][C] = data。需要沿着路径深入，使用闭包修改叶子节点的数据，递归过程中逐级向上返回修改后的结果，完成整个路径上数据的更新。
///
/// - parameter index:    路径深度
/// - parameter value:    当前路径对应的值
/// - parameter complete: 路径终点所要做的操作
///
/// - returns: 当前路径层级修改后的值
func walkIn(atIndex index: Int, withCurrentValue value: Any, complete: (Any) -> Any?) -> Any? {
    if index < keys.count {
        let key = keys[index]
        if let dicValue = value as? [String: Any],
            let nextValue = dicValue[key] {
            var resultValue = dicValue
            resultValue[key] = walkIn(atIndex: index + 1, withCurrentValue: nextValue, complete: complete)
            return resultValue
        }
        else {
            print("Wrong KeyPath")
        }
    }
    else {
        return complete(value)
    }
    return value
}
```

这个方法会将当前层级（`index`）路径的节点作为键（`key`），并查找字典中该键对应的值（` nextValue`）。然后递归遍历下一层，直至步入到路径（`keypath`）最末端。此时会执行传入的 `complete` 闭包，并将结果作为该方法的返回值。这样在对路径最末端的节点值做出修改后就可以逐层同步上去，最后完成对整条路径的修改。

如果能直接给 `value[A][B][C]` 赋值就好了，但是这是不可能的。因为路径内容是未知的，这样的代码不可能写死的，只能动态地递归进去，并在调用后将修改内容返回上层。

之前提到过 JSON 文件格式中包含三种命令：`insert`、`remove` 和 `modify`。所以在实现 `complete` 方法的时候需要针对这三种命令分别处理，每种命令还要区分字典和数组两种数据类型。这里处理的逻辑基本是上一步的逆逻辑，很容易理解。

```
/// 这个方法可厉（dan）害（teng）咯，把 json 配置数据应用到工程文件数据上
///
/// - parameter json:        配置文件数据，用于对工程文件的增删改操作
/// - parameter projectData: 工程文件数据，project.pbxproj 的内容
class func apply(json: [String: [String: Any]], onProjectData projectData: [String: Any]) -> [String: Any] {
    var appliedData = projectData
    // 遍历 JSON 中的三个命令
    for (command, arguments) in json {
	     // 遍历每个命令中的路径
        for (keyPath, data) in arguments {
            let keys = keyPath.components(separatedBy: ".")
            
            func walkIn(atIndex index: Int, withCurrentValue value: Any, complete: (Any) -> Any?) -> Any? {
            ... 此处省略
            }
            
            // 调用 `walkIn` 方法，
            if let result = walkIn(atIndex: 0, withCurrentValue: appliedData, complete: { (value) -> Any? in
                // value 为路径叶子节点的数据。根据 command 的不同，处理的规则也不一样：
                switch command {
                    // 添加数据时 data 和 value 类型要统一，要么都是数组，要么都是字典，否则不做变更
                case "insert":
                    if var dictionary = value as? [String: Any],
                        let dicData = data as? [String: Any] {
                        for (dataKey, dataValue) in dicData {
                            dictionary[dataKey] = dataValue
                        }
                        return dictionary
                    }
                    if var array = value as? [Any],
                        let arrayData = data as? [Any] {
                        array.append(contentsOf: arrayData)
                        return array
                    }
                    return value
                    // 移除数据时被移除的 data 为包含数据或键的数组，否则不做变更
                case "remove":
                    if var dictionary = value as? [String: Any],
                        let arrayData = data as? [Any] {
                        for removeData in arrayData {
                            if let removeKey = removeData as? String {
                                dictionary[removeKey] = nil
                            }
                        }
                        return dictionary
                    }
                    if var array = value as? [String],
                        let arrayData = data as? [Any] {
                        for removeData in arrayData {
                            if let removeIndex = removeData as? Int {
                                if (0 ..< array.count).contains(removeIndex) {
                                    array.remove(at: removeIndex)
                                }
                            }
                            if let removeElement = removeData as? String,
                                let removeIndex = array.index(of: removeElement) {
                                array.remove(at: removeIndex)
                            }
                        }
                        return array
                    }
                    return value
                    // 直接用 data 替换 value
                case "modify":
                    return data
                default:
                    return value
                }
                
            }) as? [String: Any] {
                appliedData = result
            }
        }
    }
    return appliedData
}
```

因为 JSON 文件内容层级较深，所以需要先遍历最外面的字典。一共有三个键值对，分别对应 `insert`、`remove` 和 `modify` 三个命令（`command`）及其参数（`arguments`）。每种命令的参数都是由『(路径:字典或数组)』这样格式的键值对组成。路径对应的值的类型需要与 JSON 文件中一样。

在遍历的同时修改工程文件数据的内容，这里使用了 Swift 的嵌套方法和尾随闭包语法。这总语法虽然用着爽，但是对代码的可读性也有所降低。
### 操作工程文件

可以用 `PropertyListSerialization` 来（反）序列化 project.pbxproj 文件的内容：

```
let fileData = try Data(contentsOf: url)
let plist = try PropertyListSerialization.propertyList(from: fileData, options: .mutableContainersAndLeaves, format: nil)

let data = try PropertyListSerialization.data(fromPropertyList: list, format: .xml, options: 0)
try data.write(to: url, options: .atomic)
```

将工程文件数据写入磁盘表面上看起来是一件再简单不过的事情，但其实这里面包含编码问题和备份机制。

#### 编码问题

直接把工程文件数据写入文件后，中文会有乱码。需要做的是把中文内容的 Unicode 的标量值提取出并转成 numeric character reference（NCR）。"&#dddd" 的一串字符是 HTML、XML 等 SGML 类语言的转义序列（escape sequence），它们不是『编码』。

下面的方法可以将生成的工程文件中文内容替换成 NCR：

```
func handleEncode(fileURL: URL) {
    func encodeString(_ str: String) -> String {
        var result = ""
        for scalar in str.unicodeScalars {
            if scalar.value > 0x4e00 && scalar.value < 0x9fff {
                result += String(format: "&#%04d;", scalar.value)
            }
            else {
                result += scalar.description
            }
        }
        return result
    }
    do {
        var txt = try String(contentsOf: fileURL, encoding: .utf8)
        txt = encodeString(txt)
        try txt.write(to: fileURL, atomically: true, encoding: .utf8)
    } catch let error {
        print("translate chinese characters to mathematical symbols error: \(error.localizedDescription)")
    }
}
```

#### 备份机制

既然是要生成新的工程文件来替换原来的工程文件，备份机制肯定不能少。当前的备份机制仅仅备份上次修改的文件，这是考虑到备份历史文件会占用大量磁盘的问题。比如大一些的工程文件可能占用10M 甚至更多的空间，频繁操作产生的备份会很多。

在生成备份文件和使用备份文件还原时，都需要获取到当前工程文件对应的备份文件 URL。真正的主角 project.pbxproj 被包含在工程文件（夹）内部，所以要根据文件后缀名来决定如何处理。下面的私有方法会将传入的 URL 引用参数修改为真正的 project.pbxproj 文件 URL，并返回备份文件的 URL：

```
/// 返回指定文件对应的备份文件路径
///
/// - parameter url: 文件 URL，如果是工程文件，会被修改为 project.pbxproj 文件
///
/// - returns: 备份文件路径
fileprivate class func backupURLOf(projectURL url: inout URL) -> URL {
    var backupURL = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Documents")
    if url.pathExtension == "xcodeproj" {
        backupURL.appendPathComponent(url.lastPathComponent)
        backupURL.appendPathExtension("project.pbxproj")
        url.appendPathComponent("project.pbxproj")
    }
    else {
        let count = url.pathComponents.count
        if count > 1 {
            backupURL.appendPathComponent(url.pathComponents[count-2])
            backupURL.appendPathExtension(url.pathComponents[count-1])
        }
    }
    backupURL.appendPathExtension("backup")
    return backupURL
}
```

一个方法只干一件事，这个方法设计的很不好，干了两件事，别学我这么做。我这么做是为了省代码量。（狡辩，逃）

### 预览和过滤工程文件内容

主界面如下，在展示所有数据的同时，可以在 Filter 文本框中输入关键词来过滤数据：

![MainWindow](https://raw.githubusercontent.com/yulingtianxia/pbxprojHelper/master/images/MainWindow%402x.png)

#### 预览

关于如何使用 `NSOutlineView` 展示数据，不想多说，查文档写 UI 谁都会。

我定义了一个数据结构 `Item` 来表示 `NSOutlineView` 中每行节点的数据：

```
typealias Item = (key: String, value: Any, parent: Any?)
```

因为有了 `parent` 指向父节点，可以递归搜寻到某个 `Item` 对象所处的路径（`keypath`）：

```
func keyPath(forItem item: Any?) -> String {
    let key: String
    let parent: Any?
    if let tupleItem = item as? Item {
        key = tupleItem.key
        parent = tupleItem.parent
    }
    else {
        key = ""
        parent = nil
    }
    
    if let parentItem = parent {
        return "\(keyPath(forItem: parentItem)).\(key)"
    }
    return "\(key)"
}
```

这样就可以实现双击某行数据时，自动将当前数据的路径写入 Pasteboard 中。

#### 过滤

过滤关键字的重点就是判断一个 `Item` 及其子节点中是否包含此关键字，此时需要依然是需要 DFS 递归查找关键字。

查找关键字需要忽略大小写：

```
func checkAny(value: Any, containsString string: String) -> Bool {
    return ((value is String) && (value as! String).lowercased().contains(string.lowercased()))
}
```

递归查找很容易实现，只不过区分下数组和字典罢了：

```
func dfs(propertyList list: Any) -> Bool {
    if let dictionary = list as? [String: Any] {
        for (key, value) in dictionary {
            if checkAny(value: key, containsString: word) || checkAny(value: value, containsString: word) {
                return true
            }
            else if dfs(propertyList: value) {
                return true
            }
        }
    }
    if let array = list as? [Any] {
        for value in array {
            if checkAny(value: value, containsString: word) {
                return true
            }
            else if dfs(propertyList: value) {
                return true
            }
        }
    }
    return false
}
```

最后经过方法嵌套拼装成如下：

```
func isItem(_ item: Any, containsKeyWord word: String) -> Bool {
    if let tupleItem = item as? Item {
        if checkAny(value: tupleItem.key, containsString: word) || checkAny(value: tupleItem.value, containsString: word) {
            return true
        }
        func dfs(propertyList list: Any) -> Bool {
        	/// 此处省略
        }
        return dfs(propertyList: tupleItem.value)
    }
    return false
}
```

### 快速切换工程文件

下拉列表的 UI 实现很简单，就是一个 `NSView` 里面放几个 `NSTextField`。维护常用工程文件列表需要在每次用户选择工程文件后将其加入列表，实现 LRU 算法。

这里对 LRU 缓存的需求跟 [自制一款 Mac 平台 URL 辅助工具](http://yulingtianxia.com/blog/2016/02/27/TFSHelper/#缓存常用链接) 这篇文章中的 TFSHelper 的是一样的。我直接把代码搬过来了。

下拉列表的点击操作交由 `NSClickGestureRecognizer` 捕获处理。

### 构造命令行工具

为了尽可能精简命令行的使用复杂度，我只把最核心的功能封装进去，一共只有这几个命令：

```
Usage: pbxproj [command_option] file
Command options are (-convert is the default):
-compare modified_file -o path          compare modified property list file with property list file and generate a json result at the given path
-apply json_file                        apply a json file on property list file
-revert                                 revert property list file to latest backup
-convert                                rewrite property list files in xml format
```

输入的这些参数都需要自己去处理，由此会产生大量条件判断，好在我的不算复杂。需要注意的是参数列表第一个是程序名称（路径）。

在 terminal 中执行 Swift 文件时获取参数内容的方式变了好多次，一开始是 `C_ARGC` 和 `C_ARGV`，到了 Swift 1.2 只能使用 `Process.arguments`，到了 Swift 3 又变了，必须用 `CommandLine.arguments`。

拿到了参数后，我所做的事情只是调用 `PropertyListHandler` 中已经封装好的工具方法罢了。

不是所有的人都会把 Swift 文件当做脚本去执行，所以还需要创建个 target，打包成可执行程序，这样就不依赖 Swift 命令了。

## 结果

我使用 pbxprojHelper 的频率十分高，因为开发同一项目的人很多，svn 的分支也多。第一次生成好我的 JSON 配置文件后以后就几乎不用再生成了，不同分支的工程都可以共用这一个 JSON 配置。每次因为种种原因 revert 了 project.pbxproj 文件后，我都可以用它一键配置好我的工程文件，**节省了至少 90% 的时间！**即便换了个其他分支的工程，也可以在常用列表中迅速切换，不用再次 select 文件。

也正是在一次次的使用中发现了若干 bug 和体验问题，然后不断改进和完善。

## 感悟

这个项目从开始构思需求到完成基本功能花费了我大概一周的业余时间。

前期调研做了些准备工作后觉得还是有可行性的，并对部分功能需求做了妥协。比如记录工程文件修改内容需要对比新旧两个文件，这就要求使用者先把工程文件保存一份，然后再修改，最后使用 pbxprojHelper 对比两个工程文件的差异。最后生成工程文件的环节也做了妥协，因为无法将数据以 OpenStep 格式写入文件，除非调用 Xcode 私有框架 `touch` 下工程文件。所以需要用户用 Xcode 打开工程后随意修改下工程再复原即可。就是在这样一次次对功能的妥协下，使得方案的看似不可行变得可行。

这个项目的需求一开始并不明确，是在摸索中一点点确立的。比如一开始根本没有想到过要把修改保存成 JSON 文件，之后想的是让用户手动创建和编写 JSON 配置文件，再之后想的是自动生成 JSON 配置文件。在制定 JSON 配置的内容规则上也是调整了一阵子，几经修改最后定稿。所以说，产品经理下次改需求的时候可以适当理解下，毕竟产品成型的确需要个过程。

**摸着石头过河的感觉虽然忐忑，但是我更享受攻城略地般的快感。**当时在开发的过程中遇到了一个个难题，当时连自己也不知道能否搞定，很有可能半途而废。但最终还是通过制定策略和实现算法实现了，虽然算法都挺简单并不难，但是能有针对性地给出一些解决方案还是比较有成就感的。

作为一款给自己量身打造的玩票工具，使用 Swift 来开发看起来是当今标配，理所当然。也是趁着玩票的机会温（chong）习（xue）下 Swift，毕竟平时一直用 OC 写 MRC 代码，生怕落后于这个时代。
