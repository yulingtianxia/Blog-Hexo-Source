---
layout: post
title: "CoreData处理海量数据"
date: 2014-08-05 18:15:03 +0800
comments: true
tags: 
- Core Data

---

随着iOS8和OSX10.10的发布，Core Data也迎来了更新。这次的更新可谓是重量级的，它使得程序员能够更加直接高效的操作数据库，在处理大量数据时速度明显提升（这在以前不知有多少程序员因为Core Data批量更新数据效率之低而不得不放弃使用它）。Batch Updates可用于批量快速更新数据，Asynchronous Fetching可用于异步抓取海量数据，并可以通过`NSProgress`实现进度跟踪和取消。    
<!--more-->
##Batch Updates

在CoreData中想要更新大量数据，我们往往要将大量修改后的`NSManagedObject`加载到`NSManagedObjectContext`中并保存，这会占用大量内存，试想想在iPhone这样的内存有限的移动设备上将是个灾难，数据有可能丢失。你可能会采取批处理的方式，即一小批一小批的更新`NSManagedObject`并保存到`NSManagedObjectContext`中，但这样会花费很多时间，用户体验较差。  

为了解决这个问题，苹果在`NSManagedObjectContext`加入了一个新的方法：`executeRequest:error:`，它接受一个`NSPersistentStoreRequest`类型的参数，返回类型为`NSPersistentStoreResult`。  

关于`NSPersistentStoreRequest`有些人可能比较熟悉，它是`NSFetchRequest`、`NSSaveChangesRequest`、`NSBatchUpdateRequest`和`NSAsynchronousFetchRequest`的基类。后两个类是这次iOS8新加的，也是这篇文章将要讨论的内容。  

`NSPersistentStoreResult`是一个新加入的类，它也是一个基类，而且是抽象类，这个类作为`executeRequest:error:`返回内容的父类，相当于一个接口，它目前有两个子类：`NSPersistentStoreAsynchronousResult`和`NSBatchUpdateResult`。  

你大概猜到了，`NSBatchUpdateResult`对应着前面的`NSBatchUpdateRequest`，下面说说`NSBatchUpdateRequest`。它有点像`NSFetchRequest`：它允许你指定一个想要更新数据的实体；也可以指定一个`affectedStores`，它存储了一个接受更新请求的`NSPersistentStore`数组。（其实它是`NSPersistentStoreRequest`的属性）；它也有一个谓词属性来做更新的条件，它跟`NSFetchRequest`中的谓词一样强大和灵活，类似于SQL的where语句；它允许你指定想要更新的字段，通过`propertiesToUpdate`属性来描述字段更新，它是一个字段，key为`NSPropertyDescription`或属性名字符串，value为`NSExpression`或常量。  

接着谈谈`NSBatchUpdateResult`，它有一个`result`属性和`resultType`属性，`result`中的内容跟`resultType`有关，可能是成功或者失败，有可能是每行被更新的ID，也可能是被更新的行数。  

需要注意的是，由于`NSBatchUpdateRequest`并不会先将数据存入内存，而是直接操作数据库，所以并不会引起NSManagedObjectContext的同步更新，所以你不仅需要获取`NSBatchUpdateResult`然后刷新`NSManagedObjectContext`对应的数据和UI界面，还需要保证更新后的数据满足数据库模型上的`validation`，因为`NSManagedObjectContext`没有感知Batch Updates，一些数据验证工作就落在了程序员的身上（你需要写一段代码验证更新后的数据是合法的，用户可不希望在跑步APP上看到自己今天跑步里程是个负数）。一旦有非法数据录入数据库，下次加载并修改`NSManagedObject`的时候就会导致数据验证失败。除了上面提到的这些，还要注意Batch Updates对数据库的操作是乐观锁，也就是假定很少会发生同时存取同一块数据的情况，所以你需要制定一个合理的"merge"策略来应付因同时更新数据产生的冲突。  

Batch Updates的优势在于其效率，在处理上万条数据的时候，它执行的时间跟SQL语句执行时间相当。  

##Asynchronous Fetching


Asynchronous Fetching的加入依然是为了解决CoreData读取海量数据所带来的问题。通过使用Asynchronous Fetching，我们可以在抓取数据的同时不阻塞占用`NSManagedObjectContext`，并可以随时取消抓取行为，随时跟踪抓取数据的进度。  

设想我们平时用`NSFetchRequest`抓取数据的时候，我们会先用`NSManagedObjectContext`的`executeFetchRequest:error:`方法传入一个`NSFetchRequest`，然后请求会被发送到`NSPersistentStore`，然后执行一段时间后返回一个数组，在`NSManagedObjectContext`更新后，这个数组被当做`executeFetchRequest:error:`的返回值返回到我们这里。  

而Asynchronous Fetching则不同，当我们将一个`NSAsynchronousFetchRequest`对象传入`executeRequest:error:`方法后会立即返回一个“未来的”`NSAsynchronousFetchResult`。`NSAsynchronousFetchRequest`初始化时需要传入两个参数赋值给属性：  

1. `completionBlock`属性，允许我们在抓取完成后执行回调block；  
2. `fetchRequest`属性，类型是`NSFetchRequest`。也即是说虽然是异步抓取，其实我们用的还是以前的`NSFetchRequest`，当`NSFetchRequest`抓取结束后会更新`NSManagedObjectContext`，这也就意味着`NSManagedObjectContext`的并发类型只能是`NSPrivateQueueConcurrencyType`或`NSMainQueueConcurrencyType`。  

于是当我们用`NSAsynchronousFetchRequest`抓取数据时，我们会先用`NSManagedObjectContext`的`executeRequest:error:`方法传入一个`NSAsynchronousFetchRequest`，这个方法在`NSManagedObjectContext`上执行时，`NSManagedObjectContext`会立即制造并返回一个`NSAsynchronousFetchResult`，同时`NSAsynchronousFetchRequest`会被发送到`NSPersistentStore`。你现在可以继续编辑这个`NSManagedObjectContext`中的`NSManagedObject`，等到`NSPersistentStore`执行请求完毕时会将结果返回给`NSAsynchronousFetchResult`的`finalResult`属性，更新`NSManagedObjectContext`，执行`NSAsynchronousFetchRequest`的回调block。  

举个栗子：  

``` 
let request = NSFetchRequest(entityName: "MyEntity")
        let async = NSAsynchronousFetchRequest(fetchRequest: request){
            (id result) in
            if result.finalResult {
                //TODO..
            }
        }
``` 

Swift代码很简洁，并用了尾随闭包语法，看不懂的朋友也不用着急，知道`NSAsynchronousFetchRequest`大概的用法就行。  

之前提到过`NSAsynchronousFetchRequest`能在抓取数据的过程中跟踪进度，于是乎`NSProgress`登场了！一行代码顶十句话：  

``` 
let request = NSFetchRequest(entityName: "MyEntity")
var asyncResult:NSPersistentStoreResult!
let async = NSAsynchronousFetchRequest(fetchRequest: request){
            (id result) in
            if result.finalResult {
                //TODO..
            }
        }
let progress = NSProgress(totalUnitCount: 1)
progress.becomeCurrentWithPendingUnitCount(1)
managedObjectContext?.performBlock{
            [unowned self] in
            let error = NSErrorPointer()
            asyncResult = self.managedObjectContext?.executeRequest(async, error: error)
        }
progress.resignCurrent()
``` 
而取消获取数据只需要取消`NSProgress`就可以了！取消行为会沿着数的根节点蔓延到叶子。

``` 
progress.cancel()
``` 
可以在`cancellationHandler`属性设置取消后执行的block，这里不再多说。
