title: App与Extensions间通信共享数据
date: 2015-04-06 20:30:54
tags:
- iOS
- AppGroups
- App Extensions
- Swift

---

最近玩了玩Watch开发，而目前Watch的主要逻辑处理都是放在WatchKit Extension。真正的Host App，也就是WatchKit App只是用来在界面上显示数据的。于是实践了下containing app与app extension之间的通信和数据共享。  

<!--more-->

##App Groups & Framework

这两样兵器大家都很熟悉。想要共享数据就需要开启App Groups，给group起一个风骚的名字，这样无论是`NSUserDefaults`还是`NSFileManager`都能通过App Groups共享持久层数据了。Core Data也需要`NSFileManager`提供存储的URL支持，而存取Core Data中的数据需要大量的模板代码，在持久层文件共享之后，代码也应该做到共享，所以将能够重用的代码打包成Framework就显得尤为重要。(除非是为了做毕设凑代码量)  

还是以[HardChoice](https://github.com/yulingtianxia/HardChoice)为例，我新建了一个类型为Cocoa Touch Framework的target，名字叫DataKit。新建一个DataAccess.swift文件并将以前AppDelegate.swift中自动生成的Core Data模版代码转移过来。得益于Swift1.2的改进，构造一个线程安全的单例模式变得无比简单：  

```
private static let instance = DataAccess()
public class var sharedInstance : DataAccess {
   return instance
}
```

需要注意Swift的权限控制问题，我们需要在暴漏给框架使用者的公开接口和属性前加上`public`关键字修饰。  

为了实现Core Data持久层共享，需要修改原先的`applicationDocumentsDirectory`属性：  

```
lazy var applicationDocumentsDirectory: NSURL = {
   // The directory the application uses to store the Core Data store file. This code uses a directory named "com.yxy.iCloudCoreDataTest" in the application's documents Application Support directory.
   //        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
   //        return urls[urls.count-1] as! NSURL
   var sharedContainerURL:NSURL? = NSFileManager.defaultManager().containerURLForSecurityApplicationGroupIdentifier(appGroupIdentifier)
   return sharedContainerURL ?? NSURL()
   }()
```

在这里`containerURLForSecurityApplicationGroupIdentifier`方法起到了至关作用。  

同样能够共享的代码就是Model层，它们都是`NSManagedObject`的子类，用于存储Core Data中的数据实例。在把它们从原来的位置拖拽过来时别忘了更改下文件的target："File inspector"->"Target Membership"，选中DataKit。  

在处理iCloud与Core Data同步数据时，我对`NSPersistentStoreCoordinatorStoresWillChangeNotification`、`NSPersistentStoreCoordinatorStoresDidChangeNotification`和`NSPersistentStoreDidImportUbiquitousContentChangesNotification`这三个数据更新的通知进行了观察和处理，但是写在了`persistentStoreCoordinator`计算属性的get方法中。现在使用`lazy`关键字进行惰性加载，导致对这三个数据更新通知的观察延后，这会引发严重的错误。所以需要将那三个`addObserverForName(name, object, queue, usingBlock)`方法挪到`init()`方法中，在第一时间观察通知。

最后在AppDelegate.swift中添加`import DataKit`，替换掉中的`application(application, didFinishLaunchingWithOptions) -> Bool`方法中`controller.managedObjectContext = managedObjectContext`为`controller.managedObjectContext = DataAccess.sharedInstance.managedObjectContext`，也就是不再使用以前的模板代码中的上下文实例，而是用DataAccess单例中的`managedObjectContext`。  

同理，`applicationWillTerminate(application)`方法中的`saveContext()`也要替换成`DataAccess.sharedInstance.saveContext()`。  

于是我们也可以在App Extensions中import进来DataKit，进行地存取Core Data中的数据啦。而且用的是同一段代码，同一块数据。简直是同一个世界，同一个梦想啊。  

##Container app 与 Extension的通信  

要知道之前做的共享数据只能是主动获取数据，并不能在数据变化时实时获取通知。如果用户在iPhone上更改了数据，我们需要在Watch上实时更改界面上数据的显示。这点`NSNotificationCenter`是做不到的，因为它只在App内部工作而不会在两个App之间发通知。同样KVO也无能为力，自己手写委托什么的更是别想了(因为我试过了)。直到我在[这篇文章](https://medium.com/@saberjack/ios-sending-notifications-between-your-apps-3fe7422d6a41)找到了救世主，问题迎刃而解：  

###CFNotificationCenterGetDarwinNotifyCenter

这是CoreFoundation库中一个系统级的通知中心，苹果的系统自己也在用它，看清了"Darwin"了没有？哈哈！看了下`CFNotificationCenter`相关的API，跟`NSNotificationCenter`有点像。需要用到Toll-Bridge的知识与CoreFoundation相关的类进行桥接，这虽不常用但也不难。还需要注意下个别参数的使用。  

###MMWormhole

更有趣的是几乎同时我也发现了[MMWormhole](https://github.com/mutualmobile/MMWormhole)这个开源库，它专门用于在Container app 与 Extension间传递消息。我读了下它的代码，虽然只有一个类，但是依然学到了很多。虽然在我的[HardChoice](https://github.com/yulingtianxia/HardChoice)上完全可以只用`CFNotificationCenter`进行通知就可以了，完全不需要使用MMWormhole来持久化数据和传递数据。但我觉得以后还可能会用到MMWormhole，于是我用Swift1.2重新写了一个[Wormhole.swift](https://github.com/yulingtianxia/HardChoice/blob/master/HardChoice/DataKit/Wormhole.swift)，放在了DataKit里。  

###Swift与CoreFoundation

原来OC写的两百多行的MMWormhole被我用150行“清新优雅”的Swift代码取代。之所以打上引号是因为Swift与CoreFoundation之间的桥接有些不愉快。因为CoreFoundation中都是C的API，C中的指针和类型转换很出格，有安全隐患。Swift是一门安全的语言，但为了调用由历史原因造成的不安全的C的API，Swift中引入了很多类型来映射C中的类型，参考[Interacting with C APIs](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/BuildingCocoaApps/InteractingWithCAPIs.html#//apple_ref/doc/uid/TP40014216-CH8-XID_11)  

Swift中不用像OC那样使用`__bridge`和类型转换、内存管理交接，因为这些全都交给Swift了：如果Swift中存在类型映射到C的API所需的参数类型，那么可以直接将其传入API。此外内存管理也归Swift中的ARC统一管理。于是Swift大大简化了与CoreFoundation打交道的过程。  

我们最关心的是指针，`UnsafePointer<SwiftType>`对应了`const CType *`，`UnsafeMutablePointer<SwiftType>`对应了`CType *`。当然SwiftType与CType也是对应的：  

| C Type       | Swift Type |
| ------------- |:-------------:|
|bool|CBool|
|char, signed char|CChar|
|unsigned char|CUnsignedChar|
|short|CShort|
|unsigned short|CUnsignedShort|
|int|CInt|
|unsigned int|CUnsignedInt|
|long|CLong|
|unsigned long|CUnsignedLong|
|long long|CLongLong|
|unsigned long long|CUnsignedLongLong|
|wchar_t|CWideChar|
|char16_t|CChar16|
|char32_t|CChar32|
|float|CFloat|
|double|CDouble|

更多的转换规则，在上面提到的官方文档有很详细的描述，这里只说三个tips：  

1. 在Swift中将`self`转成`UnsafePointer<Void>`(也就是`const void *`)只需用这个函数：`unsafeAddressOf(self)`  
2. CoreFoundation库中后缀为"Ref"的类在Swift中已经去掉后缀。  
3. Swift中函数指针被表示为`CFunctionPointer<Type>`，Type就是函数的类型，但还不允许你将Swift写的函数或闭包转化成`CFunctionPointer`，也就是干脆没提供建立`CFunctionPointer`实例的方法，只能通过外部引入C的函数。这就涉及到了Swift与OC混编，请戳[Swift and Objective-C in the Same Project](https://developer.apple.com/library/ios/documentation/Swift/Conceptual/BuildingCocoaApps/MixandMatch.html#//apple_ref/doc/uid/TP40014216-CH10-XID_77)  

###在Framework中混编OC

我之所以需要做这种破坏工程纯洁性的事儿，是因为要用到下面这个方法来对通知进行观察：  

```
func CFNotificationCenterAddObserver(center: CFNotificationCenter!, observer: UnsafePointer<Void>, callBack: CFNotificationCallback, name: CFString!, object: UnsafePointer<Void>, suspensionBehavior: CFNotificationSuspensionBehavior)
``` 

除了类型为`CFNotificationCallback`的参数，其余的都好说：  

```
typealias CFNotificationCallback = CFunctionPointer<((CFNotificationCenter!, UnsafeMutablePointer<Void>, CFString!, UnsafePointer<Void>, CFDictionary!) -> Void)>
```

于是就回到了`CFunctionPointer`这块蛋疼地上了，只好在OC里写C函数然后调用之：  

```
static NSString * const WormholeNotificationName = @"WormholeNotificationName";
@implementation HelpMethod
- (instancetype)init
{
    self = [super init];
    if (self) {
        _callback = wormholeNotificationCallback;
    }
    return self;
}
void wormholeNotificationCallback(CFNotificationCenterRef center,
                                  void * observer,
                                  CFStringRef name,
                                  void const * object,
                                  CFDictionaryRef userInfo) {
    NSString *identifier = (__bridge NSString *)name;
    [[NSNotificationCenter defaultCenter] postNotificationName:WormholeNotificationName
                                                        object:nil
                                                      userInfo:@{@"identifier" : identifier}];
}

@end
```

然后在Swift中这样写就可以了：  

```
CFNotificationCenterAddObserver(center, unsafeAddressOf(self), helpMethod.callback, identifier, nil, CFNotificationSuspensionBehavior.DeliverImmediately)
```

在Swift中使用OC写的类本来是一件很easy的事儿，但是到了Framework中就变得不寻常。我在DataKit中新建了`HelpMethod`类，并建立"DataKit-Bridging-Header.h"文件，将HelpMethod.h头文件引入，然后在DataKit target下的"Build Settings" -> "Swift Complier-Code Generation" -> "Objective-C Bridging Header"下填入"DataKit-Bridging-Header.h"，编译出错：**using bridging headers with framework targets is unsupported**。  

在stackoverflow上找到了[解决方案](http://stackoverflow.com/questions/24875745/xcode-6-beta-4-using-bridging-headers-with-framework-targets-is-unsupported)，于是删除之前的"DataKit-Bridging-Header.h"文件并清除"Build Settings"关于Bridging Header的引用；在DataKit.h添加`#import "HelpMethod.h"`，并在HelpMethod.h文件的 "File inspector"->"Target Membership"中DataKit右侧将"project"修改为"public"(否则会出现**include of non-modular header inside framework module 'DataKit'**的编译错误)。  

至此，我们可以在`HelpMethod`类中实现一个函数指针，并在Wormhole.swift文件中直接使用这个函数指针来为`CFunctionPointer`类型的参数传值。  

##总结

来个效果图：  

![](http://yulingtianxia.qiniudn.com/hardchoice.gif)  

这是我第一次写Watch的App(废话谁不是第一次)，经验并不是很多，也因为Swift1.2还未正式发布，遇到了一些坑。好歹最后克服了，但也丢了贞操(毕竟不是纯Swift的App了)。有不对的地方还请多多指教。随着Swift的不断完善，希望以后能够支持创建`CFunctionPointer`对象，这样它好我也好😄
