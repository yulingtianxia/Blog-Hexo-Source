---
layout: post
title: "Xcode单元测试-XCTest"
date: 2014-04-28 13:25:12 +0800
comments: true
tags: 
- Xcode

---
第一次接触单元测试还是在SQA课程上，那时我用的是JUnit来对Java程序进行单元测试。如今XCode自带的单元测试工具已经从OCUnit演变到了XCTest，但其本质还是差不多的，其好处在于XCode集成，简单方便    
<!--more-->
在XCode5中新建一个工程的时候，会默认带一个用于单元测试的target，其名字为工程名加Test后缀，并且文件名也以Test结尾。你会发现已经有了一个默认的测试用例，其中有三个方法：`setUp`,`tearDown`,`testExample`。其中`testExample`方法左侧有一个播放按钮，点击它就会对这个方法进行测试，而在整个文件的`@implementation`那行也有个同样的按钮，点击后会对当前测试用例的所有方法进行测试，也可通过Command＋U快捷键来触发。这个测试用例类没有头文件，因为测试用例不需要给外部暴漏接口。按照苹果官方的文档，建立一个测试用例的过程应该是这样的：  
1. 建立一个`XCTestCase`的子类
2. 实现测试方法
3. 选择性的定义一些实例变量来存储fixture的状态
4. 通过重写`setUp`方法选择性的实例化fixture
5. 通过重写`tearDown`方法来在测试后清除
测试方法没有参数和返回值，用test作为前缀，比如：

```objc
 - (void) testSomething;
```
会自动被`XCTest`架构识别为测试用例，每个`XCTestCase`的子类中的`defaultTestSuite`都是一个`XCTestSuite`，它包含了这些测试用例。  
测试方法的实现经常包含断言，必须通过验证才能通过测试，举个例子：

```
 @interface MathTest : XCTestCase {
 @private
    float f1;
    float f2;
 }
 
 - (void) testAddition;
 
 @end
 
 @implementation MathTest
 
 - (void) setUp
 {
    f1 = 2.0;
    f2 = 3.0;
 }
 
 - (void) testAddition
 {
    XCTAssertTrue (f1 + f2 == 5.0, @"%f + %f should equal 5.0", f1, f2);
 }
 @end
```
感觉这根JUnit很像的，下面列出所有的断言：  
XCTFail(format…) 生成一个失败的测试；

XCTAssertNil(a1, format...)为空判断，a1为空时通过，反之不通过；

XCTAssertNotNil(a1, format…)不为空判断，a1不为空时通过，反之不通过；

XCTAssert(expression, format...)当expression求值为TRUE时通过；

XCTAssertTrue(expression, format...)当expression求值为TRUE时通过；

XCTAssertFalse(expression, format...)当expression求值为False时通过；

XCTAssertEqualObjects(a1, a2, format...)判断相等，[a1 isEqual:a2]值为TRUE时通过，其中一个不为空时，不通过；

XCTAssertNotEqualObjects(a1, a2, format...)判断不等，[a1 isEqual:a2]值为False时通过，

XCTAssertEqual(a1, a2, format...)判断相等（当a1和a2是 C语言标量、结构体或联合体时使用,实际测试发现NSString也可以）；

XCTAssertNotEqual(a1, a2, format...)判断不等（当a1和a2是 C语言标量、结构体或联合体时使用）；

XCTAssertEqualWithAccuracy(a1, a2, accuracy, format...)判断相等，（double或float类型）提供一个误差范围，当在误差范围（+/-accuracy）以内相等时通过测试；

XCTAssertNotEqualWithAccuracy(a1, a2, accuracy, format...) 判断不等，（double或float类型）提供一个误差范围，当在误差范围以内不等时通过测试；

XCTAssertThrows(expression, format...)异常测试，当expression发生异常时通过；反之不通过；（很变态）

XCTAssertThrowsSpecific(expression, specificException, format...) 异常测试，当expression发生specificException异常时通过；反之发生其他异常或不发生异常均不通过；

XCTAssertThrowsSpecificNamed(expression, specificException, exception_name, format...)异常测试，当expression发生具体异常、具体异常名称的异常时通过测试，反之不通过；

XCTAssertNoThrow(expression, format…)异常测试，当expression没有发生异常时通过测试；

XCTAssertNoThrowSpecific(expression, specificException, format...)异常测试，当expression没有发生具体异常、具体异常名称的异常时通过测试，反之不通过；

XCTAssertNoThrowSpecificNamed(expression, specificException, exception_name, format...)异常测试，当expression没有发生具体异常、具体异常名称的异常时通过测试，反之不通过

关于测试函数执行的顺序：以函数名中test后面的字符大小有关，比如-（void）test001XXX会先于-（void）test002XXX执行；

这里只是Mark下单元测试的基本知识，具体应用的话这里推荐几篇不错的教程：  

[测试 View Controllers](http://objccn.io/issue-1-3/)  
[Xcode 5 单元测试（一）使用XCTest进行单元测试](http://blog.csdn.net/jymn_chen/article/details/21552941)  
[Xcode 5 单元测试（二）OCMock和GHUnit](http://blog.csdn.net/jymn_chen/article/details/21562869)  
[XCTest 测试实战](http://objccn.io/issue-15-2/)  

可能有的测试工具会用到CocoaPods来管理，给出一篇入门文章：  

[iOS中使用cocoaPods管理第三方类库](http://blog.csdn.net/mysevenmi/article/details/17878421)
