title: 悟空!
date: 2015-03-08 20:06:02
tags:
---

斗战胜佛传记。。。  

<!--more-->
## NULL和nullptr

在Clang 6.0 的stddef.h文件中可以找到`NULL`和`nullptr`的声明：

```
#undef NULL
#ifdef __cplusplus
#  if !defined(__MINGW32__) && !defined(_MSC_VER)
#    define NULL __null
#  else
#    define NULL 0
#  endif
#else
#  define NULL ((void*)0)
#endif

#ifdef __cplusplus
#if defined(_MSC_EXTENSIONS) && defined(_NATIVE_NULLPTR_SUPPORTED)
namespace std { typedef decltype(nullptr) nullptr_t; }
using ::std::nullptr_t;
#endif
#endif
```

早在1972年，C语言诞生的初期，常数0带有常数及空指针的双重身分。 C使用preprocessor macro `NULL`表示空指针，让`NULL`及`0`分别代表空指针及常数0。 `NULL`可被定义为`((void*)0)`或是`0`。

C++并不采用C的规则，不允许将`void*`隐式转换为其他类型的指针。为了使代码`char* c = NULL;`能通过编译，`NULL`只能定义为`0`。这样的决定使得函数重载无法区分代码的语义：  

```
void foo(char *);
void foo(int);
```

C++建议`NULL`应当定义为`0`，所以`foo(NULL);`将会调用`foo(int)`，这并不是程序员想要的行为，也违反了代码的直观性。0的歧义在此处造成困扰。

C++11引入了新的关键字来代表空指针常数：`nullptr`，将空指针和整数0的概念拆开。 `nullptr`的类型为`nullptr_t`，能隐式转换为任何指针或是成员指针的类型，也能和它们进行相等或不等的比较。而`nullptr`不能隐式转换为整数，也不能和整数做比较。

为了向下兼容，`0`仍可代表空指针常数。  

```
char* pc = nullptr;     // OK
int * pi = nullptr;     // OK
int    i = nullptr;     // error
 
foo(pc);           // 呼叫foo(char *)
```

PS：`__MINGW32__`是MinGW编译器的预定义宏。`_MSC_VER`是微软C/C++编译器——cl.exe 编译代码时预定义的一个宏。`_MSC_VER`的值表示cl的版本。需要针对cl特定版本编写代码时，也可以使用该宏进行条件编译。


## nil和Nil

### Objective-C

`nil`定义为实例对象的空值(a null instance)  
`Nil`定义为类对象的空值(a null class)  
`nil`和`Nil`在objc.h和MacTypes.h文件中均有等价的声明：  

```
#ifndef Nil
# if __has_feature(cxx_nullptr)
#   define Nil nullptr
# else
#   define Nil __DARWIN_NULL
# endif
#endif

#ifndef nil
# if __has_feature(cxx_nullptr)
#   define nil nullptr
# else
#   define nil __DARWIN_NULL
# endif
#endif
```

根据Clang 3.7 文档对`__has_feature`的描述: "`__has_feature` evaluates to 1 if the feature is both supported by Clang and standardized in the current language standard or 0 if not"，`__has_feature(cxx_nullptr)`是用来判断是否支持C++11中的`nullptr`特性的。在Objective-C中`nil`和`Nil`都是`__DARWIN_NULL`宏定义。按住CMD鼠标点击进入`_types.h`:  

```
#ifdef __cplusplus
#ifdef __GNUG__
#define __DARWIN_NULL __null
#else /* ! __GNUG__ */
#ifdef __LP64__
#define __DARWIN_NULL (0L)
#else /* !__LP64__ */
#define __DARWIN_NULL 0
#endif /* __LP64__ */
#endif /* __GNUG__ */
#else /* ! __cplusplus */
#define __DARWIN_NULL ((void *)0)
#endif /* __cplusplus */
```

因为Objective-C不是C++代码，所以倒数第二行`#define __DARWIN_NULL ((void *)0)`此时高亮，意味着最终`nil`和`Nil`本质都为`((void *)0)`  

PS：其实如果只看Objective-C中的`nil`和`Nil`定义不用这么麻烦的，只需查看Objective-C Runtime Reference中的"Constants->Null Values"即可。  

### Swift

Swift 1.2 目前只有`nil`而没有`Nil`。为了安全性Swift新增了`Optional`类型来作为一个容器。好比一个箱子里面可能装有某种类型的对象，也可能是空的(`nil`)。箱子也可以嵌套，也可以去掉，但这都基于安全的解析、绑定等。Swift 的nil和 Objective-C 中的nil并不一样。在 Objective-C 中，`nil`是一个指向不存在对象的指针。在 Swift 中，`nil`不是指针——它是一个确定的值，用来表示值缺失。任何类型的可选值都可以被设置为`nil`，不只是对象（object）类型。  

PS:有关Swift中的`Optional`类型的更多信息可以参考我的另一篇博文：[Optionals and Optional Chaining in Swift](http://yulingtianxia.com/blog/2014/06/17/optionals-and-optional-chaining-in-swift/#Nil_Coalescing_Operator)  

PS：曾几何时，Swift的`nil`还不是字面量，而是`NilType`类型的唯一实例。但这一切都是历史了。  

## NSNull
`NSNull`在NSNull.h中的定义：  

```
@interface NSNull : NSObject <NSCopying, NSSecureCoding>

+ (NSNull *)null;

@end
```

`NSNull`是个单例，只有一个方法`null`，也用来表示空值。但它出现在一些`nil`无法胜任的场景来替代`nil`来表示空值。比如`NSArray`和`NSDictionary`中`nil`代表数组或字典的末尾(即使`nil`不出现在末尾，也会将其切断，`nil`后面的值会丢失)，此时只能用NSNull对象来表示空值：  

```
NSNull *nullValue = [NSNull null];
NSArray *arrayWithNull = @[nullValue];
NSLog(@"arrayWithNull: %@", arrayWithNull);
// Output: "arrayWithNull: (<null>)"
```

虽然`NSNull`语义上等同于`nil`，但却并不完全等于`nil`：  

```
id aValue = [arrayWithNull objectAtIndex:0];
if (aValue == nil) {
    NSLog(@"equals nil");
}
else if (aValue == [NSNull null]) {
    NSLog(@"equals NSNull instance");
    if ([aValue isEqual:nil]) {
        NSLog(@"isEqual:nil");
    }
}
// Output: "equals NSNull instance"
```


## 参考
- [维基百科C++11](http://zh.wikipedia.org/wiki/C%2B%2B11#.E9.80.9A.E7.94.A8.E6.99.BA.E8.83.BD.E6.8C.87.E9.87.9D)
- [Clang 3.7 documentation](http://clang.llvm.org/docs/LanguageExtensions.html#langext-has-feature-back-compat)
