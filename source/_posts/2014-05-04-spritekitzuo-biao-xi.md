---
layout: post
title: "SpriteKit坐标系"
date: 2014-05-04 19:36:26 +0800
comments: true
tags: 
- iOS
- SpriteKit

---
前一阵子在用SpriteKit写一个小游戏的时候，因为对坐标系系统不是很熟悉，结果耽误了不少时间，现在将这些SKNode(及其子类)中常用的部分记下来，以利于以后快速查找  

本文测试用到的工程代码可以在[这里](https://github.com/yulingtianxia/NodesCoordinates/tree/master)下载    

**一般来说，SpriteKit中所有坐标系都是x轴正方向向右，y轴正方向向上的，后面不再重复**  
<!--more-->

##SKScene
虽然是`SKNode`的子类的子类，但是因为所有`SKNode`都需要在场景上构建布局，所以比较重要，其原点在左下角，y轴向上，x轴向右；正是因为UIView的原点在左上角，y轴向下，x轴向右，所以在`SKScene`中判别手势坐标的时候需要将y轴反向：  

```objc
- (void)handlePanFrom:(UIPanGestureRecognizer *)recognizer {
	if (recognizer.state == UIGestureRecognizerStateBegan) {
        CGPoint touchLocation = [recognizer locationInView:recognizer.view];
        touchLocation = [self convertPointFromView:touchLocation];
        AtomNode *touchedNode = (AtomNode *)[self nodeAtPoint:touchLocation];
        if (isAllAtomStatic&&[touchedNode.name isEqualToString:AtomName]) {
            touchedAtom = touchedNode;
            isPanningAtom = YES;
        }
        
        
    } else if (recognizer.state == UIGestureRecognizerStateChanged) {
        
        CGPoint translation = [recognizer translationInView:recognizer.view];
        translation = CGPointMake(translation.x, -translation.y);
        if (isPanningAtom==YES) {
            touchedAtom.position = CGPointMake(touchedAtom.position.x+translation.x, touchedAtom.position.y+translation.y);
        }
        [recognizer setTranslation:CGPointZero inView:recognizer.view];
        
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        
        if (isPanningAtom==YES) {
            CGPoint velocity = [recognizer velocityInView:recognizer.view];
            touchedAtom.physicsBody.velocity =CGVectorMake(velocity.x, -velocity.y);
            isPanningAtom = NO;
        }
    }
}
```

在第一个判断分支中，因为用了`convertPointFromView`方法，已经将`CGPoint`从`UIView`坐标系转为`SKScene`坐标系，所以不用反转，其余两个分支中的代码均需要反转y轴。  

##SKNode  
SKNode的原点在正中央，也就是(0.5,0.5)  
我构建了一个App，分别将被测试的Node放置在场景中央，并用一个黑色的小圆圈代表Node的坐标系的原点  
因为SKNode比较抽象，没填充内容，所以只显示了一个原点：  

![](http://yulingtianxia.qiniudn.com/140353411185.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

如果想填充些东西来证明SKNode的坐标系原点的确在其中央，将下面代码注释部分取消注释即可：  

```
#import "NodeButton.h"

@implementation NodeButton
-(id)init{
    if (self = [super initWithName:@"SKNode"]) {
        SKNode *sknode = (SKNode *)self.node;
        SKSpriteNode *fill = [[SKSpriteNode alloc] init];
        fill.size = CGSizeMake(100, 100);
        fill.color = [UIColor redColor];
        fill.colorBlendFactor = 1;
//        [sknode addChild:fill];
    }
    return self;
}
@end
```

##SKEmitterNode  
粒子系统比较有趣，它从原点发射大量粒子，不同的粒子系统也会构筑不同的效果，因为它没有边界，还可调节发射粒子的数量方向速度等，这也使得原点在整个粒子系统中的位置有了错觉，但其本质还是(0.5,0.5)，也就是在中心  

![](http://yulingtianxia.qiniudn.com/140353410978.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

这个火苗看起来中心在哪呢？当然在圆圈处！因为粒子是从圆圈处的区域产生的，然后向上发射  

##SKLabelNode  
label比较特殊，可能是因为需要现实文字的关系吧，其坐标原点在中下方，但不是(0.5,0)，因为如果文字包含y，p之类的“带尾巴”的字符，那么将会突出十字线下方，可以理解为写英文用的四线本的第三条线？因为字号大小不同或者提子不同，也会影响到原点位置。

知道其原点精确位置对于编程来说意义不大，以后有时间会深究下    

![](http://yulingtianxia.qiniudn.com/140353410886.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

##SKShapeNode  
这个类也很特殊，因为其frame是根据path填充内容来确定的，而原点又是其在父坐标的position处，那么`SKShapeNode`的原点具体位置在哪也就没意义了，只要按照其position的位置当作原点建立坐标系就好  

```
@implementation ShapeButton
-(id)init{
    if (self = [super initWithName:@"SKShapeNode"]) {
        SKShapeNode *shape = (SKShapeNode *)self.node;
        shape.path = CGPathCreateWithRect(CGRectMake(-50,-50, 100, 100), NULL);
        shape.strokeColor = [UIColor redColor];

    }
    return self;
}
@end
```

下图是我故意画了个正方形使其居中：    

![](http://yulingtianxia.qiniudn.com/140353411872.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

##SKSpriteNode  
坐标原点在其frame中心，也就是(0.5,0.5)  

![](http://yulingtianxia.qiniudn.com/140353412174.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

##总结

其实之所以会出现坐标系原点位置一说，是因为不同类型的Node其frame大小也不一样，而其原点在其frame中的位置也不一样，这就给人一种错觉：有的Node原点在左下角，只暴漏给我们第一象限；有的Node原点在中间，其四个象限都被填充了。。。无论原点在哪，其x轴，y轴方向都是不变的，所以本质都是一样的，只是写代码的时候需要注意，比如如果觉得将一个`SKLabelNode`的position设置为屏幕中心，则其文字内容就会正好居中，其实那就错了，因为y轴并没有居中。  





