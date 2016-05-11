---
layout: post
title: "Swift中的ARC"
date: 2014-06-17 10:32:38 +0800
comments: true
tags: 
- Swift
- ARC

---
Objective-C中的ARC被Swift很好的继承下来了，本文参考自Swift文档网上的翻译，主要重点记录下Swift中的ARC与OC对比需要注意的地方。(2014-8-8更新至beta5语法)
<!--more-->
## 简介
当你每次创建一个类的新的实例的时候，ARC 会分配一大块内存用来储存实例的信息。内存中会包含实例的类型信息，以及这个实例所有相关属性的值。此外，当实例不再被使用时，ARC 释放实例所占用的内存，并让释放的内存能挪作他用。这确保了不再被使用的实例，不会一直占用内存空间。  
## 类实例之间强引用循环的产生

如果你对OC中的强引用循环很了解，可以直接跳过这节。  

但是如果两个类的实例之间互相引用，这样就产生了强引用循环。下面展示了一个不经意产生强引用循环的例子。例子定义了两个类：`Person`和`Apartment`，用来建模公寓和它其中的居民:  

```js
class Person {
    let name: String
    init(name: String) { self.name = name }
    var apartment: Apartment?
    deinit { println("\(name) is being deinitialized") }
}

class Apartment {
    let number: Int
    init(number: Int) { self.number = number }
    var tenant: Person?
    deinit { println("Apartment #\(number) is being deinitialized") }
}
```

接下来的代码片段定义了两个可选类型的变量`john`和`number73`,并分别被设定为下面的`Apartment`和`Person`的实例。这两个变量都被初始化为`nil`，并为可选的（让它们可选是为了以后能销毁，为了演示程序）：  

```
var john: Person?
var number73: Apartment?
```

现在你可以创建特定的`Person`和`Apartment`实例并将类实例赋值给`john`和`number73`变量：  

```
john = Person(name: "John Appleseed")
number73 = Apartment(number: 73)
```

在`john`和`number73`互相引用之前，它们的强引用关系是这样的：  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/referenceCycle01_2x.png)  

现在你能够将这两个实例关联在一起，这样人就能有公寓住了，而公寓也有了房客。注意感叹号是用来强制解析可选变量`john`和`number73`中的实例：  

```
john!.apartment = number73
number73!.tenant = john
```
在将两个实例联系在一起之后，强引用的关系变成了这样：  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/referenceCycle02_2x.png)  

这样即使让`john`和`number73`断开它们持有的强引用，内存中的那两个`Person`和`Apartment`实例并不会销毁，因为它们互相引用，引用计数都为1：  

```
john = nil
number73 = nil
```
当你把这两个变量设为`nil`时，没有任何一个析构函数被调用。强引用循环阻止了`Person`和`Apartment`类实例的销毁，并在你的应用程序中造成了内存泄漏。  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/referenceCycle03_2x.png)  

## 如何解决实例间强引用循环
### 弱引用
跟OC中的弱引用相似，声明属性或者变量时，在前面加上`weak`关键字表明这是一个弱引用。弱引用不会牢牢保持住引用的实例，并且不会阻止 ARC 销毁被引用的实例。因为弱引用的值会变化并可能为`nil`，所以弱引用不能是常量，必须是可选类型（Optional）。因为弱引用不会保持所引用的实例，即使引用存在，实例也有可能被销毁。因此，ARC 会在引用的实例被销毁后自动将其赋值为nil。  

下面的例子跟上面`Person`和`Apartment`的例子一致，但是有一个重要的区别。这一次，`Apartment`的`tenant`属性被声明为弱引用：  

```
class Person {
    let name: String
    init(name: String) { self.name = name }
    var apartment: Apartment?
    deinit { println("\(name) is being deinitialized") }
}
class Apartment {
    let number: Int
    init(number: Int) { self.number = number }
    weak var tenant: Person?
    deinit { println("Apartment #\(number) is being deinitialized") }
}
```
然后跟之前一样，建立两个变量（`john`和`number73`）之间的强引用，并关联两个实例：  

```
var john: Person?
var number73: Apartment?

john = Person(name: "John Appleseed")
number73 = Apartment(number: 73)

john!.apartment = number73
number73!.tenant = john
```
现在的引用关系如下：  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/weakReference01_2x.png)  

当`john`的强引用断开后，引用关系变成了这样子：  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/weakReference02_2x.png)  

因为没有强引用指向`Person`实例，它的引用计数为0，所以该实例会被销毁。因此`number73`指向的`Apartment`实例的的引用计数会变为1，因为`Person`实例销毁后，其`apartment`属性对`Apartment`实例的强引用也会断开。此时如果再断开`number73`对`Apartment`实例的强引用：  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/weakReference03_2x.png)  

