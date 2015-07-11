title: "ReactiveCocoa 和 MVVM 入门"
date: 2015-05-21 21:43:37
tags:
- 翻译
- RAC

---

翻译自[ReactiveCocoa and MVVM,  an Introduction](http://www.sprynthesis.com/2014/12/06/reactivecocoa-mvvm-introduction). ~~文中引用的 Gist 可能无法显示. 为了和谐社会, 请[科学上网](http://tizipro.com/?r=ee0508bc191f5651)😂~~   

<!--more-->

## MVC
任何一个正经开发过一阵子软件的人都熟悉**MVC**. 它意思是**Model View Controller**, 是一个在复杂应用设计中组织代码的公认模式. 它也被证实在 iOS 开发中有着第二种含义:  **Massive View Controller(重量级视图控制器)**. 它让许多程序员绞尽脑汁如何去使代码被解耦和组织地让人满意. 总的来说, iOS 开发者已经得出结论: 他们需要[给视图控制器瘦身](http://www.objc.io/issue-1/), 并进一步分离事物;但该怎么做呢?  

## MVVM
于是**MVVM**流行起来, 它代表**Model View View-Model**, 它在这帮助我们创建更易处理, 更佳设计的代码.   

有时候违背苹果建议的编码方式并不是个好做法. 我不是说不赞成这样子, 我指的是可能会弊大于利. 比如我不建议你去实现个自己的 view controller 基类并试着自己处理视图生命周期.   

带着这种情绪, 我想提个问题: **使用除苹果推荐的 MVC 之外的应用设计模式是愚蠢的么?**  

**不**. 有两个原因.   

1.  苹果没有为解决重量级试图控制器问题提供真正的指导. 他们留给我们来解决如何向代码添加更多清晰的思路. 用 MVVM 来实现这个目的想必是极好哒. (在今年 WWDC 的一些视频中, 苹果工程师在屏幕上的示例代码的确少许出现了 view-model, 不知道是否因为有它才成为了示例代码)
2.  MVVM,  至少是我将要在这里展示的 MVVM 的风格, 都跟 MVC 十分兼容. 仿佛我们将 MVC 进行到下一个逻辑步骤. 

我不会提及 MVC/MVVM 的历史, 因为其他地方已经有所介绍, 并且我也不精通. 我将会关注如何用它进行 iOS/Mac 开发.   

### 定义 MVVM
1.  **Model** - model 在 MVVM 中没有真正的变化. 取决于你的偏好, 你的 model 可能会或可能不会封装一些额外的业务逻辑工作. 我更倾向于把它当做一个容纳表现数据-模型对象信息的结构体, 并在一个单独的管理类中维护的创建/管理模型的统一逻辑. 
2.  **View** - view 包含实际 UI 本身(不论是 `UIView` 代码, storyboard 和 xib), 任何视图特定的逻辑, 和对用户输入的反馈. 在 iOS 中这不仅需要 `UIView` 代码和那些文件, 还包括很多需由 `UIViewController` 处理的工作. 
3.  **View-Model** - 这个术语本身会带来困惑, 因为它混搭了两个我们已知的术语, 但却是完全不同的东东. 它不是传统数据-模型结构中模型的意思(又来了, 只是我喜欢这个例子). 它的职责之一就是作为一个表现视图显示自身所需数据的静态模型;但它也有收集, 解释和转换那些数据的责任. 这留给了 view (controller) 一个更加清晰明确的任务: 呈现由 view-model 提供的数据. 

### 关于 view-model 的更多内容
**view-model** 一词的确不能充分表达我们的意图. 一个更好的术语可能是 “View Coordinator”(感谢[Dave Lee](https://twitter.com/kastiglione)提的这个 “View Coordinator” 术语, 真是个好点子). 你可以认为它就像是电视新闻主播背后的研究人员和作家团队. 它从必要的资源(数据库, 网络服务调用, 等)中获取原始数据, 运用逻辑, 并处理成 view (controller) 的展示数据. 它(通常通过属性)暴露给视图控制器需要知道的仅关于显示视图工作的信息(理想地你不会暴漏你的 data-model 对象). 它还负责对上游数据的修改(比如更新模型/数据库, API POST 调用). 

## MVC 世界中的 MVVM
我认为 MVVM 这个首字母缩写如同 view-model 术语一样, 对如何使用它们进行 iOS 开发体现得有点不太准确. 让我们再检查下这个首字母缩写, 了解下它是怎么与 MVC 融为一体的.   

为了图解表示, 我们颠倒了 **MVC** 中的 **V** 和 **C**, 于是首字母缩写更能准确地反映出组件间的关系方位, 给我们带来 **MCV**. 我也会对 **MVVM** 这么干, 将 **V(iew)** 移到 **VM** 的右边最终成为了 **MVMV**. (我相信这些首字母缩写起初不排成这样更合理的顺序是有原因的. )  

这是这两种模式如何在 iOS 中组装在一起的简单映射:   

![](http://www.sprynthesis.com/assets/images/MCVMVMV.svg)  

- 我试图遵循区块尺寸(非常)大致对应它们负责的工作量. 
- [注意到视图控制器有多大?](http://i0.kym-cdn.com/photos/images/newsfeed/000/228/269/demotivational-posters-theres-your-problem.jpg)
- 你可以看到我们巨大的视图控制器和 view-model 之间有大块工作上的重合. 
- 你也可以看看视图控制器在 MVVM 中的足迹有多大一部分是跟视图重合的. 

你大可安心获知我们并没有真的去除视图控制器的概念或抛弃 “controller” 术语来匹配 MVVM. (唷. )我们正要将重合的那块工作剥离到 view-model 中, 并让视图控制器的生活更加简单.   

我们实际上最终以 **MVMCV** 告终. **M**odel **V**iew-**M**odel **C**ontroller **V**iew. 我确信我无拘无束的应用设计模式骇客行为会让人大吃一惊.   

![](http://www.sprynthesis.com/assets/images/MCVMVMV.gif)  

**我们的结果: **  

![](http://www.sprynthesis.com/assets/images/MVMCV.svg)  

现在视图控制器仅关注于用 view-model 的数据配置和管理各种各样的视图, 并在先关用户输入时让 view-model 获知并需要向上游修改数据. 视图控制器不需要了解关于网络服务调用, Core Data, 模型对象等. (事实上有时通过 view-model 头文件而不是复制一大堆属性来暴漏 model 是很务实的, 后面还会有)  

view-model 会在视图控制器上以一个属性的方式存在. 视图控制器知道 view-model 和它的公有属性, 但是 view-model 对视图控制器一无所知. 你早就该对这个设计感觉好多了因为我们的关注点在这儿进行更好地分离.   

帮助你理解我们如何把组件组装在一起还有组件对应职责的另一种方式, 就是着眼于我们新的应用构建模块层级图.   

![](http://www.sprynthesis.com/assets/images/mvvm-layers.svg)  

(感谢[Dave Lee @kastiglione](https://twitter.com/kastiglione))

## View-Model 和 View Controller,  在一起，但独立

我们来看个简单的 view-model 头文件来对我们新构件的长相有个更好地概念. 为了情节简单, 我们构建按了一个伪造的推特客户端来查看任何推特用户的最新回复, 通过输入他们的姓名并点击 "Go".  我们的样例界面将会是这样:   

- 有一个让用户输入他们姓名的 `UITextField` , 和一个写着 "Go" 的 `UIButton`
- 有显示被查看的当前用户头像和姓名的 `UIImageView` 和 `UILabel` 各一个
- 下面放着一个显示最新回复推文的 `UITableView`
- 允许无限滚动

![](http://www.sprynthesis.com/assets/images/tweeboatplus.svg)  

### View-Model 实例
我们的 view-model 头文件应该长这样:   

```objc
//MYTwitterLookupViewModel.h
@interface MYTwitterLookupViewModel: NSObject
 
@property (nonatomic, assign, readonly, getter=isUsernameValid) BOOL usernameValid;
@property (nonatomic, strong, readonly) NSString *userFullName;
@property (nonatomic, strong, readonly) UIImage *userAvatarImage;
@property (nonatomic, strong, readonly) NSArray *tweets;
@property (nonatomic, assign, readonly) BOOL allTweetsLoaded;
 
@property (nonatomic, strong, readwrite) NSString *username;
 
- (void) getTweetsForCurrentUsername;
- (void) loadMoreTweets;
```

相当直截了当的填充. 注意到这些**壮丽的 `readonly` 属性**了么?这个 view-model 暴漏了视图控制器所必需的最小量信息, 视图控制器实际上并不在乎 view-model 是如何获得这些信息的. 现在我们两者都不在乎. 仅仅假定你习惯于标准的网络服务请求, 校验, 数据操作和存储.   

#### view-model 不做的事儿

- 对视图控制器以任何形式直接起作用或直接通告其变化

### View Controller(视图控制器)

#### 视图控制器从 view-model 获取的数据将用来: 

- 当 `usernameValid` 的值发生变化时触发 "Go" 按钮的 `enabled` 属性
- 当 `usernameValid` 等于 `NO` 时调整按钮的 `alpha` 值为0. 5(等于 `YES` 时设为1. 0)
- 更新 `UILable` 的 `text` 属性为字符串 `userFullName` 的值
- 更新 `UIImageView` 的 `image` 属性为 `userAvatarImage` 的值
- 用 `tweets` 数组中的对象设置表格视图中的 cell (后面会提到)
- 当滑到表格视图底部时如果 `allTweetsLoaded` 为 `NO`, 提供一个 显示 “loading” 的 cell

#### 视图控制器将对 view-model 起如下作用: 

- 每当 `UITextField` 中的文本发生变化, 更新 view-model 上仅有的 `readwrite` 属性 `username`
- 当 "Go" 按钮被按下时调用 view-model 上的 `getTweetsForCurrentUsername` 方法
- 当到达表格中的 "loading" cell 时调用 view-model 上的 `loadMoreTweets` 方法

#### 视图控制器不做的事儿: 

- 发起网络服务调用
- 管理 `tweets` 数组
- 判定 `username` 内容是否有效
- 将用户的姓和名格式化为全名
- 下载用户头像并转成 `UIImage`(如果你习惯在 `UIImageView` 上使用类别从网络加载图片, 你可以暴漏 URL 而不是图片. 这样就给 view-model 与 UIKit 之间一个更清晰的划分, 但我视 `UIImage` 为数据而非数据的确切显示. 这些东西不是固定死的. )
- 流汗

请再次注意视图控制器总的责任是处理 view-model 中的变化. 

## 子 View-Model

我提到过使用 view-model 上的 `tweets` 数组中的对象配置表格视图的 cell.通常你会期待展现 `tweets` 的是数据-模型对象. 你可能已经对其感到奇怪, 因为我们试图通过 MVVM 模式不暴漏数据-模型对象. (前面提到过的)  

**view-model 不必在屏幕上显示所有东西. **你可用子 view-model 来代表屏幕上更小, 更潜在被封装的部分. 如果一个视图上的一小块儿(比如表格的 cell)在 app 中可以被重用以及(或)表现多个数据-模型对象, 子 view-model 会格外有利.   

你不总是需要子 view-model.  比如, 我可能用表格 header 视图来渲染我们“tweetboat plus”应用的顶部. 它不是个可重用的组件, 所以我可能仅是将我们已经给视图控制器用过的相同的 view-model 传给那个自定义的 header 视图. 它会用到 view-model 中它需要的信息, 而无视余下的部分. 这对于保持子视图同步是极好的方式, 因为它们可以有效地与信息中相同确切的上下文作用, 并观察确切相同属性的更新.   

在我们的例子中,  `tweets` 数组将会被下面这样的子 view-model 充满: 

```
//MyTweetCellViewModel.h
@interface MYTweetCellViewModel: NSObject
 
@property (nonatomic, strong, readonly) NSString *tweetAuthorFullName;
@property (nonatomic, strong, readonly) UIImage *tweetAuthorAvatarImage;
@property (nonatomic, strong, readonly) NSString *tweetContent;
```

你可能认为这也太像普通"推特"里的数据-模型对象了吧. 为啥要干将其转化成 view-model 的工作?即使类似,  view-model 让我们限制信息只暴露给我们需要的地方, 提供额外数据转换的属性, 或为特定的视图计算数据. (此外, 当可以不暴露可变数据-模型对象时也是极好的, 因为我们希望 view-model 自己承担起更新它们的任务, 而不是靠视图或视图控制器. )  

### View-Model 从哪来?

那么 view-model 是何时何处被创建的呢?视图控制器创建它们自己的 view-model 么?  

#### View-Model 产生 View-Model

严格来说, 你应该为 app delegate 中的顶级视图控制器创建一个 view-model. 当展示一个新的视图控制器时, 或很小的视图被 view-model 表现时, 你应要求当前的 view-model 为你创建一个子 view-model.   

![](http://www.sprynthesis.com/assets/images/child-view-models.svg)  

加入我们想要在用户轻拍应用顶部的头像时添加一个资料视图控制器. 我们可以为一级 view-model 添加类似如下方法:   

```objc
- (MYTwitterUserProfileViewModel *) viewModelForCurrentUser;
```

然后在我们的一级视图控制器中这么用它:   

```
//MYMainViewController.m 
- (IBAction) didTapPrimaryUserAvatar
{
    MYTwitterUserProfileViewModel *userProfileViewModel = [self.viewModel viewModelForCurrentUser];
    
    MYTwitterUserProfileViewController *profileViewController = 
        [[MYTwitterUserProfileViewController alloc] initWithViewModel: userProfileViewModel];
    [self.navigationController pushViewController: profileViewController animated:YES];
}
```

在这个例子中我将会展现当前用户的资料视图控制器, 但是我的资料视图控制器需要一个 view-model. 我这的主视图控制器不知道(也不该知道)用于创建关联相关用户 view-model 的全部必要数据, 所以它请求它自己的 view-model 来干这种创建新 view-model 的苦差事.   

#### View-Model 列表

至于我们的推特 cell, 当数据驱动屏幕(在这个例子中或许是通过网络服务调用)聚到一起时, 我将会代表性地提前为对应的 cell 创建所有的 view-model.  所以在我们这个方案中,  `tweets` 将会是一个 `MYTweetCellViewModel` 对象数组. 在我的表格视图中的 `cellForRowAtIndexPath` 方法中, 我将会在正确的索引上简单地抓取 view-model,  并把它赋值给我的 cell 上的 view-model 属性.   

## Functional Core,  Imperative Shell

view-model 这种通往应用设计的方法是一块应用设计之路上的垫脚石, 这种被称作["Functional Core,  Imperative Shell"](https://www.destroyallsoftware.com/screencasts/catalog/functional-core-imperative-shell)的应用设计由[Gary Bernhardt](https://twitter.com/garybernhardt)创造. (我最近十分有幸去听[Andy Matuschak](http://andymatuschak.org)关于这方面的演讲, 他为"胖的数值层, 瘦的对象层"提出充分理由. 虽然观点相似, 但关注于我们怎样移除对象和它们状态的边界影响性质, 并用 Swift 中的新数据结构构建更加函数式, 可测试的数值层. )

### Functional Core

view-model 就是 [“functional core”](http://www.smashingmagazine.com/2014/07/02/dont-be-scared-of-functional-programming/), 尽管实际上在 iOS/Objective-C 中达到纯函数水平是很棘手的(Swift 提供了一些附加的函数性, 这会让我们更接近). 大意是让我们的 view-model 尽可能少的对剩余的"应用世界"的依赖和影响. 那意味着什么?想起你第一次学编程时可能学到的简单函数吧. 它们可能接受一两个参数并输出一个结果. **数据输入, 数据输出.**这个函数可能是做一些数学运算或是将姓和名结合到一起. 无论应用的其他地方发生啥, 这个函数总是对相同的输入产生相同的输出. 这就是函数式方面.   

这就是我们为 view-model 谋求的东西. 他们富有逻辑和转换数据并将结果存到属性的功能. 理想上相同的输入(比如网络服务响应)将会导出相同的输出(属性的值). 这意味着尽可能多地消除由"应用世界"剩余部分带来的可能影响输出的因素, [比如使用一堆状态. ](http://www.sprynthesis.com/2014/06/15/why-reactivecocoa/)**一个好的第一步就是不要再 view-model 头文件中引入 UIKit.h.**(这是个重大原则, 但也有些灰色区域. 比如, 你可能认为 `UIImage` 是数据而不是展示信息. PS:  我爱这么干. 既然这样的话就得引入 UIKit. h 以便使用 `UIImage` 类)UIKit 其性质就是将要影响许多应用世界. 它包含很多"副作用", 凭借改变一个值或调用一个函数将触发很多间接(甚至未知)的改变.   

**更新:** 刚刚看了 Andy 在[函数式 Swift 会议](http://2014.funswiftconf.com)上给出的另一个超赞的演讲, 于是又想到了一些. 要清楚你的 view-model *仍然*只是一个对象, 而不用维护一些状态(否则它将不会是你视图中非常好用的模型了. )但你仍该努力将尽可能多的逻辑移到无状态的函数"值"中. 再重复一次, Swift在这方面比 Objective-C 更加可行. 

### Imperative (Declarative?) Shell

命令式外壳 (Imperative Shell) 是我们需要做所有的状态转换, 应用世界改变的苦差事的地方, 为的是将 view-model 数据转成给用户在屏幕上看到的东西. 这是我们的视图(控制器), 实际上我们在这分离 UIKit 的工作. 我仍将特别注意尽可能消除状态并用 ReactiveCocoa 这种陈述性质的东西做这方面工作, 而 iOS 和 UIKit 在设计上是命令式的.  (表格的 data source 就是个很好的例子, 因为它的委托模式强制将状态应用到委托中, 为了当请求发生时能够为表格视图提供信息. 实际上委托模式通常强制一大堆状态的使用)

### 可测试的核心

iOS 的单元测试是个脏, 苦, 乱的活儿. 至少我去做的时候得出的是这么个结论. 就这方面我还出读过一两本书, 但当开始做视图控制器的 mocking 和 swizzling 使其一些逻辑可测试时, 我目光呆滞. 我最终把单元测试归入模型和任何同类别模型管理类中. (译者注:  mock 是测试常用的手段, 而 method swizzling 是基于 Objective-C Runtime 交换方法实现的黑魔法)  

这个函数式核心一样的 view-model 的最大优点, 除了 bug 数量随着状态数递减之外, 就是*变得非常能够进行单元测试*. 如果你有那种每次输入相同而产生的输出也相同的方法, 那就非常适合单元测试的世界. 我们现在将我们的数据用获取/逻辑/转换提取出, 避免了视图控制器的复杂性. 那意味着构建棒棒哒测试时不需要用疯狂的 mock 对象,  method swizzling,  或其他疯癫的变通方法(希望能有).   

## 连接一切

**那么当 view-model 的共有属性发生变化时我们如何更新我们的视图呢?**  

绝大部分时间我们用对应的 view-model 来初始化视图控制器, 有点类似我们刚刚在上文见到的:   

```
MYTwitterUserProfileViewController *profileViewController =
    [[MYTwitterUserProfileViewController alloc] initWithViewModel:  userProfileViewModel];
```

有时你无法在初始化时将 view-model 传入, 比如在 storyboard segue 或 cell dequeuing 的情况下. 这时你应该在讨论中的视图(控制器)中暴露一个公有可写的 view-model 属性.   

```
MYTwitterUserCell *cell =
    [self.tableView dequeueReusableCellWithIdentifier: @"MYTwitterUserCell" forIndexPath: indexPath];
// grab the cell view-model from the vc view-model and assign it
cell.viewModel = self.viewModel. tweets[indexPath. row];
```

有时我们可以在钩子程序调用前传入 view-model,  比如 `init` 和 `viewDidLoad`,  我们可以从view-model 的属性初始化所有 UI 元素的状态.   

```
//dontDoThis1.m 
- (id) initWithViewModel:(MYTwitterLookupViewModel *) viewModel {
    self = [super init];
    if (!self) return nil;
    _viewModel = viewModel;
    return self;
}
- (void) viewDidLoad {
    [super viewDidLoad];
    _goButton.enabled = viewModel.isUsernameValid;
    _goButton.alpha = viewModel.isUsernameValid ? 1 : 0.5;
    // etc
}
```

好棒!我们已经配置好了初始值. 当 view-model 上的数据改变时怎么办? 当"go" 按钮在什么时候可用了怎么办?当用户标签和头像在什么时候从网络上下载并填充了怎么办?  

我们可以将视图控制器暴露给 view-model,  以便于当相关数据变化或类似事件发送时它可以调用一个 "updateUI" 方法. (别这么干. )在 view-model 上将视图控制器作为一个委托?当 view-model 内容有变化时发个通知?(不不不不. )

我们的视图控制器会感知一些变化的发生. 我们可以使用从 `UITextfield` 得来的委托方法在每当有字符变化时通过检查 view-model 来更新按钮的状态.   

```
//dontDoThisEither.m
- (void)textFieldDidChange:(UITextField *)sender {
    // update the view-model
    self.viewModel.username = sender.text;
    // check if things are now valid
    self.goButton.enabled = self.viewModel.isUsernameValid;
    self.goButton.alpha = self.viewModel.isUsernameValid ? 1.0 : 0.5;
}
```

这种方法解决的场景是在只有再文本框发生变化时才会影响 view-model 中的 `isUsernameValid` 值. 假使还有其他变量/动作改变 `isUsernameValid` 的状态将会怎么样?对于 view-model 中的网络调用会怎么样?或许我们该为 view-model 上的方法加一个完成后回调处理, 这样我们此时就可以更新 UI 的一切东西了?使用珍贵而笨重的 KVO 方法怎么样?

我们或许最终使用多种多样我们熟悉的机制将 view-model 和视图控制器所有的接触点都连起来, 但你已经知道了[标题上不是这么写的](http://www.sprynthesis.com/2014/06/15/why-reactivecocoa/). 这样在代码中创建了大量的入口点, 仅仅为了简单的更新 UI 就要在代码中完全重新创建应用状态上下文. 

## 进入 ReactiveCocoa

ReactiveCocoa(RAC) 是来拯救我们的, 并恰好返回给我们一点理智. 让我们看看如何做到.   

思考在一个新的用户页面上控制信息的流动, 当表单合法时更新提交按钮的状态. 你现在可能会照下面这么做:   

![](http://www.sprynthesis.com/assets/images/new-user-form-imperative.svg)  

你最后通过使用状态, 小心翼翼地代码中许多不同且零碎无关的内容穿到简单的逻辑上. 看看你信息流中所有不同的入口点?(这还只是*一个* UI 元素中的*一条*逻辑线. )[我们程序中现在用的抽象概念还不够厉害](http://www.sprynthesis.com/2014/06/15/why-reactivecocoa/), 不能为我们追踪所有事物的关系, 所以我们停止自己去干这蛋疼事儿.   

让我们看看陈述版本: 

![](http://www.sprynthesis.com/assets/images/new-user-form-declarative.svg)  

这看起来可能像是为我们应用流程文档中的一张老旧的计算机科学图解. 通过陈述式的编程, 我们使用了更高层次的抽象, 来让我们实际编程更靠近我们在脑海中设计流程的方式. 我们让电脑为我们做更多工作. 实际的代码更加像这幅图了.   

### RACSignal

`RACSignal` (信号)就 RAC 来说是构造单元. 它代表我们最终将要收到的信息. 当你能将未来某时刻收到的消息具体表示出来时, **你可以开始预先(陈述性)运用逻辑并构建你的信息流,**而不是必须等到事件发生(命令式).   

**信号会为了控制通过应用的信息流而获得所有这些异步方法(委托, 回调 block,  通知,  KVO, target/action 事件观察, 等)并将它们统一到一个接口下.**这只是直观理解. 不仅是这些, 因为信息会流过你的应用, 它还提供给你轻松转换/分解/合并/过滤信息的能力.   

![](http://www.sprynthesis.com/assets/images/replace-async-tools.svg)  

#### 那么什么是信号呢?这是一个信号: 

![](http://www.sprynthesis.com/assets/images/signal-no-subscribers.svg)  

信号是一个发送一连串值的物体. 但是我们这儿的信号啥也不干, 因为它还没有订阅者. 如果有订阅者监听时(已订阅)信号才会发信息. 它将会向那个订阅者发送0或多个载有数值的"next"事件, 后面跟着一个"complete"事件或一个"error"事件. (信号类似于其他语言/工具包中的 "promise", 但更强大, 因为它不仅限于向它的订阅者一次只传递一个返回值. )  

![](http://www.sprynthesis.com/assets/images/signal-with-subscriber.svg)  

正如我之前提到的, 如果觉得需要的话你可以过滤, 转换, 分解和合并那些值. 不同的订阅者可能需要使用信号通过不同方式发送的值.   

![](http://www.sprynthesis.com/assets/images/signal-map.svg)  

#### 信号发送的值是从哪获得的?

信号是一些等待某事发生的异步代码, 然后把结果值发送给它们的订阅者. 你可以用 `RACSignal` 的类方法 `createSignal: ` 手动创建信号:   

```
//networkSignal.m
RACSignal *networkSignal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NetworkOperation *operation = [NetworkOperation getJSONOperationForURL:@"http://someurl"];
        [operation setCompletionBlockWithSuccess:^(NetworkOperation *theOperation, id *result) {
            [subscriber sendNext:result];
            [subscriber sendCompleted];
        } failure:^(NetworkOperation *theOperation, NSError *error) {
            [subscriber sendError:error];
        }];
```

我在这用一个具有成功和失败 block (伪造)的网络操作创建了一个信号. (如果我想让信号在被订阅时才让网络请求发生, 还可以用 `RACSignal` 的类方法 `defer`. )我在成功的 block 里使用提供的 `subscriber` 对象调用 `sendNext: ` 和 `sendCompleted: ` 方法, 或在失败的 block 中调用 `sendError: `. 现在我可以订阅这个信号并将在响应返回时接收到 json 值或是 error.   

幸运的是,  RAC 的创造者实际上使用它们自己的库来创建真的事物(捉摸一下), 所以对于我们在日常需要什么, 他们有很强烈的想法. 他们为我们提供了很多机制, 来从我们通常使用的现存的异步模式中拉取信号. 别忘了如果你有一个没有被某个内建信号覆盖到的异步任务, 你可以*很容易地*用 `createSignal: ` 或类似方法来创建信号.   

一个被提供的机制就是 `RACObserve()` 宏. (如果你不喜欢宏, 你可以简单地看看罩子下面并用稍微多些冗杂的描述. 这也非常好. 在我们得到 [Swift 版本的替代](https://github.com/ReactiveCocoa/ReactiveCocoa/pull/1382)之前, 这也有[在 Swift 中使用 RAC](http://blog.scottlogic.com/2014/07/24/mvvm-reactivecocoa-swift.html) 的解决方案. )这个宏是 RAC 中对 KVO 中那些悲惨的 API 的替代. 你只需要传入对象和你想观察的那个对象某属性的 keypath. 给出这些参数后,  `RACObserve` 会创建一个信号, 一旦它有了订阅者, 它就立刻发送那个属性的当前值, 并在发送那个属性在这之后的任何变化.   

```
RACSignal *usernameValidSignal = RACObserve(self.viewModel,  usernameIsValid);
```

![](http://www.sprynthesis.com/assets/images/signal-racobserve.svg)  

这仅是提供用于创建信号的一个工具. 这里有几个立即可用的方式, 来从内置控制流机制中拉取信号:   

```
//signals.m
RACSignal *controlUpdate = [myButton rac_signalForControlEvents:UIControlEventTouchUpInside];
    // signals for UIControl events send the control event value (UITextField, UIButton, UISlider, etc)
    // subscribeNext:^(UIButton *button) { NSLog(@"%@", button); // UIButton instance }
 
RACSignal *textChange = [myTextField rac_textSignal];
    // some special methods are provided for commonly needed control event values off certain controls
    // subscribeNext:^(UITextField *textfield) { NSLog(@"%@", textfield.text); // "Hello!" }
 
RACSignal *alertButtonClicked = [myAlertView rac_buttonClickedSignal];
    // signals for some delegate methods send the delegate params as the value
    // e.g. UIAlertView, UIActionSheet, UIImagePickerControl, etc
    // (limited to methods that return void)
    // subscribeNext:^(NSNumber *buttonIndex) { NSLog(@"%@", buttonIndex); // "1" }
 
RACSignal *viewAppeared = [self rac_signalForSelector:@selector(viewDidAppear:)];
    // signals for arbitrary selectors that return void, send the method params as the value
    // works for built in or your own methods
    // subscribeNext:^(NSNumber *animated) { NSLog(@"viewDidAppear %@", animated); // "viewDidAppear 1" }
```

记住你也能轻松创建自己的信号, 包括[替代那些没有内建支持的其他委托](http://spin.atomicobject.com/2014/02/03/objective-c-delegate-pattern/). 我们现在能够从所有这些不连贯的异步/控制流工具中拉取出信号并将他们合并, 试想想这该多酷!这些会成为我们之前看到的陈述性图表中的节点. 真是兴奋. 

#### 什么是订阅者?

简言之, 订阅者就是一段代码, 它等待信号给它发送一些值, 然后订阅者就能处理这些值了. (它也可以作用于 "complete" 和 "error" 事件. )

这有一个简单的订阅者, 是通过向信号的实例方法 `subscribeNext` 传入一个 block 来创建的. 我们在这通过 `RACObserve()` 宏创建信号来观察一个对象上属性的当前值, 并把它赋值给一个内部属性.   

```
- (void) viewDidLoad {
  // . . . 
  // create and get a reference to the signal
  RACSignal *usernameValidSignal = RACObserve(self.viewModel,  isUsernameValid);
  // update the local property when this value changes
  [usernameValidSignal subscribeNext: ^(NSNumber *isValidNumber) {
          self.usernameIsValid = isValidNumber. boolValue
      }];
}
```

注意 RAC 只处理对象, 而不处理像 `BOOL` 这样的原始值. 不过不用担心,  RAC 通常会帮你这些转换.   

幸运的是 RAC 的创造者也意识到这种绑定行为的普遍必要性, 所以他们提供了另一个宏 `RAC()`.  与 `RACObserve()` 相同, 你提供想要与即将到来的值绑定的对象和参数, 在其内部它所做的是创建一个订阅者并更新其属性的值. 我们的例子现在看起来像这样:   

```
- (void) viewDidLoad {
    //. . . 
    RAC(self,  usernameIsValid) = RACObserve(self.viewModel,  isUsernameValid);
}
```

考虑下我们的目标, 这么干有点傻啊. 我们不需要将信号发送的值存到属性中(这会创建状态), 我们真正要做的是用从那个值获取到信息来更新 UI. 

#### 转换数据流

现在我们进入 RAC 为我们提供的用于转换数值流的方法. 我们将会利用 `RACSignal` 的实例方法 `map`. 

```
//transformingStreams.m
- (void) viewDidLoad {
    //...
    RACSignal *usernameIsValidSignal = RACObserve(self.viewModel, isUsernameValid);
    RAC(self.goButton, enabled) = usernameIsValidSignal;
    RAC(self.goButton, alpha) = [usernameIsValidSignal
        map:^id(NSNumber *usernameIsValid) {
            return usernameIsValid.boolValue ? @1.0 : @0.5;
        }];
}
```

这样现在我们将 view-model 上的 `isUsernameValid` 发生的变化直接绑定到 `goButton` 的 `enabled` 属性上. 酷吧?对 `alpha` 的绑定更酷, 因为我们正在使用 `map` 方法将值转换成与 `alpha` 属性相关的值. (注意在这里我们返回的是一个 `NSNumber` 对象而不是原始float值. 这基本上是唯一的污点: 你需要负责为 RAC 将原始值转化为对象, 因为它不能帮你导出来.   

### 多个订阅者, 副作用, 昂贵的操作

订阅信号链时要明白重要的一件事是每当一个新值通过信号链被发送出去时, 实际上会给每个订阅者都发送一次. 直到意识到这就我们而言是有意义的, 信号发出的值不存储在任何地方(除了 RAC 在内部实现中). 当信号需要发送一个新的值时, 它会遍历所有的订阅者并给每个订阅者发送那个值. (这是对信号链实际工作的简化说明, 但基本想法是对的)  

这为什么重要?这意味着信号链某处存在的任何副作用, 任何影响应用世界的转变, 将会发生多次. 这对新接触 RAC 的用户来说是意想不到的. (这也违反了函数式构建的理念-数据输入, 数据输出).   

一个做作的例子可能是: 信号链某处的信号在每次按钮被按下时更新 `self` 中的一个计数器属性. 如果信号链有多个订阅者, 计数器的增长将会比你想的还要多. 你需要努力从信号链中尽可能剔除副作用. 当副作用不可避免时, 你可以使用一些恰当的预防机制. 我将会在另一篇文章中探索.   

除副作用之外, 你需要注意带有昂贵操作和可变数据的信号链. 网络请求就是一个三者兼得的例子:   

1.  网络请求影响了应用的网络层(副作用). 
2.  网络请求为信号链引入了可变数据. (两个完全一样请求可能返回了不同的数据. )
3.  网络请求反应慢啊. 

例如, 你可能有个信号在每次按钮按下时发送一个值, 而你想将这个值转换成网络请求的结果. 如果有多个订阅者要这个处理信号链上返回的这个值, 你将发起多个网络请求.   

![](http://www.sprynthesis.com/assets/images/signal-side-effect.svg)  

网络请求明显是经常需要的. 正如你所期望,  RAC 提供这些情况的解决方案, 也就是 `RACCommand` 和多点广播. 我将会在下一篇文章中更深入地分析.   

## Tweetboat Plus

既然简短的介绍(嗯哼)扯远了, 让我们着眼于如何用 ReactiveCocoa 将 view-model 与视图控制器连接起来. 

```
//
// View Controller
//
 
- (void) viewDidLoad {
    [super viewDidLoad];
 
    RAC(self.viewModel,  username) = [myTextfield rac_textSignal];
 
    RACSignal *usernameIsValidSignal = RACObserve(self.viewModel,  usernameValid);
 
    RAC(self.goButton,  alpha) = [usernameIsValidSignal
        map:  ^(NSNumber *valid) {
            return valid. boolValue ? @1 :  @0. 5;
        }];
 
    RAC(self.goButton,  enabled) = usernameIsValidSignal;
 
    RAC(self.avatarImageView,  image) = RACObserve(self.viewModel,  userAvatarImage);
    
    RAC(self.userNameLabel,  text) = RACObserve(self.viewModel,  userFullName);
 
    @weakify(self);
    [[[RACSignal merge: @[RACObserve(self.viewModel,  tweets), 
                        RACObserve(self.viewModel,  allTweetsLoaded)]]
        bufferWithTime: 0 onScheduler: [RACScheduler mainThreadScheduler]]
        subscribeNext: ^(id value) {
            @strongify(self);
            [self.tableView reloadData];
        }];
    
    [[self.goButton rac_signalForControlEvents: UIControlEventTouchUpInside]
        subscribeNext:  ^(id value) {
            @strongify(self);
            [self.viewModel getTweetsForCurrentUsername];
        }];
}
 
-(UITableViewCell*)tableView: (UITableView *)tableView cellForRowAtIndexPath: (NSIndexPath *)indexPath {
    // if table section is the tweets section
    if (indexPath. section == 0) {
        MYTwitterUserCell *cell =
        [self.tableView dequeueReusableCellWithIdentifier: @"MYTwitterUserCell" forIndexPath: indexPath];
        
        // grab the cell view model from the vc view model and assign it
        cell.viewModel = self.viewModel. tweets[indexPath. row];
        return cell;
    } else {
        // else if the section is our loading cell
        MYLoadingCell *cell =
        [self.tableView dequeueReusableCellWithIdentifier: @"MYLoadingCell" forIndexPath: indexPath];
        [self.viewModel loadMoreTweets];
        return cell;
    }
}
 
 
//
// MYTwitterUserCell
//
 
// this could also be in cell init
- (void) awakeFromNib {
    [super awakeFromNib];
    
    RAC(self.avatarImageView,  image) = RACObserve(self,  viewModel. tweetAuthorAvatarImage);
    RAC(self.userNameLabel,  text) = RACObserve(self,  viewModel. tweetAuthorFullName);
    RAC(self.tweetTextLabel,  text) = RACObserve(self,  viewModel. tweetContent);
}
```

让我们过一遍这个例子.   

```
RAC(self.viewModel,  username) = [myTextfield rac_textSignal];
```

在这我们用 RAC 库中的方法从 `UITextField` 拉取一个信号. 这行代码将 view-model 上的可读写属性 `username` 绑定到文本框上的用户输入的任何更新.   

```
RACSignal *usernameIsValidSignal = RACObserve(self.viewModel,  usernameValid);

RAC(self.goButton,  alpha) = [usernameIsValidSignal
    map:  ^(NSNumber *valid) {
        return valid. boolValue ? @1 :  @0. 5;
    }];

RAC(self.goButton,  enabled) = usernameIsValidSignal;
```

在这我们用 `RACObserve` 方法在 view-model 的 `usernameValid` 属性上创建了一个信号 `usernameIsValidSignal`.  无论何时属性发生变化, 它将会沿着管道发送一个新的 `@YES` 或 `@NO`. 我们拿到那个值并将其绑定到 `goButton` 的两个属性上. 首先我们将 `alpha` 分别对应 YES 或 NO 更新到1或0. 5(记着在这必须返回 `NSNumber`). 然后我们直接将信号绑定到 `enabled` 属性, 因为 YES 和 NO 在这无需转换就能完美地运作.   

```
RAC(self.avatarImageView,  image) = RACObserve(self.viewModel,  userAvatarImage);

RAC(self.userNameLabel,  text) = RACObserve(self.viewModel,  userFullName);
```

下面我们为表头的图像视图和用户标签创建绑定, 再次在 view-model 上对应的属性上用 `RACObserve` 宏创建信号.   

```
@weakify(self);
[[[RACSignal merge: @[RACObserve(self.viewModel,  tweets), 
                     RACObserve(self.viewModel,  allTweetsLoaded)]]
    bufferWithTime: 0 onScheduler: [RACScheduler mainThreadScheduler]]
    subscribeNext: ^(id value) {
        @strongify(self);
        [self.tableView reloadData];
    }];
```

这货看上去有点诡异, 所以我们在这上多花点时间. 我们想在 view-model 上 `tweets` 数组或 `allTweetsLoaded` 属性发生变化时更新表格视图. (在这个例子中, 我们要用一个简单的方法来重新加载整张表. )所以我们将这两个属性被观察后创建的两个信号合并成一个更大的信号, 当两个属性中有一个发生变化, 这个信号就会发送值. (你一贯认为信号的值是同类型的, 不会像这个信号有一样混杂的值. 这很可能在 Swift 版本的 RAC 中强制要求, 但在这我们不关心发出的真实值, 我们只是用它来触发表格式图的重新加载. )  

那么这儿看起来最吓人的部分可能是信号链中的 `bufferWithTime: onScheduler: ` 方法. 需要它来围绕 UIKit 中的一个问题进行变通.  `tweets` 和 `allTweetsLoaded` 这两个属性我们都需要追踪, 万一 `tweets` 变化和 `allTweetsLoaded` 为否(不管怎样我们都得重新加载表格). 有时两个属性都将在同一准确的时间发生变化, 意味着合并后的大信号中的两个信号都会发送一个值, 那么 `reloadData` 方法将会在同一个运行循环中被调用两次.  UIKit 不喜欢这样.  `bufferWithTime: ` 在给明的时间内抓取所有下一个到来的值, 当给定的时间过后将所有值合在一起发给订阅者. 通过传入0作为时间,  `bufferWithTime: ` 将会抓取那个合并信号在特定的运行循环中发出的全部值, 并将他们一起发送出去. (`NSTimer` 以同样的方式工作, 这不是巧合, 因为 `bufferWithTime: ` 是用 `NSTimer` 构建的. )暂时不用担心 scheduler, 试把它想做指明这些值必须在主线程上被发送. 现在我们确保 `reloadData` 每次运行循环只被调用一次.   

*注意我在这用 `@weakify/@strongify` 宏切换 strong 和 weak.  这在创建所有这些 block 时非常重要. 在 RAC 的 block 中使用 `self` 时`self` 将会被捕获为强引用并得到保留环, 除非你尤其意识到要破除保留环*  

```
[[self.goButton rac_signalForControlEvents: UIControlEventTouchUpInside]
    subscribeNext:  ^(id value) {
        @strongify(self);
        [self.viewModel getTweetsForCurrentUsername];
    }];
```

我将会在下一篇文章中在这里引入 `RACCommand`,  但目前我们只是当按钮被触碰时手动调用 view-model 的 `getTweetsForCurrentUsername` 方法.   

我们已经搞定了 `cellForRowAtIndexPath` 的第一部分, 那么我在这将只说下 loading cell: 

```
MYLoadingCell *cell =
    [self.tableView dequeueReusableCellWithIdentifier: @"MYLoadingCell" forIndexPath: indexPath];
[self.viewModel loadMoreTweets];
return cell;
```

这是另一块我们以后将利用到 `RACCommand` 的地方, 但目前我们只是调用 view-model 的 `loadMoreTweets` 方法. 我们将只是信任如果 cell 显示或隐藏多次的话 view-model 会避免多次内部调用.   

```
- (void) awakeFromNib {
    [super awakeFromNib];

    RAC(self.avatarImageView,  image) = RACObserve(self,  viewModel. tweetAuthorAvatarImage);
    RAC(self.userNameLabel,  text) = RACObserve(self,  viewModel. tweetAuthorFullName);
    RAC(self.tweetTextLabel,  text) = RACObserve(self,  viewModel. tweetContent);
}
```

这段现在应该非常直接了, 除此之外我想指出一点. 我们正在将图片和文字绑定到 UI 上对应的属性, 但注意 `viewModel` 出现在 `RACObserve` 宏中逗号右边. 这些 cell 终将被重用, 新的 view-models 将会被赋值. 如果我们不将 `viewModel` 放在逗号右边, 那就会监听 `viewModel` 属性的变化然后每次都要重新设置绑定;如果放在逗号右边,  `RACObserve` 将会为我们负责这些事儿. 因此我们只需要设定一次绑定并让 Reactive Cocoa 做剩余的部分. 这是在绑定表格 cell 时为了性能需要记住的好东西. 我在实践中即使是有很多表格 cell 依然没有出过问题.   

#### 福利-消除更多的状态

有时候你可以在 view-model 中暴露 `RACSignal` 对象来替代像字符串和图像这样的属性, 这能在 view-model 上消除更多的状态. 然后视图控制器就不需要自己用 `RACObserve` 创建信号了, 并只是直接影响这些信号. 要意识到如果你的信号在被 UI 订阅/绑定到 UI 之前发出过一个值, 那么你将不会收到那个"初始"的值. 

## 结论

本文篇幅略长, 但别被吓着. 这还有好多没讲的, 而且是干货儿, 是舒展你大脑的好方法. 这毫无疑问是*不同的*编程风格. 花一会儿功夫停止机械地试图用命令式方案去解决问题. 即使你一开始不是经常用这种编程风格, 我认为这有助于理解和提醒我们有截然不同的途径来解决我们程序员的困惑.   

下一次我将稍微深入 view-model 内部中本文没提到的内容, 并介绍下 `RACCommand`(希望篇幅能短很多). 然后我们将投入到一个真实案例中, 那是我的一个叫做[Three Cents](http://www.threecentsapp.com)的 app 中的一个相当复杂的页面, 它混合了网络调用, CoreData, 多重 UI 状态, 等等!

![](http://www.sprynthesis.com/assets/images/ThreeCentsExplore.gif)

### 拓展阅读

- [Introduction to MVVM](http://www.objc.io/issue-13/mvvm.html) by Ash Furrow
- [Functional Reactive Programming on iOS](https://leanpub.com/iosfrp/) by Ash Furrow
- [A sample app by Ash Furrow](https://github.com/AshFurrow/C-41)
- [MVC,  MVVM,  FRP,  And Building Bridges](http://cocoamanifest.net/articles/2013/10/mvc-mvvm-frp-and-building-bridges.html) by Jonathan Penn
- [MVVM Tutorial with ReactiveCocoa](http://www.raywenderlich.com/74106/mvvm-tutorial-with-reactivecocoa-part-1) by Colin Eberhardt on the Ray Wenderlich site. 
- [Basic MVVM with ReactiveCocoa](http://cocoasamurai.blogspot.jp/2013/03/basic-mvvm-with-reactivecocoa.html) by Colin Wheeler
- [On MVVM,  and Architecture Questions](http://twocentstudios.com/blog/2014/06/08/on-mvvm-and-architecture-questions/) by Chris Trott
