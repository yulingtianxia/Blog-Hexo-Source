---
layout: post
title: "Initialization in Swift"
date: 2014-06-24 09:50:23 +0800
comments: true
tags: 
- Swift

---
本文参考自Swift文档，主要包括以下内容：  

- 简介
- 自定义构造过程
- 默认构造器
- 值类型的构造器代理
- 类的继承和构造过程
- 可失败构造器
- 必需构造器
- 通过闭包和函数来设置属性的默认值  

(2014-8-8更新至beta5语法)  
(2014-10-24更新至Swift1.1)
<!--more-->

## 简介
构造过程是为了使用某个类、结构体或枚举类型的实例而进行的准备过程。这个过程包含了为实例中的每个属性设置初始值和为其执行必要的准备和初始化任务。  

Swift中的构造器不像Objective-C那样有返回值，但是跟C++有点像：所有的构造器都以`init`命名，用参数列表来区分各个构造器    

```swift
struct Fahrenheit {
    var temperature = 16.0
    init() {
        temperature = 32.0
    }
}
var f = Fahrenheit()
```

`Fahrenheit`是一个结构体，与类一样，Swift中的值类型也有构造器和普通方法。上面的代码先是定义了`temperature`属性的默认值，然后又在构造器中将其赋值，最后`temperature`属性的值为32。对于`temperature`这种存储型属性，无论定义默认值还是在构造器中赋值，最终它们实现的效果是一样的。  

**给存储型类型属性赋默认值或在初始构造器中设置初始值时，此属性的属性观察者不会被调用**

## 自定义构造过程
你可以定义一些带参数的构造器  

```
struct Celsius {
    var temperatureInCelsius: Double = 0.0
    init(fromFahrenheit fahrenheit: Double) {
        temperatureInCelsius = (fahrenheit - 32.0) / 1.8
    }
    init(fromKelvin kelvin: Double) {
        temperatureInCelsius = kelvin - 273.15
    }
}
```
构造器的参数也跟Swift中的方法定义（注意不是函数）一样，也分内部和外部参数名。上面代码中两个构造器外部参数名不同，调用构造器的时候也是通过外部参数名来区分的：  

```
let boilingPointOfWater = Celsius(fromFahrenheit: 212.0)
// boilingPointOfWater.temperatureInCelsius 是 100.0
let freezingPointOfWater = Celsius(fromKelvin: 273.15)
// freezingPointOfWater.temperatureInCelsius 是 0.0”
```
如果不写外部参数名那么外部参数名就等于内部参数名：  

```
struct Color {
    let red = 0.0, green = 0.0, blue = 0.0
    init(red: Double, green: Double, blue: Double) {
        self.red   = red
        self.green = green
        self.blue  = blue
    }
}
let magenta = Color(red: 1.0, green: 0.0, blue: 1.0)
```

如果你不希望为构造器的某个参数提供外部名字，你还可以使用下划线`_`来显示描述它的外部名：  

```
struct Celsius {
    var temperatureInCelsius: Double
    init(fromFahrenheit fahrenheit: Double) {
        temperatureInCelsius = (fahrenheit - 32.0) / 1.8
    }
    init(fromKelvin kelvin: Double) {
        temperatureInCelsius = kelvin - 273.15
    }
    init(_ celsius: Double) {
        temperatureInCelsius = celsius
    }
}
let bodyTemperature = Celsius(37.0)
// bodyTemperature.temperatureInCelsius is 37.0
```

你会发现构造器的第一个内部参数名也会默认作为其外部参数名供调用，这一点与方法不同（方法不会默认将第一个内部参数名作为外部参数名使用），因为方法名可以在结尾加上介词来烘托出第一个参数的名字，这样就不需要为第一个参数弄一个外部参数名了，但是构造器只能用`init`关键字来定义。  

如果你定制的类型包含一个逻辑上允许取值为空的存储型属性--不管是因为它无法在初始化时赋值，还是因为它可以在之后某个时间点可以赋值为空--你都需要将它定义为可选类型`optional type`。可选类型的属性将自动初始化为空`nil`，表示这个属性是故意在初始化时设置为空的。  

