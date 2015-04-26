title: UIDynamics in Swift
date: 2015-03-01 14:46:51
tags:
- 翻译
- UIKit Dynamics
- Swift

---

本文翻译自[BigNerdRanch](http://www.bignerdranch.com/blog/uidynamics-in-swift/)，作者[Steve Sparks](http://www.bignerdranch.com/about-us/nerds/steve-sparks/)  
<!--more-->  


就像我们几乎所有的iOS开发者那样，我也玩了玩Swift。现在谈及它在我iOS开发任务中的作用还为时过早，因为它对于应用的生产环境的使用还有些不成熟。（WWDC一周过后，苹果就重新构造了数组的运作方式。那可是数组啊！）  

然而，在WWDC之前，我一直在使用UIDynamics，所以我踏上Swift的第一步便是尝试用这方面的知识，这似乎合乎逻辑。结论是，Swift中的UIDynamics跟在Objective-C中使用没啥差别。我们只需要将其套上Swift风格的养分，它会像我们预期的那样奏效。  

为了示范，我们匆匆拼凑了一个敏捷工程。使用Xcode 6，创建了一个新的Swift单视图工程。我称它是我的“[Rock Box](https://github.com/stevesparks/RockBox)”。  

![](http://www.bignerdranch.com/img/blog/2014/07/newproj.jpg)  

我们无需用到Storyboard，所以我们直接在`ViewController.swift`文件中加入下面的代码：  

```
var box : UIView?

func addBox(location: CGRect) {
   let newBox = UIView(frame: location)
   newBox.backgroundColor = UIColor.redColor()

   view.insertSubview(newBox, atIndex: 0)
   box = newBox
}
```

我们在`viewDidLoad()`中加上一行代码来调用它。  

```
override func viewDidLoad() {
   super.viewDidLoad()
   // Do any additional setup after loading the view, typically from a nib.
   addBox(CGRectMake(100, 100, 30, 30))
}
```

运行程序，会看到一个红色的箱子：  

![](http://www.bignerdranch.com/img/blog/2014/07/initial.png)  

它不动；啥都没动。那也太无聊了。我们设置它动起来吧。  

##魁首：UIDynamicAnimator
 
这出戏的魁首是`UIDynamicAnimator`。按照给出的一系列规则，animator在屏幕每次重绘时调整每个物体的位置。就其本身而言，animator根本不执行任何操作；它需要的规则被称为行为（behavior）。行为描述的事物类似于一个冲量，例如推一下，或重力那种持久的力。你也可以指定它们的摩擦力，弹力等等。animator不做任何对自己制定的规则；它只是魁首。我们在下一节将会声明它的一个实例。  

##最简单的行为：UIGravityBehavior
 
让我们从一个重力行为开始，结果便是我们的红色箱子掉落到屏幕底部。它是从概念上最容易理解的行为了；一个已知方向的拉力会在每个时钟周期向物体施加速度。我们打算施加垂直向下的重力。  

```
var animator:UIDynamicAnimator? = nil;
let gravity = UIGravityBehavior()

func createAnimatorStuff() {
   animator = UIDynamicAnimator(referenceView:self.view);
   animator?.addBehavior(collider)

   gravity.addItem(box);
   gravity.gravityDirection = CGVectorMake(0, 0.8)
   animator?.addBehavior(gravity);

}
```

重要的是注意`UIDynamicAnimator`后面标记的问号意思是变量可能为`nil`。事实上，我就在这里把它设为`nil`。原因有些微妙：  


- animator是在类中声明的，这意味着当view controller的`init`调用时必需对其进行赋值。
- `self.view` 必须在 `init` 之后调用。
- animator的构造器需要一个视图作为它的参照视图，而且这个值将会是`self.view`。

因为我们已经在这酿造了一个鸡生蛋的问题，我们不会允许此变量为`nil`，并且在`viewDidLoad()`期间将其设定好。这引入了一些波折，任何时间我们使用`animator`变量，都将发现我们不得不亲自确保在使用之前它的值不是`nil`。这在Swift中被处理成在`animator`后面用一个问号标记，比如`animator?.behaviors()`。我们将会讨论更多些这方面的内容。暂且让我们向`viewDidLoad`加点代码来调用我们的新方法...  

```
    addBox(CGRectMake(100, 100, 30, 30))
        createAnimatorStuff()
}
```

...编译运行。它看起来是这样的：  

![](http://www.bignerdranch.com/img/blog/2014/07/round1.gif)  

嗯，真有趣...就一会儿，它立刻跌出了底部。  

##反弹的墙壁：UICollisionBehavior

`UICollisionBehavior`关注担心物体是否会在它们的轨迹上碰撞，如果碰撞，它们怎么相互作用。除了让物体互相碰撞，它也推断边界，也就是类似物体边框的路径。（使用`let`）声明一个`UICollisionBehavior`常量，并把它添加到设置代码中：  

```
collider.addItem(box)
// 我们在反弹墙壁
collider.translatesReferenceBoundsIntoBoundary = true
animator?.addBehavior(collider)
```

运行，看看得到了什么？  

![](http://www.bignerdranch.com/img/blog/2014/07/round2.gif)  

更棒了！箱子掉落并停在“地板”上，甚至还有点弹性！  

我们稍微重构一下，我想要看到更多箱子。我们创建了一个函数用于找到随机边框但又不压在之前绘制的箱子上，还有另一个产生随机颜色的函数。我们一旦有了这些，就能在屏幕上随机创建十个箱子。其实要做的还有很多，所以直接查看[这个commit](https://github.com/stevesparks/RockBox/commit/97b87458b5911f880f30179ee0630f933b48bbf5)来看看都做了什么。感兴趣的细节是，调用` createAnimatorStuff()`时我们不再将箱子加到行为中，而是单独地调用`addBoxToBehaviors(box)`来添加箱子。  

现在我们有10个箱子并能相互碰撞！  

![](http://www.bignerdranch.com/img/blog/2014/07/round3.gif)  

但是它们做的还是不够好。我们为啥不将环境重力绑定到从加速计读取到的重力上呢？  

##Core Motion

iOS设备的加速计能做一堆巧活儿，这其中最常见的就是告诉我们重力向哪个方向牵引。[苹果关于 `UIAcceleration` 的文档](https://developer.apple.com/library/ios/documentation/UIKit/Reference/UIAcceleration_Class/index.html)在一开始就给出了一张示范坐标轴如何转化到设备上的图片：  

![](https://developer.apple.com/library/prerelease/ios/documentation/UIKit/Reference/UIAcceleration_Class/Art/device_axes.jpg)  

这些坐标轴相当于重力的方向...基本上。我已经发现Y轴貌似被翻转了。照此，当我将`CMAcceleration`值转化成`CGVector`时，我需要转换它的值。  

创建一个`CMMotionManager`使我们获得加速计的数据的入口。我们可以自己查询加速计数据，也可以要求管理者频繁地向我们发送更新。为了做到这点，我们创建一个`NSOperationQueue`，然后调用运动管理者的方法：  

```
motionManager.startDeviceMotionUpdatesToQueue(motionQueue,
                                 withHandler: gravityUpdated)
```

这应该放在`viewDidAppear`方法，在`viewWillDisappear`中我们应该调用相反的操作：  

```
motionManager.stopDeviceMotionUpdates()
```

当视图出现，系统开始定期调用`gravityUpdated`方法并传入新的加速计数据。让我们实现这个方法：  

```
func gravityUpdated(motion: CMDeviceMotion!, error: NSError!) {
   if (error != nil) {
       NSLog("\(error)")
   }

   let grav : CMAcceleration = motion.gravity;

   let x = CGFloat(grav.x);
   let y = CGFloat(grav.y);

   var v = CGVectorMake(x, y);
   gravity.gravityDirection = v;
}
```

让我们谈一谈感叹号。它跟我们声明`animator`用到的问号无关。问号表明“变量可能为空”，感叹号意思相反：“变量永远不为空”，但实际意义更深。  

当你声明一个`animator?`形式的变量时，它跟`animator`这样的变量是不一样的。你可以把它看做是一种`Optional`类型的对象，有可能包含`animator`也有可能不包含。所以问号和感叹号只对`Optional`起作用，对`animator`不起作用。问号在代码上意味着“如果不为空就继续”，像这样：  

```
animator?.addBehavior(collider)
```

你可以生成等效的代码：  

```
if let x = animator { x.addBehavior(collider) }
```

或者，你可以用感叹号来解析本质的值，取得`Optional`里面的东东并传递它的值来代替整个容器。在`gravityUpdated`的声明中，我们预示我们会收到解析好的值-它不会是`nil`。  

不管怎样，这的确很酷，但是没有考虑读取加速计时设备的朝向问题。结果就是如果你颠倒你的手机，它会翻转显示，但不是加速计数据，你的箱子会开始鬼畜。所以我们加了些代码来让数据视朝向情况而定。  

```
func gravityUpdated(motion: CMDeviceMotion!, error: NSError!) {
	if error {
	  NSLog("\(error)")
	}

	let grav : CMAcceleration = motion.gravity;

	let x = CGFloat(grav.x);
	let y = CGFloat(grav.y);
	var p = CGPointMake(x,y)

	// Have to correct for orientation.
	var orientation = UIApplication.sharedApplication().statusBarOrientation;

	if orientation == UIInterfaceOrientation.LandscapeLeft {
	  var t = p.x
	  p.x = 0 - p.y
	  p.y = t
	} else if orientation == UIInterfaceOrientation.LandscapeRight {
	  var t = p.x
	  p.x = p.y
	  p.y = 0 - t
	} else if orientation == UIInterfaceOrientation.PortraitUpsideDown {
	  p.x *= -1
	  p.y *= -1
	}

	var v = CGVectorMake(p.x, 0 - p.y);
	gravity.gravityDirection = v;
}
```

你注意的第一件事就是我们用`x`和`y`的值创建了一个`CGPoint`。使用`CGPoint`没有什么特别的原因，只是为了把数值放在一起。  

它看起来像什么？  

![](http://www.bignerdranch.com/img/blog/2014/07/round4.gif)  

太酷了！  

##其他的行为

我提交了两个commit将事情推进了一点：[其中一个](https://github.com/stevesparks/RockBox/commit/8752153e608e621193742582913e2e3aaba207c9)添加了`UIDynamicItemBehavior`，允许我们修改箱子的摩擦力和弹性。我让他们超弹(elasticity = 0.9, friction = 0.1)，于是重力演变成了箱子们狂躁弹跳似的疯狂演示。  

这说明了UIDynamics中的一个缺点。当箱子速度增长，最终它们达到一个速度使得箱子在上一帧还完全在视图内，下一帧完全在视图外。在这种情况`UICollisionBehavior`将不会触发，箱子将会消失。它仍然存在，并持续消耗计算资源，但它永远不会再次出现在视图内。（一种设想是箱子永远坠落，速度递增。）  

下一个[commit](https://github.com/stevesparks/RockBox/commit/ac1a838d2b4ef575f8581f1ff8c9e9433f8362a8)添加了一些`UIAttachmentBehaviors`使10个箱子变成一串箱子。它有点破坏了应用的可玩性，但我想让你看看这些物体是怎么相互连接起来的。  

---

译者注：最后一节是作者吐槽Swift经历的，因为Swift版本更新了，这节内容不是很重要所以没翻译。原作者代码风格不够Swift而且语法老旧，我提了个[PR](https://github.com/stevesparks/RockBox/pull/2)，将语法更新到最新的Swift 1.2。  
