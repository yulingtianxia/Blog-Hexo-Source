title: CoreData遇见iCloud的那些坑  
date: 2015-02-10 12:04:50
tags:
- Core Data
- iCloud

---
尽管苹果把iCloud与CoreData之间的完美配合吹的天花乱坠，但在iOS7之前，想用iCloud同步CoreData数据简直就是噩梦，苹果自己也承认了之前的诸多bug和不稳定性，这让苹果不得不重新站出来说他们的工程师已经在iOS7中修复了bug，增强了体验，balabala，关键是对于程序员来说，将iCloud集成到CoreData变得无比简单。  

<!-- more -->  

在苹果的[官方文档](https://developer.apple.com/library/ios/documentation/DataManagement/Conceptual/UsingCoreDataWithiCloudPG/UsingSQLiteStoragewithiCloud/UsingSQLiteStoragewithiCloud.html#//apple_ref/doc/uid/TP40013491-CH3-SW1)中已经把配置工作叙述的很明确了，简单地说可以总结为三步：  
- 在iTunes Connect创建App ID，在Xcode中找到项目的Capabilities标签并开启iCloud选项。这会为你创建一个默认的iCloud容器，名字格式为“com.XXX.yourAppID”  
- 添加`NSPersistentStore`时向`options`参数传入一个持久存储的名称，自己起一个就行，示例代码如下:  

```objc
NSDictionary *storeOptions =
    @{NSPersistentStoreUbiquitousContentNameKey: @"MyAppCloudStore"};
NSPersistentStore *store = [coordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                     configuration:nil
                                                               URL:storeURL
                                                           options:storeOptions
                                                             error:&error];
```
-  对`NSPersistentStoreCoordinatorStoresWillChangeNotification`,`NSPersistentStoreCoordinatorStoresDidChangeNotification`和`NSPersistentStoreDidImportUbiquitousContentChangesNotification`这三个通知进行注册以便接收通知后对数据进行处理。最好用`NSNotificationCenter`的`addObserverForName:object:queue:usingBlock:`方法来使逻辑更加明确，代码更紧凑。
最后贴上Swift实现`persistentStoreCoordinator`的代码：
```swift
var persistentStoreCoordinator: NSPersistentStoreCoordinator! {
   if _persistentStoreCoordinator == nil {
       let storeURL = self.applicationDocumentsDirectory.URLByAppendingPathComponent("HardChoice.sqlite")
       var error: NSError? = nil
       _persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
       
       // iCloud notification subscriptions
       let dc = NSNotificationCenter.defaultCenter()
       dc.addObserverForName(NSPersistentStoreCoordinatorStoresWillChangeNotification, object: self.persistentStoreCoordinator, queue: NSOperationQueue.mainQueue(), usingBlock: { (note) -> Void in
           self.managedObjectContext.performBlock({ () -> Void in
               var error: NSError? = nil
               if self.managedObjectContext.hasChanges {
                   if !self.managedObjectContext.save(&error) {
                       println(error?.description)
                   }
               }
               self.managedObjectContext.reset()
           })
       })
       dc.addObserverForName(NSPersistentStoreCoordinatorStoresDidChangeNotification, object: self.persistentStoreCoordinator, queue: NSOperationQueue.mainQueue(), usingBlock: { (note) -> Void in
           self.managedObjectContext.performBlock({ () -> Void in
               var error: NSError? = nil
               if self.managedObjectContext.hasChanges {
                   if !self.managedObjectContext.save(&error) {
                       println(error?.description)
                   }
               }
           })
       })
       dc.addObserverForName(NSPersistentStoreDidImportUbiquitousContentChangesNotification, object: self.persistentStoreCoordinator, queue: NSOperationQueue.mainQueue(), usingBlock: { (note) -> Void in
           self.managedObjectContext.performBlock({ () -> Void in
               self.managedObjectContext.mergeChangesFromContextDidSaveNotification(note)
           })
       })
       
       if _persistentStoreCoordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: storeURL, options: [NSPersistentStoreUbiquitousContentNameKey:"MyAppCloudStore"], error: &error) == nil {

           println("Unresolved error \(error), \(error?.userInfo)")
           abort()
       }
   }
   return _persistentStoreCoordinator!
}
var _persistentStoreCoordinator: NSPersistentStoreCoordinator? = nil
```

当然你也可以用`lazy`关键字同样来实现`persistentStoreCoordinator`属性的惰性加载。  

已经有人将整套CoreData集成iCloud的逻辑抽象出来，比如[iCloudCoreDataStack](https://github.com/mluisbrown/iCloudCoreDataStack)。完全不需要再用宣称能让CoreData与iCloud搭配更简单的第三方库了，因为在iOS7中苹果的确让它简单至极了。  

然而当Xcode6和iOS8袭来，一个个坑争先恐后的出现了。  

首先是**iCloud Drive**，它与之前iCloud有冲突。如升级，请彻底，让测试机器都升级iCloud Drive。  

然后是Xcode6中开启Capabilities标签的iCloud选项卡后，如下的场景简直是卧槽：  

![](http://yulingtianxia.qiniudn.com/QQ20150210-1@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)   

该怎么选怎么选啊？！我只能说按照上图这么选就对了。顺便说一下iCloud默认容器名称格式已经变成了“iCloud.com.yourname.yourAppID”，其实这也不太准确，官方称作“iCloud.$(CFBundleIdentifier)”,后面的美元号所指的变量就是General中Identity一栏的“Bundle Identifier”值。此外“Key-value storage”和“CloudKit”选项选不选都可以，但“iCloud Documents”一定要勾选，否则是无法同步CoreData数据的。  

PS：CloudKit是苹果最新推出的基于iCloud的一个云端数据存储服务,提供了低成本的云存储并能作为一个后端服务通过用户们的iCloud账号分享其应用数据。 

接下来是时候检查我们是否成功添加了iCloud容器，可以在`applicationDidFinishLaunchingWithOptions`方法中尝试获取容器的URL来判断：  
```swift
let containerURL = NSFileManager.defaultManager().URLForUbiquityContainerIdentifier("iCloud.com.yulingtianxia.HardChoice")
if containerURL != nil {
  println("success:\(containerURL)")
}
else{
  println("URL=nil")
}
```
如果之前没有在Capabilities标签的iCloud中勾选“iCloud Documents”，“URLForUbiquityContainerIdentifier”方法会始终返回`nil`。来看看苹果开发者论坛上关于这个话题的[讨论](https://devforums.apple.com/message/1006124#1006124)吧  

PS：官方文档不建议在主线程使用`URLForUbiquityContainerIdentifier`方法，因为它可能需要较长时间来返回URL而阻塞主线程。这里只是为了测试使用。  

然而判断iCloud是否真的与CoreData工作正常，苹果的官方文档写的很详细：[Using the iCloud Debugging Tools](https://developer.apple.com/library/ios/documentation/DataManagement/Conceptual/UsingCoreDataWithiCloudPG/UsingiCloudDebuggingTools/UsingiCloudDebuggingTools.html#//apple_ref/doc/uid/TP40013491-CH8-SW1)  

当我兴致冲冲的打开Xcode中的debug navigator，点击左边的iCloud查看状态时，被眼前的一切惊呆了：  

![](http://yulingtianxia.qiniudn.com/QQ20150210-4@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

“iCloud Usage”告诉我状态不可用，然而右下角的日志中Using local storage已经从1变成了0，也就是证明了我的APP([HardChoice](http://hardchoice.yulingtianxia.com))已经从CoreData使用本地持久仓库转移到了使用“iCloud-enabled”持久仓库。“Transfer Activity”中柱状图更是显示从iCloud下载了数据。而这其实应该是Xcode6的一个bug，有人已经在[苹果开发者论坛](https://devforums.apple.com/message/1026708#1026708)讨论了。  

根据我的测试，只勾选“Key-value storage”或者在模拟器上调试时，“iCloud Usage”都不会出现。而即使“iCloud Usage”出现了，状态也始终是Disabled，“Transfer Activity”也不是很灵敏。唯独只能相信CoreData的log了。  

但我们可以查看“My Mac”的“iCloud Usage”而不是iPhone的“iCloud Usage”：  

![](http://yulingtianxia.qiniudn.com/QQ20150210-6@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

在“Documents”一栏中可以看出我在两个设备间同步了数据，“mobile”后面跟着的是我的设备编号。展开数据可以看到更详细的同步记录：  

![](http://yulingtianxia.qiniudn.com/QQ20150210-5@2x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

虽然通过“My Mac”可以看到iCloud与CoreData的数据同步记录，但是在Xcode6.1.1中“Documents”的显示不是很正常，在最新的Xcode6.2beta版中虽然修复了“Documents”的显示问题，但“iCloud Usage”的种种bug依然存在。  

最后，确保网络通常。我在中软实训一个月时，网络奇差，或是屏蔽了iCloud，一直没能调试成功。  

贴一张[HardChoice](http://hardchoice.yulingtianxia.com)同步成功的测试图，因为我是用Swift写的这个Demo，所以喜欢用Swift的可以直接把我的那部分源码粘过去用：  

![](http://yulingtianxia.qiniudn.com/52D3D9B3C9688FB91EDAEB5F88BF102C.jpg?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  


参考：  

- http://stackoverflow.com/questions/26195612/icloud-debug-gauge-status-disabled  
- http://stackoverflow.com/questions/25971816/xcode-6-ios-8-icloud-core-data-setup