```
class SurveyQuestion {
    let text: String
    var response: String?
    init(text: String) {
        self.text = text
    }
    func ask() {
        println(text)
    }
}
let cheeseQuestion = SurveyQuestion(text: "Do you like cheese?")
cheeseQuestion.ask()
// 输出 "Do you like cheese?"
cheeseQuestion.response = "Yes, I do like cheese.
```

调查问题在问题提出之后，我们才能得到回答。所以我们将属性回答response声明为String?类型，或者说是可选字符串类型optional String。当SurveyQuestion实例化时，它将自动赋值为空nil，表明暂时还不存在此字符串。  
只要在构造过程结束前常量的值能确定，你可以在构造过程中的任意时间点修改常量属性的值。尽管text属性是常量，我们仍然可以在其类的构造器中设置它的值。**对某个类实例来说，它的常量属性只能在定义它的类的构造过程中修改；不能在子类中修改。**
## 默认构造器
Swift将为所有属性已提供默认值的且自身没有定义任何构造器的结构体或基类，提供一个默认的构造器。这个默认构造器将简单的创建一个所有属性值都设置为默认值的实例：  

```
class ShoppingListItem {
    var name: String?
    var quantity = 1
    var purchased = false
}
var item = ShoppingListItem()
```
`ShoppingListItem`类没有父类（是基类），所有属性都有默认值（可选属性默认值为`nil`），所以可以直接调用默认的无参数构造器来初始化。  
除上面提到的默认构造器，如果结构体对所有存储型属性提供了默认值且自身没有提供定制的构造器，它们能自动获得一个**逐一成员构造器（Memberwise Initializers）**：  

```
struct Size {
    var width = 0.0, height = 0.0
}
let twoByTwo = Size(width: 2.0, height: 2.0)
```
逐一成员构造器是用来初始化结构体新实例里成员属性的快捷方法。我们在调用逐一成员构造器时，通过与成员属性名相同的参数名进行传值来完成对成员属性的初始赋值。  

## 值类型的构造器代理
构造器可以通过调用其它构造器来完成实例的部分构造过程。这一过程称为构造器代理，它能减少多个构造器间的代码重复：  

```
struct Size {
    var width = 0.0, height = 0.0
}
struct Point {
    var x = 0.0, y = 0.0
}
struct Rect {
    var origin = Point()
    var size = Size()
    init() {}
    init(origin: Point, size: Size) {
        self.origin = origin
        self.size = size
    }
    init(center: Point, size: Size) {
        let originX = center.x - (size.width / 2)
        let originY = center.y - (size.height / 2)
        self.init(origin: Point(x: originX, y: originY), size: size)
    }
}
```
在值类型中，如果你添加了自定义构造器（如`init(center: Point, size: Size)`），Swift不会再为结构体生成一个默认构造器和逐一成员构造器，所以我们自己定义了`init()`和`init(origin: Point, size: Size)`，他们与自动生成的默认构造器和逐一成员构造器是一样的。这样子会显得很麻烦，我们可以将自定义构造器`init(center: Point, size: Size)`写在结构体`Rect`的扩展（`extension`）里，这样就不用自己把默认构造器和逐一成员构造器写一遍了。  

构造器`init(center:size:)`先通过`center`和`size`的值计算出`origin`的坐标。然后再调用（或代理给）`init(origin:size:)`构造器来将新的`origin`和`size`值赋值到对应的属性中。因为值类型（结构体和枚举类型）不支持继承，所以构造器代理的过程相对简单，因为它们只能代理给本身提供的其它构造器：你只能在构造器内部调用`self.init`  

## 类的继承和构造过程
类里面的所有存储型属性--包括所有继承自父类的属性--都必须在构造过程中设置初始值。  

Swift 提供了两种类型的类构造器来确保所有类实例中存储型属性都能获得初始值，它们分别是指定构造器(`Designated Initializers`)和便利构造器(`Convenience Initializers`)。  
### 指定构造器和便利构造器
指定构造器是类中最主要的构造器。一个指定构造器将初始化类中提供的所有属性，并根据父类链往上调用父类的构造器来实现父类的初始化。**每一个类都必须拥有至少一个指定构造器。**  

