---
layout: post
title: "Swift重载和自定义运算符"
date: 2014-06-16 20:45:20 +0800
comments: true
tags: 
- Swift

---

最近一直边忙毕设边学Swift，终于看完了官方的教程（语言参考暂不打算看），在iBooks上做了一些笔记（看英文伤不起），感觉Swift是一门大杂烩类型的语言，我会记录一些我自认为以前遇到较少或者需要重点记忆的语法特性，在此作为分享，这次是运算符的重载，几乎每门语言都有，只是语法不一样罢了。  
(2014-8-8更新至beta5语法)
<!--more-->

## 运算符重载
在Swift的官方文档中运算符重载叫做运算符函数（Operator Functions），顾名思义就是对已经有的运算符覆盖定义自己的函数实现。三元运算符（a？b：c）和默认的默认的赋值符(=)是不可重载的。  
### 中缀运算符的重载
在`func`关键字前使用属性`@infix`来重载中缀运算符，函数名为想要重载的中缀运算符：  

```js
struct Vector2D {
    var x = 0.0, y = 0.0
}
func + (left: Vector2D, right: Vector2D) -> Vector2D {
    return Vector2D(x: left.x + right.x, y: left.y + right.y)
}
```
上面的代码是对结构体`Vector2D`之间双目运算符`+`的重载，下面可以直接使用`+`对`Vector2D`进行操作了：

```
let vector = Vector2D(x: 3.0, y: 1.0)
let anotherVector = Vector2D(x: 2.0, y: 4.0)
let combinedVector = vector + anotherVector
// combinedVector 是一个新的Vector2D, 值为 (5.0, 5.0)
```

除了对双目运算符的重载，还有对比较运算符的重载  

```
func == (left: Vector2D, right: Vector2D) -> Bool {
    return (left.x == right.x) && (left.y == right.y)
}
func != (left: Vector2D, right: Vector2D) -> Bool {
    return !(left == right)
}
```

现在我们可以使用这两个运算符来判断两个Vector2D对象是否相等  

```
let twoThree = Vector2D(x: 2.0, y: 3.0)
let anotherTwoThree = Vector2D(x: 2.0, y: 3.0)
if twoThree == anotherTwoThree {
    println("这两个向量是相等的.")
}
// prints "这两个向量是相等的."
```


### 前缀和后缀运算符的重载
前缀和后缀一元运算符重载需要在将`func`关键字前用`prefix`和`postfix`修饰，比如：

```
prefix func - (vector: Vector2D) -> Vector2D {
    return Vector2D(x: -vector.x, y: -vector.y)
}
```

这段代码为`Vector2D`类型提供了单目减运算，并且是前缀，也就是取负操作。

```
let positive = Vector2D(x: 3.0, y: 4.0)
let negative = -positive
// negative 为 (-3.0, -4.0)
let alsoPositive = -negative
// alsoPositive 为 (3.0, 4.0)
```
### 组合赋值运算符的重载
组合赋值是其他运算符和赋值运算符一起执行的运算。如`+=`把加运算和赋值运算组合成一个操作。实现一个组合赋值符号需要把运算符的左参数设置成`inout`，因为这个参数会在运算符函数内直接修改它的值。  

```
func += (inout left: Vector2D, right: Vector2D) {
    left = left + right
}
```

因为加法运算在之前定义过了，这里无需重新定义。所以，加赋运算符函数使用已经存在的高级加法运算符函数来执行左值加右值的运算。  

```
var original = Vector2D(x: 1.0, y: 2.0)
let vectorToAdd = Vector2D(x: 3.0, y: 4.0)
original += vectorToAdd
// original 现在为 (4.0, 6.0)
```
你可以将赋值运算结合`prefix` 或 `postfix`修饰，例如实现一个`Vector2D`的前缀自增运算符（++a）。  

```
@prefix func ++ (inout vector: Vector2D) -> Vector2D {
    vector += Vector2D(x: 1.0, y: 1.0)
    return vector
}
```
这个前缀使用了已经定义好的高级加赋运算，将自己加上一个值为` (1.0，1.0) `的对象然后赋给自己，然后再将自己返回。  

```
var toIncrement = Vector2D(x: 3.0, y: 4.0)
let afterIncrement = ++toIncrement
// toIncrement 现在是 (4.0, 5.0)
// afterIncrement 现在也是 (4.0, 5.0)
```
## 自定义运算符
标准的运算符不够玩，那你可以声明一些个性的运算符，但个性的运算符只能使用这些字符 `/ = - + * % < > ! & | ^ . ~`    
新的运算符声明需在全局域使用`operator`关键字声明，可以声明为前缀，中缀或后缀的，分别用`prefix`、`infix`和`postfix`修饰。  

```
prefix operator +++ {}
```
这段代码定义了一个新的前缀运算符叫`+++`，此前Swift并不存在这个运算符。此处为了演示，我们让`+++`对`Vector2D`对象的操作定义为“双自增”（prefix doubling incrementer） 这样一个独有的操作，这个操作使用了之前定义的加赋运算（`+=`）实现了自已加上自己然后返回的运算。  

```
prefix func +++ (inout vector: Vector2D) -> Vector2D {
    vector += vector
    return vector
}
```

`+++`运算的实现是把自己再加上自己  

```
var toBeDoubled = Vector2D(x: 1.0, y: 4.0)
let afterDoubling = +++toBeDoubled
// toBeDoubled 现在是 (2.0, 8.0)
// afterDoubling 现在也是 (2.0, 8.0)
```
此外还可以定义运算符的结合性(associativity)和优先级(precedence)，结合性(associativity)的值可取的值有left，right和none。左结合运算符跟其他优先级相同的左结合运算符写在一起时，会跟左边的操作数结合。同理，右结合运算符会跟右边的操作数结合。而非结合运算符不能跟其他相同优先级的运算符写在一起。  
结合性(associativity)的值默认为none，优先级(precedence)默认为100。  

```
infix operator +- { associativity left precedence 140 }
func +- (left: Vector2D, right: Vector2D) -> Vector2D {
    return Vector2D(x: left.x + right.x, y: left.y - right.y)
}
let firstVector = Vector2D(x: 1.0, y: 2.0)
let secondVector = Vector2D(x: 3.0, y: 4.0)
let plusMinusVector = firstVector +- secondVector
// plusMinusVector 此时的值为 (4.0, -2.0)
```


