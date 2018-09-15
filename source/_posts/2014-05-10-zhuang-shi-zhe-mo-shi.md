---
layout: post
title: "装饰者模式"
date: 2014-05-10 09:47:05 +0800
comments: true
tags: 
- 设计模式
- Java
- Objective-C

---
装饰者模式动态地将责任附加到对象上。若要扩展功能，装饰者提供了比继承更有弹性的替代方案。  

![](http://yulingtianxia.com/resources/140353405846.png)  

<!--more-->

- 装饰者和被装饰对象有相同的超类型。
- 你可以用一个或多个装饰者包装一个对象。
- 既然装饰者和被装饰对象有相同的超类型，所以在任何需要原始对象（被包装的）的场合 ,可以用装饰过的对象代替它。
- **装饰者可以在所委托被装饰者的行为之前与/或之后，加上自己的行为，以达到特定的目的。**
- 对象可以在任何时候被装饰，所以可以在运行时动态地、不限量地用你喜欢的装饰者来装饰
对象。  

**类应该对扩展开放，对修改关闭。**  

## 用配置咖啡饮料做例子

比如，现在有一个饮料类（Beverage），向饮料中添加不同的配料（蒸奶（Steamed Milk）、豆浆（Soy）、
摩卡（Mocha，也就是巧克力风味）或覆盖奶泡），就会配制出很多种不同的种类的饮料，其价格也随着添加的配料而变化，饮料店需要计算价格，如果用具体子类继承饮料类并考虑到所有组合的话，将是一个“类爆炸”：  

![](http://yulingtianxia.com/resources/140353406269.png)  

更恶心的是，如果某种配料的价格有变化，就必须含有此配料相应的更改一些饮料子类的实现，记住：**类应该对扩展开放，对修改关闭。**   

应用装饰者模式，就像给对象穿衣服一样一层一层将拓展动态的添加上去，灵活多变有弹性  

![](http://yulingtianxia.com/resources/140353407109.png)  

下面用Java实现这个例子  

Beverage是一个抽象类，有两个方法：getDescrip-tion()及cost（）  
 
```java
public abstract class Beverage {
String description = "Unknown Beverage";
public String getDescription() {
return description;
}
public abstract double cost();
}
```
Beverage很简单。让我们也来实现Condiment（配料）抽象类，也就是装饰者类吧：  

```
public abstract class CondimentDecorator extends Beverage {
public abstract String getDescription();
}
```
必须让Condiment Decorator能够取代Beverage，所以将CondimentDecorator扩展自 Beverage 类  

现在，已经有了基类，让我们开始开始实现一些饮料吧！先从浓缩咖啡（Espresso）开始。别忘了，我们需要为具体的饮料设置描述，而且还必须实现cost()方法    

```
public class Espresso extends Beverage {
public Espresso() {
description = "Espresso";
}
public double cost() {
return 1.99;
}
}
```

其他几种具体的饮料就不写了  

如果你回头去看看装饰者模式的类图，将发现我们已经完成了抽象组件（Beverage），有了具体组件（HouseBlend），也有了抽象装饰者（CondimentDecorator）。现在，我们就来实现具体装饰者。先从摩卡下手：  

  

```
public class Mocha extends CondimentDecorator {
Beverage beverage;
public Mocha(Beverage beverage) {
this.beverage = beverage;
}
public String getDescription() {
return beverage.getDescription() + ", Mocha";
}
public double cost() {
return .20 + beverage.cost();
}
}
```

你会发现在装饰者类中，完成了描述和价格的效果添加，也就是完成了拓展  

其他几种配料代码就不写了  

下面进行测试：  

```
public class StarbuzzCoffee {
public static void main(String args[]) {
Beverage beverage = new Espresso();
System.out.println(beverage.getDescription()
+ " $" + beverage.cost());
Beverage beverage2 = new DarkRoast();
beverage2 = new Mocha(beverage2);
beverage2 = new Mocha(beverage2);
beverage2 = new Whip(beverage2);
System.out.println(beverage2.getDescription()
+ " $" + beverage2.cost());
Beverage beverage3 = new HouseBlend();
beverage3 = new Soy(beverage3);
beverage3 = new Mocha(beverage3);
beverage3 = new Whip(beverage3);
System.out.println(beverage3.getDescription()
+ " $" + beverage3.cost());
}
}
```

输出结果： 

```
% java StarbuzzCoffee  
Espresso $1.99  
Dark Roast Coffee, Mocha, Mocha, Whip $1.49  
House Blend Coffee, Soy, Mocha, Whip $1.34  
%

```
果然是一层套一层吧：  

![](http://yulingtianxia.com/resources/140353407345.png)  

## Java中的装饰者

java.io包内的类太多了，简直是……“排山倒海”。你第一次（还有第二次和第三次）看到这些API发出“哇”的惊叹时，放心，你不是唯一受到惊吓的人。现在，你已经知道装饰者模式，这些I/O的相关类对你来说应该更有意义了，因为其中许多类都是装饰者。下面是一个典型的对象集合，用装饰者来将功能结合起来，以读取文件数据：  

![](http://yulingtianxia.com/resources/140353408228.png)  

`BufferedInputStream`及`LineNumberInputStream`都扩展自`FilterInputStream`，而`FilterInputStream`是一个抽象的装饰类。  

![](http://yulingtianxia.com/resources/140353408237.png)  

你会发现“输出”流的设计方式也是一样的。你可能还会发现Reader/Writer流（作为基于字符数据的输入输出）和输入流/输出流的类相当类似（虽然有一些小差异和不一致之处，但是相当雷同，所以你应该可以了解这些类）。  

但是JavaAI/O也引出装饰者模式的一个“缺点”：利用装饰者模式，常常造成设计中有大量的小类，数量实在太多，可能会造成使用此API程序员的困扰。但是，现在你已经了解了装饰者的工作原理，以后当使用别人的大量装饰的API时，就可以很容易地辨别出他们的装饰者类是如何组织的，以方便用包装方式取得想要的行为。  


## Objective-C类别与装饰模式  

Objective-C中也可以实现基于继承和接口的装饰者模式，但这里介绍的是另一种实现方法：类别  

类别是一个Objective-C的语言功能，通过它可以向类添加行为（方法的接口与实现），而不必进行子类化。通过类别添加的方法对类原有的方法没有不良影响。类别中的方法成为了类的一部分，并可由其子类继承。  

我们可以用类别来实现装饰模式，然而这不是一种严格的实现，它实现了模式的意图，但却是一种变体。由装饰器类别添加的行为是编译时绑定的，虽然Objective-C原本支持动态绑定（应该用方法的哪个实现）。而且装饰器类别实际上没有封装被扩展的类的实例。  


尽管使用类别来实现这个模式跟原始风格有些偏离，但是实现少量的装饰器的时候，它比真正子类的方式更为轻量、更为容易。

这次我们来装饰一张照片，装饰的方法有很多，比如旋转位移变换，阴影。。。  

![](http://yulingtianxia.com/resources/140353408757.png)  

工程代码可以在[这里](https://github.com/yulingtianxia/Decorator)下载  

这一方式中有三个类别：UIImage(BaseFilter),UIImage(Transform)和UIImage(Shadow)。从现在起，我把它们分别简称为BaseFilter、Transform和Shadow。BaseFilter定义了几个基本的二维绘图操作，使用当前绘图上下文绘制自己，其他滤镜类别可以使用同样的方法来绘制图像。Transform和Shadow没有继承BaseFilter，但他们属于同一类，因为他们都是UIImage的类别。BaseFilter中定义的方法也能在Transform和Shadow类别中使用，而不必像子类化那样进行继承。  

UIImage(BaseFilter)中的方法定义，用户绘制图像，相当于装饰者抽象类，而UIImage则是被装饰的组件:  


```objc
#import "UIImage+BaseFilter.h"

@implementation UIImage (BaseFilter)
- (CGContextRef) beginContext
{
    
    CGSize size = [self size];
    UIGraphicsBeginImageContextWithOptions(size, NO, 0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    return context;
}

- (UIImage *) getImageFromCurrentImageContext
{
    [self drawAtPoint:CGPointZero];
    
    // Retrieve the UIImage from the current context
    UIImage *imageOut = UIGraphicsGetImageFromCurrentImageContext();
    
    return imageOut;
}

- (void) endContext
{
    UIGraphicsEndImageContext();
}
@end
```

Transform类别定义了一个`imageWithTransform:transform`方法，接受一个转换引用，然后把应用于内部的图像引用，并让它把自己画出来，然后返回变换后的图像:  

```
#import "UIImage+Transform.h"
#import "UIImage+BaseFilter.h"
@implementation UIImage (Transform)
- (UIImage *) imageWithTransform:(CGAffineTransform)transform
{
    CGContextRef context = [self beginContext];
    
    // setup transformation
    CGContextConcatCTM(context, transform);
    
    // Draw the original image to the context
    UIImage *imageOut = [self getImageFromCurrentImageContext];
    
    [self endContext];
    
    return imageOut;
}
@end
```

Shadow类别定义了一个`imageWithDropShadow`方法，向图像的内部引用添加阴影效果，并返回应用效果之后的最终图像。  

```
#import "UIImage+Shadow.h"
#import "UIImage+BaseFilter.h"
@implementation UIImage (Shadow)
- (UIImage *) imageWithDropShadow
{
    CGContextRef context = [self beginContext];
    
    // set up shadow
    CGSize offset = CGSizeMake (-25,  15);
    CGContextSetShadow(context, offset, 20.0);
    
    // Draw the original image to the context
    UIImage * imageOut = [self getImageFromCurrentImageContext];
    
    [self endContext];
    
    return imageOut;
}
@end
```
最后在ViewController中加载图像：  

```
- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    UIImage *image = imageView.image;
    
    
    // create a transformation
    CGAffineTransform rotateTransform = CGAffineTransformMakeRotation(-M_PI / 4.0);
    CGAffineTransform translateTransform = CGAffineTransformMakeTranslation(-image.size.width / 2.0,
                                                                            image.size.height / 8.0);
    CGAffineTransform finalTransform = CGAffineTransformConcat(rotateTransform, translateTransform);
    UIImage* finalImage = [[image imageWithTransform:finalTransform] imageWithDropShadow];
    [imageView setImage:finalImage];

}
```

因为类别只能拓展方法，不能在原有类的基础上添加属性，但是我们依然可以通过下面的方式向类中动态添加属性，来弥补类别的不足：  

给UIImage添加一个新的title属性  
具体代码如下：  
`UIImage+Title.h`:  

```
@interface UIImage(Title)
@property(nonatomic, copy) NSString *title;
@end
```
`UIImage+Title.m`:  

```
#import "UIImage+Title.h"
static char titleKey;

@implementation UIImage(Title)
- (NSString *)title
{
    return objc_getAssociatedObject(self, &titleKey);
}

- (void)setTitle:(NSString *)title
{
    objc_setAssociatedObject(self, &titleKey, title, OBJC_ASSOCIATION_COPY);
}
@end
```
可以看到关键是用到了runtime的两个函数：  
1. `id objc_getAssociatedObject(id object, void *key)`  
2. `void objc_setAssociatedObject(id object, void *key, id value, objc_AssociationPolicy policy)`  

该函数中第一个参数表示目标对象，第三个参数表示要添加的属性，第四个参数设置objc_AssociationPolicy,它有以下几个选项：  
`OBJC_ASSOCIATION_ASSIGN`，`OBJC_ASSOCIATION_RETAIN`，`OBJC_ASSOCIATION_COPY`，分别对应我们在声明属性时的`assign`,`retain`,`copy`。  
关于第二个参数，key。因为一个对象可以关联多个新的对像，我们需要一个标志来区分他们。所以这个key就起这样的作用。这里的需要的key的地址，不关心它指向谁。  

当我们第二次以新的value调用objc_setAssociatedObject时，如果policy是OBJC_ASSOCIATION_ASSIGN，新的value被关联，对原来旧的value没有任何影响。如果policy是OBJC_ASSOCIATION_RETAIN和OBJC_ASSOCIATION_COPY，新的value被关联，旧的value被release。如果想release原来的value又不关联新的value，，可以用objc_setAssociatedObject直接传一个nil做为value的值。  

注意不要使用`objc_removeAssociatedObjects`，因为它用去掉所有的关联的对象。

参考资料：  
1. 《iOS设计模式解析》  
2. 《HeadFirst设计模式》  
3. http://fanliugen.com/?p=460  
