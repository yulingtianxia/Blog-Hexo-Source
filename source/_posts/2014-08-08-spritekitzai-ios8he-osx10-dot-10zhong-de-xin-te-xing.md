---
layout: post
title: "SpriteKit在iOS8和OSX10.10中的新特性"
date: 2014-08-08 19:11:14 +0800
comments: true
tags: 
- SpriteKit

---

在iOS8和OSX10.10中SpriteKit迎来了重大升级。在物理表现方面增加了着色器，光照和阴影；在物理模拟方面增加了像素物理体、力场和宇宙动力学和约束等；在Xcode中集成了场景编辑器，你不需要写代码就能完成一些复杂的工作；此外它还集成了SceneKit以及其他的改进。  
<!--more-->
##Shader

有时候为了表现一些形变和模糊效果，比如透过热气和火焰看一些物体，或者是飞船被攻击而产生弯曲。SpriteKit新加入了`SKShader`类来帮助我们更简单的实现这个效果。它通过使用自定义的OpenGL ES碎片着色来完成绘制一些`SKNode`的自定义行为。现在支持以下几种类型的绘制：  

- `SKSpriteNode`
- `SKShapeNode`
- `SKEmitterNode`
- `SKEffectNode`
- `SKScene`

放一张官方演示的效果图：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/140738700571.png)  

`SKShader`内建了一些`uniforms`，用`SKUniform`来描述，当你创建一个`SKShader`时，需要通过一个`fsh`文件或者一个字符串代码来创建，也可选择性的传入`uniforms`来定义游戏中一些额外的参数。下面是创建Shader方法的集合：  

（下面的只是伪代码，不是OC也不是Swift语法，只是为了更简洁的标记方法名，后面类似情形都会标记为“伪代码”）  

```
+ shaderWithFileNamed:
+ shaderWithSource:uniforms:
+ shaderWithSource:
+ shader
- initWithSource:uniforms:
- initWithSource:
```

这些方法很相似，都是传入`source`或`source`与`uniforms`来创建shader。官方建议我们用`fsh`文件作为`source`而不是字符串代码；并且避免更改`source`或添加删除`uniforms`（修改`uniforms`是可以的），因为这样会导致后台花时间重新编译shader；尽量在加载时初始化shader。这些注意事项都可以总结为尽量使用内建的`uniforms`和共享shader对象。

我们可以将创建好的`SKShader`对象赋值给支持Shader渲染对象的`shader`属性。  

下面列举一下Shader中的预定义符号：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/140738949518.png)

##Lighting and Shadows

灯光和阴影效果可以给游戏增加真实感，SpriteKit这次增加了`SKLightNode`来作为光源节点。我们可以定义光源的颜色，阴影和衰弱程度。  

`SKLightNode`继承于`SKNode`，也就是说你可以把它加在其他`SKNode`上，并能够动起来，它是一个会发光的`SKNode`，cool！NOTE：它的光照以及阴影效果只对`SKSpriteNode`起作用。  

下面我们看看`SKLightNode`的一些属性：  

- **`enabled`** 光源的开关  
- **`ambientColor`** 环境色，默认是黑色，也就是没有环境色。它无视自身的alpha以及`SKLightNode`的`falloff`属性和`SKSpriteNode`的`normalTexture`属性，分分钟照亮全场。  
- **`lightColor`** 顾名思义就是光的颜色，默认是白色。  
- **`shadowColor`** 被精灵物体遮挡产生的阴影颜色。  
- **`falloff`** 光源强度的衰减比率
- **`categoryBitMask`** 光的种类，32位整型数。`SKSpriteNode`的`lightingBitMask`、`shadowedBitMask`和`shadowCastBitMask`存储着光的种类，分别意味着：被何种光照亮、被何种光产生的阴影覆盖和遮挡何种光线并产生阴影。  

为了在`SKSpriteNode`上实现更加逼真的光照效果（如阴影和反射光），`SKSpriteNode`新增了`normalTexture`属性来储存原帖图的法线贴图（Normal Map）：   

