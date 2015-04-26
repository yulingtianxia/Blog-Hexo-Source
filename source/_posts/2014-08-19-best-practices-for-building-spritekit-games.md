---
layout: post
title: "创建SpriteKit游戏的最佳范例"
date: 2014-08-19 22:16:13 +0800
comments: true
tags: 
- SpriteKit

---
本文会从拓展性、游戏构造和性能三个方面分别讲述建立SpriteKit游戏时的一些实践经验和范例。建议先阅读[SpriteKit在iOS8和OSX10.10中的新特性](http://yulingtianxia.com/blog/2014/08/08/spritekitzai-ios8he-osx10-dot-10zhong-de-xin-te-xing/)有助于理解本文内容。  
<!--more-->
##拓展性最佳范例

###硬编码问题

在以前，程序员在场景中做了所有的事情，在代码中引用美工，游戏第一关采用硬编码，第二关第三关就是一顿复制粘贴修修补补。修改美工图片也意味着要改代码，每次预览修改后的效果都要Build和Run，而设计游戏的人甚至要会编程，因为修改设计（比如一些游戏参数）也要改代码。如果项目接着编写下去，这导致重复性的构建代码，将数据硬编码到代码中也是种低效率做法，编码与美工和设计人员之间合作困难。  

解决方案：  

- 将游戏内容与游戏逻辑分离
- 将场景构造与素材分离
- 将数据与代码分离
- 在Xcode中所见即所得  

具体实现：  

- 游戏逻辑写在MyScene.m文件中（使用SpriteKit的模板）
- 游戏场景结构创建在MyScene.sks文件中
- 场景用到的素材使用单独的sks文件分开管理
- 数据要存储在plist文件中（XML格式）

Xcode6为我们提供的工具：  

- SpriteKit模版，支持OC和Swift
- SpriteKit编辑器：可视化编辑sks文件，即时预览效果，实时物理模拟
- plist数据编辑器：XML语言被可视化成字典来编辑，简单高效


在MyScene.m文件中使用下面的模板来加载MyScene.sks中设计好的场景结构，然后你就可以接着写游戏的逻辑了：  

``` js
let path = NSBundle.mainBundle().pathForResource(file, ofType: "sks")       
var sceneData = NSData.dataWithContentsOfFile(path, options: .DataReadingMappedIfSafe, error: nil)
var archiver = NSKeyedUnarchiver(forReadingWithData: sceneData)
archiver.setClass(self.classForKeyedUnarchiver(), forClassName: "SKScene")
let scene = archiver.decodeObjectForKey(NSKeyedArchiveRootObjectKey) as GameScene
archiver.finishDecoding()
``` 

##游戏构造最佳范例

程序员总是想让游戏尽可能早地跑起来。为了完成这个目标，我们要懂得与美工和设计合作，毕竟程序员不能独自完成所有事情，下面列举下快速达成目标的步骤：  

1. 先把一般性的工作做完，这只是逻辑布局上的编程，不必等美工提供素材。标记好英雄、敌人等人物出现的位置，设计好背景、平台等。  
2. 用只有颜色没有贴图的`SKSpriteNode`来充当英雄和敌人，只要能区分开就好。现在可以设定父子层级关系，比如设定粒子发射位置，连接组件和关节（胳膊腿儿啥的）  
3. 设定物理层面的相互作用，比如各种物理体的类别，碰撞掩码，是否受物理世界的影响等。在Xcode中模拟物理场景，保证你做的这些从一开始就万无一失。  
4. 初始化场景逻辑和游戏逻辑，把之前在场景上布置好的物体与代码中的游戏中的物体用之前设定好的名字（英雄or敌人）联系起来。使用SpriteKit模板加载好游戏场景后，`SKScene`的`initWithCoder`会被调用，我们可以在这里加载声音和AI数据等不会变化的数据。当`SKView.presentScene:`被调用时，`SKScene`的`didMoveToView:`会被调用，在这里你要缓存可见的元素，比如敌人，你可以通过名字将它们从场景的子节点中遍历出来。    
5. 完成游戏：将美工给你的素材替代以前的纯色，增加关卡和效果（Shader，滤镜等），迭代测试。

PS：两种搜索节点元素的方法：
``` 
– childNodeWithName:
– enumerateChildNodesWithName:usingBlock:
``` 
> 关于搜索文本的语法补充：  
> 通过name查找：  

> - “hero”是查找叫做“hero”的子节点，不迭代
> - “//hero”是查找场景图中所有叫做“hero”的子节点，迭代

> 通过class查找：

> - “//SKEmitterNode”会在场景图中迭代查找所有粒子节点

> 通过通配符查找：

> - “//he*”查找所有以“he”开头的子节点

##性能最佳范例

我们要尽可能维持游戏每秒60帧频率的刷新，就需要从性能上优化。  

###Drawing performance
影响绘图性能的两个主要因素：  

- 绘制顺序：默认的绘制顺序是按照代码中构造节点树的顺序绘制的，先绘制父节点，然后依次绘制子节点，并向下迭代。你可以将`SKView`的`ignoresSiblingOrder`属性设为YES，然后利用Z轴的层级深浅关系来定制绘制次序。
- 共享：使用纹理图集（texture atlases），共享法线贴图，从文件加载Shader而不是字符串，将混合模式放在Z轴同一层级。  

下面的工具能帮你评估图形性能：  

`SKView`上的HUD flags：  

``` 
showsFPS
showsDrawCount
showsNodeCount
showsQuadCount
``` 

profile：检测硬件使用情况。
###Actions and constraints

使用`SKAction`类实现SpriteKit中的动画是很高效的。用一行代码就能实现诸如平移、旋转、缩放、渐入渐出等动画效果。你可以将多个动画组成一个序列（sequence）来依次执行，也可组成一个group来同时执行，sequence和group之间也可以互相嵌套。`SKAction`有很多方法，可以查看它的API文档。  

如果你给Action使用Key命名的话，你还可以通过Key来动态删除和重写这个Action。

`SKConstraints`类能在节点与节点或固定点之间建立约束。详见我的另一篇文章[SpriteKit在iOS8和OSX10.10中的新特性](http://yulingtianxia.com/blog/2014/08/08/spritekitzai-ios8he-osx10-dot-10zhong-de-xin-te-xing/)中New Physics->Constraints小节。  

###Physics

模拟物理世界需要很多的硬件计算，当务之急就是减少能耗。  

静态物体耗能较小，即使他们外形复杂。所以尽可能的将物理体的`dynamic`属性设为NO  

物理体的外形复杂程度也决定着能耗。圆形是最简单的，耗能最少，再往上依次是矩形、多边形、复合图形、alpha像素图形：  

![](http://yulingtianxia.qiniudn.com/140844930564.png)  

所以你需要权衡利弊来设计你游戏中物理体的外形。上图的后两种外形是iOS8新加入的，你可以在[SpriteKit在iOS8和OSX10.10中的新特性](http://yulingtianxia.com/blog/2014/08/08/spritekitzai-ios8he-osx10-dot-10zhong-de-xin-te-xing/)中的New Physics->Per-Pixel Physics和Improvements->Physics Updates这两个小节中学到有关它们的更多知识。  

在设置碰撞掩码（mask）时，尽量将相同类别的物体归为一类，用尽可能少得类别来划分你游戏中的物体。这样能减少很多能耗。  

尽可能使用iOS8新加入的`SKFieldNode`来模拟一些物理场景，而不是通过传统代码方式（自己向各种物体施加各种力）。有关`SKFieldNode`的知识可以查看[SpriteKit在iOS8和OSX10.10中的新特性](http://yulingtianxia.com/blog/2014/08/08/spritekitzai-ios8he-osx10-dot-10zhong-de-xin-te-xing/)中New Physics->Physics Fields那节。  

将`SKView`的`showsFields`属性设为YES可以将`SKFieldNode`的debug信息显示出来：  

![](http://yulingtianxia.qiniudn.com/140845151467.png)
![](http://yulingtianxia.qiniudn.com/140845150994.png)  

上面两个场景是我的一个SpriteKit游戏[ColorAtom](http://coloratom.yulingtianxia.com)中的秘密模式和黑洞模式截图，欢迎Star和Follow。  
###Shapes

`SKShapeNode`的耗能层级图如下：  

![](http://yulingtianxia.qiniudn.com/14084531435.png)  

上图中的分界线区分了低功耗和高功耗的Shape。绘制分段的linear strok所需的功耗也很少。  

###Effects

`SKEffectNode`可以将它的子节点渲染的更加出彩，比如用CoreImage滤镜等合成出复杂的特效。但这也会对性能有很大影响，请谨慎使用。  

Shader是一个不错的选择，它不需要离屏渲染，想用就用，节能环保。有关`SKShader`的知识可以查看[SpriteKit在iOS8和OSX10.10中的新特性](http://yulingtianxia.com/blog/2014/08/08/spritekitzai-ios8he-osx10-dot-10zhong-de-xin-te-xing/)中Shader那节。  

`shouldRasterize`属性暗示是否缓存以备将来之需。如果你的画面会停留一段时间，可以考虑设置为YES。

我们还可以从`SKNode`中获取纹理（这不费吹灰之力），还可以对纹理进行滤镜加工：   

``` 
SKTexture *texture = [myView textureFromNode:node size:size];
SKTexture *texture = [myTexture textureByApplyingCIFiler:filer];
``` 

###Lighting

光照的功耗是跟像素数量成比例的，每个`SKSpriteNode`最多能被八个光源照射，你可以利用光照掩码来优化性能。  

环境光照（ambient light）所需功耗是免费的，而法线贴图（Normal Maps）功耗很低。  

阴影的功耗跟光源数量成正比，所以尽可能减少光源数量。  

有关Lighting的更多知识可以查看[SpriteKit在iOS8和OSX10.10中的新特性](http://yulingtianxia.com/blog/2014/08/08/spritekitzai-ios8he-osx10-dot-10zhong-de-xin-te-xing/)中Lighting and Shadows那节。  

  
