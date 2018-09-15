---
layout: post
title: "初识Core Data(2)"
date: 2014-05-02 20:17:04 +0800
comments: true
tags: 
- Objective-C
- Core Data

---

本文内容：  

+ 自定义NSManagedObject
+ 使用数据模型设计器
+ 探究Core Data在SQLite中的实现  

推荐先阅读上一篇文章：[初识Core Data(1)](http://yulingtianxia.com/blog/2014/05/01/chu-shi-core-data-1/)  

**文章所使用的项目代码可以到[这里](https://github.com/yulingtianxia/MyCDDemo)下载**  

在[下一篇文章](http://yulingtianxia.com/blog/2014/07/03/chu-shi-core-data-3/)里，我将会通过教程的方式，讲述如何用Swift结合CoreData的NSFetchedResultsController写一个小Demo-[HardChoice](http://hardchoice.yulingtianxia.com)  

<!--more-->

## 自定义NSManagedObject
在上一篇教程中我们每条数据都是通过`NSManagedObject`对象装载，通过KVC方式使用`valueForKey：`方法访问对象属性，但是使用KVC要比使用访问器效率低一点。 只在必要时使用KVC，比如你需要动态选择key或keyPath。  

```objc
[newEmployee setValue:@”Stig” forKey:firstName];
[aDepartment setValue:@1000 forKeyPath:manager.salary];
```

下面我们将自定义`NSManagedObject`类，通过对它的继承拓展，使得我们有自己的Event类，并通过访问器方法代替KVC方式来访问对象的属性。  
按CMD+N或者在可视化建模工具下选择菜单中Editor->Create NSManagedObject Subclass：  

![](http://yulingtianxia.com/resources/140353399425.png)  

![](http://yulingtianxia.com/resources/140353399917.png)  

选中需要子类化的Entity（当然我们只有一个Event，自动勾选了）：  

![](http://yulingtianxia.com/resources/140353400261.png)  

最后点击Create，于是Event类就创建好了，可以看到属性timeStamp已经自动生成了，并且实现为`@dynamic`  

熟悉Objective-C语法的都知道`@synthesize`实际的意义就是自动生成属性的setter和getter方法。  

`@dynamic`就是要告诉编译器，代码中用`@dynamic`修饰的属性，其getter和setter方法会在程序运行的时候或者用其他方式动态绑定，以便让编译器通过编译。其主要的作用就是用在`NSManagerObject`对象的属性声明上，由于此类对象的属性一般是从Core Data的属性中生成的，Core Data框架会在程序运行的时候为此类属性生成getter和setter方法。  

好的，下面我们改写以前的代码，这次我们将使用Event类的对象完成以前的任务：  

在MasterViewController.m文件中加入`#import "Event.h"`，然后将`insertNewObject:`方法替换如下  

```
- (void)insertNewObject:(id)sender
{
    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
    NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
    Event *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
    
    // If appropriate, configure the new managed object.
    // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
//    [newManagedObject setValue:[NSDate date] forKey:@"timeStamp"];
    newManagedObject.timeStamp = [NSDate date];
    // Save the context.
    NSError *error = nil;
    if (![context save:&error]) {
         // Replace this implementation with code to handle the error appropriately.
         // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
}
```
嗯，英文注释还告诉我们通常你应该用访问器方法呢，还说但是现在在这用KVC就避免了向模板添加自定义类的需求，真逗啊  
依此类推，更改`prepareForSegue: sender:`方法：    

```
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        Event *object = [[self fetchedResultsController] objectAtIndexPath:indexPath];
        [[segue destinationViewController] setDetailItem:object];
    }
}
```

还有`configureCell: atIndexPath:`方法：  

```
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    Event *object = [self.fetchedResultsController objectAtIndexPath:indexPath];
//    cell.textLabel.text = [[object valueForKey:@"timeStamp"] description];
    cell.textLabel.text = [object.timeStamp description];
}
```
相应地我们也可以针对`DetailViewController`进行改造：  

DetailViewController.h:  

```
#import <UIKit/UIKit.h>
@class Event;
@interface DetailViewController : UIViewController

@property (strong, nonatomic) Event *detailItem;

@property (weak, nonatomic) IBOutlet UILabel *detailDescriptionLabel;
@end
```

DetailViewController.m:  

```
#import "DetailViewController.h"
#import "Event.h"
@interface DetailViewController ()
- (void)configureView;
@end

@implementation DetailViewController

#pragma mark - Managing the detail item

- (void)setDetailItem:(Event *)newDetailItem
{
    if (_detailItem != newDetailItem) {
        _detailItem = newDetailItem;
        
        // Update the view.
        [self configureView];
    }
}

- (void)configureView
{
    // Update the user interface for the detail item.

    if (self.detailItem) {
//        self.detailDescriptionLabel.text = [[self.detailItem valueForKey:@"timeStamp"] description];
        self.detailDescriptionLabel.text = [self.detailItem.timeStamp description];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    [self configureView];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
```
这部分比较简单，就不详细解释了，运行程序，跟以前一样（不截图了）  

如果想复用`MasterViewController`里面那些代码，需要做些大改动，具体可以参看[更轻量的 View Controllers](http://objccn.io/issue-1-1/)这篇文章  

## 使用数据模型设计器  

点击MyCDDemo.xcdatamodeld文件进入数据模型设计器，点击下方的加号（Add Enity），添加一个Enity，将其名字改为Person。然后添加name和sex属性，类型为string，需要注意的是属性名需要首字母小写，而且我们无需像往常给数据库建表一样为其添加ID字段，因为Core Data中你不需要任何类型的唯一标识Id，也不需要处理表连接。Core Data将在后台自动处理。你所需要做的就是定义对象间的关系。Core Data框架将在后台决定如何生成最佳的底层机制。  

与实体名一样，属性的命名也有很多的要求和约定。属性名不能以大写字母开头，不能包含空格，一般都是单数。对于Boolean类型属性，你应该遵循Objective-C实例变量的约定,比如指定一个CustomerOrder对象是否已经发货，那么应该命名属性为shipped，而不是isShipped、hasShipped等。

关于Core Data属性类型，我从网上摘抄了一段比较全面的解释：  

+ Undefined选项值是新创建的属性的默认类型；如果属性类型为undefined，项目将无法通过编译。


+ Integer 16/32/64只表示整数，没有小数点。所以如果10除以3，你将会得到3，而余数1会丢失。Integer 16/32/64之间唯一的区别是所表示的数值范围不同。因为Core Data使用符号数，所以起始范围是负数，而不是0。

	+ Integer 16 数值范围：-32768~32767；

	+ Integer 32 数值范围：-2147483648~2147483647；

	+ Integer 64 数值范围：–9223372036854775808~9223372036854775807。

	标准整型数的最大值和最小值可以在stdint.h中找到。在任何类文件中输入INT32_MAX,选中右击，然后选择Jump To Definition，你将看到许多最大值最小值定义。**实体的属性的类型是Integer 16/32/64，当创建此实体对应的NSManagedObject子类时，属性最终的类型将会是NSNumber**。


+ Double和Float可以认为是有小数部分的整数。它们都是基于二进制数值系统，在CPU运算时很可能会发生舍入误差。比如1/5，如果使用十进制数值系统，可以精确表示为0.2.但在二进制数值系统中，只能表示一个大概，在小数部分你会得到大量数字。**所以不要使用Integer、Double、Float表示货币值。**计算精度越高则越加趋于准确值，但内存占用也会越大。一个Float数使用32bit进行存储，一个Double数使用64bit。它们都使用科学计数法进行存储，所以一个数包含尾数和指数部分。

	在iOS中，最大的Float值是340282346638528859811704183484516925440.000000，最小的Float值是340282346638528859811704183484516925440.000000Double和Float都有一个符号位。而Double比Float的数值范围更大。

	当你决定该选择Float还是Double时，想一下你的属性是否真的需要超过Float提供的7位精度，如果不是，你应该选择Float，因为它更加匹配64bit的iPhone 5S底层处理器。除此之外，如果你想增加浮点数的计算速度而精度并没有严格要求，Float也是最佳选择。**实体的属性的类型是Float或Double，当创建此实体对应的NSManagedObject子类时，属性最终的类型将会是NSNumber。**

+ **Decimal（十进制）是处理货币值和其他需要十进制场合下最佳选择**，Decimal提供了优秀的计算精度，也消除了计算过程中的舍入误差。因为CPU的本地数制是二进制，所以CPU在处理十进制数时，开销会多一点。**实体的属性的类型是Decimal，当创建此实体对应的NSManagedObject子类时，属性最终的类型将会是NSDecimalNumber。**当你使用NSDecimalNumber执行计算时(如加减乘除计算)，为了保证计算精度，你只能使用它提供的内建方法。更多关于NSDecimalNumber可参见这里。

+ String类型和Objective-C中的NSString类似，用于保存字符数组。当生成实体对应的NSManagedObject子类时，String属性被表示为NSString。

+ Boolean数据类型被用于表示YES/NO值。当生成实体对应的NSManagedObject子类时，Boolean数据类型会被表示为NSNumber。所以为了获取布尔值，你需要想NSNumber对象发送boolValue消息。

+ Date类型是自解释类型。用来存储日期和时间。**当生成实体对应的NSManagedObject子类时，Date类型会被表示为NSDate。**

+ Binary Data用来表示照片，音频，或一些BLOB类型数据("Binary Large OBjects" such as image and sound data)。**当生成实体对应的NSManagedObject子类时，Binary Data数据类型会被表示为NSData。**

+ Transformable属性类型用于存储一个Objective-C对象。该属性类型允许你存储任何类的实例，比如你使用Transformable属性表示UIColor。**当生成NSManagedObject子类时，Transformable类型会被表示为id。**对于id对象的保存和解档需要使用一个NSValueTransformer的实例或子类的实例。由该类负责属性值与NSData之间的转换。但这也相当的简单，尤其是当属性值的类型已经实现了NSCoding协议，此时系统会自动提供一个默认的NSValueTransformer实例来完成归档和解档。  

![](http://yulingtianxia.com/resources/140353400282.png)  

选择一个属性，在右侧的Data Model Inspector中可以对属性进行更为详细的设置，而且这些设置项会根据你所设置的属性类型不同而不同，大致分为以下几类：  

+	Transient（瞬时）选项表示属性不会存储到持久化存储文件中。Transient通常用在属性的值是由其他属性计算或合成而来（比如fullName属性是根据Persion类实例的firstName和lastName拼接而来）。
+   Optional（可选）选项表示当前属性的值允许为空。如果将属性指定为Optional，那么即使属性的值为空，实体的NSManagedObject实例也可被保存。如果该值是必选的（不选中Optional则为必选），如果属性值为空，NSManagedObject对象上下文将拒绝保存这个属性值不完整的NSManagedObject对象（当你尝试并保存上下文，你将接收到一个NSError对象）。所有的属性最初的状态都是Optinal。
+   Indexed选项表示底层的持久化存储文件应该为该属性生成一个索引；如果你使用基于多个属性的查询条件来提取对象，指定此类属性为Indexed，可以大幅提高提取速度。
+   Reg.Ex是Regular Expression的缩写，主要是用来验证属性值是否匹配特定的模式。此选项只对String类型有效。
+   Validation可以保证非法数据不被保存进持久化存储文件中。数值属性类型（Integer 16/32/64、Float、Double、Decimal）都有maximum和minimum最大值最小值设定。你也可以对String类型设置最大长度和最小长度。或对Date类型设置日期范围。不过最好的做法是当用户向UITextField中输入数据时就开始验证数据，而非等到向上下文发送save消息才验证数据。
+ 除了Transformable和Binary Data类型以外，Default适用于所有属性类型。它被用来配置属性的默认值。
+   Allows External Storage允许大尺寸的二进制数据可以保存在持久化存储文件的外部。当你保存如照片，音频或视频时，建议是选中该选项， 这样Core Data就会对大于1MB的数据保存在持久化存储文件的外部。  

如果你细心的话，会发现无论是属性还是实体等选项，右侧的Data Model Inspector经常会出现User Info一栏。  
在managed object model中很多元素，比如entities, attributes,和 relationships，有一个相关联的用户信息字典。你可以在用户信息字典中以键值对的形式放入你想要的任何信息。这里常用的信息有实体的版本详情，还有fetched property中谓词（predicate）用到的值。  

说了一大堆，再添加两个实体吧：Teacher和Student，都继承自Person：  

![](http://yulingtianxia.com/resources/140353400755.png)  

![](http://yulingtianxia.com/resources/140353401739.png)  

点击右下方的Editor Style切换到Graph模式：  

![](http://yulingtianxia.com/resources/140353401953.png)  

选中Teacher，长按Add Attribute会弹出所有的选项（同样你也可以试试长按Add Enity），选择Add Relationship，添加一个关系，命名为students，Type为To Many，目标为Student（一个老师教很多学生）：  

![](http://yulingtianxia.com/resources/140353402308.png)  

![](http://yulingtianxia.com/resources/14035340227.png)  

我们再尝试一种添加关系的新方法：把以前在Teacher中建立的students删除，选中Student，按住Ctrl，鼠标拖至Teacher，这样一个双向的关系就建立起来了：  

![](http://yulingtianxia.com/resources/140353402879.png)  

分别编辑双方的关系，Tpye都是To Many：  

![](http://yulingtianxia.com/resources/140353402596.png)  

用上一节中提到的方法，建立这三个新建的Entity的`NSManagedObject`子类：  

![](http://yulingtianxia.com/resources/14035340286.png)  

因为创建顺序的问题，当Student创建的时候还不知道有`Teacher`类，于是其生成的一些方法将Teacher默认为`NSManagedObject`类：  

```
#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Student : NSManagedObject

@property (nonatomic, retain) NSNumber * grade;
@property (nonatomic, retain) NSSet *teachers;
@end

@interface Student (CoreDataGeneratedAccessors)

- (void)addTeachersObject:(NSManagedObject *)value;
- (void)removeTeachersObject:(NSManagedObject *)value;
- (void)addTeachers:(NSSet *)values;
- (void)removeTeachers:(NSSet *)values;

@end
```

而Teacher类创建的时候已经有了`Student`类，就不会出现上面的问题：  

```
#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Student;

@interface Teacher : NSManagedObject

@property (nonatomic, retain) NSString * course;
@property (nonatomic, retain) NSSet *students;
@end

@interface Teacher (CoreDataGeneratedAccessors)

- (void)addStudentsObject:(Student *)value;
- (void)removeStudentsObject:(Student *)value;
- (void)addStudents:(NSSet *)values;
- (void)removeStudents:(NSSet *)values;

@end
```

虽然`Teacher`类认识`Student`类，因为它已经创建了，但是此时Persion类还没有创建，于是此时`Student`类和`Teacher`类继承的依然是`NSManagedObject`，这不是我们想要的结果。  
解决方法是重新生成下这三个Entity对应的`NSManagedObject`子类，并覆盖原有的文件：  

```
#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "Person.h"

@class Teacher;

@interface Student : Person

@property (nonatomic, retain) NSNumber * grade;
@property (nonatomic, retain) NSSet *teachers;
@end

@interface Student (CoreDataGeneratedAccessors)

- (void)addTeachersObject:(Teacher *)value;
- (void)removeTeachersObject:(Teacher *)value;
- (void)addTeachers:(NSSet *)values;
- (void)removeTeachers:(NSSet *)values;

@end
```

你会发现多了一个`CoreDataGeneratedAccessors`类别，这个类别中的方法是Core Data框架根据你在数据模式编辑器中设置的实体关系自动生成的，你不需要实现它们，Core Data会在运行时实现这些方法  
如果你偏要想看看其实现机理，在右下方的代码片段库中选择“Core Data To-Many Relationship Accessors”并拖拽到代码中  

![](http://yulingtianxia.com/resources/140353403195.png)  

生成的代码如下：  

```
- (void)add<#CapitalizedRelationshipName#>Object:(<#relationship destination class#> *)value
{    
    NSSet *changedObjects = [NSSet setWithObject:value];
    [self willChangeValueForKey:@"<#relationshipName#>" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:@"<#relationshipName#>"] addObject:value];
    [self didChangeValueForKey:@"<#relationshipName#>" withSetMutation:NSKeyValueUnionSetMutation usingObjects:changedObjects];
}

- (void)remove<#CapitalizedRelationshipName#>Object:(<#relationship destination class#> *)value
{
    NSSet *changedObjects = [NSSet setWithObject:value];
    [self willChangeValueForKey:@"<#relationshipName#>" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
    [[self primitiveValueForKey:@"<#relationshipName#>"] removeObject:value];
    [self didChangeValueForKey:@"<#relationshipName#>" withSetMutation:NSKeyValueMinusSetMutation usingObjects:changedObjects];
}

- (void)add<#CapitalizedRelationshipName#>:(NSSet *)value
{    
    [self willChangeValueForKey:@"<#relationshipName#>" withSetMutation:NSKeyValueUnionSetMutation usingObjects:value];
    [[self primitiveValueForKey:@"<#relationshipName#>"] unionSet:value];
    [self didChangeValueForKey:@"<#relationshipName#>" withSetMutation:NSKeyValueUnionSetMutation usingObjects:value];
}

- (void)remove<#CapitalizedRelationshipName#>:(NSSet *)value
{
    [self willChangeValueForKey:@"<#relationshipName#>" withSetMutation:NSKeyValueMinusSetMutation usingObjects:value];
    [[self primitiveValueForKey:@"<#relationshipName#>"] minusSet:value];
    [self didChangeValueForKey:@"<#relationshipName#>" withSetMutation:NSKeyValueMinusSetMutation usingObjects:value];
}
```

我们需要将<#Capitalized relationship name#>, <#Relationship destination class#> 和 <#Relationship name#>替换为我们定义的连接名，对照下前面`CoreDataGeneratedAccessors`类别中的方法名，你就会明白了  

同样以前标记为`@dynamic`的属性，其实现原理如下：  

```
- (<#propertyObjectType#> *)<#propertyName#>
{
    [self willAccessValueForKey:@"<#propertyName#>"];
    <#propertyObjectType#> *value = [self primitiveValueForKey:@"<#propertyName#>"];
    [self didAccessValueForKey:@"<#propertyName#>"];
    return value;
}
            
- (void)set<#CapitalizedPropertyName#>:(<#propertyObjectType#> *)value
{
    [self willChangeValueForKey:@"<#propertyName#>"];
    [self setPrimitiveValue:value forKey:@"<#propertyName#>"];
    [self didChangeValueForKey:@"<#propertyName#>"];
}
```
现在，我们并不需要知道他们的实现方法是如何被动态生成的，估计是用到了block或者delegate。  

## 探究Core Data在SQLite中的实现  

在上一节中我们创建了`Person`，`Teacher`和`Student`三个Entity和对应的`NSManagedObject`子类，下面我们需要在代码中对其进行“实战部署”，并观察它们是如何在SQLite数据库中保存的，这样更有利于理解Core Data机制。  

为了简单测试，我直接在MasterViewController.m文件中的`insertNewObject:`方法中加入测试代码（其实关于测试应该利用好Xcode自带的单元测试工具[XCTest](http://yulingtianxia.com/blog/2014/04/28/iosdan-yuan-ce-shi-%5Bnil%5Dxctest/)，我这里为了方便操作，用了以前添加数据的`insertNewObject:`方法，关于工程初始代码的讲解，请看我之前的一篇[教程](http://yulingtianxia.com/blog/2014/05/01/chu-shi-core-data-1/)）  

```
- (void)insertNewObject:(id)sender
{
    NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
    NSEntityDescription *entity = [[self.fetchedResultsController fetchRequest] entity];
    Event *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:[entity name] inManagedObjectContext:context];
    
    // If appropriate, configure the new managed object.
    // Normally you should use accessor methods, but using KVC here avoids the need to add a custom class to the template.
//    [newManagedObject setValue:[NSDate date] forKey:@"timeStamp"];
    newManagedObject.timeStamp = [NSDate date];
    //新加的测试代码
    Student *aStudent = [NSEntityDescription insertNewObjectForEntityForName:@"Student" inManagedObjectContext:context];
    aStudent.name = @"LiLei";
    aStudent.sex = @"male";
    aStudent.grade = @1;
    Teacher *aTeacher = [NSEntityDescription insertNewObjectForEntityForName:@"Teacher" inManagedObjectContext:context];
    aTeacher.name = @"MissGao";
    aTeacher.sex = @"female";
    aTeacher.course = @"English";
    [aTeacher addStudentsObject:aStudent];
    
    
    // Save the context.
    NSError *error = nil;
    if (![context save:&error]) {
         // Replace this implementation with code to handle the error appropriately.
         // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    
    
}
```

我们建立了一名叫LiLei的一年级男生和一名叫MissGao的教英语的女教师，并将LiLei同学添加到高老师的学生名单中。  

运行程序，打开MyCDDemo.sqlite文件，查看表结构：  

![](http://yulingtianxia.com/resources/140353403982.png)  

你会发现虽然Student和Teacher继承Person，但是Person表里面竟然也有grade和course字段

点击程序中的加号来添加一条数据：  

![](http://yulingtianxia.com/resources/140353403912.png)  

查看ZPERSON，Z_3TEACHERS，Z_PRIMARYKEY表内容：  

![](http://yulingtianxia.com/resources/140353404264.png)  

![](http://yulingtianxia.com/resources/140353404745.png)  

![](http://yulingtianxia.com/resources/140353405697.png)  

这次一目了然了：   

ZPERSON表存储了子类所有字段数据，其Z_ENT字段标志着这条数据的类型，Z_ENT与类型名Z_NAME的映射关系储存在Z_PRIMARYKEY表中，而Z_3TEACHERS存储的则是ZPERSON表中数据项之间的关系，也就是之前我们建立的学生和老师的对应关系，其原理是将ZPERSON表中的Z_PK字段内容两个一组对应起来，这样就相当于把ZPERSON表中两条数据项关联起来了。之前我们在代码中只将LiLei同学添加到了MissGao老师的学生列表中，但是Core Data已经自动维护起了关系，让MissGao也存在于LiLei的老师列表中。Core Data把底层的数据库封装起来，通过简单的操作让程序员更高校的管理数据，所以SQLite这部分我们只是了解下就可以了。  




