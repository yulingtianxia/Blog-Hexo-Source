---
layout: post
title: "iOS刮刮卡的实现"
date: 2014-04-09 15:38:52 +0800
comments: true
tags: 
- iOS


---
##前言
去年在实习的期间，需要写一个类似刮刮乐的小功能，当时是从网上下载的demo，后来经过自己研读代码和debug后，终于整理出了一套比较easy的实现方法  
<!-- more-->
##正文
需要源码的可以在[这里](https://github.com/yulingtianxia/ImageMask)下载  
我用的是从网上下载的`ImageMaskView`类，这个类还调用了工具类`Matrix`以及`PointTransforms.h`,使用非ARC实现并且在`ImageMaskView`类中使用了Objective－C和C＋＋混编，废话不多说，介绍下具体搭建方法吧  
首先需要使用IB在你的工程的某个ViewController中加入一个UIImageView，任选一张图片赋予它image属性，并在Identity Inspector中将其类型设置成我们的自定义类`ImageMaskView`  
![QQ20140409-0@2x](http://yulingtianxia.qiniudn.com/140353390164.png)  
我选的是一个美女图片，这张图片将会作为一个Mask来遮挡住它“底下”的View（在这之前我已经在美女图片底下放置了一个UIImageView作为背景，当然你也可以根据你的需要自定义其他的背景） 
上素材！下面分别是我的背景图片和遮罩图片    
 ![QQ20140409-2@2x](http://yulingtianxia.qiniudn.com/140353391174.png)![QQ20140409-3@2x](http://yulingtianxia.qiniudn.com/140353391416.png)  
下面就是通过IB将ImageMaskView按住Ctrl拖拽到ViewController.h中作为一个新的属性，属性名自己起，并将其设置为strong类型  
![QQ20140409-1@2x](http://yulingtianxia.qiniudn.com/140353390318.png)  
然后在ViewController.m中重写viewDidLoad  

``` objc
@synthesize FengjieMask;//是的，它是个ImageMaskView类的对象，名字很古怪吧
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    FengjieMask.radius = 20;//设置画笔半径
    [FengjieMask beginInteraction];//初始化方法
    FengjieMask.imageMaskFilledDelegate = self;//将代理设置为当前的VC
}
``` 

这里需要特别说明的是，`radius`是刮刮卡刮奖的时候画笔的半径，`imageMaskFilledDelegate`是一个代理，协议类型为`ImageMaskFilledDelegate`，只声明了一个方法`- (void) imageMaskView:(ImageMaskView *)maskView clearPercentDidChanged:(float)clearPercent`，这个方法在刮刮卡被刮下的面积变化时被调用，下面让我们的VC实现这个协议，并实现这个方法  
先在VC头文件增加`<ImageMaskFilledDelegate>`  
``` 
@interface YXYViewController : UIViewController<ImageMaskFilledDelegate>
``` 
然后实现协议方法   
``` 
 #pragma mark ImageMaskFilledDelegate
- (void) imageMaskView:(ImageMaskView *)maskView clearPercentDidChanged:(float)clearPercent{
    if (clearPercent > 50) {
        [UIView animateWithDuration:2
                         animations:^{
                             FengjieMask.userInteractionEnabled = NO;
                             FengjieMask.alpha = 0;
                             http://yulingtianxia.qiniudn.com/FengjieMask.imageMaskFilledDelegate = nil;
                         }
                         completion:^(BOOL finished) {
                         }];
    }
}

```   
上面的代码先是做了个判断，当被涂刮的面积超过50%的时候，产生一个时长2秒的动画，让ImageMaskView渐渐变透明，传入的animations参数是个block块  
好的，现在可以运行啦，我的demo效果如下  
![QQ20140409-4@2x](http://yulingtianxia.qiniudn.com/140353391637.png)  
##后记
对iOS的Core Graphics不是很熟悉，还没有去深入看代码中的实现过程，不过修复了一个小bug：在UITouchPhaseBegan的时候刮开的圆形面积坐标错位了，并针对Retina和非Retina进行测试，效果都不错。以前用过其他的刮刮乐的代码，缺点是跟图片像素比之类的有关，显示效果很不好；但这个demo可以适配任意大小的Image而不用更改代码。

