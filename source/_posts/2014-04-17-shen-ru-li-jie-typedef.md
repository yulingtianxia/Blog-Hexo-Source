---
layout: post
title: "深入理解typedef"
date: 2014-04-17 18:38:37 +0800
comments: true
tags: 
- C

---
第一次对typedef语法产生疑惑是在大一使用struct的时候，而在使用Objective－C对Block进行操作的时候，再一次困惑  
<!--more-->

```
typedef <#returnType#>(^<#name#>)(<#arguments#>);//typedefBlock Code Snippets

typedef void (^RWAlertViewCompletionBlock)(UIAlertView *alertView, NSInteger buttonIndex);
```

然后就可以把`RWAlertViewCompletionBlock`当成一个Block的类型大摇大摆的使用啦  
在这之前楼主心目中的typedef一般都是这样的  

```
typedef int INT32;
typedef char Line[81];//表示使用Line代表具有81个元素的char类型数组。

```
甚至有时候是这样的  

```
typedef struct tagPOINT
{
    int x;
    int y;
}POINT;
POINT p1;//在C++中即使不用typedef也可直接中tagPOINT声明变量，但在旧的C中就需要typedef来省略struct关键字
```
如今遇到的Block其实可以当作函数指针啦  

```
int (*PF)(int *, int);
//也就是说，PF是一个函数指针“变量”。当使用typedef声明后，则PF就成为了一个函数指针“类型”，即：
typedef int (*PF)(int *, int);
```

**typedef的语法规则其实很简单，一句话来说就是定义对象的语法前加关键字typedef，剩下的不变，原本定义的对象标识符换成类型标识符，对应语义从定义一个对象改成定义一个类型别名。typedef看起来复杂根本原因是对象定义的语法比较复杂，例如分隔符*和[]的用法。**  
  
针对经典的const来个例子

```
typedef char * pStr;
char string[4] = "abc";
const char *p1 = string;
const pStr p2 = string;
p1++;
p2++;//error
```
`p2++`这句会报错的.  
`const char *p1 = string; `你可以这样理解：`(const char) *p1 = string`, `p1`是一个指针，指向`const char`的东西，这个东西就是`string`(string是一个字符数组的首地址，它的地址声明后肯定是`const`的，除非该数组销毁)，但是`p1`是一个指针变量，它是可以递增的，即你看到的`p1++`，它可以完成从数组的来遍历数组的目的。  
而`const pStr p2 = string;`是这样的：由于`p2`不是指针，`const`直接修饰到了`p2`,即现在的`p2`是常量了，它的类型是`pStr`(我们自己定义的类型)，相当于`const int p2`, `const long p2`等等，`const`都是直接修饰`p2`的，只不过`int`，`long`是系统类型，而`pStr`是我们定义的类型。为什么会出现这种效果了，就是因为`typedef`,它把`char *`定义成一个复合的类型，要从整体上来理解语义，而不是字符替换后来理解语义。  

最后作死下，引入非人类的案例：  

为复杂的声明定义一个新的简单的别名。方法是：在原来的声明里逐步用别名替换一部分复杂声明，如此循环，把带变量名的部分留到最后替换，得到的就是原声明的最简化版。举例： 

原声明：`void (*b[10]) (void (*)());`

变量名为b，先替换右边部分括号里的，pFunParam为别名一：

`typedef void (*pFunParam)();`

再替换左边的变量b，pFunx为别名二：

`typedef void (*pFunx)(pFunParam);`

原声明的最简化版：

`pFunx b[10];`
 
原声明：`doube(*)() (*e)[9];`

变量名为e，先替换左边部分，pFuny为别名一：

`typedef double(*pFuny)();`

再替换右边的变量e，pFunParamy为别名二

`typedef pFuny (*pFunParamy)[9];`

原声明的最简化版：

`pFunParamy e;`

理解复杂声明可用的“右左法则”：从变量名看起，先往右，再往左，碰到一个圆括号

就调转阅读的方向；括号内分析完就跳出括号，还是按先右后左的顺序，如此循环，直

到整个声明分析完。举例：

`int (*func)(int *p);`

首先找到变量名func，外面有一对圆括号，而且左边是一个*号，这说明func是一个指针

；然后跳出这个圆括号，先看右边，又遇到圆括号，这说明(*func)是一个函数，所以

func是一个指向这类函数的指针，即函数指针，这类函数具有int*类型的形参，返回值

类型是int。

`int (*func[5])(int *);`

func右边是一个[]运算符，说明func是具有5个元素的数组；func的左边有一个*，说明

func的元素是指针（注意这里的*不是修饰func，而是修饰func[5]的，原因是[]运算符

优先级比*高，func先跟[]结合）。跳出这个括号，看右边，又遇到圆括号，说明func数

组的元素是函数类型的指针，它指向的函数具有int*类型的形参，返回值类型为int。

这种用法是比较复杂的，出现的频率也不少，往往在看到这样的用法却不能理解，相信以上的解释能有所帮助。