---
layout: post
title: "使用Xcode6将你的项目本地化"
date: 2014-10-02 12:54:41 +0800
comments: true
tags: 
- Xcode
- 本地化

---
iOS和OSX支持40种语言的本地化，Xcode无疑为这一过程提供了强有力的支持。苹果将这一多语言适配过程细分为Internationalization（国际化）和Localization（本地化）两个阶段。  
<!--more-->
##国际化--准备你的APP

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20141002-9%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

在将你的APP适配各种语言本地化之前，你得先让你的APP富有国际范儿，也就是说国际化是一条通往本地化的必经之路。在国际化阶段，你需要让你的APP与语言和区域独立。  

苹果的框架已经帮我们把不同语言的数据分离开，这更有助于我们管理这些资源，包括图片、声音、视频、文档、用户界面文字（甚至代码中编写的用户界面文字），它们会被建立在同一个bundle中。  

###NSLocalizedString

我们来使用`NSLocalizedString`来让用户界面的文字国际化，不过这些文字不是在IB上输入的，而是在代码中产生并赋值的：  

```swift
func NSLocalizedString(key: String, tableName: String? = default, bundle: NSBundle = default, value: String = default, #comment: String) -> String
```
上面这个Swift语言声明的函数可以直接返回一个经过本地化处理过的字符串，这就使得你在代码中给一些控件文本赋值时更有“国际化视野”：  
```
self.text = NSLocalizedString("SHARE", comment: "share score")
```
因为不用的语言会有不同的专业名词，所以最后的comment参数很重要，它可以暗示翻译人员这段文字要表达的含义。而第一个参数key的内容为基础语种的内容，将它作为“键”来映射其他语言对应翻译后的“值”。如果我们需要在字符串中插入其他内容，这时需要改进下：  

```
let text = String.localizedStringWithFormat(NSLocalizedString("I got %d points in Spiral. Come on with me! https://itunes.apple.com/us/app/square-spiral/id920811081", comment: "share content"), Data.score)
```
`localizedStringWithFormat:`方法保证了插入字符串中的内容也被转化成本地格式，比如时间格式、数字的格式等。而此时在Swift字符串中插入其他数据就不能使用`\()`了，只能用百分号占位的形式。  

对应的在Localizable.strings中可以这样写：  

```
/*share score*/
"SHARE"="分享战绩";
/*share content*/
"I got %d points in Spiral. Come on with me! https://itunes.apple.com/us/app/square-spiral/id920811081"="我在Spiral游戏中得了%1$d分，快来超越我吧！https://itunes.apple.com/cn/app/square-spiral/id920811081";
```

这样就将英文与中文键值对应起来了，注意那个“1$”表示是在键内容（即英文原文）中第一个插入的数据，因为不用语言表达同一个意思时，插入字符串中的数据顺序可能会有变化，这个"数字+$"的标记记录了它们原本的顺序。  
###NSFormatter
NSFormatter算是老朋友了，它把数据转化成人们易读的字符串，而且还会根据不同语言和区域进行格式上的优化。它默认使用当地的语言习惯，我们不需要配置任何参数。比如显示时间日期，数字，金融，字节计数等格式上的本地化。现在iOS8和OSX Yosemite加入了健康相关的功能，NSFormatter也加入了很多新的量词，比如能量、长度高度、重量等方面。  
###NSBundle
你的APP构建于很多文件夹中，而不是一个单独的文件。这些文件夹被叫做bundle。它们不仅仅包含了你的APP，还有你APP的扩展(extensions)，你的构架(frameworks)等。而NSBundle提供了获取这些bundle中资源的标准API。当你使用这些API的时候，它们会自动使用符合当前地区语言的最恰当的资源。建立bundle是Xcode的活儿，所以我们不需要手动去管理这些资源文件放在bundle的具体位置，而是告诉Xcode哪些资源可以被本地化，设置好资源文件对应的语言，然后就交给Xcode去管理这些资源文件在bundle中的位置吧。  

所以我们在加载一些资源文件的时候依然向以前那样从bundle获取url就行啦，Xcode已经帮我们替换成了本地化的资源，前提是你已经在Xcode中设置好了当前语言版本的对应资源。  
###Xcode
在Xcode5中支持了使用base国际化并用自动布局优化国际化后的界面，现在其他资源文件也可以这么干了，甚至可以在Xcode中预览界面布局效果。  

