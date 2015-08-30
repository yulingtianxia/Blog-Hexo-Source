title: When to Use Swift Structs and Classes
date: 2015-08-12 10:05:20
tags:
- 翻译
- Swift

---
本文翻译自 Mike Ash 的 [Friday Q&A 2015-07-17: When to Use Swift Structs and Classes][1]  

<!--more-->

Swift 圈中有一个被反复讨论的话题已经成为了:何时使用`class`,何时使用`struct`.我觉得今天我也要给出我的个人观点.
## 值 VS 引用
答案真的很简单了:当你需要用值语义的时候使用`struct`,需要用引用语义使用`class`.就是这样!

我们下周再见...

**等下**  
干啥?

**还没回答我的问题呢**  
你啥意思?答案不明摆着么?

**哦,但是...**  
啥?

**什么是值/引用语义?**  
哦我明白了,我可能接下来会探讨下.

**还有他们是如何关联到`class`和`struct`上的**  
嗯

所有都归根结底到数据以及数据存储的位置.我们把东西存在局部变量,参数,属性和全局变量中.从根本上又划分为两种不同的*方式*.

对于值语义来说,数据直接存在于存储单元中.对于引用语义,数据存在于其他地方,存储单元存储一个对数据的*引用*.当你存储数据的时候这种差异不一定明显.要注意的是拷贝存储的时候.对于值语义,你得到的是数据一份新拷贝.对于引用语义,你得到的是一份指向相同数据引用的新拷贝.

真是抽象,我们来看个例子吧.我们暂时先把 Swift 这茬放下,我们先看个 Objective-C 的例子:

```
@interface SomeClass : NSObject 
@property int number;
@end
@implementation SomeClass
@end

struct SomeStruct {
int number;
};

SomeClass *reference = [[SomeClass alloc] init];
reference.number = 42;
SomeClass *reference2 = reference;
reference.number = 43;
NSLog(@"The number in reference2 is %d", reference2.number);

struct SomeStruct value = {};
value.number = 42;
struct SomeStruct value2 = value;
value.number = 43;
NSLog(@"The number in value2 is %d", value2.number);
```

打印结果:

```
The number in reference2 is 43
The number in value2 is 42
```

为啥不一样呢?

`SomeClass *reference = [[SomeClass alloc] init]` 这行代码在内存中创建了一个 `SomeClass` 的新实例,然后在变量中放置了一个对那个实例的引用. `reference2 = reference` 这行代码在新变量中放置了对相同对象的引用. `reference.number = 43` 这行代码修改的是两个变量当前一起指向的对象中存储的数字.结果就是日志打印的是对象中的值,即`43`.

`struct SomeStruct value = {}` 这行代码在变量中创建了一个 `SomeStruct` 的新实例. `value2 = value` 将实例拷贝到第二个变量.每个变量有各自的数据块.

Swift 对应的例子:

```
class SomeClass {
   var number: Int = 0
}

struct SomeStruct {
   var number: Int = 0
}

var reference = SomeClass()
reference.number = 42
var reference2 = reference
reference.number = 43
print("The number in reference2 is \(reference2.number)")

var value = SomeStruct()
value.number = 42
var value2 = value
value.number = 43
print("The number in value2 is \(value2.number)")
```

输出结果跟以前一样:

```
The number in reference2 is 43
The number in value2 is 42
```

##值类型的经验
值类型并不是新鲜事物,但是对于很多人来说觉得它是新的.这是怎么回事呢?

`struct` 在绝大部分 Objective-C 代码中并不是很常用.我们偶尔以 `CGRect` 和 `CGPoint` 等方式接触到它们,但很少会自己去写.首先,它们不是很实用.用 Objective-C 在 `struct` 中正确地存储对象的引用的确很难,尤其是使用 ARC 的时候.

很多其他语言干脆没有类似 `struct` 的东东.许多语言如同 Python 和 JavaScript 一样"万物皆对象",只有引用类型.如果你是从这类语言转型到 Swift 的, 你可能对 `struct` 的概念就更陌生了.

等一下!有种情况下几乎所有语言都使用的值类型:数字!稍微有点编程经验的程序员都不会对下面的行为感到惊讶,这跟语言无关:

```
var x = 42
var x2 = x
x++
print("x=\(x) x2=\(x2)")
// prints: x=43 x2=42
```

