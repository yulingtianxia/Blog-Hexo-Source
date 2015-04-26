---
layout: post
title: "初识Core Data(3)"
date: 2014-07-03 10:28:28 +0800
comments: true
tags: 
- Swift
- Core Data

---
在Swift发布后，我尝试用Swift和Core Data做了一个小Demo，名字叫“[HardChoice](http://hardchoice.yulingtianxia.com)”。它用于帮助人们随机生成一个问题的结果，当然结果是预设好的，并可以加入权值。本文将通过这个Demo来进一步阐述Core Data的知识。  

本文包含以下内容：  

- 建立数据模型
- Swift与Objective-C桥接
- NSFetchedResultsController
- UITextField键盘响应
- 随机选择算法

<!--more-->
你可以在[GitHub](https://github.com/yulingtianxia/HardChoice)上下载HardChoice的代码  

在没弄懂Core Data的基础知识之前，我建议你先阅读我之前的两篇博文：  

[初识Core Data(1)](http://yulingtianxia.com/blog/2014/05/01/chu-shi-core-data-1/)  
[初识Core Data(2)](http://yulingtianxia.com/blog/2014/05/02/chu-shi-core-data-2/)  

如果你不懂Swift也没关系，只要了解OC和Core Data，总是能看懂的  

在写代码前先了解下我们要做什么：  
![](http://yulingtianxia.qiniudn.com/140435701469.png)
![](http://yulingtianxia.qiniudn.com/1404357012.png)  

先在第一个页面添加问题（吃啥？），然后点击问题进入到第二个添加选项（鸭子，蛋，猪）的页面。每个选项左边是选项名，右边是该选项的权值。摇动手机就能随机从所有选项中选出答案（就像第二张图那样）。  
##建立数据模型
还是像以前那样新建一个Master-Detail Application，勾选Use Core Data选项，语言选择Swift，然后Xcode会自动生成一个具有`UITableView`的Demo，这些内容之前说过。下面我们需要打开xcdatamodeld文件来建立我们的数据模型：  

![](http://yulingtianxia.qiniudn.com/140436356516.png)  

`Question`这个实体只具有一个属性，那就是问题内容`content`，类型为`String`；`Choice`实体有一个类型为`String`的`name`属性和一个类型为`Integer32`的`weight`属性，分别代表问题选项的名字和权重。  

下面我们来建立`Question`和`Choice`这两个实体之间的关系：  

假设每个问题都对应多个选项，也可以没有选项：  

![](http://yulingtianxia.qiniudn.com/14043675716.png)  

`Optional`被打钩是因为问题可以没有任何选项，在Tpye那里我们选择`To Many`  

相反，每个选项一定会对应一个问题，并且是唯一的问题：  

![](http://yulingtianxia.qiniudn.com/140436793089.png)  

`Optional`那里不打钩是为了避免关系的目标为空，在`Tpye`那里我们选择了`To One`

**关于`Delete Rule`的选择**  

下面会通过部门与员工的例子来阐述`Delete Rule`的用法  

- **`Deny`** 如果关系指向的目标仍然有对象，那么关系的源对象就不会被删除，比如你想删除一个部门，必须先确保该部门所有员工已经调到其他部门（或被解雇），否则这个部门就不会被删除。
- **`Nullify`** 将被删除对象反向关系的目标设为null，比如如果你删除了一个部门，那么将这个部门所有成员的department关系目标设为null。需要注意的是员工的department关系应该被勾选为Optional，或者是在删除部门之后马上给该部门员工设置一个新的部门。  
- **`Cascade`** 顾名思义它会传递删除命令，删除一个对象会导致这个对象关系中所指向的所有目标对象也被删除。比如如果你删除了一个部门那么这个部门所有员工都会被立即删除。
- **`No Action`** 无为而治。比如如果你删除了一个部门，那么这个部门底下的所有员工什么都不知道，他们还以为自己还属于这个部门。

回到我们的例子，因为`Question`指向`Choice`的`choices`关系具有从属的性质，问题被删除后`choices`所指向的选项也应该被删除，所以`choices`关系中的`Delete Rule`我们选择`Cascade`；而`Choice`指向`Question`的`question`关系中`Delete Rule`被设置成了`Nullify`，也就是解除了`Question`与这个`Choice`的关系，并且我们之前已经设置`Question`的`choices`关系设置为`Optional`来满足`Nullify`这一选项的要求。  

**注意：每当你修改过数据模型后，需要将以前生成好的APP删除后再重新Run一下，这样才不会发生错误。这是因为手动删除APP会连同将其数据一起删除，然后重新Run一下会将新的数据表结构安装在模拟器或真机上**  

如果你对建立数据模型的过程生疏，建议回到[初识Core Data(2)](http://yulingtianxia.com/blog/2014/05/02/chu-shi-core-data-2/)中复习下“使用数据模型设计器”一节  

##Swift与Objective-C桥接

在使用Xcode6 Beta2生成`NSManagedObject`子类的时候，生成的代码依然是Objective-C的代码（即使我的工程是用Swift语言建立的），这就涉及到在Swift工程中调用Objective-C类的问题。苹果给我们提供了一个比较简单的解决方案。在你向工程中加入OC文件时，Xcode会自动弹出消息问你是否需要生成一个桥接头文件（“工程名-Bridging-Header.h”），然后我们在这个头文件中加入想要在Swift中调用的OC类的头文件：  

``` objc
//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "Question.h"
#import "Choice.h"
#import "CustomIOS7AlertView.h"
``` 

`Question`和`Choice`这两个类是用之前数据模型中同名实例创建的`NSManagedObject`子类，`CustomIOS7AlertView`类是本项目用到的一个自定义AlertView（iOS7之后苹果不再允许自定义`UIAlertView`了）  

这样在Swift文件中不用`import`任何东西就可以直接使用上面被引入的OC类了  

有关Swift和OC在同一项目中混合使用的方法详见[这里](https://github.com/CocoaChina-editors/Welcome-to-Swift/blob/master/Using%20Swift%20with%20Cocoa%20and%20Objective-C/03Mix%20and%20Match/Swift%20and%20Objective-C%20in%20the%20Same%20Project.md)  

##NSFetchedResultsController

在[初识Core Data(1)](http://yulingtianxia.com/blog/2014/05/01/chu-shi-core-data-1/)中我们提到过`NSFetchedResultsController`的作用，简单地说，`NSFetchedResultsController`的作用就是有效率的管理从CoreData获取请求的数据结果，并将结果提供给`UITableView`作为数据源。  

在`MasterViewController.swift`文件中，Xcode生成了两个`NSFetchedResultsController`属性：一个只读计算属性`fetchedResultsController`和一个可选存储属性`_fetchedResultsController`，通过两者搭配来实现setter，这里不再多说，将计算属性`fetchedResultsController`的定义替换如下：  

``` js

	var fetchedResultsController: NSFetchedResultsController {
        if _fetchedResultsController != nil {
            return _fetchedResultsController!
        }
        
        let fetchRequest = NSFetchRequest()
        // Edit the entity name as appropriate.
        let entity = NSEntityDescription.entityForName("Question", inManagedObjectContext: self.managedObjectContext)
        fetchRequest.entity = entity
        
        // Set the batch size to a suitable number.
        fetchRequest.fetchBatchSize = 20
        
        // Edit the sort key as appropriate.
        let sortDescriptor = NSSortDescriptor(key: "content", ascending: true)
        let sortDescriptors = [sortDescriptor]
        
        fetchRequest.sortDescriptors = sortDescriptors
        
        // Edit the section name key path and cache name if appropriate.
        // nil for section name key path means "no sections".
        let aFetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: self.managedObjectContext, sectionNameKeyPath: nil, cacheName: "Master")
        aFetchedResultsController.delegate = self
        _fetchedResultsController = aFetchedResultsController
        
    	var error: NSError? = nil
    	if !_fetchedResultsController!.performFetch(&error) {
    	     // Replace this implementation with code to handle the error appropriately.
    	     // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
             //println("Unresolved error \(error), \(error.userInfo)")
    	     abort()
    	}
        
        return _fetchedResultsController!
    }
``` 

`NSFetchRequest`对象描述了从数据持久层获取数据的标准，也就是相当于SQL中的from和where等条件语句，它是初始化`NSFetchedResultsController`的必要参数之一，因为它规定了从`NSManagedObjectContext`实例中获取什么样的数据。  

![](http://img41.wal8.com/img41/425047_20140623222918/140353389167.png)  

`NSFetchRequest`的属性`NSEntityDescription`，`predicate`和`sortDescriptors`分别对应着SQL中的from，where和order by语句，只不过`NSFetchRequest`把复杂的SQL语句进行了简化，查抄条件和排序方法更加灵活。  

在上面的`fetchedResultsController`属性中我们设置了`NSFetchRequest`实例：获取所有`Question`实体对应的数据，并将结果按照`content`属性的升序排列。  

`init(fetchRequest: NSFetchRequest!, managedObjectContext context: NSManagedObjectContext!, sectionNameKeyPath: String!, cacheName name: String!)`是`NSFetchedResultsController`的指定构造器，除了刚才提到的`fetchRequest`参数外，还需传入一个必要参数`managedObjectContext`，在这里我们传入的`managedObjectContext`是来自`AppDelegate`的`managedObjectContext`属性。有关`NSManagedObjectContext`的知识参见[初识Core Data(1)](http://yulingtianxia.com/blog/2014/05/01/chu-shi-core-data-1/)，这里不再赘述。**当构造器执行结束后，你就不能再修改`NSFetchedResultsController`的`fetchRequest`属性了**。  

`sectionNameKeyPath`参数是用来指定抓取数据结果的`section`信息的，这样`UITableView`的`section`信息此时已经预编译好了。因为我们的程序只需要一个`section`，所以只需传入`nil`；`cacheName`参数用于指定缓存`section`预编译信息的文件名，我们不需要缓存`section`信息，所以传入`nil`。  

当执行`performFetch(error: NSErrorPointer) -> Bool`方法成功后，你可以通过`NSFetchedResultsController`的`fetchedObjects`属性来获取数据结果，如果为`UITableView`提供数据，可以用`objectAtIndexPath(indexPath: NSIndexPath!) -> AnyObject!`方法来更加便捷的将数据与`NSIndexPath`对接上。在我们的例子中，会把数据结果转化为`NSManagedObject`的子类`Question`或`Choice`类：  

``` 
	func configureCell(cell: UITableViewCell, atIndexPath indexPath: NSIndexPath) {
        let object = self.fetchedResultsController.objectAtIndexPath(indexPath) as Question
        cell.textLabel.text = object.content
    }
``` 

下面修改`insertNewObject`方法来添加新的`Question`：  

``` 
	var addAV = CustomIOS7AlertView()
	func insertNewObject(sender: AnyObject) {
        let textField = UITextField(frame:CGRectMake(0,0,290,50))
        textField.becomeFirstResponder()
        textField.placeholder = "question"
        textField.keyboardType = .Default
        textField.returnKeyType = .Done
        textField.delegate = self
        addAV.containerView = textField
        addAV.buttonTitles = ["OK","Cancel"]
        addAV.delegate = self
        addAV.useMotionEffects = true
        addAV.show()
        
    }
``` 

有了添加`Question`功能，当然还会有修改功能：  

``` 
	var modifyAV = CustomIOS7AlertView()
	func modifyObject(indexPath:NSIndexPath){
        let question = self.fetchedResultsController.objectAtIndexPath(indexPath) as Question
        let textField = UITextField(frame:CGRectMake(0,0,290,50))
        textField.becomeFirstResponder()
        textField.placeholder = "question"
        textField.keyboardType = .Default
        textField.returnKeyType = .Done
        textField.delegate = self
        modifyAV.containerView = textField
        modifyAV.buttonTitles = ["OK","Cancel"]
        modifyAV.delegate = self
        modifyAV.useMotionEffects = true
        (modifyAV.containerView as UITextField).text = question.content
        modifyAV.show()
    }
``` 

`CustomIOS7AlertView`是一个第三方的开源AlertView，它允许我们自定义AlertView的内容，并提供了`CustomIOS7AlertViewDelegate`协议来用于按钮点击的回调，我们将这两个`CustomIOS7AlertView`实例的`delegate`属性都设置为`self`，然后在`MasterViewController`中的实现协议中唯一的方法`customIOS7dialogButtonTouchUpInside(alertView:AnyObject!, clickedButtonAtIndex buttonIndex:Int)`：  

``` 
	func customIOS7dialogButtonTouchUpInside(alertView:AnyObject!, clickedButtonAtIndex buttonIndex:Int){
        switch buttonIndex{
            case 0:
            let context = self.fetchedResultsController.managedObjectContext
            let entity = self.fetchedResultsController.fetchRequest.entity
            var newManagedObject:Question!
            let av = alertView as CustomIOS7AlertView
            if addAV == av{
                newManagedObject = NSEntityDescription.insertNewObjectForEntityForName(entity.name, inManagedObjectContext: context) as Question
            }
            if modifyAV == av{
                newManagedObject = self.fetchedResultsController.objectAtIndexPath(selectedIndexPath) as Question
            }
            // If appropriate, configure the new managed object.
            // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
            newManagedObject.content = (av.containerView as UITextField).text
            
            // Save the context.
            var error: NSError? = nil
            if !context.save(&error) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                //println("Unresolved error \(error), \(error.userInfo)")
                abort()
            }
            alertView.close()
            default:
            alertView.close()
        }
    }
``` 

当用户点击`alertView`的OK按钮时，判断`alertView`对象是`addAV`还是`modifyAV`，然后对应通过不同途径（新插入到`ManagedObjectContext`还是从`ManagedObjectContext`中取出）产生`Question`实例`newManagedObject`，最后的结果会保存回`ManagedObjectContext`中，最后关闭`alertView`。  

添加`Question`时使用的`insertNewObjectForEntityForName(entityName: String!, inManagedObjectContext context: NSManagedObjectContext!) -> AnyObject!`方法是一个配置和添加实体，并返回该实体对应`NSManagedObject`子类（在这里是`Question`类）的便捷方法，这是一个很强大的类方法，我们无需知道创建`Question`类的细节就能创建并添加一个`Question`实例到`NSManagedObjectContext`中，在保存前我们还可以对这个方法返回的`Question`实例做修改，然后再通过`save(error: NSErrorPointer) -> Bool`方法保存。  

修改`Question`的过程其实就是先通过`objectAtIndexPath(indexPath: NSIndexPath!) -> AnyObject!`方法取出数据请求结果当中的某一项并转换成`Question`对象，对其进行修改后再保存。在界面中通过点击cell右侧带有字母i的蓝色圆圈来修改`Question`内容：  

![](http://yulingtianxia.qiniudn.com/140438530596.png)  

上图的中的蓝色圆圈是`AccessoryButton`，需要在IB中设置`TableViewCell`的`Identifier`为`QuestionCell`，`Accessory`为`Detail Disclosure`，这样我们就能在`UITableViewDelegate`的`tableView(tableView: UITableView!, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath!)`方法中响应`AccessoryButton`了：  

``` 
	override func tableView(tableView: UITableView!, accessoryButtonTappedForRowWithIndexPath indexPath: NSIndexPath!){
        selectedIndexPath = indexPath
        modifyObject(indexPath)
        
    }
``` 

导航栏右侧的添加`Question`按钮已经通过下面的代码配置了响应函数：  

``` 
let addButton = UIBarButtonItem(barButtonSystemItem: .Add, target: self, action: "insertNewObject:")
self.navigationItem.rightBarButtonItem = addButton
``` 
在`UITableViewDelegate`中删除`Question`的代码如下：  

``` 
	override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            let context = self.fetchedResultsController.managedObjectContext
            context.deleteObject(self.fetchedResultsController.objectAtIndexPath(indexPath) as NSManagedObject)
                
            var error: NSError? = nil
            if !context.save(&error) {
                // Replace this implementation with code to handle the error appropriately.
                // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                //println("Unresolved error \(error), \(error.userInfo)")
                abort()
            }
        }
    }
``` 

这里多说一嘴，如果你想打印出错误信息的话，不要直接反注释那行`println`代码，还需要在`error`后加上感叹号，因为`error`是可选类型，需要强制解析：  

``` 
println("Unresolved error \(error!), \(error!.userInfo)")
``` 


##UITextField键盘响应

在将`UITextField`实例赋值给`CustomIOS7AlertView`的`containerView`属性前需要先让其获取当前焦点，并将`UITextField`的`delegate`属性设为`self`：  

``` 
	var addAV = CustomIOS7AlertView()
	func insertNewObject(sender: AnyObject) {
        let textField = UITextField(frame:CGRectMake(0,0,290,50))
        textField.becomeFirstResponder()//获取当前焦点
        textField.placeholder = "question"
        textField.keyboardType = .Default
        textField.returnKeyType = .Done
        textField.delegate = self
        addAV.containerView = textField
        addAV.buttonTitles = ["OK","Cancel"]
        addAV.delegate = self
        addAV.useMotionEffects = true
        addAV.show()
        
    }
``` 

然后让`MasterViewController`遵循`UITextFieldDelegate`协议，并实现下面两个协议中的方法：  

``` 
	func textFieldDidBeginEditing(textField: UITextField!){
        let animationDuration:NSTimeInterval  = 1
        var frame = self.view.frame;
        frame.origin.y-=116
        frame.size.height+=116
        self.view.frame = frame;
        UIView.animateWithDuration(animationDuration){
            self.view.frame = frame;
        }
    }
    
    func textFieldShouldEndEditing(textField: UITextField!) -> Bool{
        let animationDuration:NSTimeInterval  = 1
        var frame = self.view.frame;
        frame.origin.y+=116;
        frame.size.height-=116;
        self.view.frame = frame;
        //self.view移回原位置
        UIView.animateWithDuration(animationDuration){
            self.view.frame = frame;
        }
        textField.resignFirstResponder();
        return true
    }
``` 

这里我将键盘高度硬编码为116，当`UITextField`开始编辑时获取焦点键盘弹出，背景上移；当其结束编辑时键盘消失，背景移回原位。  

在Xcode6 beta2中的模拟器不是很好使，经常不能弹出键盘，这里给出的代码有很多疏漏，只提供个参考，主要是处理`UITextField`代理的思想  

##随机选择算法

`DetailViewController`的内容跟`MasterViewController`内容很像，最大的区别在于多了一个从`Choice`数据中随机抽选的一个方法。因为是通过摇一摇的方式来触发随机算法，所以我们重载`motionBegan(motion: UIEventSubtype, withEvent event: UIEvent!)`方法来响应手机摇动： 

``` 
override func motionBegan(motion: UIEventSubtype, withEvent event: UIEvent!) {
        if motion == .MotionShake{
            
            let count = self.fetchedResultsController.fetchedObjects.count
            var arr = fetchedResultsController.fetchedObjects
            var sum:Int = 0
            for object : AnyObject in arr{
                sum+=(object as Choice).weight.integerValue
            }
            if sum>0{
                var lucknum = arc4random()%UInt32(sum)
//                println("\(lucknum)")
                var num = 0
                var n:UInt32 = 0
                while lucknum>0{
                    if lucknum <= n{
                        break
                    }
                    else{
                        num++
                        lucknum-=n
                        if num>=count{
                            break
                        }
                        n = UInt32((arr[num] as Choice).weight.integerValue)
                    }
                }
//                println("\(num)")
                var alertView = UIAlertView()
                alertView.alertViewStyle = .Default
                alertView.title = "恭喜"
                alertView.message = "\(detailItem!.content)的答案是：\n\((arr[num] as Choice).name)"
                alertView.addButtonWithTitle("OK")
                alertView.show()
            }
            
        }
    }
``` 

前面提到过`NSFetchedResultsController`对象在执行`performFetch(error: NSErrorPointer) -> Bool`方法后会将获取的数据存在`fetchedObjects`数组中，上面这段代码首先获取该问题对应的选项数量，并通过加权运算得到总的权重，然后通过随机数算法生成一个幸运数字，最后计算幸运数字落在哪个选项上。  





