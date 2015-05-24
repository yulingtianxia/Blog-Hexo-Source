---
layout: post
title: "Optionals and Optional Chaining in Swift"
date: 2014-06-17 20:42:17 +0800
comments: true
tags: 
- Swift

---
可选类型（`Optionals`）在Swift中用于处理值可能缺失的情况，也就是说可能存在没有值的情况。C 和 Objective-C 中并没有可选类型这个概念。但在Objective-C中，一个方法的返回值可以是一个对象或`nil`值（`nil`表示缺少一个合法对象），而对象只是针对类而言，结构体、基本C类型和枚举并不适用`nil`来表示值的缺失，对于这些类型，Objective-C 方法一般会返回一个特殊值（比如`NSNotFound`）来暗示值缺失。这种表示“值缺失”方法不统一的局面使得调用方法的程序员蛋疼了-需要针对不同情况进行处理-但随着可选类型的诞生，这种情形在Swift中得到解决，`Optionals`可以表示任意类型值的缺失。(2014-8-8更新至beta5语法)    
<!--more-->
##可选类型（Optionals）

###理论

**Xcode6beta5发布后，`Optional`的定义有了修改：**  

```
enum Optional<T> : Reflectable, NilLiteralConvertible {
    case None
    case Some(T)
    init()
    init(_ some: T)
    var hasValue: Bool { get }

    /// Haskell's fmap, which was mis-named
    func map<U>(f: (T) -> U) -> U?
    func getMirror() -> MirrorType
    static func convertFromNilLiteral() -> T?
}
```

可选类型是本质是一个枚举类型，包含两个成员：`None`和`Some`，其中`Some`成员还有一个类型为泛型`T`的关联值（Associated Values）。  

光凭猜测大约知道：当可选类型有值的时候其实是`Some`成员，并在构造器`init(_ some: T)`调用时将值存储在`Some`成员的关联值中，此时`getLogicValue()`方法返回true；当可选类型没有值的时候其实是`None`成员，并在构造器`init()`调用时将`nil`给了`None`成员，具体细节不是很清楚。   

看得出可选类型的设计借鉴了Haskell语言，至于`nil`这个字面量到底是什么：  
 
Swift 的`nil`和 Objective-C 中的`nil`并不一样。在 Objective-C 中，`nil`是一个指向不存在对象的指针。在 Swift 中，`nil`不是指针——它是一个确定的值，用来表示值缺失。任何类型的可选值都可以被设置为`nil`，不只是对象（object）类型。 

**可选类型默认值为`nil`**  

###if条件判断和强制解析

在Swift中，有时候需要把内容为数字的字符串转化成数字：  

```swift
let possibleNumber = "123"
let convertedNumber = possibleNumber.toInt()
// convertedNumber 被推测为类型 "Int?"， 或者类型 "optional Int"
```

因为Swift是类型安全的语言，为了保证转化过程中不出错，`toInt()`方法返回的是一个`Optional<Int>`(也可写成`Int?`)类型的实例。如果被转化的字符串不是一个数字（比如是“hello world”），那样`toInt()`返回的内容将不含有`Int`值。这保证了整个过程不报错，下面我们可以“优雅的”检查下`convertedNumber`是否有`Int`值：  

```
if convertedNumber != nil {
    println("convertedNumber has an integer value of \(convertedNumber!).")
}
// 输出 "123 has an integer value of 123"
```

当你确定可选类型确实包含值之后，你可以在可选的名字后面加一个感叹号（!）来获取值。这个惊叹号表示“我知道这个可选有值，请使用它。”这被称为可选值的**强制解析（forced unwrapping）**  

PS：beta5中去掉了`LogicValue`协议，并用`hasValue`替代它来存储是否有值。也就是`Optional`不会隐式转换成`Bool`，在条件判断语句中需要用`==`或`!=`来判断是否为空。苹果取消了`Optional`的隐式`Bool`值是为了防止混淆。（新手可以无视这段话，我在讲述Swift的变更史，哈哈）

###可选绑定

除了用if语句判断和强制解析来获取可选类型中的值，还可以用**可选绑定**的方式来来判断可选类型是否包含值：  

```
if let constantName = someOptional {
    statements
}
```
于是之前的例子可以可以改写为：  

```
if let actualNumber = possibleNumber.toInt() {
    println("\(possibleNumber) has an integer value of \(actualNumber)")
} else {
    println("\(possibleNumber) could not be converted to an integer")
}
// 输出 "123 has an integer value of 123"
```

如果`possibleNumber.toInt`返回的可选`Int`包含一个值，创建一个叫做`actualNumber`的新常量并将可选包含的值赋给它。它已经被可选类型包含的值初始化过，所以不需要再使用`!`后缀来获取它的值。  

有时候在程序架构中，第一次被赋值之后，可以确定一个可选类型总会有值。在这种情况下，每次都要判断和解析可选值是非常低效的，因为可以确定它总会有值。这种类型的可选状态被定义为**隐式解析可选类型**（implicitly unwrapped optionals）。把想要用作可选的类型的后面的问号（`String?`）改成感叹号（`String!`）来声明一个隐式解析可选类型。

