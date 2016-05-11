title: SpriteKit在iOS9和OSX10.11中的新特性
date: 2015-06-12 16:21:30
tags:
- SpriteKit

---
这是一篇 WWDC2015 Session 604 的学习笔记,在看 WWDC2014 的 Session 时也总结过一篇[SpriteKit在iOS8和OSX10.10中的新特性](http://yulingtianxia.com/blog/2014/08/08/spritekitzai-ios8he-osx10-dot-10zhong-de-xin-te-xing/),从 iOS7 发布 SpriteKit 以来我一直利用课余时间做些小游戏,感受着 SpriteKit 的一路成长.这次也在第一时间总结了下 今年 WWDC SpriteKit 的新特性.  
<!--more-->
## Viewport 和 SKCameraNode

![viewport](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-1@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

Viewport(视口) 指的是当前场景中哪些部分是可见的.也就是说场景很大时,我们要计算哪块区域是要呈现给玩家的,这块区域是可以移动的.就像是摄像头跟着玩家在一张大地图中跑一样,这些工作现在可以交给 SpriteKit 了, `SKCameraNode` 就是干这个的.有了它就能确定哪些部分是可见的.它相当于viewport的中心,所以我们可以移动场景的摄像头,而不用像以前那样移动整个场景. SpriteKit 终于也能像其他游戏框架一样移动摄像头啦!`SKScene` 中有个 `camera` 属性,类型就是 `SKCameraNode`.所以我们可以给场景任意一个选择合适的摄像头.更令人欣喜的是 `SKCameraNode` 也是个 `SKNode`,所以我们可以给摄像头加上动作,约束,旋转和缩放.(这里自行脑补长镜头,视角跟踪,天旋地转,鼠标滚轮)  

![SKCameraNode](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-2@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

其实现原理大致是将`SKCameraNode`的 `xScale`, `yScale`, 和 `zRotation` 对场景所有节点做逆运算.并且只渲染 viewport 的那部分场景.  

其实摄像头早就该加了,这是专业的游戏框架不可或缺的元素.  

## SKAudioNode
![SKAudioNode](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-3@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

`SKAudioNode` 的加入更是令人激动.我们可以在游戏场景中的某个位置加入声源,让玩家身临其境.此前无论你的音效再怎么狂拽屌炸天,都只能是背景音乐的效果.这次终于能发挥下我们的双耳效应了.想象下在游戏中一辆 F1 赛车从你身边飚过的声音.然而这本身就是游戏框架的标配, SpriteKit 这次只是努力追赶而已.  

## 引用与实例化

![引用与实例化](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-6@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

简单来说就是将动作和节点封装成实例,这样可以在其他地方引用它们,以达到组件重用的效果.  

### SKReferenceNode

![SKReferenceNode](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-4@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

`SKReferenceNode` 使我们能重复利用`SKNode`.在 Xcode7 场景编辑器中直接将想要重用的 sks文件拖拽到场景中, Xcode7 会自动为我们创建 `SKReferenceNode`.我们也可以在代码中使用 URL 或文件名手动创建一个 `SKReferenceNode` 对象.因为这里是引用, Xcode7 会从 Bundle 中加载最新版本的文件.  

而在 Xcode6 的场景编辑器中, sks 文件会把它使用的素材都拷贝一份,当我想更改Images.xcassets中素材的名字或内容的时候, sks 文件中的素材并没有发生变化.一开始我很想抓狂,直达后来我找到了修复的方法:在 Finder 中找到 sks 文件,将其拖拽到工程外面的目录并打开,这里最好多打开关闭几次,然后再将其拖拽回原来在项目工程中的位置,然后回到 Xcode6 中查看是否成功.如果这样还不行,就在Xcode6 中删掉 sks 文件并重新导入试试.    

不得不吐槽下之前的场景编辑器,竟然不能重复使用一些组件,甚至不能引用我做的粒子效果 sks 文件到场景中.但这本来应该是一个游戏场景编辑器本该有的功能啊!  

### Named SKActions

![Named SKActions](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-5@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

嗯动作(Action)也能以文件的方式共享了.我们可以创建一个sks 文件用于保存自定义动作. Xcode7 为我们提供了一些基本动作对象,可以拖拽到编辑器中:  

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-7@2x.png)  

我们可以用下面这些 `SKAction` 新加入的 API 来从 sks 文件中加载自定义动作:  

```
actionNamed:
actionNamed:duration:
actionNamed:fromURL:
actionNamed:fromURL:duration:
```

此外,这回 `SKAction` 还增添了一些新动作:  

```
play //用于 `SKAudioNode` 的播放
pause //用于 `SKAudioNode` 的暂停
changePlaybackRateTo:duration: //调节 `SKAudioNode` 的播放速率
changeVolumeTo:duration: //调节 `SKAudioNode` 的播放音量
animateWithNormalTextures: //使 `SKSpriteNode` 的法线贴图按照给定贴图数组的顺序动起来
```

在之前的动作中只提供了贴图切换的动作,而没有法线贴图切换的动作,这就让光照效果只能应用在贴图固定的`SKSpriteNode`中.这回我们可以让法线贴图和跟着动起来了!    

## 优化

![Metal](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-8@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

苹果总不会忘记夸赞自己在底层优化所作出的努力. SpriteKit 会自动使用 Metal 技术,将其 CPU 使用率降低,性能更赞之类的. 最关键的是这些事苹果已经帮你做好了,程序员们微笑接受.因为这种优化不需要我们重新编译项目,就能在支持 Metal 的设备上自动使用它.  

受益于 Swift 类型安全的提升, Objective-C 泛型的加入,还有对 nullability 的改进, SpriteKit 的 API 也跟着做出了一系列优化调整.无论是使用 Swift 还是 Objective-C, 我们都能玩转 SpriteKit.  

## SceneKit

SpriteKit 和 SceneKit 这对儿难兄难弟虽然一直不受游戏开发者的宠爱,但它们总是喜欢相互搞基.可以在 SceneKit 中渲染 SpriteKit 的内容,反之亦然.今年搞基的方式又多了:  

1. 可以在 SceneKit 中使用 `SKTransition` 进行转场,各种转场效果随你挑.
2. SceneKit 也支持 Metal 了,可以一起躺在 Metal 上面搞基了.
3. 要么都在 Metal 上搞基,要么都在 OpenGL 上开搞,自动匹配相同的"大床".

## GameplayKit

![GameplayKit](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-9@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

GameplayKit 是个新推出的框架,它能帮我们构建一些游戏中的逻辑,比如状态机, AI 和路径查找.我本已经迫不及待地想使用它了,可惜在 iOS9 beta 中我用 SpriteKit 写的游戏卡顿严重,我想还是再等等吧.

## SpriteKit工具

### Texture atlas

如果你有游戏编程的经验，那么你一定对图片拼合的概念很熟悉，图片能够在屏幕上独立地变更位置。图片拼合后可以打包整合到一张大图上一次性载入。相比多次载入不同的图片，这样做能够带来很多方面的好处：内存使用，载入时间，渲染性能等等.

2D游戏引擎如Cocos2D使用了拼合技术，它使用OpenGL来显示图片。  

但有了 Xcode ,我们将多个图片加入图册中就可以了,无需自己手动创建一张大的贴图,并计算其中每部分的边界.这的确很省事,还记得游戏设计概论课的实验上,我们的游戏素材都需要手动将人物的好几部分拼合到一张大图上,当人物奔跑时就在大图上切换edge并读取. 做过游戏的人都体会过这一点,现在 Xcode 帮我们做了.这项功能之前就有了,今年拿出来忽悠一遍只是因为他们做得更好了.  

### Texture atlas in Asset Catalog

![Texture atlas in Asset Catalog](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-10@2x.png)  

好处都有啥:
- 可以直接在界面上操作来区分不同设备不同分辨率的图片.
- 通过 App thinning 来使游戏体积更小.因为用户从 AppStore 下载游戏时,只会下载他们设备所对应的图片.节省时间和空间.

### Texture atlas with On Demand Resources

![Texture atlas with On Demand Resources](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-11@2x.png)  

On Demand Resources 之前的 Session 提到过,它是属于 App thinning 中的一部分.通过给图片打上 On Demand Resources 标签,并可以通过网络在后台下载对应标签的图片.比如在游戏中快要进入到第一关,可以在后台使用"Level1"标签获取对应的那些图片.这样游戏的体积也会大大缩小,因为很多图片只是在即将用到的时候被下载下来.一个图片有多个标签时,只需要使用其中任一个标签就可以将其下载.  

### 粒子编辑器

又是老把戏重新炫耀,可以在界面上实时修改参数(据说49个呢)来观察效果,无需写代码无需重新编译,嗯.  

### Xcode Quicklook

继续扯老把戏,比如在 Playground 里面能显示 SpriteKit 程序的效果图.这早就可以了好么?去年还拿这个做例子呢!气球那个!还有在 debug 时显示节点当前的缩略图,我记得这个去年也早就有了:  

![Quicklook](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-12@2x.png)  

### 2D 编辑器

新的编辑器可以模拟和预览场景了,会动了.之前 Xcode6 已经支持编辑粒子效果和整个游戏场景,今年 Xcode7 还加入了动画和动作效果.想想一行代码都不用写就能做出会动的场景,越来越靠近 Unity 等专业的游戏平台框架了.(凭我的经验肯定这肯定会让 Mac 煎鸡蛋,因为在之前仅是静态场景下模拟光照就已经发热有些严重了,更别提模拟物理计算让场景内容动起来了)  

### 新的附加部件

之前提到的 SKCameraNode, SKAudioNode 和 SKReferenceNode,Xcode7 都是给予激情支持的:

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-14@2x.png)  

这样我们就可以在 Xcode7 中预览时感受摄像头的移动缩放,感受声音由远及近身临其境,当然这在 Unity 中早就有了, SpriteKit 一直在努力追赶.  

让强迫症激动的是场景编辑器终于支持将 Node 设为自定义类了.这真是太赞了!  

### 动作编辑器

最让人激动的是我们可以在动作编辑器中像做视频一样基于时间线构建出复杂的交互动画!支持 2D 和 3D, 并能实时预览:  

![Action](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20150612-15@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

## 总结

老实说作为一个游戏引擎, SpriteKit 这次带来的新功能大部分依然是其他各大游戏引擎早就有的标配,但苹果最吸引人的地方就是它学得很快,每次总会给大家带来新的变化,会让它的粉丝们看到希望. SpriteKit 和 SceneKit 这两个苹果自家的游戏引擎一直不温不火,一是不够成熟,二是不能跨平台,但我相信苹果每年都会给它们带来更新更炫的功能,让开发者接受它们.  

这次没来得及做 Demo, 但等到 iOS9 稳定后,我肯定会继续在[ColorAtom](http://coloratom.yulingtianxia.com) 和 [Spiral](http://spiral.yulingtianxia.com) 上分别用 Objective-C 和 Swift 来写一些新的游戏模式作为 SpriteKit 新特性的演示 Demo.  

最后, Apple 给我们提供了一个 SpriteKit 和 GameplayKit 的 [Demo](https://developer.apple.com/library/prerelease/ios/samplecode/DemoBots/Introduction/Intro.html)