---
layout: post
title: "SpriteKit截屏并分享至社交网络"
date: 2014-04-22 17:36:25 +0800
comments: true
tags: 
- SpriteKit
- iOS
- Social Framework

---
本文讲述在用`SpriteKit`制作iOS游戏的时候，如何让在用户在达到某种成就后分享自己的成就或分数，并附上一张游戏截屏，然后发到社交网络上  
<!--more-->
##SpriteKit截屏
传统的截屏方法是用UIView的layer来读取渲染上下文，生成图片  

```objc

UIGraphicsBeginImageContext(self.view.frame.size); //currentView 当前的view
[self.view.layer renderInContext:UIGraphicsGetCurrentContext()];
UIImage *viewImage = UIGraphicsGetImageFromCurrentImageContext();
UIGraphicsEndImageContext();
```

viewImage就是获取的截图，如果要将图片存入相册，只需在后面调用  

```
UIImageWriteToSavedPhotosAlbum(viewImage,nil,nil,nil);
```
而这一切都是基于`UIKit`的，在`SpriteKit`中，上面的方法是实效的，截屏的效果就是一张白色图片 
但在苹果的官方文档中，明确提到了`SKTexture`的作用，最后一条是说可以将节点树渲染成纹理，可以应用于对游戏截屏。苹果还告诉了我们`SKView`的一个方法：`textureFromNode:`，该方法将以node包含的内容渲染成一个纹理，但是如何将`SKTexture`转换为`UIView`呢？我在workoverflow的一个[提问](http://stackoverflow.com/questions/21061248/uiimage-from-sktexture)中找到了答案：  
###方法一：  

```
- (UIImage*) imageWithView:(UIView *)view
{
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);

    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];

    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    return img;
}


- (UIImage*) imageFromNode:(SKNode*)node
{
    SKTexture*      tex     = [self.scene.view textureFromNode:node];
    SKView*         view    = [[SKView alloc]initWithFrame:CGRectMake(0, 0, tex.size.width, tex.size.height)];
    SKScene*        scene   = [SKScene sceneWithSize:tex.size];
    SKSpriteNode*   sprite  = [SKSpriteNode spriteNodeWithTexture:tex];
    sprite.position = CGPointMake( CGRectGetMidX(view.frame), CGRectGetMidY(view.frame) );
    [scene addChild:sprite];
    [view presentScene:scene];

    return [self imageWithView:view];
}
```
1. get the SKTexture for your node using the current SKView
2. make another SKView that is just big enough for your texture
3. add a SKSpriteNode with the texture into your new scene, placing it in the middle
4. render the view into a graphics context

###方法二:
```
-(UIImage *)imageFromNode:(SKNode *)node {
    SKView *view = node.scene.view;
    CGFloat scale = [UIScreen mainScreen].scale;
    CGRect nodeFrame = [node calculateAccumulatedFrame];
    
    // render SKView into UIImage
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, YES, 0.0);
    [view drawViewHierarchyInRect:view.bounds afterScreenUpdates:YES];
    UIImage *sceneSnapshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    // crop to the requested node (making sure to flip the y-coordinate)
    CGFloat originY = sceneSnapshot.size.height*scale - nodeFrame.origin.y*scale - nodeFrame.size.height*scale;
    CGRect cropRect = CGRectMake(nodeFrame.origin.x * scale, originY, nodeFrame.size.width*scale, nodeFrame.size.height*scale);
    CGImageRef croppedSnapshot = CGImageCreateWithImageInRect(sceneSnapshot.CGImage, cropRect);
    UIImage *nodeSnapshot = [UIImage imageWithCGImage:croppedSnapshot];
    CGImageRelease(croppedSnapshot);
    
    return nodeSnapshot;
}
```
**以上两个方法亲测好使！**

##使用Social.Framework分享游戏战绩
因为比较懒不想在各种第三方社交网站申请APP注册然后使用SDK等，有点复杂，所以暂时用了苹果自带的Social.Framework  

首先推荐一个比较好的[Demo](https://github.com/yulingtianxia/ios6ShareDemo.git)，代码很容易读，容易上手  

首先到target，Build Phases->link binary with libraries，添加social.framework，然后在要使用这个framework的文件头添加`@import Social;`  

记得要到iphone或者simulator里设置好对应社交网络的账号，填上用户名密码登录上，不然找不到account，不能post。如果找不到新浪微博，把系统语言调到中文。如果没有预先设置好账号，social.framework在真机和simulator上表现会不同。  
###使用UIActivityViewController
```
//某个SKScene中添加的代码
		sharingImage = [self imageFromNode:self];//获取截屏图片
        NSArray *activityItems;
        if (sharingImage != nil) {
            activityItems = @[sharingText, sharingImage];
        } else {
            activityItems = @[sharingText];
        }
        
        UIActivityViewController *activityController =
        [[UIActivityViewController alloc] initWithActivityItems:activityItems
                                          applicationActivities:nil];
        
        [(UIViewController *)[self.view nextResponder] presentViewController:activityController
                           animated:YES completion:nil];
```

`[self.view nextResponder]`的作用是获取当前`SKScene`的`UIViewController`  

如果想系统的学一下`UIActivityViewController`，建立看看这篇翻译自[Mattt Thompson](http://nshipster.com/uiactivityviewcontroller/)的[博文](https://github.com/nixzhu/dev-blog/blob/master/2014-04-22-ui-activity-viewcontroller.md)  

###使用SLComposeViewController  
这个就相当于上面里介绍的单个分享service
目前支持的平台有以下这些：  

```
SOCIAL_EXTERN NSString *const SLServiceTypeTwitter NS_AVAILABLE(10_8, 6_0);
SOCIAL_EXTERN NSString *const SLServiceTypeFacebook NS_AVAILABLE(10_8, 6_0);
SOCIAL_EXTERN NSString *const SLServiceTypeSinaWeibo NS_AVAILABLE(10_8, 6_0);
SOCIAL_EXTERN NSString *const SLServiceTypeTencentWeibo NS_AVAILABLE(10_9, 7_0);
SOCIAL_EXTERN NSString *const SLServiceTypeLinkedIn NS_AVAILABLE(10_9, NA);
```
先声明一个`SLComposeViewController *slComposerSheet;`，然后在需要添加分享逻辑的地方加入下面代码：(依然以微博为例子)  

```
	[slComposerSheet setCompletionHandler:^(SLComposeViewControllerResult result) {
        NSLog(@"start completion block");
        NSString *output;
        switch (result) {
            case SLComposeViewControllerResultCancelled:
                output = @"Action Cancelled";
                break;
            case SLComposeViewControllerResultDone:
                output = @"Post Successfull";
                break;
            default:
                break;
        }
        if (result != SLComposeViewControllerResultCancelled)
        {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Weibo Message" message:output delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
            [alert show];
        }
    }];
    
    if([SLComposeViewController isAvailableForServiceType:SLServiceTypeSinaWeibo])
    {
        slComposerSheet = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeSinaWeibo];
        [slComposerSheet setInitialText:self.sharingText];
        [slComposerSheet addImage:self.sharingImage];
        [slComposerSheet addURL:[NSURL URLWithString:@"http://www.weibo.com/"]];
        [self presentViewController:slComposerSheet animated:YES completion:nil];
    }
```
这种方法我没试过，代码是照抄自前面提到的[Demo](https://github.com/yulingtianxia/ios6ShareDemo.git)里