`Apartment`实例因为引用计数为0，会被销毁，到此为止强引用循环被打破。  

### 无主引用
和弱引用类似，无主引用不会牢牢保持住引用的实例。和弱引用不同的是，无主引用是永远有值的（不能为`nil`）。因此，无主引用总是被定义为非可选类型（non-optional type）。你可以在声明属性或者变量时，在前面加上关键字`unowned`表示这是一个无主引用。

下面的例子定义了两个类，`Customer`和`CreditCard`，模拟了银行客户和客户的信用卡。一个客户可能有或者没有信用卡，但是一张信用卡总是关联着一个客户。所以`Customer`类的`card`属性可以为`nil`，但是`CreditCard`类的`customer`属性不能为`nil`，所以创建CreditCard实例的时候必须给`customer`属性赋值避免其为`nil`。将`customer`属性定义为无主引用，用以避免循环强引用：  

```
class Customer {
    let name: String
    var card: CreditCard?
    init(name: String) {
        self.name = name
    }
    deinit { println("\(name) is being deinitialized") }
}
class CreditCard {
    let number: Int64
    unowned let customer: Customer
    init(number: Int64, customer: Customer) {
        self.number = number
        self.customer = customer
    }
    deinit { println("Card #\(number) is being deinitialized") }
}
var john: Customer?
john = Customer(name: "John Appleseed")
john!.card = CreditCard(number: 1234_5678_9012_3456, customer: john!)
```
关联两个实例后，引用关系如下：  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/unownedReference01_2x.png)

由于`customer`的无主引用，当你断开`john`变量持有的强引用时，再也没有指向`Customer`实例的强引用了：  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/unownedReference02_2x.png)  

于是`Customer`实例被销毁，这样又导致没有强引用指向`CreditCard`实例，最后`CreditCard`实例也被销毁了，这样说明强引用循环被打破了。  
### 无主引用以及隐式解析可选属性
下面的例子定义了两个类，`Country`和`City`，每个类将另外一个类的实例保存为属性。在这个模型中，每个国家必须有首都，而每一个城市必须属于一个国家。为了实现这种关系，`Country`类拥有一个`capitalCity`属性，而`City`类有一个`country`属性：  

```
class Country {
    let name: String
    let capitalCity: City!
    init(name: String, capitalName: String) {
        self.name = name
        self.capitalCity = City(name: capitalName, country: self)
    }
}
class City {
    let name: String
    unowned let country: Country
    init(name: String, country: Country) {
        self.name = name
        self.country = country
    }
}
```
在这种场景中，两个属性都必须有值，并且初始化完成后不能为`nil`。在这种场景中，需要一个类使用无主属性，而另外一个类使用隐式解析可选属性。

隐式解析可选(`Implicitly Unwrapped Optionals`)被用于类的初始化方法中，避免循环引用，因为编译器会将其认为默认`nil`，不需赋值就可以完成类的初始化，在例子中一旦`name`属性被赋值后(但`capitalCity`还没被赋值时)`Country`类就已经初始化并且自身（`self`）可以被引用；这样就能实现一行代码建立`Country`和`City`实例而不造成强引用循环。  

```
var country = Country(name: "Canada", capitalName: "Ottawa")
println("\(country.name)'s capital city is called \(country.capitalCity.name)")
// prints "Canada's capital city is called Ottawa"
```
使用隐式解析可选值的意义在于满足了两个类构造函数的需求。`capitalCity`属性在初始化完成后，能像非可选值一样使用和存取同时还避免了循环强引用。

### 总结
`Person`和`Apartment`的例子展示了两个属性的值都允许为`nil`，并会潜在的产生循环强引用。这种场景最适合用弱引用来解决。  

`Customer`和`CreditCard`的例子展示了一个属性的值允许为`nil`，而另一个属性的值不允许为`nil`，并会潜在的产生循环强引用。这种场景最适合通过无主引用来解决。  

`Country`和`City`的例子展示了两个属性的值都不允许为`nil`，并会潜在的产生循环强引用。这种场景需要一个类使用无主属性，而另外一个类使用隐式解析可选属性。  
## 闭包引起的强引用循环
强引用循环还会发生在当你将一个闭包赋值给类实例的某个属性，并且这个闭包体中又使用了实例。这个闭包体中可能访问了实例的某个属性，例如`self.someProperty`，或者闭包中调用了实例的某个方法，例如`self.someMethod`。这两种情况都导致了闭包 “捕获" `self`，因为闭包也是引用类型，从而产生了强引用循环。在Swift中闭包如果想使用外部的实例，不必像OC中的Block那样在外部实例前加`__block`加以修饰，而是可以直接用“值捕获”的方式捕获到闭包外面的实例。Swift 会决定捕获引用还是拷贝值，并负责管理内存释放。    

