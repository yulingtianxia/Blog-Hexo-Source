---
layout: post
title: "Double Dispatch模式及其在iOS开发中实践"
date: 2014-04-13 15:51:03 +0800
comments: true
tags: 
- 设计模式
- iOS
- Objective-C
- 碰撞检测

---
## 本文内容
- 引子
- C++中的Double Dispatch实例
- Java中的Double Dispatch实例
- Objective-C中实现碰撞检测用到的Visitor模式
 
<!-- more-->

## 引子
在一个太空大战游戏中，导弹可以撞向飞船，也可能撞向行星，所以在碰撞检测的时候就需要判断碰撞的结果。假设游戏有四种物体：飞船，陨石，行星，导弹，那么就产生了`4*3/2+4`种情形（一枚导弹撞上另一枚导弹）。这种排列组合计算出的结果会随着物体种类N的增多爆炸性增长，如果这个时候还用一堆if－else来检测碰撞，那真是`Naive`了。这时我们可以利用面向对象语言的多态性质来在程序运行时动态绑定，因为碰撞检测是一种“双向选择”，所以我们需要`double dispatch`（双分派），`Visitor`模式就是`double dispatch`的一种应用。  
![Visitor模式](http://7ni3rk.com1.z0.glb.clouddn.com/14035338896.jpg?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)   

DD模式适合于处理多个对象之间的相互作用。假如不用DD模式的话，那么每个对象跟别的对象发生关系时，就必须辛辛苦苦的进行if...else...枚举，因为它并不知道对方是何神圣。DD模式的引入解决了这个问题，其实说白了就是利用语言内置的虚函数机制来替你干活，把工作移交给编译器去做了。  


## C++中的Double Dispatch实例
本节内容摘自[这里](http://www.cnblogs.com/west-link/archive/2011/07/26/2116887.html?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  
我们先从字面上去理解它吧，直观地说，它指的是两次dispatch。这里的dispatch指的是什么呢？举个例子：  


```cpp
class Event
   {
       public:
           virtual void PrintName()
           {
                cout<<"我是通用事件"<<endl;           
           }
   }
   
   class KeyEvent:public Event
   {
      public:
           virtual void PrintName()
           {
                cout<<"我是按键事件"<<endl;           
           }
   }
   
   class ClickEvent:public Event
   {
       public:
           virtual void PrintName()
           {
                cout<<"我是单击事件"<<endl;           
           }
   }
```

多态性是动态的，被调用的方法由对象的真正类型确定，这个过程就被称之为dispatch。例如在C++中，每个对象都有一个虚函数表，当用基类的类型引用子类对象时，虚函数指针指向的是子类的虚函数表，调用的虚函数都是子类中的版本，所以下面代码输出的是：“我是按键事件”，这就算是一次dispatch的过程，即根据对象类型来动态确定调用哪个函数的过程。  

```
Event* pEvent = new KeyEvent();
pEvent->PrintName();
```

什么时候会用到两次dispatch呢? 继续往下看：  

```
class EventRecorder
   {
       public:
           virtual void RecordEvent(Event* event)
           {
               cout<<"使用EventRecorder记录通用事件"<< endl;           
           }
           
           virtual void RecordEvent(KeyEvent* event)
           {
               cout<<"使用EventRecorder记录按键事件"<< endl;           
           }
           
           virtual void RecordEvent(ClickEvent* event)
           {
               cout<<"使用EventRecorder记录单击事件"<< endl;           
           }
   }
   
   class AdvanceEventRecorder:public EventRecorder
   {
       public:
           virtual void RecordEvent(Event* event)
           {
               cout<<"使用高级EventRecorder记录通用事件"<< endl;           
           }
           
           virtual void RecordEvent(KeyEvent* event)
           {
               cout<<"使用高级EventRecorder记录按键事件"<< endl;           
           }
           
           virtual void RecordEvent(ClickEvent* event)
           {
               cout<<"使用高级EventRecorder记录单击事件"<< endl;           
           }
   }
```

这两个类中分别包含三个重载函数，多态是动态的，而函数重载则是静态的，它在编译时期就确定下来了，所以，下面代码片段的运行结果并不是我们所期望的:  

```
	EventRecorder* pRecorder = new AdvanceEventRecorder();
	Event* pEvent = new KeyEvent();
	pRecorder->RecordEvent(pEvent);
```
输出内容为：使用高级EventRecorder记录通用事件  
实际上，在这个场景中，我们期望调用的是：AdvanceEventRecorder::RecordEvent(KeyEvent* event)  
下面我们使用Double Dispatch设计模式来达到上面的代码片段的目的，在所有Event对象中增加下面的函数：  

```
   virtual void RecordEvent(EventRecorder* recorder)
   {
      recorder->RecordEvent(this);
   }
```
下面的代码片段将输出：使用高级EventRecorder记录按键事件  

```
	EventRecorder* pRecorder = new AdvanceEventRecorder();
   	Event* pEvent = new KeyEvent();
   	pEvent->RecordEvent(pRecorder);
```
可以看出，第一次dispatch正确地找到了`KeyEvent`的`RecordEvent(EventRecorder* recorder)`，第二次dispatch找到了`AdvanceEventRecorder`的`RecordEvent(KeyEvent* event)`。
   Visitor模式就是对Double Dispatch的应用，另外，在碰撞检测算法中也会经常用到。
## Java中的Double Dispatch实例
本节参考自[这里](http://www.blogjava.net/chaocai/archive/2009/02/19/255640.html)
相对于C++中使用继承来说，Java提供的接口和函数重载让Double Dispatch模式更容易实现  
### 1 根据对象来选择行为问题  

```java
public interface Event {
}
public class BlueEvent implements Event {
}
public class RedEvent implements Event {
}
public class Handler {
public void handle(Event event){
System.out.println("It is event");
}
public void handle(RedEvent event){
System.out.println("It is RedEvent");
}
public void handle(BlueEvent event){
System.out.println("It is BlueEvent");
}
}
public class Main {
public static void main(String[] args) {
Event evt=new BlueEvent();
new Handler().handle(evt);
}
}
```

你认为运行结果是什么呢？  
结果：It is event  
是不是有点出乎意料，不是It is BlueEvent，**这是因为Overload并不支持在运行时根据参数的运行时类型来绑定方法**，所以要执行哪个方法是在编译时就选定了的。    
### 2 Double Dispatch Pattern  
由于Java,C++及C#都具有上述局限，通常我们只能通过Switch或if结构来实现，当然这种实现方式既不优雅而且影响代码的可维护性。  
通过以下的Double Dispatch Pattern便可以优雅的实现。  

```
public interface Event {
public void injectHandler(EventHandler v);
}
public class BlueEvent implements Event {
public void injectHandler(EventHandler v) {
v.handle(this);
}
}
public class RedEvent implements Event {
public void injectHandler(EventHandler v) {
v.handle(this);
}
}
public class EventHandler {
public void handle(BlueEvent e){
System.out.println("It is BlueEvent");
}
public void handle(RedEvent e){
System.out.println("It is RedEvent");
}
}
public class Main {
public static void main(String[] args) {
Event evt=new BlueEvent();
evt.injectHandler(new EventHandler());
}
}
```
## Objective-C中实现碰撞检测用到的Visitor模式

虽然OC不支持函数重载，但是我们可以老老实实的用方法名来区分类似`visitXXX`的访问方法，并利用OC其独有的SEL类型可以很好的在运行时判断该调用哪个方法  

![](http://7ni3rk.com1.z0.glb.clouddn.com/140353389425.jpg?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)   

感谢kouky提供的iOS上碰撞检测的[Demo](https://github.com/kouky/iOS-SpriteKit-Pong)，这里他用到了Visitor模式  
由于判断物体类型是用一个32位掩码来标记，所以这里不可避免的要用到if语句，这不代表它不是动态绑定，因为if语句是在初始化方法`+ (id)contactVisitorWithBody:(SKPhysicsBody *)body forContact:(SKPhysicsContact *)contact`中其作用的，只是为了判断物体类型，而不是判断碰撞两者的组合类型  
可以参考我写的例子[ColorAtom](https://github.com/yulingtianxia/MyFirstGame/tree/master/ColorAtom)  

首先新建一个访问者基本类`ContactVisitor`，其本质为对SKPhysicsBody和SKPhysicsContact对象的封装，而SKPhysicsContact在本例中虽未用到（因为碰撞检测后啥也没干，只输出了碰撞双方name），但其保存着碰撞坐标等信息，也很重要。两次dispatch都是在访问者基本类实现的，而碰撞后具体操作则卸载了访问者具体类（如AtomNodeContactVisitor）


```objc

//  ContactVisitor.h
//  ColorAtom
//
//  Created by 杨萧玉 on 14-4-13.
//  Copyright (c) 2014年 杨萧玉. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SpriteKit/SpriteKit.h>
@interface ContactVisitor : NSObject

@property (nonatomic,readonly, strong) SKPhysicsBody *body;
@property (nonatomic, readonly, strong) SKPhysicsContact *contact;

+ (id)contactVisitorWithBody:(SKPhysicsBody *)body forContact:(SKPhysicsContact *)contact;
- (void)visit:(SKPhysicsBody *)body;

@end
```

属性body即为访问者的SKPhysicsBody，而方法`visit:`的参数为被访问者的SKPhysicsBody  
`contactVisitorWithBody:forContact:`方法的作用是根据掩码类型初始化对应类型的访问者具体类  

```
//
//  ContactVisitor.m
//  ColorAtom
//
//  Created by 杨萧玉 on 14-4-13.
//  Copyright (c) 2014年 杨萧玉. All rights reserved.
//

#import "ContactVisitor.h"
#import <objc/runtime.h>
#import "NodeCategories.h"
#import "AtomNodeContactVisitor.h"
#import "PlayFieldSceneContactVisitor.h"
@implementation ContactVisitor
+ (id)contactVisitorWithBody:(SKPhysicsBody *)body forContact:(SKPhysicsContact *)contact
{
    //第一次dispatch，通过node类别返回对应的实例
    if ((body.categoryBitMask&AtomCategory)!=0) {
        return [[AtomNodeContactVisitor alloc] initWithBody:body forContact:contact];
    }
    if ((body.categoryBitMask&PlayFieldCategory)!=0) {
        return [[PlayFieldSceneContactVisitor alloc] initWithBody:body forContact:contact];
    }
    else{
        return nil;
    }
}

- (id)initWithBody:(SKPhysicsBody *)body forContact:(SKPhysicsContact *)contact
{
    self = [super init];
    if (self) {
        _contact = contact;
        _body = body;
    }
    return self;
}

- (void)visit:(SKPhysicsBody *)body
{
    //第二次dispatch，通过构造方法名来执行对应方法
    // 生成node的名字，比如"AtomNode"
    NSString *bodyClassName = [NSString stringWithUTF8String:class_getName(body.node.class)];
    
    // 生成方法名，比如"visitAtomBody"
    NSMutableString *contactSelectorString = [NSMutableString stringWithFormat:@"visit"];
    [contactSelectorString appendString:bodyClassName];
    [contactSelectorString appendString:@":"];
    
    SEL selector = NSSelectorFromString(contactSelectorString);
    //判断是否存在此方法
    if ([self respondsToSelector:selector]) {
        [self performSelector:selector withObject:body];
    }
    
}

```

以访问者具体类以`AtomNodeContactVisitor`类为例，它继承自访问者基本类ContactVisitor  

```

//
//  AtomNodeContactVisitor.h
//  ColorAtom
//
//  Created by 杨萧玉 on 14-4-13.
//  Copyright (c) 2014年 杨萧玉. All rights reserved.
//

#import "ContactVisitor.h"

@interface AtomNodeContactVisitor : ContactVisitor

/*Atom访问了Atom，同类碰撞*/
-(void) visitAtomNode:(SKPhysicsBody*) anotherAtomBody;
/*Atom访问了边界，也就是球撞墙上了*/
-(void) visitPlayFieldScene:(SKPhysicsBody*) playfieldBody;
@end

```

在处理碰撞后的visitXXX方法中，我将碰撞双方的访问者和被访问者的关系输出  

```
//
//  AtomNodeContactVisitor.m
//  ColorAtom
//
//  Created by 杨萧玉 on 14-4-13.
//  Copyright (c) 2014年 杨萧玉. All rights reserved.
//

#import "AtomNodeContactVisitor.h"
#import "AtomNode.h"
#import "PlayFieldScene.h"
@implementation AtomNodeContactVisitor
-(void) visitAtomNode:(SKPhysicsBody*) anotherAtomBody
{
    AtomNode *thisAtom = (AtomNode*)self.body.node;
    AtomNode *anotherAtom = (AtomNode*)anotherAtomBody.node;
    //处理碰撞后的结果
    NSLog(@"%@->%@",thisAtom.name,anotherAtom.name);
}
-(void) visitPlayFieldScene:(SKPhysicsBody*) playfieldBody
{
    AtomNode *atom = (AtomNode*)self.body.node;
    PlayFieldScene *playfield = (PlayFieldScene*) playfieldBody.node;
    NSLog(@"%@->%@",atom.name,playfield.name);
}
@end
```
下面建立被访问者类，其本质就是对SKPhysicsBody的封装，并接受Visitor的注入  

```
//
//  VisitablePhysicsBody.h
//  ColorAtom
//
//  Created by 杨萧玉 on 14-4-13.
//  Copyright (c) 2014年 杨萧玉. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ContactVisitor.h"
@interface VisitablePhysicsBody : NSObject
@property (nonatomic, readonly, strong) SKPhysicsBody *body;

- (id) initWithBody:(SKPhysicsBody *)body;
- (void) acceptVisitor:(ContactVisitor *)visitor;

@end
```

关键的一步：在`acceptVisitor:`方法中调用访问者的`visit:`方法  

```
//
//  VisitablePhysicsBody.m
//  ColorAtom
//
//  Created by 杨萧玉 on 14-4-13.
//  Copyright (c) 2014年 杨萧玉. All rights reserved.
//

#import "VisitablePhysicsBody.h"

@implementation VisitablePhysicsBody
- (id)initWithBody:(SKPhysicsBody *)body
{
    self = [super init];
    if (self) {
        _body = body;
    }
    return self;
}

- (void)acceptVisitor:(ContactVisitor *)visitor
{
    [visitor visit:self.body];
}

@end

```

可能有人会有疑问，`visit:`方法穿入的参数类型永远是`SKPhysicsBody`，这哪里是动态绑定啊，其实是由于本例的特殊性，碰撞检测时区分物体类型不是靠`SKPhysicsBody`子类化来区分和绑定，而是靠SKPhysicsBody类中的`categoryBitMask`属性来区分，这也就免不了需要在`ContactVisitor`初始化的时候通过if语句来判断具体初始化哪个子类  
最后，在Scene实现SKPhysicsContactDelegate协议  

```
#pragma mark SKPhysicsContactDelegate
-(void)didBeginContact:(SKPhysicsContact *)contact
{
    //A->B
    ContactVisitor *visitorA = [ContactVisitor contactVisitorWithBody:contact.bodyA forContact:contact];
    VisitablePhysicsBody *visitableBodyB = [[VisitablePhysicsBody alloc] initWithBody:contact.bodyB];
    [visitableBodyB acceptVisitor:visitorA];
    //B->A
    ContactVisitor *visitorB = [ContactVisitor contactVisitorWithBody:contact.bodyB forContact:contact];
    VisitablePhysicsBody *visitableBodyA = [[VisitablePhysicsBody alloc] initWithBody:contact.bodyA];
    [visitableBodyA acceptVisitor:visitorB];
    
}
```
物理老师总说力的作用时相互的，所以我们需要两次访问：A访问B和B访问A，但是这样会调用两次visitXXX方法，原则上这两个逻辑上对称的方法我们只需要实现其中一个就可以，但必须得像上面代码一样，A->B和B->A缺一不可，因为碰撞的时候我们不知道bodyA和bodyB的类型，也就无法判断visitXXX方法是A->B时能调用还是B->A时能调用到  
当然，你也可以两个visit方法都实现，但只对visitor的node做操作，或只对visitable的node操作，总之仁者见仁智者见智啦