![](http://7ni3rk.com1.z0.glb.clouddn.com/140739494085.png)  

上图中左侧的是原贴图，加上中间的法线贴图就合成出最右侧带有质感的光照纹理。当然提供这样一张发现纹理图片会增加开发者的工作量，苹果还提供了另一种更加简单的方案-“automatic normal map”：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/140739540301.png)  

SpriteKit能够根据给出的纹理图片，用一系列算法分析原贴图，然后生成一个最佳的法线贴图，又是苹果的黑魔法！

毕竟众口难调，所以SpriteKit让你也可以在生成法线贴图的时候给出平滑度(smoothness)和对比度(contrast)来调节你想要的效果：（伪代码）  

```
- textureByGeneratingNormalMapWithSmoothness:contrast:
```

PS：法线贴图将具有高细节的模型通过映射烘焙出法线贴图，贴在低端模型的法线贴图通道上，使之拥有法线贴图的渲染效果。可以大大降低渲染时需要的面数和计算内容，从而达到优化动画渲染和游戏渲染的效果。

在一个场景中可以添加多个光源，程序会运行的很快；但是如果用两个或以上的光源照亮同一个精灵，在某些iOS设备上可能保证不了60帧的刷新频率。  

##New Physics

###Per-Pixel Physics

在定义一些复杂轮廓的物理体时，我们经常用简单图形代替，否则就用`CGPath`一点点描绘多边形或者把多个物理体组合在一起（这也是新加入的API，后面会提到），比如下面这把斧头，大多数程序员直接用矩形当做它的物理体：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/140740041011.png)  

而Per-Pixel Physics根据纹理图片的alpha通道遮罩来生成一个粗略的形状，然后再用粗略的形状生成精确的形状，它让以前复杂的`CGPath`创建工作转变成一行代码：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/140740040721.png)  

毕竟众口难调，所以SpriteKit给出了一个可以自由调节alpha阈值的物理体生成方法，所有alpha值大于`alphaThreshold`的像素点都将被认为是不透明的，并纳入物理体范围内：（伪代码）  

```
+ bodyWithTexture:alphaThreshold:size:
```

因为SpriteKit是逐个像素计算才得出精确的物理体轮廓，所以我们应该尽量给出合适大小的图片，不要将分辨率过高的图片用在很小的`SKSpriteNode`上。  

###Constrains

试想如果你要做一款塔防游戏，你需要让你的大炮一直瞄准某个怪物，大炮会随着怪物的行走来转动炮台。我们需要不停地根据怪物和大炮的位置来计算需要旋转的角度，甚至当怪物跑的快的时候还要考虑怪物的速度来调整大炮旋转的速度，这是一个很麻烦的事情。现在SpriteKit帮你把这些都做好了，你只需要建立一个`SKConstrains`对象，并约束大炮的角度跟怪物一致就行。  

约束的计算工作发生在模拟物理之后，SpriteKit提供了一个回调函数`didApplyConstraints`，我们可以在约束完成后在里面做一些善后工作：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/140740456021.png)  

在SpriteKit中我们可以向SKNode添加三种约束：（工厂方法的伪代码）   

- 位置约束：  

```
//约束节点的X坐标范围
+ positionX:
//约束节点的Y坐标范围
+ positionY:
//约束节点的X和Y坐标范围
+ positionX:Y:
```

- 方向约束：  

```
//约束节点基于另一个SKNode旋转
+ orientToNode:offset:
//约束节点基于一个固定点旋转
+ orientToPoint:offset:
//约束节点基于另一个SKNode坐标系中的一个固定点旋转
+ orientToPoint:inNode:offset:
//约束节点的方向范围
+ zRotation:
```

- 距离约束：  

```
//约束节点与另一节点保持一定距离
+ distance:toNode:
//约束节点与一个固定点保持一定距离
+ distance:toPoint:
//约束节点与另一个SKNode坐标系中的一个固定点保持一定距离
+ distance:toPoint:inNode:
```

