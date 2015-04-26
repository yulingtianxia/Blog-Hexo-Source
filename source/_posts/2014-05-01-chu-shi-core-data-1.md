---
layout: post
title: "初识Core Data(1)"
date: 2014-05-01 19:58:00 +0800
comments: true
tags: 
- Objective-C
- Core Data

---
本文内容：  

- Core Data概述  
- 新建一个Core Data工程  
- 总结

---
<!--more-->
##Core Data概述
Core Data本身既不是数据库也不是数据库访问框架。相反，Core Data是一个完整的数据模型解决方案。我简单理解为对持久层的封装，使得我们可以通过可视化建立数据模型，简化数据存取。有人会联想到Hibernate，其实Core Data比Hibernate强大得多，它不仅支持SQLite数据库，还能对XML文件、二进制文件、用户自定义文件进行操作。  

即使不懂SQL语句，也依然可以使用Core Data。因为Core Data将底层的数据库SQL语句封装成了一套API，并可通过可视化操作来建立数据库的模型和表之间的关系，它甚至在数据变化时会帮你自动处理关系（比如删除了一门课程，所有选这门课程的学生也会自动解除与此门课程的关系），Core Data还能对非法数据进行过滤，还支持对数据操作的Undo/Redo功能。更重要的是，Core Data的`NSFetchRequest`类可以替代SQL中的Select语句，并提供了更高效的方法将查询结果显示在UITableView中。 

iOS 3.0和Mac OS X10.5都支持Core Data，但iOS上不支持XML文件存储。Core Data对读取性能做了大量优化，其中惰性加载（Faulting）就是一个例子，毕竟设备的内存是有限切珍贵的。  
在OSX上可以绑定利用KVO和KVC保持UI项与模型对象或属性之间的连接，无需编写任何代码，通过对象和数组控制器自动从Core Data存储区分批提取`NSManagedObject`对象。这就像在VS中用.Net构建基于SQLServer的桌面程序。  
苹果公司单独为iOS平台的Core Data引入了`NSFetchedResultsController`类帮助视图与从持久化存储文件提取的数据之间的交互。它主要是用来充当`UITableiView`的数据源，负责调整`UITableiView`行与节（section）的显示数目，以及为各表格行提供内容。  
##新建一个Core Data工程
在Xcode5中，只有Master-Detail Application，Utility Application以及Empty Application支持创建时使用Core Data模板，我们选择带有UITableView的Master-Detail Application吧。  

