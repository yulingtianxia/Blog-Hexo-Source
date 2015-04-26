---
layout: post
title: "在游戏的SKScene中添加Button"
date: 2014-04-27 13:18:04 +0800
comments: true
tags: 
- SpriteKit
- iOS

---
偶然发现`SpriteKit`中的`SKNode`也有`userInteractionEnabled`属性，就像`UIKit`中的`userInteractionEnabled`一样，于是我对以前的代码进行重构，发现了在游戏中添加交互button的新的方式（估计很多大神们早就发现了）  
<!--more-->
##在SKScene中添加SKNode对象作为Button
不得不承认，我以前在`SKScene`中添加一个`Button`的过程是这样的：  

**添加一个`SKNode`（一般都是它的子类：`SKLabelNode`和`SKSpriteNode`）属性**  

``` objc
SKLabelNode *button = [SKLabelNode labelNodeWithFontNamed:@"Chalkduster"]; 
``` 

**设置其填充的内容和放置位置，还有`SKNode`的`name`**  

```
button.text = @"Click me";
button.name = @"button";
button.fontSize = 40;
button.fontColor = [SKColor purpleColor];
button.position = CGPointMake(self.size.width/2, self.size.height/2);
[self addChild:button]; 
```
	
**在`SKScene`重写`touchesEnded: withEvent: `方法，并在方法中判断触摸到哪个`SKNode`**  

``` 
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    UITouch * touch = [touches anyObject];
    CGPoint location = [touch locationInNode:self];
    SKSpriteNode *touchedNode = (SKSpriteNode *)[self nodeAtPoint:location];
    if ([touchedNode.name isEqualToString:@"button"]) {
        //TODO:
    }
}
``` 
如果某个场景中需要设置很多Button，比如游戏设置界面，那么在`touchesEnded: withEvent: `方法中就会出现好多if判断，这么多分支，每个分支可能还有很多操作，这样增加了SKScene的体积，使得代码可读性变差，维护也困难  
##通过继承来封装自己的Button
`UIKit`中的`userInteractionEnabled`大家一定都很熟悉，它默认值是`YES`，也就是默认接受触摸事件，偶然发现`SKNode`也有`userInteractionEnabled`属性，但是默认值是`NO`，而且`SKNode`是继承`UIResponder`的，这么说，我们可以在SKNode中一展拳脚了，不必再麻烦SKScene了  
下面添加一个用于跳转到主菜单场景页面的Button为例：  
**新建一个类，名字叫MainSceneButton，继承`SKLabelNode`，并构造出时候方法**  

``` 
-(id)init{
    if (self = [super initWithFontNamed:@"Chalkduster"]) {
        self.text = @"MENU";
        self.fontSize = 20;
        self.userInteractionEnabled = YES;
    }
    return self;
}

``` 
这里碰到一个问题：如果用上面的代码初始化，将会出现 `EXC_BAD_ACCESS` 错误，问题的解决方法是在超类初始化时用init方法代替，然后再设置字体：  

``` 
-(id)init{
    if (self = [super init]) {
        self.fontName = @"Chalkduster";
        self.text = @"MENU";
        self.fontSize = 20;
        self.userInteractionEnabled = YES;
    }
    return self;
}
``` 
至于原因，我也没弄清楚，估计是`SKLabelNode`的bug吧，因为初始化`SKSpriteNode`时用`initWithTexture: color: size:`方法就不会报错  
**在MainSceneButton中重写`touchesEnded: withEvent: `方法**  

``` 
-(void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event{
    SKTransition *reveal = [SKTransition flipHorizontalWithDuration:0.5];
    SKScene * myScene = [[MainScene alloc] initWithSize:self.scene.size];
    [self.scene.view presentScene:myScene transition: reveal];
}
``` 
MainScene是我的一个SKScene，通过点击MainSceneButton来切换到MainScene  
**最后在某个场景中将button添加上去，跟之前的类似**  

``` 
MainSceneButton *mainScene = [[MainSceneButton alloc] init];
mainScene.position = CGPointMake(self.size.width/2, self.size.height/2);
[self addChild:mainScene];
``` 
感觉这样做是不是很像以前继承一个UIView然后封装自己的Custom View呢？给SKScene瘦身的方法还有很多，参照给UIViewController瘦身的方法，我们还可以把其他SKNode也从SKScene中剥离出去，一些用于设置SKNode的方法也会随之剥离到自定义的类中，便于以后维护代码  



