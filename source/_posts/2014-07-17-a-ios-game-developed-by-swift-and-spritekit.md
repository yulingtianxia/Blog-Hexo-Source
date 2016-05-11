---
layout: post
title: "用Swift和SpriteKit开发iOS游戏"
date: 2014-07-17 12:54:13 +0800
comments: true
tags: 
- Swift
- SpriteKit
- iOS

---
之前用SpriteKit做过一个叫做[ColorAtom](http://coloratom.yulingtianxia.com)的小游戏，用了访问者模式处理碰撞检测，还用了SpriteKit中的粒子系统、连接体、力场和动画等，可以说是一个学习SpriteKit比较不错的Demo，随着Swift的火热，我也用Swift和SpriteKit写了一个更为简单的小游戏[Spiral](http://spiral.yulingtianxia.com)  

<!--more-->
附上Spiral的动图：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/140557437844.gif)  

游戏规则是：玩家是五角星小球，小球自动沿着陀螺线向外运动，当玩家点击屏幕时五角星小球会跳跃到内层螺旋，当五角星小球碰到红色旋风或滚动到螺旋线终点时游戏结束。玩家吃掉绿色旋风来得2分，吃到紫色三角得一分并获得保护罩，保护罩用来抵挡一次红色旋风。随着分数的增加游戏会升级，速度加快。游戏结束后可以截屏分享到社交网络，也可以选择重玩。    

以下是本文内容：  

1. 准备工作
2. 绘制基本界面
3. Swift中用访问者模式处理碰撞
4. 界面数据显示
5. 按钮的绘制和截图分享  


## 准备工作

SpriteKit是苹果iOS7新推出的2D游戏引擎，这里不再过多介绍。我们新建工程的时候选取iOS中的Game，然后选择SpriteKit作为游戏引擎，语言选择Swift，Xcode6会为我们自动创建一个游戏场景`GameScene`，它包含`GameScene.swift`和`GameScene.sks`两个文件，`sks`文件可以让我们可视化拖拽游戏控件到场景上，然后再代码中加载`sks`文件来完成场景的初始化：  

```js

extension SKNode {
    class func unarchiveFromFile(file : NSString) -> SKNode? {
        
        let path = NSBundle.mainBundle().pathForResource(file, ofType: "sks")
        
        var sceneData = NSData.dataWithContentsOfFile(path, options: .DataReadingMappedIfSafe, error: nil)
        var archiver = NSKeyedUnarchiver(forReadingWithData: sceneData)
        
        archiver.setClass(self.classForKeyedUnarchiver(), forClassName: "SKScene")
        let scene = archiver.decodeObjectForKey(NSKeyedArchiveRootObjectKey) as GameScene
        archiver.finishDecoding()
        return scene
    }
}
```

但我比较喜欢纯写代码的方式来搭接面，因为`sks`文件作为游戏场景布局还不成熟，它是iOS8新加入的功能，以前在iOS7的时候`sks`文件只是作为粒子系统的可视化编辑文件。  

所以我们修改`GameViewController.swift`文件的`viewDidLoad()`函数，像以前那样直接用代码加载游戏场景：  

```
override func viewDidLoad() {
        super.viewDidLoad()
        // Configure the view.
        let skView = self.view as SKView
        /* Sprite Kit applies additional optimizations to improve rendering performance */
        skView.ignoresSiblingOrder = true
        let scene = GameScene(size: skView.bounds.size)
        /* Set the scale mode to scale to fit the window */
        scene.scaleMode = .AspectFill
        skView.presentScene(scene)
        
    }
```

`GameScene`虽然是Xcode自动生成的，但是只是个空架子，我们需要把它生成的没用的代码删掉，比如初始化函数里内容为“HelloWorld”的`SKLabelNode`，还有`touchesBegan(touches: NSSet, withEvent event: UIEvent)`方法中绘制飞船的代码。把这些删光后，我们还需要有图片素材来绘制这四类精灵节点：`Player`（五角星），`Killer`（红色旋风），`Score`（绿色旋风）和`Shield`（紫色三角）。我是用Sketch来绘制这些矢量图形的，文件名为`spiral.sketch`，随同工程文件一同放到GitHub上了。当然你不需要手动导出图片到工程，直接下载工程文件就好了：  