很对我们来说如此显而易见和自然以至于我们甚至没意识到结果的差异,但它就在我们眼前.你从开始编程之日起一直在使用值类型,即使你没意识到.

很多语言实际上将数字实现为引用类型,因为它们是"万物皆对象"哲学的死忠粉.然而,它们是*不可变*类型,值类型与不可变引用类型之间的差异很难察觉.它们表现得与值类型相同,尽管实现方式可能不同.

这是理解值和引用类型重要的一环.当数据变化时,差异主要关系到语法方面.假如数据是不可变的,那么值和引用的差别就消失了,或至少变成了仅是性能问题而不是语法差异.

实际上 Objective-C 的 [tagged pointers][2] 对此提到过.一个对象遇上了 tagged pointer 的处理,然后存储在指针的值中,就成了值类型.拷贝操作这时拷贝的就是对象内容了.表面上没差异,因为 Objective-C 函数库小心翼翼地仅将不可变类型放到 tagged pointer 中.有些 `NSNumber` 对象是引用类型而有些是值类型,但用起来没什么差别.

##做出抉择

既然我们知道了值类型的工作原理,我们改为自己的数据类型选择那种方式呢?

这两种类型根本的区别就是当对其使用`=`时会发生什么.值类型是被拷贝,而引用类型只是得到另一个新引用.

因此在选择使用哪种类型时面对的根本问题是:拷贝它有意义么?拷贝操作是你想要变得简单,并经常使用的么?

我们先看些极端的,显而易见的例子.整型数明显是可以拷贝的,应该是值类型.网络套接字感觉是不能被拷贝,应该是引用类型.像是用 x,y 对儿的点坐标是可拷贝的,应该是值类型.用来表示磁盘的控制器感觉上不太容易被拷贝,应该是引用类型.

有些类型可以被拷贝,但它们不总是你希望的那样.建议把它们设为引用类型.比如屏幕上的一个按钮从概念上讲是可以拷贝的.副本按钮不会跟原来的按钮完全一样.点击副本按钮将不会激活原来的按钮.副本不会占用相同的屏幕位置.如果你将按钮传递到周围或放到一个新的变量里,你大概将想引用原本的按钮,除非明确被请求要做一份拷贝.这意味着你的按钮类型应该是一个引用类型.

视图和窗口控制器是类似的例子.它们可能想象上是能拷贝的,但它几乎从来都不是你想要的那样.它们应该是引用类型.

用于 Model 的类型该怎么搞?比方你有个 `User` 类型来表示系统中的用户,或者 `Crime` 类型来表示用户的活动.这些都是可完美拷贝的,所以它们或许应该是值类型.然而,你可能希望你程序中某处对 `User` 的 `Crime` 上的更新在程序的其他地方也可见.这就建议 `User` 应该被某种用户控制器来管理,而且它应该是引用类型.

集合是个有趣的例子.这包括比如数组和字典之类的东西,以及字符串.它们是可拷贝的么?显而易见.你想要做的拷贝操作是否易发生且经常发生呢?这不好说.

大多数语言对此说"不",而是实现为引用类型. Objective-C,Java,Python,JavaScript 和几乎其他所有我能想到的语言都是这么干的.(一个主要的例外就是 C++ 的 STL 中的集合类型,但是 C++ 是语言世界中胡言乱语的疯子,它不走寻常路.)

Swift 说"不错",这意味着如 `Array`,`Dictionary` 和 `String` 都是 `struct` 而不是 `class`. 它们在赋值和作为参数传递时被拷贝.只要拷贝的开销小,这就是个彻底明智的选择,而Swift费了很大力气去实现这点.

##嵌套类型

嵌套使用值类型和引用类型会有四种组合方式.只是其中一个比较有趣.

如果一个引用类型包含了另一个引用类型,没有什么有趣的发生.任何指向其内部或外部值的引用通常都能修改它.每个人都会看到发生的变更.

如果一个值类型包含了另一个值类型,这实际上只是让其占用空间更多.内部值是外部值的一部分.如果你将外部值放进某个新的存储区,所有的值都会被拷贝,包括内部值.如果你将内部值放入某个新的存储,它会被拷贝.

一个引用类型包含了一个值类型实际上让被引用的值占用空间更大了.拥有对外部值的引用就可以操作全部值,包括被嵌入的值.被嵌入值的所有变更对指向外部值的引用是可见的.如果你将内部值放入某个新的存储区,它会被拷贝至那里.