Swift 有如下要求：只要在闭包内使用self的成员，就要用self.someProperty或者self.someMethod（而不只是someProperty或someMethod）。这提醒你可能会不小心就捕获了self。  

在OC中也存在`Block`中引用`self`或`self`的属性而导致`self`被`Block` retain，进而产生引用循环，这也是为什么代理属性都被声明为`weak`的原因。  

  

下面的例子为你展示了当一个闭包引用了self后是如何产生一个循环强引用的。例子中定义了一个叫HTMLElement的类，用一种简单的模型表示 HTML 中的一个单独的元素：  

```
class HTMLElement {

    let name: String
    let text: String?

    lazy var asHTML: () -> String = {
        if let text = self.text {
            return "<\(self.name)>\(text)</\(self.name)>"
        } else {
            return "<\(self.name) />"
        }
    }

    init(name: String, text: String? = nil) {
        self.name = name
        self.text = text
    }

    deinit {
        println("\(name) is being deinitialized")
    }

}
```

`HTMLElement`定义了一个`lazy`属性`asHTML`。这个属性引用了一个闭包，将`name`和`text`组合成 HTML 字符串片段。该属性是`() -> String`类型，或者可以理解为“一个没有参数，返回`String`的函数”。因为该闭包无参数并可推断出返回值类型，所以采取了简写，省略了关键字`in`和闭包的参数和返回值类型声明。  

`asHTML`声明为`lazy`属性，因为只有当元素确实需要处理为HTML输出的字符串时，才需要使用`asHTML`。也就是说，在默认的闭包中可以使用`self`，因为只有当初始化完成以及`self`确实存在后，才能访问`lazy`属性。  

下面的代码展示了如何用HTMLElement类创建实例并打印消息  

```
var paragraph: HTMLElement? = HTMLElement(name: "p", text: "hello, world")
println(paragraph!.asHTML())
// prints"hello, world"
```

不幸的是，上面写的HTMLElement类产生了类实例和asHTML默认值的闭包之间的循环强引用。循环强引用如下图所示：  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/closureReferenceCycle01_2x.png)  

虽然闭包多次使用了`self`，它只捕获`HTMLElement`实例的一个强引用。如果设置`paragraph`变量为`nil`，打破它持有的`HTMLElement`实例的强引用，`HTMLElement`实例和它的闭包都不会被销毁，也是因为强引用循环  
## 解决闭包引起的循环强引用
Swift 提供了一种优雅的方法来解决这个问题，称之为闭包捕获列表（closuer capture list）  
### 定义捕获列表
捕获列表放置在闭包参数列表和返回类型之前，列表中每项都是由`weak`或`unowned`关键字和实例的引用（如self或someInstance）成对组成。每项都通过逗号分开写在方括号中。  

```
lazy var someClosure: (Int, String) -> String = {
    [unowned self] (index: Int, stringToProcess: String) -> String in
    // closure body goes here
}
```
如果闭包没有指定参数列表或者返回类型，则可以通过上下文推断，那么可以捕获列表放在闭包开始的地方，跟着是关键字`in`：  

```
lazy var someClosure: () -> String = {
    [unowned self] in
    // closure body goes here
}
```
### 捕获列表中的弱引用和无主引用
当捕获引用有时可能会是`nil`时，将闭包内的捕获定义为弱引用。  
当闭包和捕获的实例总是互相引用时并且总是同时销毁时，将闭包内的捕获定义为无主引用。  
如果捕获的引用绝对不会置为`nil`，应该用无主引用，而不是弱引用。  

前面的`HTMLElement`例子中，无主引用是正确的解决循环强引用的方法。这样编写`HTMLElement`类来避免循环强引用：  

```
class HTMLElement {

    let name: String
    let text: String?

    lazy var asHTML: () -> String = {
        [unowned self] in
        if let text = self.text {
            return "<\(self.name)>\(text)</\(self.name)>"
        } else {
            return "<\(self.name) />"
        }
    }

    init(name: String, text: String? = nil) {
        self.name = name
        self.text = text
    }

    deinit {
        println("\(name) is being deinitialized")
    }

}
```

上面的例子只是多了一个捕获列表并增加关键字`in`，使用捕获列表后引用关系如下图所示：  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/closureReferenceCycle02_2x.png)  

这一次，闭包以无主引用的形式捕获`self`，并不会持有`HTMLElement`实例的强引用。如果将`paragraph`赋值为`nil`，`HTMLElement`实例将会被销毁，并能看到它的析构函数打印出的消息。  

```
paragraph = nil
// prints "p is being deinitialized"
```

