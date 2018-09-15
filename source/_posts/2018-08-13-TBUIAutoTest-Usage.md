---
title: iOS 自动化测试标签生成工具接入指南
date: 2018-08-13 00:24:45
tags:
---
[TBUIAutoTest](https://github.com/yulingtianxia/TBUIAutoTest) 可以帮开发人员生成UI 控件的标签，便于自动化测试。只需一行代码或一个配置，几乎所有的 iOS Native UI 都会在运行时生成一个页面内唯一且不变的标签。不仅节省了开发人员手动为每个 UI 控件加标签的时间，也节省了测试人员与开发人员的沟通成本。

<!--more-->

## 应用场景

目前已经有 QQ、今日头条、兴趣部落、NOW直播等几十款 App 接入 [TBUIAutoTest](https://github.com/yulingtianxia/TBUIAutoTest)。阿里系自动化测试开源框架 [Macaca](https://github.com/macacajs/iosHookViewId) 也在使用此方案，服务阿里多款 App。

以往的工作流程是：

1. 测试同学梳理出需要加标签的 UI 控件，通过截图标注给开发同学。
2. 开发同学按照标注，给相应的 UI 控件手写代码添加标签。（花时间起唯一的标签名，增加安装包体积）
3. 测试同学使用工具抓取控件树，查看控件标签，编写脚本。

如果使用 [TBUIAutoTest](https://github.com/yulingtianxia/TBUIAutoTest)，只需要简化成一个步骤：

1. 测试同学使用工具抓取控件树，查看控件标签，编写脚本。

而且几乎是**一劳永逸**的，后续新增的代码也会在运行时生成标签，**以不变应万变**！

近些年苹果的自动化测试框架经历过一些变化，但是始终是使用无障碍化相关的 API 来获取控件树和标签。

实现的思路和原理：[为 UIAutomation 添加自动化测试标签的探索](http://yulingtianxia.com/blog/2016/03/28/Add-UITest-Label-for-UIAutomation/)

## 集成方式

### 手动拖拽文件

将 TBUIAutoTest 文件夹内的所有文件加入到工程中即可。

```
TBUIAutoTest.h
TBUIAutoTest.m
UIImage+TBUIAutoTest.h
UIImage+TBUIAutoTest.m
UIResponder+TBUIAutoTest.h
UIResponder+TBUIAutoTest.m
UIView+TBUIAutoTest.h
UIView+TBUIAutoTest.m
```

### CocoaPods

首先要安装 CocoaPods：

```
gem install cocoapods
```

在 `Podfile` 中添加 TBUIAutoTest。需要将 "MyApp" 替换成自己的名字：

```
source 'https://github.com/CocoaPods/Specs.git'
platform :ios, '6.0'
use_frameworks!
target 'MyApp' do
	pod 'TBUIAutoTest'
end
```

最后需要运行下面的命令行安装下：

```
pod install
```

### Carthage

首先要通过 homebrew 安装 Carthage:

```
brew update
brew install carthage
```

然后在 `Cartfile` 文件中添加

```
github "yulingtianxia/TBUIAutoTest"
```

运行 `carthage update` 命令来获取 `TBUIAutoTest.framework`，将其拖拽到工程中使用即可。

## 使用方法

- `kAutoTestUITurnOnKey` ：是否生成 UI 标签
- `kAutoTestUILongPressKey` ：是否开启长按弹窗显示 UI 标签

[TBUIAutoTest](https://github.com/yulingtianxia/TBUIAutoTest) 会在 `+ load` 方法中从 `NSUserDefaults` 中读取 `kAutoTestUITurnOnKey` 和 `kAutoTestUILongPressKey` 的值。所以在设置这两个 Key 之后，一般需要下次启动 App 才生效。这里推荐拉一条自动化测试专用分支，通过宏控制在 App 启动更早的时机设置这两个 Key。

```
extern NSString * const kAutoTestUITurnOnKey;
extern NSString * const kAutoTestUILongPressKey;
[NSUserDefaults.standardUserDefaults setBool:YES forKey:kAutoTestUITurnOnKey];
[NSUserDefaults.standardUserDefaults setBool:YES forKey:kAutoTestUILongPressKey];
```

## 注意事项

系统一些自带的 UI 控件的 `isAccessibilityElement` 属性默认是 `YES`，但是如果想让自定义的 UI 控件能够被捕获，需要手动将其设为 `YES`。除此之外还有一些容器控件之间的嵌套场景，需要在容器类中实现 `UIAccessibilityContainer`，这样才能捕获到容器控件内的子视图。最简单的一种实现如下：

```
#pragma mark - UIAccessibilityContainer

#ifdef AUTO_TEST_ENV
-(BOOL)isAccessibilityElement
{
    return NO;
}

- (NSInteger)accessibilityElementCount
{
    return [[self subviews] count];
}

- (id)accessibilityElementAtIndex:(NSInteger)index
{
    return [[self subviews] objectAtIndex:index];
}

- (NSInteger)indexOfAccessibilityElement:(id)element
{
    return [[self subviews] indexOfObject:element];
}
#endif
```

对于那种绘制上去的 UI，但非使用原生 UI 控件的场景，就需要自己创建 `UIAccessibilityElement` 对象，并手动设置标签了。这部分其实都是 App 无障碍化的知识，具体细节可以参考苹果官方文档：https://developer.apple.com/documentation/uikit/accessibility/uiaccessibilitycontainer?language=objc