```
let possibleString: String? = "An optional string."
println(possibleString!) // 需要惊叹号来获取值
// 输出 "An optional string."
let assumedString: String! = "An implicitly unwrapped optional string."
println(assumedString)  // 不需要感叹号
// 输出 "An implicitly unwrapped optional string."
```
你仍然可以把隐式解析可选类型当做普通可选类型来判断它是否包含值：  

```
if assumedString != nil {
    println(assumedString)
}
// 输出 "An implicitly unwrapped optional string."
```
你也可以在可选绑定中使用隐式解析可选类型来检查并解析它的值：  

```
if let definiteString = assumedString {
    println(definiteString)
}
// 输出 "An implicitly unwrapped optional string."
```
可能看到这里你会觉得隐式解析可选类型的存在意义是什么？为何不直接用普通的非可选类型呢？其实`Implicitly Unwrapped Optionals`被用于类的初始化方法中，避免循环引用:  

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

var country = Country(name: "Canada", capitalName: "Ottawa")
println("\(country.name)'s capital city is called \(country.capitalCity.name)")
// prints "Canada's capital city is called Ottawa”

```

因为编译器会将其认为默认`nil`，不需赋值就可以完成类的初始化，在例子中`capitalCity`还没被赋值时`Country`类就已经初始化并可以被引用；这样就能实现一行代码建立`Country`和`City`实例而不造成强引用循环。有关ARC的更多知识可以看看这篇[文章](http://yulingtianxia.com/blog/2014/06/17/swiftzhong-de-arc/)  

###Nil Coalescing Operator

`??`是beta5新加入的一个二元运算符，`a ?? b`相当于`a != nil ? a! : b`的简写。也就是如果`a`是有值就返回`a`的值，否则返回`b`的值。  

##可选链（Optional Chaining）
可选链（Optional Chaining）是一种可以请求和调用属性、方法及下标的过程，它的可选性体现于请求或调用的目标当前可能为空（`nil`）。如果可选的目标有值，那么调用就会成功；相反，如果选择的目标为空（`nil`），则这种调用将返回空（`nil`）。多次请求或调用可以被链接在一起形成一个链，如果任何一个节点为空（`nil`）将导致整个链失效。  

可能官方的定义不接地气，先来个例子做铺垫：  

```
class Person {
    var residence: Residence?
}

class Residence {
    var rooms = [Room]()
    var numberOfRooms: Int {
        return rooms.count
    }
    subscript(i: Int) -> Room {
        get {
            return rooms[i]
        }
        set {
            rooms[i] = newValue
        }
    }
    func printNumberOfRooms() {
        println("The number of rooms is \(numberOfRooms)")
    }
    var address: Address?
}

class Room {
    let name: String
    init(name: String) { self.name = name }
}

