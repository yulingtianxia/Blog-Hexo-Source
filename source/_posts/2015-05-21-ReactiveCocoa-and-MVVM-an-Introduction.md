title: "ReactiveCocoa and MVVM, an Introduction"
date: 2015-05-21 21:43:37
tags:
- 翻译

---
## MVC
任何一个正经开发过一阵子软件的人都熟悉**MVC**.它意思是**Model View Controller**,是一个在复杂应用设计中组织代码的公认模式.它也被证实在 iOS 开发中有着第二种含义: **Massive View Controller(重量级视图控制器)**.它让许多程序员绞尽脑汁如何去使代码被解耦和组织地让人满意.总的来说,iOS 开发者已经得出结论:他们需要[给view controller 瘦身](http://www.objc.io/issue-1/),并进一步分离事物;但该怎么做呢?  

## MVVM
于是**MVVM**流行起来,它代表**Model View View-Model**,它在这帮助我们创建更易处理,更佳设计的代码.  

在有些情况违背苹果建议的编码方式不是很能讲得通.我不是说不赞成这样子,我指的是可能会弊大于利.比如我不建议你去实现个自己的 view controller 基类并试着自己处理视图生命周期.  

带着这种情绪,我想提个问题:**使用除苹果推荐的 MVC 之外的应用设计模式是愚蠢的么?**  

**不**.有两个原因.  

1. 苹果没有为解决重量级试图控制器问题提供真正的指导.他们留给我们来解决如何向代码添加更多清晰的思路.用 MVVM 来实现这个目的想必是极好哒.(在今年 WWDC 的一些视频中,苹果工程师在屏幕上的示例代码的确少许出现了 view-model,不知道是否因为有它才成为了示例代码)
2. MVVM, 至少是我将要在这里展示的 MVVM 的风格,都跟 MVC 十分兼容.仿佛我们将 MVC 进行到下一个逻辑步骤.

我不会提及 MVC/MVVM 的历史,因为其他地方已经有所介绍,并且我也不精通.我将会关注如何用它进行 iOS/Mac 开发.  

### 定义 MVVM
1. **Model** - model 在 MVVM 中没有真正的变化.取决于你的偏好,你的 model 可能会或可能不会封装一些额外的业务逻辑工作.我更倾向于把它当做一个容纳表现数据-模型对象信息的结构体,并在一个单独的管理类中维护的创建/管理模型的统一逻辑.
2. **View** - view 包含实际 UI 本身(不论是 `UIView` 代码,storyboard 和 xib),任何视图特定的逻辑,和对用户输入的反馈.在 iOS 中这不仅需要 `UIView` 代码和那些文件,还包括很多需由 `UIViewController` 处理的工作.
3. **View-Model** - 这个术语本身会带来困惑,因为它混搭了两个我们已知的术语,但却是完全不同的东东.它不是传统数据-模型结构中模型的意思(又来了,只是我喜欢这个例子).它的职责之一就是作为一个表现视图显示自身所需数据的静态模型;但它也有收集,解释和转换那些数据的责任.这留给了 view (controller) 一个更加清晰明确的任务:呈现由 view-model 提供的数据.

### 关于 view-model 的更多内容
**view-model** 一词的确不能充分表达我们的意图.一个更好的术语可能是 “View Coordinator”(感谢[Dave Lee](https://twitter.com/kastiglione)提的这个 “View Coordinator” 术语,真是个好点子).你可以认为它就像是电视新闻主播背后的研究人员和作家团队.它从必要的资源(数据库,网络服务调用,等)中获取原始数据,运用逻辑,并处理成 view (controller) 的展示数据.它(通常通过属性)暴露给视图控制器需要知道的仅关于显示视图工作的信息(理想地你不会暴漏你的 data-model 对象).它还负责对上游数据的修改(比如更新模型/数据库,API POST 调用).

## MVC 世界中的 MVVM
我认为 MVVM 这个首字母缩写如同 view-model 术语一样,对如何使用它们进行 iOS 开发体现得有点不太准确.让我们再看一下这个首字母缩写,了解下它是怎么与 MVC 融为一体的.  

为了图解表示,我们颠倒了 **MVC** 中的 **V** 和 **C**,于是首字母缩写更能准确地反映出组件间的关系方位,给我们带来 **MCV**.我也会对 **MVVM** 这么干,将 **V(iew)** 移到 **VM** 的右边最终成为了 **MVMV**.(我相信这些首字母缩写起初不排成这样更合理的顺序是有原因的.)  

这是这两种模式如何在 iOS 中组装在一起的简单映射:  

![](http://www.sprynthesis.com/assets/images/MCVMVMV.svg)  

- 我试图遵循区块尺寸(非常)大致对应它们负责的工作量.
- [注意到试图控制器有多大?](http://i0.kym-cdn.com/photos/images/newsfeed/000/228/269/demotivational-posters-theres-your-problem.jpg)
- 你可以看到我们巨大的视图控制器和 view-model 之间有大块工作上的重合.
- 你也可以看看视图控制器在 MVVM 中的足迹有多大一部分是跟视图重合的.

你大可安心获知我们并没有真的去除视图控制器的概念或抛弃 “controller” 术语来匹配 MVVM.(唷.)我们正要将重合的那块工作剥离到 view-model 中,并让视图控制器的生活更加简单.  

我们实际上最终以 **MVMCV** 告终.**M**odel **V**iew-**M**odel **C**ontroller **V**iew.我确信我无拘无束的应用设计模式骇客行为会让人大吃一惊.  

![](http://www.sprynthesis.com/assets/images/MCVMVMV.gif)  

**我们的结果:**  

![](http://www.sprynthesis.com/assets/images/MVMCV.svg)  

现在视图控制器仅关注于用 view-model 的数据配置和管理各种各样的视图,并在先关用户输入时让 view-model 获知并需要向上游修改数据.视图控制器不需要了解关于网络服务调用,Core Data,模型对象等.(事实上有时通过 view-model 头文件而不是复制一大堆属性来暴漏 model 是很务实的,后面还会有)  

view-model 会在视图控制器上以一个属性的方式存在.视图控制器知道 view-model 和它的公有属性,但是 view-model 对视图控制器一无所知.你早就该对这个设计感觉好多了因为我们的关注点在这儿进行更好地分离.  

另一种方式来帮助你理解如何把我们的组件组装在一起,还有职责落在谁头上,就是来看看我们新的应用构建模块层级图.  

![](http://www.sprynthesis.com/assets/images/mvvm-layers.svg)  

(感谢[Dave Lee @kastiglione](https://twitter.com/kastiglione))

## View-Model 和 View Controller, 在一起，但独立

我们来看个简单的 view-model 头文件来对我们新构件的长相有个更好地概念.为了情节简单,我们构建按了一个伪造的推特客户端来查看任何推特用户的最新回复,通过输入他们的姓名并点击 "Go". 我们的样例界面将会是这样:  

- 有一个让用户输入他们姓名的 `UITextField` ,和一个写着 "Go" 的 `UIButton`
- 有显示被查看的当前用户头像和姓名的 `UIImageView` 和 `UILabel` 各一个
- 下面放着一个显示最新回复推文的 `UITableView`
- 允许无限滚动

![](http://www.sprynthesis.com/assets/images/tweeboatplus.svg)  

### View-Model 实例
我们的 view-model 头文件应该长这样:  

<script src="https://gist.github.com/sprynmr/433c36a0796f17ec1946.js"></script>

相当直截了当的填充.注意到这些**壮丽的 `readonly` 属性**了么?这个 view-model 暴漏了视图控制器所必需的最小量信息,视图控制器实际上并不在乎 view-model 是如何获得这些信息的.现在我们两者都不在乎.仅仅假定你习惯于标准的网络服务请求,校验,数据操作和存储.  

#### view-model 不做的事儿

- 对视图控制器以任何形式直接起作用或直接通告其变化

### View Controller(视图控制器)

#### 视图控制器从 view-model 获取的数据将用来:

- 当 `usernameValid` 的值发生变化时触发 "Go" 按钮的 `enabled` 属性
- 当 `usernameValid` 等于 `NO` 时调整按钮的 `alpha` 值为0.5(等于 `YES` 时设为1.0)
- 更新 `UILable` 的 `text` 属性为字符串 `userFullName` 的值
- 更新 `UIImageView` 的 `image` 属性为 `userAvatarImage` 的值
- 用 `tweets` 数组中的对象设置表格视图中的 cell (后面会提到)
- 当滑到表格视图底部时如果 `allTweetsLoaded` 为 `NO`,提供一个 显示 “loading” 的 cell

#### 视图控制器将对 view-model 起如下作用:

- 每当 `UITextField` 中的文本发生变化,更新 view-model 上仅有的 `readwrite` 属性 `username`
- 当 "Go" 按钮被按下时调用 view-model 上的 `getTweetsForCurrentUsername` 方法
- 当到达表格中的 "loading" cell 时调用 view-model 上的 `loadMoreTweets` 方法

#### 视图控制器不做的事儿:

- 发起网络服务调用
- 管理 `tweets` 数组
- 判定 `username` 内容是否有效
- 将用户的姓和名格式化为全名
- 下载用户头像并转成 `UIImage`(如果你习惯在 `UIImageView` 上使用类别从网络加载图片,你可以暴漏 URL 而不是图片.这样没有让 view-model 和 UIKit 更完全摆脱,但我视 `UIImage` 为数据而非数据的确切显示.这些东西不是固定死的.)
- 流汗

请再次注意视图控制器总的责任是处理 view-model 中的变化.

## 子 View-Model

我提到过使用 view-model 上的 `tweets` 数组中的对象配置表格视图的 cell.通常你会期待展现 `tweets` 的是数据-模型对象.你可能已经对其感到奇怪,因为我们试图通过 MVVM 模式不暴漏数据-模型对象.(前面提到过的)  

**view-model 不必在屏幕上显示所有东西.**你可用子 view-model 来代表屏幕上更小,更潜在被封装的部分.如果一个视图上的一小块儿(比如表格的 cell)在 app 中可以被重用以及(或)表现多个数据-模型对象,子 view-model 会格外有利.  

你不总是需要子 view-model. 比如,我可能用表格 header 视图来渲染我们“tweetboat plus”应用的顶部.它不是个可重用的组件,所以我可能仅是将我们已经给视图控制器用过的相同的 view-model 传给那个自定义的 header 视图.它会用到 view-model 中它需要的信息,而无视余下的部分.这对于保持子视图同步是极好的方式,因为它们可以有效地与信息中相同确切的上下文作用,并观察确切相同属性的更新.  

在我们的例子中, `tweets` 数组将会被下面这样的子 view-model 充满:

<script src="https://gist.github.com/sprynmr/adfd5eb3775a225a2011.js"></script>

你可能认为这也太像普通"推特"里的数据-模型对象了吧.为啥要干将其转化成 view-model 的工作?即使类似, view-model 让我们限制信息只暴露给我们需要的地方,提供额外数据转换的属性,或为特定的视图计算数据.(此外,当可以不暴露可变数据-模型对象时也是极好的,因为我们希望 view-model 自己承担起更新它们的任务,而不是靠视图或视图控制器.)  

### 妈, View-Model 从哪来?

那么 view-model 是何时何处被创建的呢?视图控制器创建它们自己的 view-model 么?  

#### View-Model 产生 View-Model

严格来说,你应该为 app delegate 中的顶级视图控制器创建一个 view-model.当展示一个新的视图控制器时,或很小的视图被 view-model 表现时,你应要求当前的 view-model 为你创建一个子 view-model.  

![](http://www.sprynthesis.com/assets/images/child-view-models.svg)  

加入我们想要在用户轻拍应用顶部的头像时添加一个资料视图控制器.我们可以为一级 view-model 添加类似如下方法:  

``` objc
- (MYTwitterUserProfileViewModel *) viewModelForCurrentUser;
```

然后在我们的一级视图控制器中这么用它:  

<script src="https://gist.github.com/sprynmr/194ab0c97500592c3954.js"></script>

在这个例子中我将会展现当前用户的资料视图控制器,但是我的资料视图控制器需要一个 view-model.我这的主视图控制器不知道(也不该知道)用于创建关联相关用户 view-model 的全部必要数据,所以它请求它自己的 view-model 来干这种创建新 view-model 的苦差事.  

#### View-Model 列表

至于我们的推特 cell,当数据驱动屏幕(在这个例子中或许是通过网络服务调用)聚到一起时,我将会代表性地提前为对应的 cell 创建所有的 view-model. 所以在我们这个方案中, `tweets` 将会是一个 `MYTweetCellViewModel` 对象数组.在我的表格视图中的 `cellForRowAtIndexPath` 方法中,我将会在正确的索引上简单地抓取 view-model, 并把它赋值给我的 cell 上的 view-model 属性.  

## Functional Core, Imperative Shell