一个值类型包含着一个引用类型那就不这么简单了.你实际上暗地里破坏了你想要用的值类型语义.这样做或好后坏,取决于你怎样去做.当你把一个引用类型放入到一个值类型中,当你把它放入新的存储区时外部值会被拷贝,但是拷贝后的副本有一个指向*相同内嵌的原始对象*的引用.这有个例子:

```
class Inner {
   var value = 42
}

struct Outer {
   var value = 42
   var inner = Inner()
}

var outer = Outer()
var outer2 = outer
outer.value = 43
outer.inner.value = 43
print("outer2.value=\(outer2.value) outer2.inner.value=\(outer2.inner.value)")
```

输出是:

```
outer2.value=42 outer2.inner.value=43
```

虽然 `outer2` 得到一份 `value` 的拷贝,但它只拷贝了 `inner` 的*引用,于是这两个 `struct` 最终共享同一个 `Inner` 实例.因此对 `outer.inner.value` 的更新会影响到 `outer2.inner.value`. 唉呀妈呀!

这种做法真的很方便.用这个方法可以创建个能够执行写时拷贝的 `struct`,还能实现让值语义实际上不到处拷贝一坨坨的数据.这就是 Swift 中的集合的工作原理,你自己也可以实现自己的集合类型.想要知道更多详细信息,可以看看 [Let's Build Swift.Array][3].

这么做也可能变得极其危险.比方说你创建了个 `Person` 类型.它被用作 Model 类当然也是可拷贝的,所以可以用 `struct` 实现咯.突发一阵对 OC 的怀旧,你决定用 `NSString` 作为 `Person` 的 `name`:

```
struct Person {
   var name: NSString
}
```

然后你创建按了一对儿 `Person` 实例,拼接字符串构建出 `name`:

```
let name = NSMutableString()
name.appendString("Bob")
name.appendString(" ")
name.appendString("Josephsonson")
let bob = Person(name: name)

name.appendString(", Jr.")
let bobjr = Person(name: name)
```

然后输出它们:

```
print(bob.name)
print(bobjr.name)
```

结果产生了:

```
Bob Josephsonson, Jr.
Bob Josephsonson, Jr.
```

靠!

发生了什么?区别于 Swift 的 `String` 类型, `NSString` 是一个引用类型.它是不可变的,但它有个可变的子类, `NSMutableString`. 当 `bob` 创建时,它创建了一个对 `name` 字符串的引用.当那个字符串随后被修改时,变更会通过 `bob` 展现出来.要注意到即使 `bob` 是被 `let` 约束的值类型,但实际上改变了 `bob`.这*算不上真的*修改了 `bob`,只是修改了 `bob` 中引用的一个值,但因为那个值是 `bob` 数据的一部分,从语义上让人感到像是对 `bob` 作了修改.

这种事情在 Objective-C 中*一直*在发生.每个有经验的 Objective-C 程序员都有到处写防御拷贝的习惯.因为一个 `NSString` 实例可能实际上却是 `NSMutableString`, 为了避免灾难,你要将属性定义为 `copy`,或者在初始化时显式调用 `copy` 方法.这同样适用于 Cocoa 中各种各样的集合类型.

在 Swift 中解决方案更简单些:使用值类型而不是引用类型.在这种情况下,让 `name` 成为 `String`.再也不用担心无意中把引用共享咯.

在其他情况下,解决方案可能更简单.比如,你创建了一个包含视图的 `struct`,而视图是引用类型且不能改成值类型.这*或许*是个好的迹象表明你不该用 `struct`, 因为你不管怎样都不能维持值语义.

##结论

当移动值类型时它们会被拷贝,然而引用类型只是得到了一个对相同底层对象新引用.这意味着对引用类型的修改在每个引用上都看的到,然而对值类型的修改只会影响你修改的那块存储区.当选择使用哪种类型时,思考下如何拷贝你的类型比较恰当,如果需要深层拷贝就倾向于选择值类型.最后,谨防值类型中嵌入的引用类型,稍有不慎就会遭殃.



[1]:	https://www.mikeash.com/pyblog/friday-qa-2015-07-17-when-to-use-swift-structs-and-classes.html
[2]:	https://www.mikeash.com/pyblog/friday-qa-2012-07-27-lets-build-tagged-pointers.html
[3]:	https://www.mikeash.com/pyblog/friday-qa-2015-04-17-lets-build-swiftarray.html