向`SKNode`添加约束很简单，只需要将一个`SKConstrains`数组赋值给`SKNode.constraints`属性即可。约束执行的顺序取决于它们在数组中的顺序。  

###Inverse Kinematics

反向运动学，没有机械工程学位或没写过动画引擎的人干脆不知道这是个啥。它其实是解决连接体运动的，比如现在有一个机器人的手臂，我们想让它动起来去用手抓某个东西。我们会想到每个关节转多少度才能准确让机器手抓到物体，计算的时候还应该考虑连接体的层级关系：肩膀连接上臂，上臂连接小臂，小臂连接手。哦天啊这真蛋疼，不过SpriteKit的反向动力学解决了这一点，我们只需要指定每个`SKNode`的活动约束还有需要抓取物体的位置，那么这一切只需要几行代码就能搞定。  

![](http://7ni3rk.com1.z0.glb.clouddn.com/140741648388.gif)  

机器人手臂转动约束是靠`SKReachConstraints`类来定义的，它只有一个初始化方法：（伪代码）  

```
- initWithLowerAngleLimit:upperAngleLimit:
```

这个方法给`lowerAngleLimit`和`upperAngleLimit`属性赋值，约束了reach事件使其发生旋转角度的下限和上限。  

当一个`SKReachConstraints`创建好后，将其赋值给`SKNode`的`reachConstraints`属性，然后用`SKPhysicsJoint`将这些`SKNode`连接起来。使用`SKAction`的一套工厂方法创建来让连接体reach到活动目标或固定点的动作：（伪代码）    

```
+ reachTo:rootNode:duration:
+ reachTo:rootNode:velocity:
+ reachToNode:rootNode:duration:
+ reachToNode:rootNode:velocity:
```

让机器人的手部节点运行创建好的`SKAction`对象即可达到最初描述的动画效果。如果机器人的手触碰不到指定的位置或节点（gif中就是这样），`SKAction`会执行动画让其尽可能接近目的地。

PS：IK（Inverse Kinematics）也能在SceneKit上运行。  

###Physics Fields

在一个模拟宇宙空间的游戏中，星球对其他物体的引力是不可忽视的，这就涉及到物理场。SpriteKit为我们提供了一个专门描述物理场的类`SKFieldNode`，它继承于`SKNode`，也就是说它可以被添加到其他节点中。它能够描述多种场：电场、磁场、矢量重力场、辐射重力场、噪声场等十余种场。`SKFieldNode`的`strength`和`falloff`属性决定了场的强度和衰减比率。  

`SKFieldNode`还有一些属性决定了游戏中哪些物理体会被场影响：  

- **`region`** 描述了场的影响区域，类型是`SKRegion`。`SKRegion`可以是无限区域，矩形、圆形、`CGPath`多边形区域，还可以用两个`SKRegion`做逻辑运算得出新的`SKRegion`，比如交集，并集，差集，还可对一个`SKRegion`取反得到剩下的区域。  
- **`minimumRadius`** 一些场对物体的影响程度跟距离有关，当物体与场的距离小于`minimumRadius`属性的值时，仍被当做`minimumRadius`的值进行处理计算。`minimumRadius`的默认值很小很小，但不是0
- **`categoryBitMask`** 场的类别。当一个节点进入了场的影响区域，会根据节点的物理体属性的`fieldBitMask`属性来判断此节点是否收到场的影响。此外`SKPhysicsBody`的`charge`属性还会标记物理体所带的电荷量，这在跟电磁有关的场中会影响到物理体的运动。默认为 0xFFFFFFFF
- **`enabled`** 场的“开关”
- **`exclusive`** 唯我独尊，这个场的地盘内，别的场的影响被无视。别让两个唯我独尊的场影响区域重叠，那样会出乱子的。默认为`NO`。

我用SpriteKit的力场中的噪声场和辐射重力场做了一个小游戏[ColorAtom](http://coloratom.yulingtianxia.com)，有兴趣的可以去看看。应用了很多粒子系统和碰撞检测知识，把SpriteKit之前的内容能加的都加进去了，欢迎指正。    

##Integration with SceneKit

在SpriteKit这样的2D游戏引擎中也可以引入3D的内容，可以将SceneKit中的3D物体当做SpriteKit中的`SKNode`来操作，为了达到这一目的SpriteKit这次增加了`SK3DNode`类作为3D物体到SpriteKit中的桥接。  

通过`SK3DNode`的`scnScene`属性可以获取到`SCNScene`，因为`SK3DNode`把3D场景渲染成2D贴图，所以创建`SK3DNode`对象的时候需要传入一个渲染后贴图的尺寸`viewportSize`。`pointOfView`属性存储了游戏视角的位置，你可以尝试实现个上帝视角。  

由于我也不太了解“新”出的SceneKit，所以这部分不过多介绍了。  

##Tools

Xcode6增加了SpriteKit编辑器，一行代码都不用写就能创建出个游戏场景。这样你就将游戏内容从游戏逻辑冲分离出来。我们只需要将控件拖拽到游戏场景你想要的位置上，而不必每次调整一个飞船的位置，编译运行看看结果，然后再改代码微调位置再次编译运行。。。  

SpriteKit编辑器不仅有编辑功能，也可用来debug。你可以再运行过程中将当前状态存储在一个sks文件中。  

SpriteKit编辑器强大到你可以直接拖拽出一个SKSpriteNode并定义它的物理体，甚至使用Per-Pixel Physics。还可以编辑光照和阴影，编辑Shader并调整Uniforms，建立一个Inverse Kinematics并预览其效果，强大极了。  

其实说白了SpriteKit编辑器就像IB一样可以可视化编辑属性，并课即时预览效果，整个过程不需一行代码。  

Xcode能编辑fsh文件，与SpriteKit场景编辑器对照编辑，并做语法检查和编译。

##Improvements

###SKScene

SpriteKit每一帧场景的执行过程：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/update_loop_2x.png)  

除了之前提到新加的Constrains，SpriteKit这次还加入了一个回调函数`didFinishUpdate`。这绝对是SpriteKit将每帧所有东西打包好交给GPU渲染之前调用的最后一个函数。  

###SKTexture

- `SKMutableTexture`是`SKTexture`新加的子类，它的内容可以通过`
modifyPixelDataWithBlock:`方法动态地修改。  
- `SKTexture`现在可以生成“noise textures”，参见`textureVectorNoiseWithSmoothness:size:`和`
textureNoiseWithSmoothness:size:grayscale:`  
![](http://7ni3rk.com1.z0.glb.clouddn.com/14074923846.png)  

###SKShapeNode

- 增加了一些常见图形便捷的构造方法，比如矩形，圆形，椭圆和曲线。  
- 可以用贴图和Shader来美化形状的描边和填充

###Physics Updates

- `SKPhysicsBody`新加了`pinned`属性来标志此物理体对应的节点是否被钉在它的父节点上。如果父节点也有物理体，那么这两个物理体被认为被一个pin连接。如果将`allowsRotation`设为NO并且`pinned`设为YES，那么它相当于被焊在父节点上了，因为它不能转动了。  
- `SKPhysicsBody`允许用`bodyWithBodies:`把多个物理体组合在一起来创建一个新的物理体，还记得前面提到过的斧头么：  
	![](http://7ni3rk.com1.z0.glb.clouddn.com/140749497219.png)   
	
###SKTexture Atlas

- 同时支持SpriteKit和SceneKit
- 同时支持Retina和非Retina
- 同时支持16位和32位格式
- 支持4k x 4k 分辨率
- 支持运行时纹理图集的生成。比如从网上下载资源，SpriteKit会自动将透明的像素裁剪下去  

	



 
