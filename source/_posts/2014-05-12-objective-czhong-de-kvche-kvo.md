---
layout: post
title: "Objective-C中的KVC和KVO"
date: 2014-05-12 12:02:32 +0800
comments: true
tags: 
- Objective-C
- 设计模式

---

本文讲述了使用Cocoa框架中的KVC和KVO，实现观察者模式  

<!--more-->

##KVC

键/值编码中的基本调用包括`-valueForKey:`和`-setValue:forKey:`。以字符串的形式向对象发送消息，这个字符串是我们关注的属性的关键。  
`valueForKey:`首先查找以键`-key`或`-isKey	`命名的getter方法。如果不存在getter方法（假如我们没有通过`@synthesize`提供存取方法），它将在对象内部查找名为`_key`或`key`的实例变量。  
对于KVC，Cocoa自动放入和取出标量值（int，float和struct）放入NSNumber或NSValue中；当使用`-setValue:ForKey:`时，它自动将标量值从这些对象中取出。仅KVC具有这种自动包装功能，常规方法调用和属性语法不具备该功能。  
`-setValue:ForKey:`的工作方式和`-valueForKey:`相同。它首先查找名称的setter方法，如果不存在setter方法，它将在类中查找名为`_key`或`key`的实例变量。  

使用KVC访问属性的代价比直接使用存取方法要大，所以只在需要的时候才用。  

最简单的 KVC 能让我们通过以下的形式访问属性：  

```objc
@property (nonatomic, copy) NSString *name;
```

取值：   

```
NSString *n = [object valueForKey:@"name"];
```
设定：  

```
[object setValue:@"Daniel" forKey:@"name"];
```
值得注意的是这个不仅可以访问作为对象属性，而且也能访问一些标量（例如 `int` 和 `CGFloat`）和 struct（例如 `CGRect`）。Foundation 框架会为我们自动封装它们。举例来说，如果有以下属性：  

```
@property (nonatomic) CGFloat height;
```
我们可以这样设置它：  

```
[object setValue:@(20) forKey:@"height"];
```

有关KVC的更多用法，参看下面的文章：  

http://blog.csdn.net/omegayy/article/details/7381301  
http://blog.csdn.net/wzzvictory/article/details/9674431  
http://objccn.io/issue-7-3/  



##KVO

KVO是Cocoa提供的一种称为键－值观察的机制，对象可以通过它得到其他对象特性属性的变更通知。这种机制在MVC模式的场景中很重要，因为它让视图对象可以经由控制器层观察模型对象的变更。  
这一机制基于`NSKeyValueObserving`非正式协议，Cocoa通过这个协议为所有遵守协议的对象提供了一种自动化的属性观察能力。要实现自动观察，参与KVO的对象需要符合KVC的要求和存取方法，也可以手动实现观察者通知，也可以两者都保留。  

KVO是Cocoa框架使用**观察者模式**的一种途径。  

设置一个属性的观察者需要三步，理解这些步骤可以更清楚的知道KVO的工作框图  
1. 首先看看你当前的场景如果使用KVO是否更妥当，比如，当一个实例的某个具体属性有任何变更的时候，另一个实例需要被通知。  