[https://github.com/yulingtianxia/Spiral](https://github.com/yulingtianxia/Spiral)  

## 绘制基本界面

这部分的工作主要是绘制出螺旋线作为地图，并让四种精灵节点动起来。  

### 螺旋线的绘制

`SKNode`有一个子类`SKShapeNode`，专门用于绘制线条的，我们新建一个`Map`类，继承`SKShapeNode`。下面我们需要生成一个`CGPath`来赋值给`Map`的`path`属性： 

```
import UIKit
import SpriteKit
class Map: SKShapeNode {
    let spacing:CGFloat = 35
    var points:[CGPoint] = []
    convenience init(origin:CGPoint,layer:CGFloat){
        
        var x:CGFloat = origin.x
        var y:CGFloat = origin.y
        var path = CGPathCreateMutable()
        self.init()
        CGPathMoveToPoint(path, nil, x, y)
        points.append(CGPointMake(x, y))
        for index in 1..<layer{
            y-=spacing*(2*index-1)
            CGPathAddLineToPoint(path, nil , x, y)
            points.append(CGPointMake(x, y))
            x-=spacing*(2*index-1)
            CGPathAddLineToPoint(path, nil , x, y)
            points.append(CGPointMake(x, y))
            y+=spacing*2*index
            CGPathAddLineToPoint(path, nil , x, y)
            points.append(CGPointMake(x, y))
            x+=spacing*2*index
            CGPathAddLineToPoint(path, nil , x, y)
            points.append(CGPointMake(x, y))
        }
        self.path = path
        self.glowWidth = 1
        self.antialiased = true
        CGPathGetCurrentPoint(path)
    }
}
```

算法很简单，就是顺时针计算点坐标然后画线，这里把每一步的坐标都存入了`points`数组里，是为了以后计算其他数据时方便。因为这部分算法不难而且不是我们的重点，这里不过多介绍了。  

### 四种精灵的绘制

因为四种精灵都是沿着`Map`类的路径来顺时针运动，它们的动画绘制是相似的，所以我建立了一个`Shape`类作为基类来绘制动画，它继承于`SKSpriteKit`类，并拥有半径（`radius`）、移动速度（`moveSpeed`）和线段计数（`lineNum`）这三个属性。其中`lineNum`是用于标记精灵在螺旋线第几条线段上的，这样比较方便计算动画的参数。  

```
class Shape: SKSpriteNode {
    let radius:CGFloat = 10
    var moveSpeed:CGFloat = 50
    var lineNum = 0
    init(name:String,imageName:String){
        super.init(texture: SKTexture(imageNamed: imageName),color:SKColor.clearColor(), size: CGSizeMake(radius*2, radius*2))
        self.physicsBody = SKPhysicsBody(circleOfRadius: radius)
        self.physicsBody.usesPreciseCollisionDetection = true
        self.physicsBody.collisionBitMask = 0
        self.physicsBody.contactTestBitMask = playerCategory|killerCategory|scoreCategory
        moveSpeed += CGFloat(Data.speedScale) * self.moveSpeed
        self.name = name
        self.physicsBody.angularDamping = 0
        
    }
}
```

构造函数中设定了`Shape`类的一些物理参数，比如物理体的形状大小，碰撞检测掩码等。这里设定`usesPreciseCollisionDetection`为`true`是为了增加碰撞检测的精度，常用于体积小速度快的物体。`collisionBitMask`属性标记了需要模拟物理碰撞的类别，`contactTestBitMask`属性标记了需要检测到碰撞的类别。这里说的“类别”指的是物体的类别：  

```
let playerCategory:UInt32      =  0x1 << 0;
let killerCategory:UInt32      =  0x1 << 1;
let scoreCategory:UInt32       =  0x1 << 2;
let shieldCategory:UInt32      =  0x1 << 3;
```
这种用位运算来判断和存储物体类别的方式很常用，上面这段代码写在了`NodeCategories.swift`文件中。  

为了描述`Shape`的速度随着游戏等级上升而增加，这里速度的计算公式含有`Data.speedScale`作为参数，关于`Data`“类”在后面会讲到。  

为了让精灵动起来，需要知道动画的移动目的地是什么。虽然`SKAction`有`followPath(path: CGPath?, speed: CGFloat)`方法，但是在这里并不实用，因为`Player`会经常改变路线，所以我写了一个`runInMap(map:Map)`方法让精灵每次只移动到路径上的下一个节点（之前`Map`类存储的`points`属性用到了吧！嘿嘿）  

```
func runInMap(map:Map){
        let distance = calDistanceInMap(map)
        let duration = distance/moveSpeed
        let rotate = SKAction.rotateByAngle(distance/10, duration: duration)
        let move = SKAction.moveTo(map.points[lineNum+1], duration: duration)
        let group = SKAction.group([rotate,move])
        self.runAction(group, completion: {
            self.lineNum++
            if self.lineNum==map.points.count-1 {
                if self is Player{
                    Data.gameOver = true
                }
                if self is Killer{
                    self.removeFromParent()
                }
                if self is Score{
                    self.removeFromParent()
                }
                if self is Shield{
                    self.removeFromParent()
                }
            }
            else {
                self.runInMap(map)
            }
            })
    }
```

上面的代码先是调用`calDistanceInMap(map:Map)->CGFloat`方法计算精灵距离下一个节点的距离（也就是需要移动的距离），然后计算精灵需要旋转动画时间和移动动画时间，最后将两个动画作为一个`group`来运行，在动画运行结束后判断精灵是否运行到了最后一个节点，也就是螺旋线的终点：如果到终点了则移除精灵，否则开始递归调用方法，来开始下一段动画（奔向下一个节点）。  

计算距离的`calDistanceInMap(map:Map)->CGFloat`方法代码如下：  

```
func calDistanceInMap(map:Map)->CGFloat{
        if self.lineNum==map.points.count {
            return 0
        }
        switch lineNum%4{
        case 0:
            return position.y-map.points[lineNum+1].y
        case 1:
            return position.x-map.points[lineNum+1].x
        case 2:
            return map.points[lineNum+1].y-position.y
        case 3:
            return map.points[lineNum+1].x-position.x
        default:
            return 0
        }
    }
```

到此为止`Shape`类完成了，`Killer`、`Score`和`Shield`类比较简单，继承`Shape`类并设置自身纹理和类别即可：  

```
class Killer: Shape {
    convenience init() {
        self.init(name:"Killer",imageName:"killer")
        self.physicsBody.categoryBitMask = killerCategory
    }
}
class Score: Shape {
    convenience init() {
        self.init(name:"Score",imageName:"score")
        self.physicsBody.categoryBitMask = scoreCategory
    }
}
class Shield: Shape {
    convenience init() {
        self.init(name:"Shield",imageName:"shield")
        self.physicsBody.categoryBitMask = shieldCategory
    }
}
```

而`Player`因为有护盾状态并可以在螺旋线上跳跃到内层，所以稍微复杂些：  

```
class Player: Shape {
    var jump = false
    var shield:Bool = false {
    willSet{
        if newValue{
            self.texture = SKTexture(imageNamed: "player0")
        }
        else{
            self.texture = SKTexture(imageNamed: "player")
        }
    }
    }
    convenience init() {
        self.init(name:"Player",imageName:"player")
        self.physicsBody.categoryBitMask = playerCategory
        self.moveSpeed = 70
        self.lineNum = 3
    }
    func restart(map:Map) {
        self.alpha = 1
        self.removeAllActions()
        self.lineNum = 3
        self.moveSpeed = 70
        self.jump = false
        self.shield = false
        self.position = map.points[self.lineNum]
        self.runInMap(map)
    }
}
```

`Player`类的初始位置是螺旋线第四个节点，而且移动速度要略快于其他三种精灵，所以在这里设置为70（`Shape`默认速度50）。`jump`和`shield`是用来标记`Player`当前状态的属性，其中`shield`属性还定义了属性监察器，这是Swift中存储属性具有的响应机制，类似于`KVO`。在`shield`状态改变时也同时改变`Player`的纹理。**需要注意的是构造器中对属性的改变并不会调用属性检查器，在`willSet`和`didSet`中改变自身属性也不会调用属性检查器，因为那样会造成死循环。**  

`restart(map:Map)`方法用于在游戏重新开始时重置`Player`的相关数据。  

## Swift中用访问者模式处理碰撞

访问者模式是双分派（Double Dispatch）模式的一种实现，关于双分派模式的详细解释，参考我的另一篇文章：[Double Dispatch模式及其在iOS开发中实践](http://yulingtianxia.com/blog/2014/04/13/double-dispatchmo-shi-ji-qi-zai-ioskai-fa-zhong-shi-zhan/)，里面包含了C++，Java和Objective-C的实现，这次我们用Swift实现访问者模式。  

因为SpriteKit中物理碰撞检测到的都是`SKPhysicsBody`，所以我们的被访问者需要包含一个`SKPhysicsBody`对象：  

```
class VisitablePhysicsBody{
    let body:SKPhysicsBody
    init(body:SKPhysicsBody){
        self.body = body
    }
    func acceptVisitor(visitor:ContactVisitor){
        visitor.visitBody(body)
    }
}
```

`acceptVisitor`方法传入的是一个`ContactVisitor`类，它是访问者的基类（也相当于接口），访问者的`visitBody(body:SKPhysicsBody)`方法会根据传入的`body`实例来推断出被访问者的真实类别，然后调用对应的方法来处理碰撞：  

```
func visitBody(body:SKPhysicsBody){
        //第二次dispatch，通过构造方法名来执行对应方法
        // 生成方法名，比如"visitPlayer"
        var contactSelectorString = "visit" + body.node.name + ":"
        let selector = NSSelectorFromString(contactSelectorString)
        if self.respondsToSelector(selector){
            dispatch_after(0, dispatch_get_main_queue(), {
                NSThread.detachNewThreadSelector(selector, toTarget:self, withObject: body)
                })
        }
        
    }
```

Swift废弃了`performSelector`方法，所以这里耍了个小聪明来将消息传给具体的访问者。有关Swift中替代`performSelector`的方案，参见[这里](http://www.cnblogs.com/yangzhou1030/p/3830592.html)  

下面让`GameScene`实现`SKPhysicsContactDelegate`协议：  

```
func didBeginContact(contact:SKPhysicsContact){
        //A->B
        let visitorA = ContactVisitor.contactVisitorWithBody(contact.bodyA, forContact: contact)
        let visitableBodyB = VisitablePhysicsBody(body: contact.bodyB)
        visitableBodyB.acceptVisitor(visitorA)
        //B->A
        let visitorB = ContactVisitor.contactVisitorWithBody(contact.bodyB, forContact: contact)
        let visitableBodyA = VisitablePhysicsBody(body: contact.bodyA)
        visitableBodyA.acceptVisitor(visitorB)
    }
```
跟Objective-C中实现访问者模式类似，也是通过`ContactVisitor`类的工厂方法返回一个对应的子类实例来作为访问者，然后实例化一个被访问者，被访问者接受访问者的访问。A访问B和B访问A在大多数场合是相同的，但是你不知道谁是A谁是B，所以需要两种情况都调用。下面是`ContactVisitor`类的工厂方法和构造器：  

```
class ContactVisitor:NSObject{
    let body:SKPhysicsBody!
    let contact:SKPhysicsContact!
    class func contactVisitorWithBody(body:SKPhysicsBody,forContact contact:SKPhysicsContact)->ContactVisitor!{
        //第一次dispatch，通过node类别返回对应的实例
        if 0 != body.categoryBitMask&playerCategory {
            return PlayerContactVisitor(body: body, forContact: contact)
        }
        if 0 != body.categoryBitMask&killerCategory {
            return KillerContactVisitor(body: body, forContact: contact)
        }
        if 0 != body.categoryBitMask&scoreCategory {
            return ScoreContactVisitor(body: body, forContact: contact)
        }
        if 0 != body.categoryBitMask&shieldCategory {
            return ShieldContactVisitor(body: body, forContact: contact)
        }
        return nil
        
    }
    init(body:SKPhysicsBody, forContact contact:SKPhysicsContact){
        self.body = body
        self.contact = contact
        super.init()
        
    }
}
```

PS：上面的代码省略了已经提到过的`visitBody(body:SKPhysicsBody)`方法

因为这个游戏逻辑比较简单，所有碰撞后的逻辑都写到了`PlayerContactVisitor`类里：  

```
func visitKiller(body:SKPhysicsBody){
        let thisNode = self.body.node as Player
        let otherNode = body.node
//        println(thisNode.name+"->"+otherNode.name)
        if thisNode.shield {
            otherNode.removeFromParent()
            thisNode.shield = false
        }
        else {
            Data.gameOver = true
        }
    }
    func visitScore(body:SKPhysicsBody){
        let thisNode = self.body.node
        let otherNode = body.node
//        println(thisNode.name+"->"+otherNode.name)
        otherNode.removeFromParent()
        Data.score += 2
    }
    func visitShield(body:SKPhysicsBody){
        let thisNode = self.body.node as Player
        let otherNode = body.node
        otherNode.removeFromParent()
        thisNode.shield = true
        Data.score++
        //        println(thisNode.name+"->"+otherNode.name)
    }
```

上面的方法都是“visit+类名”格式的，处理的是`Player`碰撞到其他三种精灵的逻辑。而其他三种精灵之间的碰撞不需要处理，所以`KillerContactVisitor`、`ScoreContactVisitor`和`ShieldContactVisitor`这三个`ContactVisitor`的子类很空旷，这里不再赘述。  

我们设置`Player`碰撞到`Killer`游戏结束，碰撞到`Score`加两分，碰撞到`Shield`加一分并获得护甲（shield属性设为true）。可以看到这里大量用到了`Data`“类“”，它其实是一个存储并管理全局数据的结构体，它里面存储了一些静态的成员属性，也可看做非线程安全的单例。    

## 界面数据显示

这部分很简单，主要是将`Data`结构体中存储的分数和等级等数据通过`SKLabelNode`显示在界面上，只不过我封装了一个`Display`类来将所有的`SKLabelNode`统一管理，并让其实现我定义的`DisplayData`协议来让`Data`中的数据变化驱动界面更新：  

```
protocol DisplayData{
    func updateData()
    func levelUp()
    func gameOver()
    func restart()
}
```

下面是Data结构体代码，大量使用了存储属性的监察器来响应数据变化：  

```
struct Data{
    static var display:DisplayData?
    static var updateScore:Int = 5
    static var score:Int = 0{
    willSet{
        if newValue>=updateScore{
            updateScore+=5 * ++level
        }
    }
    didSet{
        display?.updateData()
    }
    }
    static var highScore:Int = 0
    static var gameOver:Bool = false {
    willSet{
        if newValue {
            let standardDefaults = NSUserDefaults.standardUserDefaults()
            Data.highScore = standardDefaults.integerForKey("highscore")
            if Data.highScore < Data.score {
                Data.highScore = Data.score
                standardDefaults.setInteger(Data.score, forKey: "highscore")
                standardDefaults.synchronize()
            }
            display?.gameOver()
        }
        else {
            display?.restart()
        }
    }
    didSet{
        
    }
    }
    static var level:Int = 1{
    willSet{
        speedScale = Float(newValue)*0.1
        if newValue != 1{
            display?.levelUp()
        }
    }
    didSet{
        display?.updateData()
        
    }
    }
    static var speedScale:Float = 0{
    willSet{
        
    }
    didSet{
        
    }
    }
    
    static func restart(){
        Data.updateScore = 5
        Data.score = 0
        Data.level = 1
        Data.speedScale = 0
    }
}
```

这里不得不提到一个更新界面时遇到的一个坑，当我想通过名字遍历`GameScene`子节点的时候，一般会用到`enumerateChildNodesWithName(name: String?, usingBlock: ((SKNode!, UnsafePointer<ObjCBool>) -> Void)?)`方法，但是这个方法在Xcode6Beta3更新后经常会抛异常强退，这让我很费解，恰巧遇到此问题的不只是我一个人，所以还是老老实实的自己写循环遍历加判断吧。  

## 按钮的绘制和截图分享

参考我的另外两篇文章：[在游戏的SKScene中添加Button](http://yulingtianxia.com/blog/2014/04/27/zai-you-xi-de-skscenezhong-tian-jia-button/)和[SpriteKit截屏并分享至社交网络](http://yulingtianxia.com/blog/2014/04/22/spritekitjie-ping-bing-fen-xiang-zhi-she-jiao-wang-luo/)  

在本工程中只有`ShareButton`和`ReplayButton`两个按钮，Swift版本的代码很简洁，而我通过`Social.Framework`中的`UIActivityViewController`来分享得分，这部分代码写在了`ShareButton.swift`中：  

```
let scene = self.scene as GameScene
let image = scene.imageFromNode(scene)
let text = "我在Spiral游戏中得了\(Data.score)分，快来追逐我的步伐吧！"
let activityItems = [image,text]
let activityController = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
(scene.view.nextResponder() as UIViewController).presentViewController(activityController, animated: true, completion: nil)
```