点选一个xib或storyboard文件后，在File Inspector中的Localization中可以设置支持的语言。Xcode会自动从界面元素中提取出文字到strings文件中，翻译人员可以根据注释来在对应语言的strings文件中进行翻译。当然也可以直观化的转换成界面形式的文件来直观化翻译工作：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20141002-2%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

其他诸如图片、声音、影片等资源文件也可以通过类似的方法本地化：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20141002-3%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

在Xcode6中我们可以在Debug时预览不同语言和地区APP的界面效果，这样我们就不用在debug阶段不断的切换模拟器或真机的系统语言了！首先要在scheme中更改下运行APP的语言和地区：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20141002-4%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

注意到后面还有两项：双倍长度的模拟语言和从右到左的模拟语言，这两种是模拟极端状况下来考验我们UI效果的。比如在表达相同语义时英语的长度要比汉语长很多，而德语又比英语长一些，这很可能让APP的界面造成混乱；而还有语言是从右到作的（古汉语的写法？），这也都是一些APP需要考虑的地方。  

在Xcode6的Assistent Editor中我们可以无须在模拟器或真机上运行APP就可以在设计界面时预览界面的本地化效果，并在右下角的语言选项中切换语言：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20141002-5%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

PS：语言和地区这两个选项是有差别的，比如当我们将地区设置成瑞典，虽然我们没有提供对应的瑞典版本的界面文字翻译，但是时间日期的显示方式等还是会遵从瑞典的习惯来显示。所以地区这一项可供选择的选项包含了所有地区，而语言这一选项只包含了我们在国际化工作中所支持的语言，因为只有国际化中支持的语言（比如上图，我只加入了英语和汉语）才有相应的资源文件；而NSFormatter地区格式优化是内建的，无需我们提供格式。  

##本地化--翻译你的APP

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20141002-8%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

之前国际化的工作就是将工程变得有国际范儿，建立起了支持多语种的架构，那么接下来就是苦逼的翻译工作和本地资源准备工作，说好听点儿就叫本地化。  

首先要把表面上的工作做了，也就是翻译用户界面上所有的文字。当然这不是程序员该干的活儿，更不能直接交给谷歌翻译，而程序员与专业翻译人员沟通时还是需要成本的：首先把需要翻译的内容从工程里整理出来，然后交给负责翻译的妹子，等妹子翻译好后再把结果导入工程中，嗯目测工作量亚历山大。PS：为什么翻译是妹子？  

就算妹子再萌，也不能因为这占用了程序猿们宝贵的工作时间！Xcode6简化了导入导出这些资源的流程，它会检查IB资源和源文件并提取“source strings”，并生成XLIFF文件。翻译好的XLIFF文件也可以通过Xcode导入到工程中来生成和更新资源。嗯，可以把省下来的时间干一些其他的事情咯。  

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20141002-6%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)    

PS：XLIFF是由软件开发商、本地化服务提供商、本地化工具提供商等团体共同倡议和设计，由OASIS标准组织发布的用于本地化数据交换的格式标准。它基于XML技术制定软件资源文件格式的转换规格，其目的在于提高软件的本地化作业效率。  

导出和导出XLIFF就是如此简单，选中项目，在Editor菜单中可以就找到：  

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20141002-7%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

也可以通过命令行的方式进行导入导出XLIFF文件操作：  

```
xcodebuide -exportLocalizations -project <project> -localizationPath <path>
xcodebuide -importLocalizations -project <project> -localizationPath <path>
```

##迭代开发--更新你的APP

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20141002-10%402x.png?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

无需把翻译工作推到最后去做，因为导入和导出XLIFF文件是可以持续集成的，一边写代码，一边把现有内容导出XLIFF给他人翻译，这样能提高效率。每当有新的翻译修改时也可以及时更新，Xcode会把XLIFF文件内容与当前翻译进度合并；在导出XLIFF时可以选择导出当前开发使用的语言还是已经翻译中的语言，这些强大的服务无疑是Xcode6所赐予我们的。  