![](http://yulingtianxia.qiniudn.com/14035339677.png)  

一定要勾选Core Data选项，项目名称就叫MyCDDemo吧，嘿嘿  

![](http://yulingtianxia.qiniudn.com/140353396978.png)  

项目建立后会发现Frameworks中已经有了`CoreData.framework`一项，并且还多了一个MyCDDemo.xcdatamodeld文件，该文件定义了数据模型结构，你可以使用XCode内置的可视化建模工具进行构建。点开它你会发现左侧有三项：Entities，Fetch Request、Configurations。  

**Entities**  

在系统的学习Core Data前，可以简单的将Entity理解为数据库中的一张表，在代码中一个`NSEntityDescription`类的对象就代表了一个Entity。Entity也像类一样可以继承，如果你有若干个相似的实体，就可以抽离出它们的共有特性作为一个“父实体”，就省去了在多个实体中都指定相同的属性。甚至可以勾选Abstract Entitiy让其成为抽象实体，就像抽象类一样。  

![](http://yulingtianxia.qiniudn.com/140353414584.png)  

现在已经有了一个现成的实体：Event，也就是在SQLite中有了一张叫做Event的表：  

![](http://yulingtianxia.qiniudn.com/140353397403.png)  

Attributes就相当于一张表的列属性，可以设置其数据类型，默认值，最大最小值等，类似数据库可视化建表。需要注意的是这里的空值是NULL，不等同于OC中的nil，更不等同于0和空字符串@“”。Event实体中已经有了一个叫timeStamp的属性，类型为Date，这是模版自动生成的，暂且别修改它。  

Relationships描述了Entity间的关系：多对一，一对一等。当你指定了一个关系后，苹果推荐我们也指定一个反转关系。比如A和B是多对多的关系，那么A指向B的关系Type为To Many，同时设定B指向A的关系Type为To Many。  

Fetched Property表示了一种弱的、单向的关系。因为Core Data不支持在persistent store之间建立Relationships，所以Fetched Property可用于建立cross-store关系，还用于建立“松耦合”关系，相似暂时的分组。（a fetched property of a department might be "recent hires" (employees do not have an inverse to the recent hires relationship)） 
 
**Fetch Request**  

我们使用`NSFetchRequest`类来描述数据请求，利用数据请求从持久存储（persistent store）中获取对象。经常碰到的情形是你经常需要多次执行同样的请求，或是执行遵循一个给定模式的请求，但是其中包含变量（如查找条件）——这些变量经常由用户提供。例如，在运行程序的时候，你要根据用户需要获取某个作者在用户指定日期后出版的所有出版物。  

你可以预定义请求，把它们作为模板存储在被管理对象模型中。预定义的模板在你需要的时候就可以取出使用。通常情况下，我们通过Xcode的data modeling tool工具创建请求模板。模板可以包含变量：  

![](http://yulingtianxia.qiniudn.com/140353412465.png)  

**Configurations**  

配置包含了一个名称和若干个相关的实体。实体的集合是可以重叠的——这就是说，一个实体可以出现在多个配置中。在代码中，我们使用`setEntities: forConfiguration:`的方法来指定配置。也可以用Xcode的建模工具来指定。要获取某项配置的实体，需要用`entitiesForConfiguration:`的方法。  

一般说来，如果你想把不同的实体存放在不同的存储中去，就可能用到配置。一个持久化存储协调器（persistent store coordinator，你暂且理解为负责数据库连接的东东）只能有一个被管理对象模型（managed object model，也就是把xcdatamodeld文件加载到代码中的内容啦）。所以，默认情况下，和协调器关联的某个存储必须包含同样的实体。要想绕过这个限制，你可以创建一个包含所有实体并集的模型，然后在模型中为每一个你想使用的实体子集创建配置，这样一来，使用这个模型创建协调器，当你需要添加存储（persistent store）时，可根据不同的配置来指定对应的存储属性。当你创建配置的时候，需要记住，不能创建跨存储的关系（cross-store relationships）。  

模版已经生成了一个叫Default的配置，但是在程序中并没有用到它（这在之后的内容会阐述）。  

在了解了xcdatamodeld类型文件之后，你可能对Core Data如何描述一个数据库有了一定的概念，下一步我们准备阅读模版自动生成的代码，你会体会到xcdatamodeld文件在程序中是如何被加载和使用的。  

先看看AppDelegate.h  

``` objc
#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (void)saveContext;
- (NSURL *)applicationDocumentsDirectory;

@end
``` 
嗯，比平时的程序多出了三个属性嘛，而且后两个属性之前还提到过，这“三剑客“是Core Data中非常重要的三个类：  

- Managed Object Model（管理数据模型）: 你可以将这个东西看作是数据库的轮廓，或者结构。这里包含了各个实体的定义信息，一般来说，你会使用我们刚刚看过的视觉编辑器来操作这个物体，添加属性，建立属性之间的关系等等，当然你也可以使用代码。
- Persistent Store Coordinator （持久性数据协调器）： 你可以将这个东西看作是数据库连接库，在这里，你将设置数据存储的名字和位置，以及数据存储的时机。
- Managed Object Context （管理数据内容）：你可以将这一部分看作是数据的实际内容，这也是整个数据库中对我们而言最重要的部分（这还用说），基本上，插入数据，查询数据，删除数据的工作都在这里完成。

如果你还是不好理解，那么简单的把这“三剑客”理解为：数据定义语言 (DDL)、数据库连接（DBC）、数据操作语言 (DML)在Core Data中的另一种存在吧！  

下面该看看AppDelegate.m，了解下“三剑客”实例化的过程： 
首先是程序加载完毕的代理方法： 

``` 
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Override point for customization after application launch.
    UINavigationController *navigationController = (UINavigationController *)self.window.rootViewController;
    MasterViewController *controller = (MasterViewController *)navigationController.topViewController;
    controller.managedObjectContext = self.managedObjectContext;
    return YES;
}
``` 
我们暂且只看`controller.managedObjectContext = self.managedObjectContext;`这句，调用`managedObjectContext`的getter方法并赋给程序启动后出现的`MasterViewController`，那么我们就看一下`managedObjectContext`的getter方法：  

``` 
// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] init];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}
``` 

嗯，英文注释不错，第一次调用的时候会实例化一个`NSManagedObjectContext`对象，并使用`persistentStoreCoordinator`方法返回的`NSPersistentStoreCoordinator`对象配置上下文，最后返回新实例化的`NSManagedObjectContext`对象。  
顺藤摸瓜，我们再看看`persistentStoreCoordinator`的getter：  

``` 
// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"MyCDDemo.sqlite"];
    
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:nil error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }    
    
    return _persistentStoreCoordinator;
}
``` 
为了访问documents目录中的SQLite存储文件MyCDDemo.sqlite，还定义了一个`applicationDocumentsDirectory`方法，它的作用是获取程序documents的路径，代码如下：  

``` 
// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}
``` 
MyCDDemo.sqlite文件是在编译MyCDDemo.xcdatamodeld时生成的，同样生成的还有MyCDDemo.momd文件，后面会提到。
`NSPersistentStoreCoordinator`初始化时需要传入`managedObjectModel`。`NSPersistentStoreCoordinator`对象在添加持久存储的时候不仅需要传入存储类型，还有配置，存储文件URL，选项以及错误类型。我们使用sqlite作为存储类型，配置为nil，还记得之前叫做default的配置么？这里我们只有一个持久存储，所以配置一项不需要。如果添加存储的时候出现错误，就会进入if判断，具体处理错误的细节可以看看模版生成的注释。  
既然`NSPersistentStoreCoordinator`又用到了`managedObjectModel`，我们再看看`managedObjectModel`方法吧：  

``` 
// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"MyCDDemo" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}
``` 
依然是跟之前一样的代码风格，这次`NSManagedObjectModel`类在初始化的时候用到了MyCDDemo.momd文件，前面提到过，当你编译项目时，MyCDDemo.xcdatamodeld数据模型将被编译成MyCDDemo.momd资源，并且保存到app的Bundle目录。  

最后，在程序退出时，会调用代理`applicationWillTerminate:`  

``` 
- (void)applicationWillTerminate:(UIApplication *)application
{
    // Saves changes in the application's managed object context before the application terminates.
    [self saveContext];
}
```
它调用了`saveContext`方法：  

``` 
- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}
``` 
`managedObjectContext`对象中的数据无论怎么修改，都是发生在内存中的，需要调用`save`方法来保存到存储文件当中。  

按理说接下来应该看看`MasterViewController中`被传入的`managedObjectContext`对象是如何使用的，但在这之前，我们先运行下程序，看看这个App有什么功能：  

![](http://yulingtianxia.qiniudn.com/140353397837.png)  

再普通不过的tableview了，点击加号便可添加一条记录，内容为时间戳，回想起之前看的名称为Event的Entity，是不是想起了什么，嘿嘿。再添加了四条记录后，不妨打开sqlite文件查看下，路径为`~/Library/Application Support/iPhone Simulator/[OS version]/Applications/[appGUID]/Documents/`(Xcode 6路径改为`~/Library/Developer/CoreSimulator/Devices/[模拟器UDID]/data/Containers/Data/Application/[appGUID]/Documents/`)，目录内包含了三个文件MyCDDemo.sqlite、MyCDDemo.sqlite-shm、MyCDDemo.sqlite-wal。如上文所述，根据AppDelegate.m文件中的`persistentStoreCoordinator`方法可知，时间戳记录被存储在MyCDDemo.sqlite文件中。我用Navicat Premium将其打开：  

![](http://yulingtianxia.qiniudn.com/14035339876.png)  

![](http://yulingtianxia.qiniudn.com/140353398727.png)  

相信你对“三剑客”有了更深的理解，再附上一张图加深下印象：  

![](http://yulingtianxia.qiniudn.com/140353388879.png)  

一个`NSManagedObjectModel`对象处在`NSPersistentStoreCoordinator`对象和`NSManagedObjectContext`对象之间。Core Data根据`NSManagedObjectModel`对象确定如何将底层的持久化文件中的数据映射为`NSManagedObject`对象。一个`NSManagedObjectModel`对象用于表示数据的结构。`NSManagedObjectModel`对象也被称为对象图(object graph)。你可以简单的理解为：**在数据库sqlite文件中，一张表中的一条数据（table row）就相当于代码中的一个NSManagedObject对象，他们之间的映射是通过`NSManagedObjectModel`对象完成的**  

下面让我们进入到`MasterViewController`中来认识一下这个新出现的`NSManagedObject`“小弟”  

既然数据库中的数据最终显示在了`UITableView`上，我们撇开`MasterViewController`中其他的方法，直奔`UITableViewDataSource`协议中已经实现的那几个方法：  

``` 
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
        
        NSError *error = nil;
        if (![context save:&error]) {
             // Replace this implementation with code to handle the error appropriately.
             // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }   
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}
``` 

如果你对`UITableView`的使用很有经验，一眼就可看出数据是由`fetchedResultsController`对象提供的。即使在`tableView: cellForRowAtIndexPath:`方法中没出现`fetchedResultsController`，但是在其调用的`configureCell: atIndexPath:`方法中依然用到了`fetchedResultsController`：  

``` 
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    NSManagedObject *object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = [[object valueForKey:@"timeStamp"] description];
}
``` 
嗯看来NSManagedObject对象全都由这个fetchedResultsController提供咯，下面揭开它神秘的面纱：  

``` 
- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Event" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:@"Master"];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
	     // Replace this implementation with code to handle the error appropriately.
	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}
``` 

嗯，之前提到过，Core Data在iOS平台使用了`NSFetchedResultsController`对象来简化对提取结果和表格视图的处理。`NSFetchedResultsController`对象被惰性创建并只在表格视图数据源方法有需要时才提取数据。你会看到在`NSFetchRequest`对象的配置中，使用了Event实体，并提供了一个`NSSortDescriptor`对象以让提取结果按timeStamp进行排序。最后通过`NSFetchRequest`对象和`managedObjectContext`（在AppDelegate中传入的`NSManagedObjectContext`实例）作为参数传入`NSFetchedResultsController`的初始化方法。（`sectionNameKeyPath`参数传入nil时表示只有一个section，你会发现`NSFetchedResultsController`从数据库获取的结果跟`UITableView`需要的数据格式相同，都通过`NSIndexPath`地址来获取一条数据的内容）  
`NSFetchedResultsController`也有它的代理，将`MasterViewController`设置为其代理，这样在fetched results 发生变化时，`MasterViewController`中实现的`NSFetchedResultsControllerDelegate`方法会被调用：  

``` 
- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

/*
// Implementing the above methods to update the table view in response to individual changes may have performance implications if a large number of changes are made simultaneously. If this proves to be an issue, you can instead just implement controllerDidChangeContent: which notifies the delegate that all section and object changes have been processed. 
 
 - (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    // In the simplest, most efficient, case, reload the table view.
    [self.tableView reloadData];
}

``` 

相对于之前`UITableViewDataSource`协议方法对`NSFetchedResultsController`对象中数据的修改（通过`NSManagedObject`对象做载体），`NSFetchedResultsControllerDelegate`协议方法会在察觉到数据修改后被调用，用于产生tableview操作数据后对应的动画效果。  

可能你会觉得有些混乱，这里贴上几张图梳理下各个类的关系和结构：  

![](http://yulingtianxia.qiniudn.com/140353388301.png)  

![](http://yulingtianxia.qiniudn.com/140353389167.png)  

![](http://yulingtianxia.qiniudn.com/140353388423.png)  

![](http://yulingtianxia.qiniudn.com/140353389646.png)  

![](http://yulingtianxia.qiniudn.com/140353389047.png)  

![](http://yulingtianxia.qiniudn.com/140353388523.jpg)  


最后，找到`insertNewObject`方法，当用户尝试加入一个对象到表视图时，该方法将被调用。接着你将看到如下的处理过程：  

-   获得一个`NSManagedObjectContext`对象；
-   决定创建新对象的实体；
-   根据实体名称创建一个新的`NSManagedObject`对象并将其插入到`NSManagedObjectContext`对象；
-   对新创建的`NSManagedObject`对象设置timeStamp属性值
-   `NSManagedObjectContext`对象执行保存。  

当上下文执行保存，新的对象将被写到持久存储区中。这是如此简单！  

DetailViewController的内容比较简单，不在叙述，到此结束，新建Core Data的模版工程代码已经解析完毕了。在下一期文章中将会亲手修改代码，探索Core Data更多的使用技巧。

##总结  
Core Data框架基本的5个类：：NSPersistentStoreCoordinator、NSManagedObjectContext、NSManagedObjectModel、NSEntityDescription、NSManagedObject。  


-   NSPersistentStoreCoordinator持久化存储协调器（简称协调器）：负责从磁盘加载数据和将数据写入磁盘。协调器可以处理多种格式的数据库文件（NSPersistentStore），如二进制文件，XML文件、SQLite文件。你也可以实现自己的数据库文件格式（使用NSAtomicStore和NSIncrementalStore类），理论上你可以实现打开World或Photoshop文件的协调器。

-   NSEntityDescription实体描述（简称实体）：实体可以被看做是NSManagedObject对象的“class”。实体定义了一个NSManagedObject对象所拥有的所有属性（NSAttributeDescription）,关系（NSRelationshipDescription），提取属性（NSFetchedPropertyDescription）。

-  NSManagedObjectContext托管对象上下文（简称上下文）：上下文是内存中的一块暂存区域。查询对象（使用NSFetchRequest），创建对象，删除对象等操作都是在上下文中进行。在上下文没有保存之前，对数据的任何修改都只记录在暂存区中，不会影响磁盘上的数据。你可以创建多个上下文，但整个程序只能创建一个NSPersstentStoreCoordinator对象。

-   NSManagedObject托管对象：Core Data的核心单元。模型对象的数据被持有在NSManagedObject对象中。每一个NSManagedObject对象都对应一个实体（就像每一个对象都有一个类）

-   NSManagedObjectModel托管对象模型：NSManagedObjectModel通常被定义在一个.mom文件中，文件中保存了所有实体的定义。NSManagedObjectModel and the NS*Description 类完整定义了Core Data模型应该/可以包含的内容。
