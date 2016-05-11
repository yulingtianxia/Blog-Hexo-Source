---
layout: post
title: "在Swift中构建assert(), 第二部分: __FILE__ 和 __LINE__"

date: 2014-09-26 16:23:21 +0800
comments: true
tags: 
- Swift

---
本文翻译自[Building assert() in Swift, Part 2: \_\_FILE\_\_ and \_\_LINE\_\_](https://developer.apple.com/swift/blog/?id=15)
<!--more-->
`__FILE__` 和 `__LINE__`这两个神奇的宏定义是C语言中偶尔有用的特性。他们被构建在预处理程序中，并在C语言语法分析程序运行前被展开。尽管Swift没有预处理程序，它却提供了名称相似的类似功能，但隐藏着极其不同的实现方式。  

## 内建标识符
就像在[the Swift programming guide](https://developer.apple.com/library/ios/documentation/swift/conceptual/swift_programming_language/LexicalStructure.html)中描述的那样，Swift有很多内建标识符，包括`__FILE__`, `__LINE__`, `__COLUMN__`, 和 `__FUNCTION__`。这些表达式可以在任何地方使用，并被语法分析器在源码对应的当前位置展开成字符串或整数字面量。这对手动日志非常管用，比如在退出前打印出当前位置。  

然而这并不能帮助我们探索实现`assert()`。如果我们这样实现断言(assert)：  

```objc
func assert(predicate : @autoclosure () -> Bool) { 
	#if DEBUG
		if !predicate() {
			println("assertion failed at \(__FILE__):\(__LINE__)")
			abort()
		}
	#endif
}
```
上面的代码将会输出实现`assert()`方法所在文件的文件/行数(file/line)位置，而不是调用者的位置信息。这并不管用。  

## 获取调用者位置
Swift从D语言借鉴了一个非常聪明的特性：当标识符在默认参数列表中被赋值时，它们会在调用者的位置被展开。为了实现这个行为，`assert()`被如下这样定义：  

```
func assert(condition: @autoclosure () -> Bool, _ message: String = "",
	file: String = __FILE__, line: Int = __LINE__) {
		#if DEBUG
			if !condition() {
				println("assertion failed at \(file):\(line): \(message)")
				abort()
			}
		#endif
}
```
Swift的`assert()`函数第二个参数是一个供你指明的可选字符串，而第三、四个参数默认为调用者上下文的位置。这就让`assert()`能默认获得调用者的原始位置。如果你想在断言顶层构建你自己的抽象层，你可以将调用者的位置传递下去。作为一个简易的例子，你可以定义一个日志和断言方法：  

```
func logAndAssert(condition: @autoclosure () -> Bool, _ message: StaticString = "",
	file: StaticString = __FILE__, line: UWord = __LINE__) {

	logMessage(message)
	assert(condition, message, file: file, line: line)
}
```
这正确的将`logAndAssert()`调用者的file/line位置传递给了`assert()`的实现。注意上面代码中的`StaticString`，它是一个类似于`String`的类型，用于存储像`__FILE__`这种不受内存管理约束的字符串字面量。  

除此之外，这种实用设计也用于Swift中实现高级XCTest框架，也可以在你自己实现的函数库中发挥作用。  
