---
title: 多媒体编辑模块架构设计
date: 2016-12-29 09:37:04
tags:
---
## 多媒体编辑模块重构概要

多媒体编辑包含了对图片和视频的编辑，比如在某个位置添加一些图片或者涂鸦等操作。这里讲的是一个平台无关的架构，包含了操作面板组件化、手势引擎、业务解耦等内容。具体对图片和视频等内容的渲染等操作不做讨论。

这里设想的场景是：用户录制好一段视频或拍照后进入编辑模块，编辑面板下方有几个按钮，点击后可以进入某种编辑模式，比如添加文字、表情、涂鸦、音乐等编辑功能。右下角会有个发表按钮，左上角有个重拍按钮：

![原型](http://7ni3rk.com1.z0.glb.clouddn.com/MultimediaEdit/原型.png)

设计一个模块首先要明确它的职责，输入和输出都是什么。多媒体编辑简介如下图所示：

![简介](http://7ni3rk.com1.z0.glb.clouddn.com/MultimediaEdit/简介.png)

## 组件化总体设计

在明确了多媒体编辑模块的本质是 UI 操作面板后，首先要从视图层级入手，设计好整个模块各职责对应的层级，并兼顾触摸事件的传递。在视图层级交互策略设计好后，就可以进行 UML 的设计了。这次，要拒绝不规范的编程习惯，并对耦合几乎零容忍！将编辑组件与 EditView 解耦，把一些基础逻辑抽象出来，与具体业务剥离开。减少了多人改同一份代码带来的风险，并能更快定位bug来源。

### 视图层级图

![框架总体视图层级设计](http://7ni3rk.com1.z0.glb.clouddn.com/MultimediaEdit/框架总体视图层级设计.png)

### UML 架构图

![多媒体编辑重构UML](http://7ni3rk.com1.z0.glb.clouddn.com/MultimediaEdit/多媒体编辑重构UML.png)

## 手势识别引擎

手势引擎既要『大一统』式地管理，又要与具体响应手势的元素视图进行解耦，做法就是统一接口，制定标准。所有想响应手势的视图都需要继承 `InteractionElementView` 或者将其作为 `parentView`。可以配置元素对象来实现对手势响应的规则，更加灵活自如，而且零耦合。有关手势命中区域的计算方法请阅读我之前发表的一篇文章：[处理手势冲突和错乱的一点经验](http://yulingtianxia.com/blog/2016/08/29/Some-Experience-of-Gesture/)，我在这里详细阐述了各种情形下的手势命中计算方法。下图为手势识别引擎策略的流程图：

![手势识别引擎](http://7ni3rk.com1.z0.glb.clouddn.com/MultimediaEdit/手势识别引擎.png)

## 组件设计

### 组件与元素

组件的 `baseZIndex` 定义了组件所创建元素的 `zIndex` 的基础值。元素容器会有一个计数器 `nextZIndexOfElement`，每次获取时会自动加一。所以元素的 `zIndex` 等于 `baseZIndex` 与 `nextZIndexOfElement` 之和。

之所以要给元素定义 `zIndex` 这个属性是考虑到某些元素可能会在元素容器与组件容器之间切换层级。比如文字元素就是这种例子。所以当某个元素重新添加到元素容器后，元素容器需要根据每个元素的 `zIndex` 属性来重新排序层级顺序。

### 组件与 EditView

组件不是必须要向 `MultimediaEditView` 中的元素容器中添加元素的，它也可以不创建任何元素，而是直接操作多媒体资源（比如选择一些滤镜），也可以是做些其他事情，比如保存多媒体资源到本地。**`MultimediaEditView` 只是给组件提供了一个操作入口，而组件为 `MultimediaEditView` 提供了很强的拓展性**。

### 组件与数据

每个组件都有自己唯一的 ID，默认是类名。组件的按钮被点击后，会将自己设为 `currentEditComponent`，`MultimediaEditView` 会调用上一个组件的 `stop` 方法，然后调用新组件的 `start` 方法。组件在 `start` 和 `stop` 方法中完成组件内容的装载和卸载。组件产生的用户数据可以存放在 `componentInfos` 中，可用于之后的发表等流程。`reset` 方法用于清除组件数据以及持有的状态和元素。继承于 `MultimediaEditComponent` 的子类需要覆写这些主要的方法。组件也可以直接操作多媒体资源，所以也可能会跟其他模块有数据流动。

![](http://7ni3rk.com1.z0.glb.clouddn.com/MultimediaEdit/组件的数据流动.png)

## 业务方

具体的业务一般是需要继承 `MultimediaEditView` 加入一些自己特有的逻辑，并在自己的 ViewController 创建和注册组件。如果某个业务需要对具体的组件进行个性化修改，我建议具体的组件也需要再继承一下。如果以后所有业务统一组件的行为，那也可以再把之前子类的逻辑迁移回基类。这样做的好处是避免某个业务直接修改基类影响到所有业务的风险，之前就有过先例。

![](http://7ni3rk.com1.z0.glb.clouddn.com/MultimediaEdit/业务方的使用.png)