![](http://7ni3rk.com1.z0.glb.clouddn.com/140353389577.jpg)  

比如，BankObject中的`accountBalance`属性有任何变更时，某个PersonObject对象都要觉察到。  
2. 这个PersonObject对象必须注册成为BankObject的`accountBalance`属性的观察者，可以通过发送`addObserver:forKeyPath:options:context:`消息来实现。  

![](http://7ni3rk.com1.z0.glb.clouddn.com/140353389319.jpg)  

注意：`addObserver:forKeyPath:options:context:`方法在你指定的两个实例间建立联系，而不是在两个类之间。  
3. 为了回应变更通知，观察者必须实现`observeValueForKeyPath:ofObject:change:context:`方法。这个方法的实现决定了观察者如何回应变更通知。你可以在这个方法里自定义如何回应被观察属性的变更。  

![](http://7ni3rk.com1.z0.glb.clouddn.com/140353388989.jpg)    
4. 当一个被观察属性的值以符合KVO方式变更或者当它依赖的键变更时，` observeValueForKeyPath:ofObject:change:context:`方法会被自动执行。  

![](http://7ni3rk.com1.z0.glb.clouddn.com/140353389524.jpg)  

###Registering for Key-Value Observing

####注册成为观察者
你可以通过发送`addObserver:forKeyPath:options:context:`消息来注册观察者  

```objc
- (void)registerAsObserver {
    /*
     Register 'inspector' to receive change notifications for the "openingBalance" property of
     the 'account' object and specify that both the old and new values of "openingBalance"
     should be provided in the observe… method.
     */
    [account addObserver:inspector
             forKeyPath:@"openingBalance"
                 options:(NSKeyValueObservingOptionNew |
                            NSKeyValueObservingOptionOld)
                    context:NULL];
}
```

`inspector`注册成为了`account`的观察者，被观察属性的KeyPath是`@"openingBalance"`，也就是`account`的`openingBalance`属性，`NSKeyValueObservingOptionNew`和`NSKeyValueObservingOptionOld`选项分别标识在观察者接收通知时`change`字典对应入口提供更改后的值和更改前的值。更简单的办法是用 `NSKeyValueObservingOptionPrior` 选项，随后我们就可以用以下方式提取出改变前后的值：(`change`是个字典，详细介绍请看下节)  

```
id oldValue = change[NSKeyValueChangeOldKey];
id newValue = change[NSKeyValueChangeNewKey];
```
  

我们常常需要当一个值改变的时候更新 UI，但是我们也要在第一次运行代码的时候更新一次 UI。我们可以用 KVO 并添加 `NSKeyValueObservingOptionInitial` 的选项 来一箭双雕地做好这样的事情。这将会让 KVO 通知在调用`-addObserver:forKeyPath:...` 到时候也被触发。  
当我们注册 KVO 通知的时候，我们可以添加 `NSKeyValueObservingOptionPrior` 选项，这能使我们在键值改变之前被通知。这和`-willChangeValueForKey:`被触发的时间相对应。  
如果我们注册通知的时候附加了 `NSKeyValueObservingOptionPrior` 选项，我们将会收到两个通知：一个在值变更前，另一个在变更之后。变更前的通知将会在 `change` 字典中有不同的键。  

`context`是一个指针，当`observeValueForKeyPath:ofObject:change:context:`方法执行时`context`会提供给观察者。`context`可以是C指针或者一个对象引用，既可以当作一个唯一的标识来分辨被观察的变更，也可以向观察者提供数据。  

####接收变更通知

当被观察的属性变更时，观察者会接到`observeValueForKeyPath:ofObject:change:context:`消息，所有的观察者都必须实现这个方法。  
观察者会被提供触发通知的对象和`keyPath`，一个包含变更详细信息的字典，还有一个注册观察者时提供的`context`指针。  

```
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary *)change
                       context:(void *)context {
 
    if ([keyPath isEqual:@"openingBalance"]) {
        [openingBalanceInspectorField setObjectValue:
            [change objectForKey:NSKeyValueChangeNewKey]];
    }
    /*
     Be sure to call the superclass's implementation *if it implements it*.
     NSObject does not implement the method.
     */
    [super observeValueForKeyPath:keyPath
                         ofObject:object
                           change:change
                           context:context];
}
```
关于change参数，它是一个字典，有五个常量作为它的键：  

```
NSString *const NSKeyValueChangeKindKey;  
NSString *const NSKeyValueChangeNewKey;  
NSString *const NSKeyValueChangeOldKey;  
NSString *const NSKeyValueChangeIndexesKey;  
NSString *const NSKeyValueChangeNotificationIsPriorKey;  
```

**NSKeyValueChangeKindKey**  
指明了变更的类型，值为“NSKeyValueChange”枚举中的某一个，类型为NSNumber。  

```
enum {
   NSKeyValueChangeSetting = 1,
   NSKeyValueChangeInsertion = 2,
   NSKeyValueChangeRemoval = 3,
   NSKeyValueChangeReplacement = 4
};
typedef NSUInteger NSKeyValueChange;
```
**NSKeyValueChangeNewKey**  
如果 `NSKeyValueChangeKindKey`的值为 `NSKeyValueChangeSetting`，并且 `NSKeyValueObservingOptionNew`选项在注册观察者时也指定了，那么这个键的值就是属性变更后的新值。  
对于 `NSKeyValueChangeInsertion`或者`NSKeyValueChangeReplacement`，如果 `NSKeyValueObservingOptionNew`选项在注册观察者时也指定了，这个键的值是一个数组，其包含了插入或替换的对象。  
**NSKeyValueChangeOldKey**  
如果 `NSKeyValueChangeKindKey`的值为 `NSKeyValueChangeSetting`，并且 `NSKeyValueObservingOptionOld`选项在注册观察者时也指定了，那么这个键的值就是属性变更前的旧值。  
对于  `NSKeyValueChangeRemoval` 或者`NSKeyValueChangeReplacement`，如果 `NSKeyValueObservingOptionOld`选项在注册观察者时也指定了，这个键的值是一个数组，其包含了被移除或替换的对象。  
**NSKeyValueChangeIndexesKey**  
如果 `NSKeyValueChangeKindKey`的值为`NSKeyValueChangeInsertion`, `NSKeyValueChangeRemoval`, 或者 `NSKeyValueChangeReplacement`，这个键的值是一个`NSIndexSet`对象，包含了增加，移除或者替换对象的index。  
**NSKeyValueChangeNotificationIsPriorKey**  
如果注册观察者时`NSKeyValueObservingOptionPrior`选项被指明了，此通知会在变更发生前被发出。其类型为`NSNumber`，包含的值为`YES`。我们可以像以下这样区分通知是在改变之前还是之后被触发的：  

```
if ([change[NSKeyValueChangeNotificationIsPriorKey] boolValue]) {
    // 改变之前
} else {
    // 改变之后
}
```
  

####移除观察者  
你可以通过发送`removeObserver:forKeyPath:`消息来移除观察者，你需要指明观察对象和路径。  

```
- (void)unregisterForChangeNotification {
    [observedObject removeObserver:inspector forKeyPath:@"openingBalance"];
}
```
上面的代码将`openingBalance`属性的观察者`inspector`移除，移除后观察者再也不会收到`observeValueForKeyPath:ofObject:change:context:`消息。  
在移除观察者之前，如果`context`是一个对象的引用，那么必须保持对它的强引用直到观察者被移除。  

###KVO Compliance（KVO兼容）

有两种方法可以保证变更通知被发出。自动发送通知是`NSObject`提供的，并且一个类中的所有属性都默认支持，只要是符合KVO的。一般情况你使用自动变更通知，你不需要写任何代码。  
人工变更通知需要些额外的代码，但也对通知发送提供了额外的控制。你可以通过重写子类` automaticallyNotifiesObserversForKey:`方法的方式控制子类一些属性的自动通知。  

####Automatic Change Notification（自动通知）

下面代码中的方法都能导致KVO变更消息发出  

```
// Call the accessor method.
[account setName:@"Savings"];
 
// Use setValue:forKey:.
[account setValue:@"Savings" forKey:@"name"];
 
// Use a key path, where 'account' is a kvc-compliant property of 'document'.
[document setValue:@"Savings" forKeyPath:@"account.name"];
 
// Use mutableArrayValueForKey: to retrieve a relationship proxy object.
Transaction *newTransaction = <#Create a new transaction for the account#>;
NSMutableArray *transactions = [account mutableArrayValueForKey:@"transactions"];
[transactions addObject:newTransaction];
```

####Manual Change Notification（手动通知）

下面的代码为`openingBalance`属性开启了人工通知，并让父类决定其他属性的通知方式。  

```
+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)theKey {
 
    BOOL automatic = NO;
    if ([theKey isEqualToString:@"openingBalance"]) {
        automatic = NO;
    }
    else {
        automatic = [super automaticallyNotifiesObserversForKey:theKey];
    }
    return automatic;
}
```

要实现人工观察者通知，你要执行在变更前执行` willChangeValueForKey:`方法，在变更后执行`didChangeValueForKey:`方法：  

```
- (void)setOpeningBalance:(double)theBalance {
    [self willChangeValueForKey:@"openingBalance"];
    _openingBalance = theBalance;
    [self didChangeValueForKey:@"openingBalance"];
}
```
为了使不必要的通知最小化我们应该在变更前先检查一下值是否变了：  

```
- (void)setOpeningBalance:(double)theBalance {
    if (theBalance != _openingBalance) {
        [self willChangeValueForKey:@"openingBalance"];
        _openingBalance = theBalance;
        [self didChangeValueForKey:@"openingBalance"];
    }
}
```
如果一个操作导致了多个键的变化，你必须嵌套变更通知：  

```
- (void)setOpeningBalance:(double)theBalance {
    [self willChangeValueForKey:@"openingBalance"];
    [self willChangeValueForKey:@"itemChanged"];
    _openingBalance = theBalance;
    _itemChanged = _itemChanged+1;
    [self didChangeValueForKey:@"itemChanged"];
    [self didChangeValueForKey:@"openingBalance"];
}
```
在to-many关系操作的情形中，你不仅必须表明key是什么，还要表明变更类型和影响到的索引。变更类型是一个 `NSKeyValueChange`值，被影响对象的索引是一个 `NSIndexSet`对象。  
下面的代码示范了在to-many关系`transactions`对象中的删除操作：  

```
- (void)removeTransactionsAtIndexes:(NSIndexSet *)indexes {
    [self willChange:NSKeyValueChangeRemoval
        valuesAtIndexes:indexes forKey:@"transactions"];
 
    // Remove the transaction objects at the specified indexes.
 
    [self didChange:NSKeyValueChangeRemoval
        valuesAtIndexes:indexes forKey:@"transactions"];
}
```

###Registering Dependent Keys（注册依赖键）

有一些属性的值取决于一个或者多个其他对象的属性值，一旦某个被依赖的属性值变了，依赖它的属性的变化也需要被通知。  

####To-one Relationships

要自动触发 to-one关系，有两种方法：重写`keyPathsForValuesAffectingValueForKey:`方法或者定义名称为`keyPathsForValuesAffecting<Key>`的方法。  

例如一个人的全名是由姓氏和名子组成的：  

```
- (NSString *)fullName {
    return [NSString stringWithFormat:@"%@ %@",firstName, lastName];
}
```
一个观察`fullName`的程序在`firstName`或者`lastName`变化时也应该接收到通知。  

一种解决方法是重写`keyPathsForValuesAffectingValueForKey:`方法来表明`fullname`属性是依赖于`firstname`和`lastname`的：  

```
+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key {
 
    NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
 
    if ([key isEqualToString:@"fullName"]) {
        NSArray *affectingKeys = @[@"lastName", @"firstName"];
        keyPaths = [keyPaths setByAddingObjectsFromArray:affectingKeys];
    }
    return keyPaths;
}
```
相当于在影响`fullName`值的`keypath`中新加了两个key：`lastName`和`firstName`，很容易理解。  

另一种实现同样结果的方法是实现一个遵循命名方式为`keyPathsForValuesAffecting<Key>`的类方法，`<Key>`是依赖于其他值的属性名（首字母大写），用上面代码的例子来重新实现一下：  

```
+ (NSSet *)keyPathsForValuesAffectingFullName {
    return [NSSet setWithObjects:@"lastName", @"firstName", nil];
}
```

有时在类别中我们不能添加`keyPathsForValuesAffectingValueForKey:`方法，因为不能再类别中重写方法，所以这时可以实现`keyPathsForValuesAffecting<Key> `方法来代替。  

注意：你不能在`keyPathsForValuesAffectingValueForKey:`方法中设立to-many关系的依赖，相反，你必须观察在to-many集合中的每一个对象中相关的属性并通过亲自更新他们的依赖来回应变更。下一节将会讲述对付此情形的策略。  

####To-many Relationships

`keyPathsForValuesAffectingValueForKey:`方法不支持包含to-many关系的`keypath`。比如，假如你有一个`Department`类，它有一个针对`Employee`类的to-many关系（雇员），`Employee`类有`salary`属性。你希望`Department`类有一个`totalSalary`属性来计算所有员工的薪水，也就是在这个关系中`Department`的`totalSalary`依赖于所有`Employee`的`salary`属性。你不能通过实现`keyPathsForValuesAffectingTotalSalary`方法并返回`employees.salary`。  

有两种解决方法：  
1. 你可以用KVO将parent（比如`Department`）作为所有children（比如`Employee`）相关属性的观察者。你必须在把child添加或删除到parent时也把parent作为child的观察者添加或删除。在`observeValueForKeyPath:ofObject:change:context:`方法中我们可以针对被依赖项的变更来更新依赖项的值： 


```
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
 
    if (context == totalSalaryContext) {
        [self updateTotalSalary];
    }
    else
    // deal with other observations and/or invoke super...
}
 
- (void)updateTotalSalary {
    [self setTotalSalary:[self valueForKeyPath:@"employees.@sum.salary"]];
}
 
- (void)setTotalSalary:(NSNumber *)newTotalSalary {
 
    if (totalSalary != newTotalSalary) {
        [self willChangeValueForKey:@"totalSalary"];
        _totalSalary = newTotalSalary;
        [self didChangeValueForKey:@"totalSalary"];
    }
}
 
- (NSNumber *)totalSalary {
    return _totalSalary;
}
```

2.如果你在使用Core Data，你可以在应用的notification center中将parent注册为它的 managed object context的观察者，parent应该回应相应的变更通知，这些通知是children以类似KVO的形式发出的。  

其实这也是Objective-C中利用Cocoa实现观察者模式的另一种途径：`NSNotificationCenter`  

###调试KVO  

你可以在 lldb 里查看一个被观察对象的所有观察信息。  

```
(lldb) po [observedObject observationInfo]
```
这会打印出有关谁观察谁之类的很多信息。  

这个信息的格式不是公开的，我们不能让任何东西依赖它，因为苹果随时都可以改变它。不过这是一个很强大的排错工具。  