便利构造器是类中比较次要的、辅助型的构造器。你可以定义便利构造器来调用同一个类中的指定构造器，并为其参数提供默认值。你也可以定义便利构造器来创建一个特殊用途或特定输入的实例。  

类的指定构造器的写法跟值类型简单构造器一样，便利构造器也采用相同样式的写法，但需要在`init`关键字之前放置`convenience`关键字：  

```
convenience init(parameters) {
    statements
}
```

### 构造器链
为了简化指定构造器和便利构造器之间的调用关系，Swift 采用以下三条规则来限制构造器之间的代理调用：  

1. 指定构造器必须调用其直接父类的的指定构造器。  
2. 便利构造器必须调用同一类中定义的其它构造器。  
3. 便利构造器必须最终以调用一个指定构造器结束。  

一个更方便记忆的方法是:  

- 指定构造器必须总是向上代理  
- 便利构造器必须总是横向代理  

![](https://developer.apple.com/library/prerelease/ios/documentation/swift/conceptual/swift_programming_language/Art/initializerDelegation01_2x.png)
举个栗子：  

```
class Food {
    var name: String
    init(name: String) {
        self.name = name
    }
    convenience init() {
        self.init(name: "[Unnamed]")
    }
}
let namedMeat = Food(name: "Bacon")
// namedMeat 的名字是 "Bacon”
let mysteryMeat = Food()
// mysteryMeat 的名字是 [Unnamed]
```

![](https://developer.apple.com/library/prerelease/ios/documentation/swift/conceptual/swift_programming_language/Art/initializersExample01_2x.png)  
### 两段式构造过程
Swift 中类的构造过程包含两个阶段。第一个阶段，每个存储型属性通过引入它们的类的构造器来设置初始值。当每一个存储型属性值被确定后，第二阶段开始，它给每个类一次机会在新实例准备使用之前进一步定制它们的存储型属性。  
下图展示了在假定的子类和父类之间构造的阶段1：  

![](https://developer.apple.com/library/prerelease/ios/documentation/swift/conceptual/swift_programming_language/Art/twoPhaseInitialization01_2x.png)  

指定构造器将确保所有子类的属性都有值，然后它将调用父类的指定构造器，并沿着造器链一直往上完成父类的构建过程。一旦父类中所有属性都有了初始值，实例的内存被认为是完全初始化，而阶段1也已完成。  

以下展示了相同构造过程的阶段2：  

![](https://developer.apple.com/library/prerelease/ios/documentation/swift/conceptual/swift_programming_language/Art/twoPhaseInitialization02_2x.png)  

父类中的指定构造器现在有机会进一步来定制实例（尽管它没有这种必要）。

一旦父类中的指定构造器完成调用，子类的构指定构造器可以执行更多的定制操作（同样，它也没有这种必要）。

最终，一旦子类的指定构造器完成调用，最开始被调用的便利构造器可以执行更多的定制操作。  

两段式构造过程是基于**安全检查**的，可以简单的理解为：  

- 指定构造器初始化顺序：初始化类自己引入的属性->向上代理调用父类指定构造器->为继承的属性设置新值  
- 便利构造器初始化顺序：代理调用同一类中的其它构造器->为任意属性赋新值
- 构造器在第一阶段构造完成之前，不能调用任何实例方法、不能读取任何实例属性的值，也不能引用self的值。  

### 构造器的继承和重载
**跟 Objective-C 中的子类不同，Swift 中的子类不会默认继承父类的构造器。**这是为了防止你想初始化一个很牛逼的类，但是调用的却是它继承于父类的菜逼构造器，那将会是个悲剧。  

**但是如果特定条件可以满足，父类构造器是可以被自动继承的：**  

1. 如果子类没有定义任何指定构造器，它将自动继承所有父类的指定构造器。  
2. 如果子类提供了所有父类指定构造器的实现--不管是通过规则1继承过来的，还是通过自定义实现的--它将自动继承所有父类的便利构造器。  

即使你在子类中添加了更多的便利构造器，这两条规则仍然适用。子类可以通过定义便利构造器来实现父类中的指定构造器，来部分满足规则2    

如果你需要在子类中重写一个父类的指定构造器（包括自动生成的默认构造器），无论子类中的构造器是指定构造器还是便利构造器，都需要在子类定义重载的构造器前加上`override`修饰；如果你需要在子类中重写一个父类的便利构造器，根据构造器链，父类的便利构造器不会被子类直接调用，所以不必在子类重写构造器的定义前用`override`修饰。这是Xcode6beta5新修订的规则，在以前的版本中重载构造器不用`override`修饰。  

还记得之前指定的`Food`类吧，现在它多了一个子类`RecipeIngredient`:  

```
class RecipeIngredient: Food {
    var quantity: Int
    init(name: String, quantity: Int) {
        self.quantity = quantity
        super.init(name: name)
    }
    override convenience init(name: String) {
        self.init(name: name, quantity: 1)
    }
}
```
可以看出来`RecipeIngredient`类的指定构造器和便利构造器都符合两段式构造安全检查，并且便利构造器跟`Food`类中的指定构造器具有相同的参数，尽管`RecipeIngredient`这个构造器是便利构造器，`RecipeIngredient`依然提供了对所有父类指定构造器的实现。因此，`RecipeIngredient`也能自动继承了所有父类的便利构造器(也就是`init()`):  

![](https://developer.apple.com/library/prerelease/ios/documentation/swift/conceptual/swift_programming_language/Art/initializersExample02_2x.png)  

上图中`RecipeIngredient`类继承的init()函数版本跟Food提供的版本是一样的，除了它是将任务代理给RecipeIngredient版本的init(name: String)而不是Food提供的版本。  

食材都已经建立好了，下面开始采购吧！我们需要一个购物单，购物单中每一项是这样子的：  

```
class ShoppingListItem: RecipeIngredient {
    var purchased = false
    var description: String {
    var output = "\(quantity) x \(name.lowercaseString)"
        output += purchased ? " ✔" : " ✘"
        return output
    }
}
```

由于它为自己引入的所有属性都提供了默认值，并且自己没有定义任何构造器，ShoppingListItem将自动继承所有父类中的指定构造器和便利构造器。  

![](https://developer.apple.com/library/prerelease/ios/documentation/swift/conceptual/swift_programming_language/Art/initializersExample03_2x.png)  

你可以使用全部三个继承来的构造器来创建ShoppingListItem的新实例：  

```
var breakfastList = [
    ShoppingListItem(),
    ShoppingListItem(name: "Bacon"),
    ShoppingListItem(name: "Eggs", quantity: 6),
]
breakfastList[0].name = "Orange juice"
breakfastList[0].purchased = true
for item in breakfastList {
    println(item.description)
}
// 1 x orange juice ✔
// 1 x bacon ✘
// 6 x eggs ✘
```
## 可失败构造器(Failable Initializers)

有时候定义一个构造器可以失败的类，结构体或枚举是很有用的。这样的失败可能被非法的初始化参数，所需外部资源的缺失或一些其他阻止初始化成功的情况触发。  

为了应付初始化可能失败的情形，需要在定义类，结构体或枚举时再定义一个或多个可失败构造器。在`init`关键字后面放一个问号(`init?`)即可写出一个可失败构造器。  

**你不能定义具有相同参数类型和参数名称的可失败构造器和非可失败构造器**

可失败构造器返回它初始化类型的可选值。你要在可失败构造器中可能触发失败的地方返回`nil`。  

**严格的来说，构造器不返回值。更确切地说，它们的角色是确保`self`在构造过程结束时被完整正确的初始化。虽然你写下`return nil`来触发一个构造过程的失败，但你不要使用`return`关键字来指明构造过程的成功。**  

下面的例子定义了一个叫做`Animal`的结构体，它有一个叫做`species`的`String`常量属性。`Animal`结构体还定义了一个可失败构造器，它只接收一个`species`参数。这个构造器检查被传递过来的`species`参数是否为空字符串：如果是空字符串那就触发构造过程失败，否则`species`属性会被赋值，构造过程成功：  

```
struct Animal {
    let species: String
    init?(species: String) {
        if species.isEmpty { return nil }
        self.species = species
    }
}
```
你可以试着使用可失败构造器来初始化一个`Animal`对象来检验构造过程是否成功：
```
let someCreature = Animal(species: "Giraffe")
// someCreature is of type Animal?, not Animal
 
if let giraffe = someCreature {
    println("An animal was initialized with a species of \(giraffe.species)")
}
// prints "An animal was initialized with a species of Giraffe"
```
如果你给可失败构造器传递一个空字符串作为参数，那么将会触发构造过程失败：
```
let anonymousCreature = Animal(species: "")
// anonymousCreature is of type Animal?, not Animal
 
if anonymousCreature == nil {
    println("The anonymous creature could not be initialized")
}
// prints "The anonymous creature could not be initialized"
```
**这里注意下空字符串与`nil`的区别。空字符串是合法的，它并不像`nil`那样代表了某种类型值得缺失。但在`Animal`中我们必须设定一个有意义的`species`属性，它不能是空字符串。**  
### 枚举的可失败构造器

你可以使用可失败构造器根据一或多个参数来选择合适的枚举成员。如果传入的参数没能匹配到合适的枚举成员，构造就会失败。  

下面的例子定义了一个叫做`TemperatureUnit`的枚举，有三个可能的情况 (`Kelvin`, `Celsius`, 和 `Fahrenheit`)。可失败构造器用于在表现一个温度符号字符时找到一个合适的枚举成员：
```
enum TemperatureUnit {
    case Kelvin, Celsius, Fahrenheit
    init?(symbol: Character) {
        switch symbol {
        case "K":
            self = .Kelvin
        case "C":
            self = .Celsius
        case "F":
            self = .Fahrenheit
        default:
            return nil
        }
    }
}
```
你可以使用这个可失败构造器来为三种可能的状况选择合适的枚举成员，也可在参数不能匹配任何状况时让构造过程失败：
```
let fahrenheitUnit = TemperatureUnit(symbol: "F")
if fahrenheitUnit != nil {
    println("This is a defined temperature unit, so initialization succeeded.")
}
// prints "This is a defined temperature unit, so initialization succeeded."
 
let unknownUnit = TemperatureUnit(symbol: "X")
if unknownUnit == nil {
    println("This is not a defined temperature unit, so initialization failed.")
}
// prints "This is not a defined temperature unit, so initialization failed."

```
### 带有原始值枚举的可失败构造器

带有原始值的枚举会自动得到一个可失败构造器：`init?(rawValue:)`，它接受`rawValue`参数来匹配一个枚举成员，如果无法匹配就出发构造过程失败。  

发挥`init?(rawValue:)`的优势将上面的例子`TemperatureUnit`重写：
```
enum TemperatureUnit: Character {
    case Kelvin = "K", Celsius = "C", Fahrenheit = "F"
}
 
let fahrenheitUnit = TemperatureUnit(rawValue: "F")
if fahrenheitUnit != nil {
    println("This is a defined temperature unit, so initialization succeeded.")
}
// prints "This is a defined temperature unit, so initialization succeeded."
 
let unknownUnit = TemperatureUnit(rawValue: "X")
if unknownUnit == nil {
    println("This is not a defined temperature unit, so initialization failed.")
}
// prints "This is not a defined temperature unit, so initialization failed."
```
### 类的可失败构造器

值类型的可失败构造器可以在任何地方触发构造过程失败。在上面的`Animal`结构体例子中，构造器在`species`属性被赋值前就触发了构造过程失败，位置很靠前。  

对于类，可失败构造器只能在所有存储型属性被赋初值并且任意构造器代理发生后才触发构造过程失败。  

下面给出的例子展现了如何使用隐式解析可选属性来满足这个可失败类构造器的需求：
```
class Product {
    let name: String!
    init?(name: String) {
        if name.isEmpty { return nil }
        self.name = name
    }
}
```
上面定义的`Product`类非常类似之前见过的`Animal`结构体。`Product`类有一个不能为空值的字符串常量属性`name`。为了强制满足这个要求，`Product`类使用可失败构造器来确保`name`属性值在构造过程成功前不为空。  

然而`Product`是一个类而不是结构体。这意味着它不像`Animal`，任何`Product`类的可失败构造器都必须在触发构造过程失败之前为`name`属性提供一个初值。  

在上面的例子中，`Product`类的`name`属性被定义成隐式解析可选的字符串类型(`String!`)。因为它是一个可选类型，这意味着构造过程中`name`属性在被赋值前有一个默认值`nil`。这个默认值`nil`意味着`Product`类中所有属性都有一个合法的初值。结果就是`Product`类的可失败构造器如果被传递的是一个空字符串，它能在构造器开始时就触发一个构造过程失败。  

因为`name`属性是常量，你可以确信在构造过程成功后它将永远不是`nil`。尽管它被定义为隐式解析可选类型，你可以永远自信地获取它的隐式解析值，而不用检验是否为`nil`：  
```
if let bowTie = Product(name: "bow tie") {
    // no need to check if bowTie.name == nil
    println("The product's name is \(bowTie.name)")
}
// prints "The product's name is bow tie"
```
### 可失败构造器的传播

类，结构体或枚举的可失败构造器可以横向代理给同一个的类，结构体或枚举中的另一个可失败构造器。类似的，子类的可失败构造器也能向上代理到超类的可失败构造器。  

不论发生何种情况，如果你代理给的另一个构造器发生了构造过程失败，整个构造过程程序立刻失败，后续的构造过程代码也不会执行。  

**可失败构造器也可代理给非可失败构造器。如果你想在一个已经存在的不会失败的构造过程中添加一个可能失败的状况时可以用到这招**  

下面的例子定义了一个`Product`的子类`CartItem`。`CartItem`类模拟了在线购物车中的一件物品。`CartItem`包含一个叫做`quantity`的常量属性并确保这个属性总是不小于1：
```
class CartItem: Product {
    let quantity: Int!
    init?(name: String, quantity: Int) {
        super.init(name: name)
        if quantity < 1 { return nil }
        self.quantity = quantity
    }
}
```
`quantity`属性类型为隐式解析整型(`Int!`)。就像`Product`类的`name`属性一样，这意味着`quantity`属性在构造过程中被赋值前有一个默认值`nil`。  

`CartItem`的可失败构造器开始于向上代理到超类`Product`的`init(name:)`构造器。这满足了要求--可失败构造器必需总是在构造过程失败被触发之前完成构造器代理。  

如果超类的构造过程由于空的`name`值而失败，整个构造过程程序立刻失败，后续的构造过程代码也不会执行。如果超类构造过程成功，`CartItem`构造器会验证获取到的`quantity`值是否大于等于1。  

如果你用非空的`name`和大等于1的`quantity`创建一个`CartItem`实例，构造过程会成功：  
```
if let twoSocks = CartItem(name: "sock", quantity: 2) {
    println("Item: \(twoSocks.name), quantity: \(twoSocks.quantity)")
}
// prints "Item: sock, quantity: 2"
```
如果你试着用值为0的`quantity`创建一个`CartItem`实例，构造器将会导致构造过程失败：  
```
if let zeroShirts = CartItem(name: "shirt", quantity: 0) {
    println("Item: \(zeroShirts.name), quantity: \(zeroShirts.quantity)")
} else {
    println("Unable to initialize zero shirts")
}
// prints "Unable to initialize zero shirts"
```
同样地，如果你尝试用空的`name`值创建一个`CartItem`实例，超类`Product`构造器会导致构造过程失败：  
```
if let oneUnnamed = CartItem(name: "", quantity: 1) {
    println("Item: \(oneUnnamed.name), quantity: \(oneUnnamed.quantity)")
} else {
    println("Unable to initialize one unnamed product")
}
// prints "Unable to initialize one unnamed product"
```
### 可失败构造器的重载

你可以在子类中重载超类的可失败构造器，就像重载其他任意构造器那样。另外，你还可以用子类的非可失败构造器重载超类的可失败构造器。这让你能定义一个构造过程不能失败的子类，尽管超类的构造过程是允许失败的。  

注意如果你用子类的非可失败构造器重载了超类的可失败构造器，子类构造器不能向上代理到超类构造器。非可失败构造器庸官都不能代理给可失败构造器。  

**注意：你可以用非可失败构造器重载可失败构造器，但是不能倒过来**  

下面的例子定义了一个叫做`Document`的类。这个类模拟了一个用`name`属性初始化的文档，`name`属性是非空字符串或者是`nil`，但不能是空字符串：  
```
class Document {
    var name: String?
    // this initializer creates a document with a nil name value
    init() {}
    // this initializer creates a document with a non-empty name value
    init?(name: String) {
        if name.isEmpty { return nil }
        self.name = name
    }
}
```
下一个例子定义了一个`Document`的子类`AutomaticallyNamedDocument`。子类`AutomaticallyNamedDocument`重载了两个`Document`添加的指定构造器。这些重载确保`AutomaticallyNamedDocument`实例在不用`name`初始化或传入`init(name:)`的值是空字符串时将“[Untitled]”作为`name`的初值：  
```
class AutomaticallyNamedDocument: Document {
    override init() {
        super.init()
        self.name = "[Untitled]"
    }
    override init(name: String) {
        super.init()
        if name.isEmpty {
            self.name = "[Untitled]"
        } else {
            self.name = name
        }
    }
}
```
`AutomaticallyNamedDocument`用非可失败的`init(name:)`构造器重载了它超类的可失败的`init?(name:)`构造器。因为`AutomaticallyNamedDocument`应付空字符串情形的方式与它的超类不同，它的构造器不需要失败，所以它提供了一个非可失败版本的构造器来替代。  

### init!可失败构造器
你一贯地通过在`init`关键字后放置问号(`init?`)来定义一个创建可选值类型实例的可失败构造器。另外，你还可以定义一个创建隐式解析可选类型实例的可失败构造器。在`init`关键字后放置一个叹号来替代问号(`init!`)就可以啦。  

你可以从`init?`代理到`init!`，反之亦然；你可以用`init!`重载`init?`，反之亦然。你也可以从`init`代理到`init!`，不过这么做将会在`init!`发生构造过程失败时触发一个断言。  

## 必需构造器(Required Initializers)

当你想让一个类的某个构造器被所有子类都实现，你可以在定义这个构造器时在前面用`required`修饰：  

```
class SomeClass {
    required init() {
        // initializer implementation goes here
    }
}
```

你也必须在它的子类定义必需构造器前用`required`修饰，但不必用`override`修饰：  

```
class SomeSubClass: SomeClass {
    required init() {
        // subclass implementation of the required initializer goes here
    }
}
```

这样的语法可以将这种“必需”信号传递给未来更多的子类，表明这个构造器一定要实现，千秋万代~  

当然你可以满足构造器的继承规则来继承必需构造器，这样就不用“必须”重写“必需”构造器了：  

```
class SomeSubSubClass:SomeSubClass {
    convenience init(a:String) {
        self.init()
        //subsubclass implementation of a convenience initializer goes here
    }
}
```

## 通过闭包和函数来设置属性的默认值

如果某个存储型属性的默认值需要特别的定制或准备，你就可以使用闭包或全局函数来为其属性提供定制的默认值。每当某个属性所属的新类型实例创建时，对应的闭包或函数会被调用，而它们的返回值会当做默认值赋值给这个属性。

```
class SomeClass {
    let someProperty: SomeType = {
        // 在这个闭包中给 someProperty 创建一个默认值
        // someValue 必须和 SomeType 类型相同
        return someValue
        }()
}
```

注意闭包结尾的大括号后面接了一对空的小括号。这是用来告诉 Swift 需要立刻执行此闭包。如果你忽略了这对括号，相当于是将闭包本身作为值赋值给了属性，而不是将闭包的返回值赋值给属性。  

如果你使用闭包来初始化属性的值，请记住在闭包执行时，实例的其它部分都还没有初始化。这意味着你不能够在闭包里访问其它的属性，就算这个属性有默认值也不允许。同样，你也不能使用隐式的self属性，或者调用其它的实例方法。