class Address {
    var buildingName: String?
    var buildingNumber: String?
    var street: String?
    func buildingIdentifier() -> String? {
        if buildingName != nil {
            return buildingName
        } else if buildingNumber != nil {
            return buildingNumber
        } else {
            return nil
        }
    }
}
```

人（`Person`）可能会拥有住所（`Residence`），一个住所肯定会有一些带名字的房间（`Room`），还有可能注明所在地址（`Address`）。住所还提供了获取房间数目的方法，并能通过下标访问某个房间，而地址包含了一些可选的信息。  

PS：不要嫌我墨迹，官方文档比我墨迹多了。。。  

现在我造个人（邪恶的孩子面壁思过去！），就叫john  

```
let john = Person()
```
如果我们想知道john同学家房子大不大，有几个房间啊？但是直接问不太好，万一john家里穷漂泊不定四海为家，那不就玩脱了么？

```
let roomCount = john.residence!.numberOfRooms
//将导致运行时错误
```

所以还是先问问他家有没有房子吧：  

```
if let roomCount = john.residence?.numberOfRooms {
    println("John's residence has \(roomCount) room(s).")
} else {
    println("我造john的时候没给他分房子，这可怜孩子！")
}
// 打印 "我造john的时候没给他分房子，这可怜孩子！"
```
可选链提供了一种另一种获得`numberOfRooms`的方法。利用可选链，使用`?`来代替原来`!`的位置，因为这种尝试获得`numberOfRooms`的操作有可能失败，可选链会返回`Int?`类型值。要注意的是，虽然`numberOfRooms`是非可选`Int`，这一点也成立。只要是通过可选链的请求就意味着最后`numberOfRooms`总是返回一个`Int?`而不是`Int`。  

反过来我们也可以通过可选链给属性赋值，比如当我们还不确定john有没有房子的时候就给人家房子规定好地址：  

```
let someAddress = Address()
someAddress.buildingNumber = "29"
someAddress.street = "Acacia Road"
john.residence?.address = someAddress
```
现在`john.residence`还是`nil`，所以给它的`address`属性赋值只会引起地产商的不满-赋值会失败-好在这种“不满”并不会让程序崩溃。  

我们也可以在可选链上调用方法：

```
if john.residence?.printNumberOfRooms() != nil {
    println("It was possible to print the number of rooms.")
} else {
    println("It was not possible to print the number of rooms.")
}
// 打印 "It was not possible to print the number of rooms."
```

虽然`printNumberOfRooms`方法无返回值，但是它有一个隐式的返回类型`Void`，在可选链上调用后返回类型就成了`Void?`，既然是可选类型，就可以放到if语句条件判断中啦！  

其实在可选链上给属性赋值也会返回类型为`Void?`的值，我们可以判断下返回值是否为`nil`，这样就知道赋值操作是否成功：  

```
if (john.residence?.address = someAddress) != nil {
    println("房子选址成功")
} else {
    println("地产商再次不满！")
}
// prints "地产商再次不满！"
```

博主你够了地产商快被你玩坏了，好吧换个话题：  

接下来想看看john家第一间房子名字叫啥，但却怕人家没房子遭遇尴尬，不用怕：  

```
if let firstRoomName = john.residence?[0].name {
    println("The first room name is \(firstRoomName).")
} else {
    println("连房子都没有更别提第一间房间名了！")
}
// 打印 "连房子都没有更别提第一间房间名了！"
```

在下标调用中可选链的问号直接跟在`john.residence`的后面，在下标中括号的前面，因为`john.residence`才是可选链试图获得的可选值。（关键是`Person`不一定有`residence`，但`Residence`肯定有`rooms`）  

但是如果下标的值本来就是可选值（如果`Residence`不一定有9号房间，正如Swift中的Dictionary类型，下标给定的key不一定能返回value：`subscript (key: Key) -> Value?`），那么我们在存取下标的时候需要在下标右中括号的右边标记`?`:  

```
var testScores = ["Dave": [86, 82, 84], "Tim": [79, 94, 81]]
testScores["Dave"]?[0] = 91
testScores["Tim"]?[0]++
testScores["Brian"]?[0] = 72
// the "Dave" array is now [91, 82, 84] and the "Tim" array is now [80, 94, 81]"
```
显而易见“Brian”并不存在，更别提把它当做数组并给第一个元素赋值了。华丽丽的失败。

类似前面用可选链给属性赋值，也可以给下标赋值：  

```
john.residence?[0] = Room(name: "Bathroom")
```

当然这不会成功，因为john没房子！  

造个john还玩了人家这么久，还不快给人家分套房子！（其实是为了演示后面的`Address`）  

```
let johnsHouse = Residence()
johnsHouse.rooms.append(Room(name: "Living Room"))
johnsHouse.rooms.append(Room(name: "Kitchen"))
john.residence = johnsHouse
 
if let firstRoomName = john.residence?[0].name {
    println("The first room name is \(firstRoomName).")
} else {
    println("Unable to retrieve the first room name.")
}
// prints "The first room name is Living Room."
```

现在john乔迁新居奔小康了，快问问他家地址，好串个门  

```
let johnsAddress = Address()
johnsAddress.buildingName = "The Larches"
johnsAddress.street = "Laurel Street"
john.residence!.address = johnsAddress
if let johnsStreet = john.residence?.address?.street {
    println("John's street name is \(johnsStreet).")
} else {
    println("Unable to retrieve the address.")
}
// 打印 "John's street name is Laurel Street."
```

值得注意的是`john.residence`属性是一个可选类型并且已经不为`nil`(刚刚奔小康了嘛)，因此你需要在它获取`address`属性之前使用`!`强制解析以获得它的实际值。

虽然这条可选链上有两个问号（两层可选链），但其返回类型依然是可选类型（`String?`），而不是可选类型的嵌套（`String??`即`Optional<Optional<String>>`）。你可以将多层可选链连接在一起，可以掘取模型内更下层的属性方法和下标。然而多层可选链不能再添加比已经返回的可选值更多的层。 也就是说：

**如果你试图获得的类型不是可选类型，由于使用了可选链它将变成可选类型。 如果你试图获得的类型已经是可选类型，由于可选链它也不会提高可选性。**  

前面的例子解释了如何通过可选链来获得可选类型属性值。你也可以通过可选链调用一个返回可选类型值的方法并按需链接该方法的返回值。 如上所述，`buildingIdentifier`方法在可选链调用后最终的返回值类型依然是`String? `:   

```
if let buildingIdentifier = john.residence?.address?.buildingIdentifier() {
    println("John's building identifier is \(buildingIdentifier).")
}
// 打印 "John's building identifier is The Larches."
```
如果你还想进一步对方法返回值执行可选链，将可选链问号符放在方法括号的后面：  

```
if let upper = john.residence?.address?.buildingIdentifier()?.uppercaseString {
    println("John's uppercase building identifier is \(upper).")
}
// 打印 "John's uppercase building identifier is THE LARCHES."
```
你将可选链问号符放在括号后面是因为你想要链接的可选值是`buildingIdentifier`方法的返回值，不是`buildingIdentifier`方法本身。



