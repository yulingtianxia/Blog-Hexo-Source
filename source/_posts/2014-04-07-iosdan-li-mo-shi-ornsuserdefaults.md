---
layout: post
title: "iOS单例模式 or NSUserDefaults"
date: 2014-04-07 15:07:08 +0800
comments: true
tags: 
- iOS
- 设计模式

---
本文内容：  

- iOS的单例模式
- NSUserDefaults的使用
- 总结：iOS单例模式 and NSUserDefaults
<!-- more-->


#iOS的单例模式
提起单例模式大家都不陌生，什么懒汉式，饿汉式，老汉式。。。扯远了  

一开始觉得Objective－C中没有绝对的私有方法，该如何实现单例模式呢？后来觉得想多了，限制构造方法的使用式徒劳的，因为程序是人写的，既然是单例了，那就老老实实调用自己写的getInstance吧。Java笑了？一个反射打趴下！
在ARC诞生之前，可以通过重写`allocWithZone`方法等来实现，下面是苹果官方的单例写法：  
``` objectivec 
static MyGizmoClass *sharedGizmoManager = nil; 
+ (MyGizmoClass*)sharedManager
{
    @synchronized(self) {
        if (sharedGizmoManager == nil) {
            [[self alloc] init]; // assignment not done here
        }
    }
    return sharedGizmoManager;
}
 
+ (id)allocWithZone:(NSZone *)zone
{
    @synchronized(self) {
        if (sharedGizmoManager == nil) {
            sharedGizmoManager = [super allocWithZone:zone];
            return sharedGizmoManager;  // assignment and return on first allocation
        }
    }
    return nil; //on subsequent allocation attempts return nil
}
 
- (id)copyWithZone:(NSZone *)zone
{
    return self;
}
 
- (id)retain
{
    return self;
}
 
- (unsigned)retainCount
{
    return UINT_MAX;  //denotes an object that cannot be released
}
 
- (void)release
{
    //do nothing
}
 
- (id)autorelease
{
    return self;
}

``` 

在ARC时代，程序员不用费心计算static的实例被引用多少次，需要release巴拉巴拉。。。而自从有了GCD，iOS的单例模式变得超级简单了：  

``` 
+ (Singleton *)sharedInstance{
    static id instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}
``` 
instance为将被实例化的对象，为了让instance只被实例化一次，用到了GCD(Grand Central Dispatch)中的`dispatch_once`方法。该方法有两个参数，第二个参数是一个block，只会被执行一次。而第一个参数是一个谓词，用于判断代码块（block）是否执行完，这个谓词只能是全局或静态变量，类型为dispatch_once_t，其实dispatch_once_t就是long类型。你可以理解为第一个参数是个标识位，能保证记录第二个参数block的执行情况，即使是在最复杂的多线程并发执行的情况下，也就是说，GCD的这个方法是线程安全的。如果你对block这种类型比较陌生，可以把它暂时当作函数指针，当然，它比函数指针还要强大。  
你可以重写init方法来实现饿汉式单例，也可以自定义initwithXXX来在需要实例化的时候调用之，实现懒汉式单例。  
#NSUserDefaults
很多APP启动时需要读取上次运行保存的一些状态，如何保存呢？Core Data，SQlite和UIDocuments未免杀鸡用牛刀了，而`NSUserDefaults`很适用于快速读取小规模的数据  

``` 
NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults]; 
``` 
写入数据  

``` 
NSString *string = @"hahaha";
[standardDefaults setObject:string forKey:@"myKey"];
[standardDefaults synchronize];//写完别忘了同步
``` 
读取数据  

``` 
NSString *value = [standardDefaults objectForKey:@"myKey"];  
``` 
`NSUserDefaults`可以很好地理解成键值对  

有时在写数据之前，想判断下这个健是否已经设置过默认值

``` 
NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
if ([standardDefaults stringForKey:@"favoriteColor"] == nil) {
[standardDefaults setObject:@"Green" forKey:@"favoriteColor"];
[standardDefaults synchronize];
}
``` 
其实大可不必这么麻烦，摘自[破船](http://beyondvincent.com/blog/2013/04/20/13/)推荐的方法`registerDefaults:`  

``` 
NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
[standardDefaults registerDefaults:@{@"favoriteColor": @"Green"}];
[standardDefaults synchronize];
``` 
每次程序启动的时候调用`registerDefaults:` 方法都是安全的。完全可以将这个方法的调用放到`applicationDidFinishLaunching:`方法中. 这个方法永远都不会覆盖用户设置的值。  
但是并不是所有类型的对象都能够直接放入NSUserDefaults，NSUserDefaults只支持： NSString, NSNumber, NSDate, NSArray, NSDictionary  
解决方法：让这个自定义的类实现<NSCoding>协议，举个例子： 

``` 
//SNShops.h

@interface SNShops : NSObject<NSCoding>

@property (nonatomic,strong) NSString* sid;
@property (nonatomic,strong) NSString* name;

- (id) initWithCoder: (NSCoder *)coder;
- (void) encodeWithCoder: (NSCoder *)coder;

//SNShops.m
@implementation SNShops
- (id) initWithCoder: (NSCoder *)coder
{
    if (self = [super init])
    {
        self.sid = [coder decodeObjectForKey:@"sid"];
        self.name = [coder decodeObjectForKey:@"name"];
    }
    return self;
}
- (void) encodeWithCoder: (NSCoder *)coder
{
    [coder encodeObject:self.sid forKey:@"sid"];
    [coder encodeObject:self.name forKey:@"name"];
}

``` 

然后再存取时通过`NSData`做载体：  
存入  

``` 
NSUserDefaults *standardDefaults = [NSUserDefaults standardUserDefaults];
SNShops *shop = [[SNShops alloc]init];
NSData *shopData = [NSKeyedArchiver archivedDataWithRootObject:shop];
[standardDefaults setObject:shopData forKey:@"myshop"];
[standardDefaults synchronize];

``` 
读取  

``` 
NSData *newshopData = [standardDefaults objectForKey:"myshop"];
SNShops *newshop = [NSKeyedUnarchiver unarchiveObjectWithData:newshopData];
``` 
#总结：iOS单例模式 and NSUserDefaults
单例模式虽然能存入任何类型的对象，但是它会随着程序的挂起而消亡。而NSUserDefaults在读取自定义类型时有些繁琐，降低编码效率和可读性，好处是程序下次启动依然能读取到上次的状态。  
笔者在实际应用中采取了二者结合的模式：让单例模式的类实现<NSCoding>协议，程序第一次启动的时候通过NSData做载体读取单例类的实例，并存入单例，程序运行中一直对单例做存储操作，当程序快要进入到后台挂起的时候，通过NSData做载体存入NSUserDefaults，一举两得。
