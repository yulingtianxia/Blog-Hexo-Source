title: 腾讯实习第一个月工作总结
date: 2015-11-13 23:55:38
tags:
---

来腾讯实习正好一个月了，因为项目已经进入了成熟期，接了两个需求，改了二十几个 bug。所以把这期间的一些思考写下来，发了邮件分享给组内同事们。我把一些自己觉得不合适的内容刨除出去，选取邮件的部分内容写在这里：）

<!--more-->

#1. 让 UIAlertController 兼容 iOS7

##问题背景

公司项目中用到了 [`UIAlertController`](http://yulingtianxia.com/blog/2014/09/29/uialertcontroller-in-ios8/) 来实现自定义 actionsheet 文字颜色的需求，而 `UIAlertController` **只能在 iOS8 及更高版本系统使用，在iOS7下会 crash**。老大让我写个组件兼容下 iOS7，于是 `TBAlertController` 诞生了。

下面给出的关于 `TBAlertController` 的代码片段都不是真实源码，只为说明

##分析问题

为了多快好省的解决当前的问题，我依然使用系统自带的 `UIAlertController` 和 `UIActionSheet` 分别兼容 iOS8、9 和 iOS7。并且接口与代码中已经存在的 `UIAlertController` 接口一致，这样只需要将代码中所有的 “UIAlertController” 和 “UIAlertAction” 改为 “TBAlertController” 和 “TBAlertAction” 即可。这样**更符合设计模式中“对扩展开放，对修改关闭”的开放原则。**

当然最长远的打算应该是自己写个 AlertController，可以随意定制想要的 style，而不受系统控件的风格限制。

##技术重点

`UIAlertController` 与 `UIActionSheet` 接口上最大的不同之处就是处理按钮点击事件时前者在 block 中实现，后者以 delegate 回调的形式实现。而且还需要高度模仿 `UIAlertController` 的接口，使原有代码修改量达到最少。而我若想实现一个组件兼容二者，那就必须将它们“装箱”封装。同理，`UIAlertAction` 也需要类似的处理。

##解决思路

###构建 TBAlertAction 替代 UIAlertAction

首先，参照 `UIAlertAction` 的接口，造一个 `TBAlertAction` 出来。思想是 iOS8以上直接使用 `UIAlertAction` 来替代，iOS7 则特殊处理，将重要信息保存下来：

```
@interface TBAlertAction ()
@property (nullable, nonatomic) NSString *title;
@property (nonatomic) TBAlertActionStyle style;
@property (nonatomic) BOOL enabled;
@property (nullable,nonatomic,strong) void (^handler)(TBAlertAction *);
@end

@implementation TBAlertAction
+ (id)actionWithTitle:(NSString *)title style:(TBAlertActionStyle)style handler:(void (^)(TBAlertAction *))handler {
    if (iOS8Later) {
        UIAlertActionStyle actionStyle = (NSInteger)style;
        
        return [UIAlertAction actionWithTitle:title style:actionStyle handler:(void (^ __nullable)(UIAlertAction *))handler];
    }
    else {
        TBAlertAction *action = [[TBAlertAction alloc] init];
        action.title = title;
        action.style = style;
        action.handler = handler;
        action.enabled = YES;
        return action;
    }
}
@end
```

这里的 `handler` block 很重要，在 iOS7 中使用 `UIActionSheet` 时是在 delegate 回调方法中处理按钮点击事件的，而处理的事务逻辑此时已经写在 `handler` 中了，后续只需在 delegate 回调方法中正确的执行对应的 block 就行了。

###构建 TBAlertController 属性

`TBAlertController` 也是采取装箱策略，模仿 `UIAlertController` 的接口，并添加了一个 `adaptiveAlert` 替身和 `actions` 数组。

![TBAlertController 属性](http://7ni3rk.com1.z0.glb.clouddn.com/TBAlertController.png)

```
- (instancetype)init
{
    self = [super init];
    if (self) {
        if (iOS8Later) {
            _adaptiveAlert = [[UIAlertController alloc] init];
        }
        else {
            _adaptiveAlert = [[UIActionSheet alloc] init];
            _actions = [NSMutableArray array];
            ((UIActionSheet *)_adaptiveAlert).delegate = self;
        }
        [self addObserver:self forKeyPath:@"view.tintColor" options:NSKeyValueObservingOptionNew|NSKeyValueObservingOptionOld context:nil];
    }
    return self;
}

- (void)dealloc {
    [self removeObserver:self forKeyPath:@"view.tintColor"];
}

+ (instancetype)alertControllerWithTitle:(NSString *)title message:(NSString *)message preferredStyle:(TBAlertControllerStyle)preferredStyle {
    TBAlertController *controller = [[TBAlertController alloc] init];
    if (iOS8Later) {
        controller.adaptiveAlert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:(NSInteger)preferredStyle];
    }
    else {
        switch (preferredStyle) {
            case TBAlertControllerStyleActionSheet: {
                controller.adaptiveAlert = [[UIActionSheet alloc] initWithTitle:title delegate:controller cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
                break;
            }
            case TBAlertControllerStyleAlert: {
                controller.adaptiveAlert = [[UIAlertView alloc] initWithTitle:title message:message delegate:controller cancelButtonTitle:nil otherButtonTitles: nil];
                break;
            }
            default: {
                break;
            }
        }
    }
    return controller;
}
```
这段实例化 `TBAlertController` 的方法很好理解，总之就是针对不同情况将 `adaptiveAlert` 赋予不同的实例。还顺带用 KVO 监听了下 tintColor，这是为了实现当初使用 `UIAlertController` 的目的-改变字体颜色。

###构建 TBAlertController 方法

`addAction:` 方法的实现类似，也是针对不同情况向 `actions` 数组添加不同内容：

```
- (void)addAction:(TBAlertAction *)action {
    if (iOS8Later) {
        [self.adaptiveAlert addAction:(UIAlertAction *)action];
    }
    else {
        [self.actions addObject:action];
        NSInteger buttonIndex = [self.adaptiveAlert addButtonWithTitle:action.title];
        UIColor *textColor;
        switch (action.style) {
            case TBAlertActionStyleDefault: {
                textColor = self.tintColor;
                break;
            }
            case TBAlertActionStyleCancel: {
                [self.adaptiveAlert setCancelButtonIndex:buttonIndex];
                textColor = self.tintColor;
                break;
            }
            case TBAlertActionStyleDestructive: {
                [self.adaptiveAlert setDestructiveButtonIndex:buttonIndex];
                textColor = [UIColor redColor];
                break;
            }
            default: {
                textColor = self.tintColor;
                break;
            }
        }
//        [((UIButton *)((UIView *)self.adaptiveAlert).subviews.lastObject) setTitleColor:textColor forState:0xFFFFFFFF];
    }
}
```
需要注意的是针对不同 style 的按钮要设置好对应的 `buttonindex` 和 `titleColor`。因为苹果可能会拒绝修改系统控件样式的 app 上架，所以我将那行设置颜色的代码注释掉了。

然后在 delegate 中取到对应的 block 并执行：

```
#pragma - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    __weak __typeof(self)weakSelf = self;
    if (self.actions[buttonIndex].handler) {
    	self.actions[buttonIndex].handler(weakSelf.adaptiveAlert);
    }
}
```
###hook presentViewController: 方法

最后封装下 `presentViewController:` 就可以了，因为要做到接口与 `UIAlertController` 一模一样，减少已有代码修改量，需要 hook 到系统的 `presentViewController:` 方法，并折腾一番：

```
+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class aClass = [self class];
        
        SEL originalSelector = @selector(presentViewController:animated:completion:);
        SEL swizzledSelector = @selector(tb_presentViewController:animated:completion:);
        
        Method originalMethod = class_getInstanceMethod(aClass, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(aClass, swizzledSelector);
        
        BOOL didAddMethod =
        class_addMethod(aClass,
                        originalSelector,
                        method_getImplementation(swizzledMethod),
                        method_getTypeEncoding(swizzledMethod));
        
        if (didAddMethod) {
            class_replaceMethod(aClass,
                                swizzledSelector,
                                method_getImplementation(originalMethod),
                                method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

#pragma mark - Method Swizzling

- (void)tb_presentViewController:(UIViewController *)viewControllerToPresent animated:(BOOL)flag completion:(void (^)(void))completion {
    if ([viewControllerToPresent isKindOfClass:[TBAlertController class]]) {
        TBAlertController* controller = (TBAlertController *)viewControllerToPresent;
        if (iOS8Later) {
            ((UIAlertController *)controller.adaptiveAlert).view.tintColor = controller.tintColor;
            [self tb_presentViewController:((TBAlertController *)viewControllerToPresent).adaptiveAlert animated:flag completion:completion];
        }
        else {
            if ([controller.adaptiveAlert isKindOfClass:[UIAlertView class]]) {
                self.tbAlertController = controller;
                controller.ownerController = self;
                [controller.adaptiveAlert show];
            }
            else if ([controller.adaptiveAlert isKindOfClass:[UIActionSheet class]]) {
                self.tbAlertController = controller;
                controller.ownerController = self;
                [controller.adaptiveAlert showInView:self.view];
            }
        }
    }
    else {
        [self tb_presentViewController:viewControllerToPresent animated:flag completion:completion];
    }
}
```

在 Objective-C 中，hook 被称为一种叫做“Method Swizzling”的技术，每种动态语言的 [Runtime](http://yulingtianxia.com/blog/2014/11/05/objective-c-runtime/) 系统都支持这些特性。在这里，我在 hook 到的方法里先实例化一个 `TBAlertController`，然后判断系统版本，分别将 `UIAlertController` 或 `UIAlertView`、`UIActionSheet`展示出来。

###还需要注意的地方

这里需要注意两点：

1. 使用 `UIAlertController` 时，必需在添加完所有 Action 之后才能设定它的 `view.tintColor` 属性，否则会在 iOS8 下出现问题：取消按钮与其他按钮连成一片。而在 iOS9 下面则不会出现此问题。这也是为什么我会在 hook 到 `presentViewController:` 时才设定它的  `tintColor`。
2. 一旦 `adaptiveAlert` 替身被展现在屏幕上， `TBAlertController` 这个箱子就可能会被释放掉。因为很可能其他人创建 `TBAlertController` 实例的时候只是个局部变量，一旦出了作用域，它就会被释放掉，而一旦它被提前释放，delegate 回调方法就永远不会执行，前面的努力都白费了，正如下面这样：
```
TBAlertController *operationAlertController = [TBAlertController alertControllerWithTitle:@"是否取消关注" message:nil preferredStyle:TBAlertControllerStyleActionSheet];
[operationAlertController addAction:[TBAlertAction actionWithTitle:@"是" style:TBAlertActionStyleDestructive handler:^(TBAlertAction * _Nonnull action) {
       [self alertControllerHandler:1 clickedButtonAtIndex:0];
}]];
   [operationAlertController addAction:[TBAlertAction actionWithTitle:@"否" style:TBAlertActionStyleCancel handler:nil]];
   operationAlertController.view.tintColor = [UIColor blackColor];

   [[[TBRootViewController sharedInstance] getCurrentNavigationController] presentViewController:operationAlertController animated:YES completion:nil];
```
我总不能强制要求所有使用 `TBAlertController` 的人都要用一个属性来强引用它吧?所以我为 `UIViewController` 添加了一个类别，目的是为其增加一个属性 `tbAlertController`（因为 OC 的类别无法为添加的属性自动生成 getter 和 setter，需要使用关联对象动态添加），利用它来保持对“箱子” `TBAlertController` 的强引用，防止其内存被过早释放。并在 hook 时的 `tb_presentViewController:` 方法中添加这样一行：
```
self.tbAlertController = controller;
```
此时又涉及到了另一个问题：内存泄露。因为我们无法确定其他人在实例化 `TBAlertAction` 时传入的 block 中做了什么，因为它很有可能捕获到了 `self`！而此时 `self` 很可能强引用了一个 `UIViewController`，然后其 `tbAlertController` 属性又强引用了 `TBAlertController`，这个 `TBAlertController` 的 `actions` 数组中的一个 `TBAlertAction` 强引用了这个 block。好长的一个保留环啊！那么如何打破这个环呢？我总不能要求使用者必需在 block 内外做个 [Weak/Strong Dance](http://ashfurrow.com/blog/weakstrong-dance/) 吧！毕竟“谁创建，谁释放”的规则我们还是要遵守的，必需在组件内部解决可能发生的内存泄露问题。于是我给 `TBAlertController` 又添加了一个属性 `ownerController`，注意内存管理语义是 `weak`：
```
@property (nullable,nonatomic,weak) UIViewController *ownerController;
```
然后在 `tb_presentViewController:` 方法中再添加一行代码，将 `TBAlertController` 的 `ownerController` 设为调用 `presentViewController:` 方法的 controller：
```
controller.ownerController = self;
```
最后在 `UIAlertView` 或 `UIActionSheet` 消失时将 `tbAlertController` 设为 `nil` 就打破保留环了，它原本指向 `TBAlertController` 自己，设为 `nil` 后，没有对象引用 `TBAlertController` 实例了，其引用计数为零，然后被释放：
```
- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
	    self.ownerController.tbAlertController = nil;
}
```

除此之外还有很多细节没有在这里阐述，比如对属性的封装，还有对 `addTextFieldWithConfigurationHandler:` 等接口的封装等。

其实早已有人做过类似的事情，将系统组件封装成兼容的版本：[PSTAlertController](https://github.com/steipete/PSTAlertController)。但其接口与原生的 `UIAlertController` 差很多，需要手动替换很多已有的代码。

##感悟&总结

在这里还想说下关于 block 中的 [Weak/Strong Dance](http://ashfurrow.com/blog/weakstrong-dance/) 的问题。我看到项目中好多带有 block 的代码都使用一些宏定义，比如 [@weakify(self): A more elegant solution to weakSelf in Objective-C](http://blog.aceontech.com/post/111694918560/weakifyself-a-more-elegant-solution-to)，而个别 block 其实是不需要使用 weakSelf 的，这些 block 的拥有者并没被 `self` 在其生存周期始终强引用着，所以没必要用 weakSelf。反而在少数极端情况下（例如异步延时执行 block）因为捕获的是 weakSelf，而在 block 执行前 self 已经是 `nil`。此时不要指望 block 中的 strongSelf 会帮到什么忙，因为它力所能及的只是在 block 执行过程中保证对 weakSelf 的强引用。如若 weakSelf 不再指向 `self` 而是 `nil`，block 中的内容肯定不会正常执行（这不代表一定会 crash，向 `nil` 发送消息会执行默认的行为）。

#2. LLDB 调试 UI 的技巧

##问题背景

在 Xcode 添加 View Debugging 之前，我们有两种方式来调试 UI 界面。一种是花钱买 [Reveal](http://revealapp.com) 享受视图层级可视化调试，另一种是用 lldb（更早是 gdb）命令来调试。而如今 Xcode 已经提供了部分审查视图元素和层级的功能，也可以在调试时显示每个视图的 frame 外框和视图的渲染状况等。这已经满足了很大部分的 UI 调试需求。[AppCode](https://www.jetbrains.com/objc/) 则选择了与 [Reveal](http://revealapp.com) 集成，虽然 jetbrains 大法好，但也有不给力的时候。

##用 LLDB 改变视图

在 **iOS7 上 Xcode 并不支持捕获可视化的视图层级，我们只能用 lldb 的命令来输出视图层级**：

```
po [[[UIApplication sharedApplication] keyWindow] recursiveDescription]
```

`po` 是 `p object` 的缩写，而 `p` 又是 `print` 的缩写，`print` 又是 `expression --`的缩写。`expression` 就是 `e` 命令，而 `--` 代表标识的结束。上面这条命令的参数是一个全局变量，所以可以在任何时候访问，无需在特定位置加断点，只需点暂停按钮即可。

通过 `e` 命令，可以*在调试时改变变量的值，比如某个视图的透明度、背景颜色等，还可以临时创建新的视图或者视图控制器，甚至可以完成视图控制器的 push 操作*。虽然此时程序（某个进程）是被我们暂停了的，但是后台的渲染服务是由后台的另一个进程完成的，所以可以**强制触发渲染服务**：

```
e (void)[CATransaction flush]
```

##使用 Chisel 简化 LLDB 命令
虽然调试器也有一定的代码补全功能，但是毕竟程序员的时间是宝贵的， Xcode 的调试器毕竟还没做到 zsh 那样屌炸天，我们需要更多的“缩写”命令。Facebook 的程序员们最先按捺不住（毕竟人家做个客户端就要动辄几百号人），开发了一个基于 lldb 的工具：[chisel](https://github.com/facebook/chisel)。从此，输出视图层级只需要一条命令：`pviews`，输出视图控制器层级也是一条命令：`pvc`，刷新渲染服务更是一条命令：`caflush`。安装 chisel 更是简单，直接用 [Homebrew](http://brew.sh) 分分钟搞定，因为 Homebrew 在 OSX 上太火，有人还专门做了个带图形界面的客户端 [Cakebrew](https://www.cakebrew.com)，简直骚得不得了。

当然我们无需查看完整的视图层级树，`pviews` 后面可以附带参数，查看当前 view 为根节点下的层级树。默认不带参数就是完整打印。

##我的实践与感悟

最直观的还是能可视化地查看视图层级，比如某个视图为何不显示？是因为 hidden 了还是 alpha 问题，或是被其他视图遮挡住了？捕获下视图层级一看便知。但其缺点是捕获速度较慢，视图层级较为复杂时，查找明确类型的视图或者明确内存地址的视图对象较为困难。所以 lldb 调试 UI 还是有一定优势的，尤其是在动画繁多界面变化节奏较快时也会需要用到。我在调试“图片选择器触发摄像头拍照后屏幕变黑无反应”的 bug 时就是靠 `pvc` 和 `pviews` 这两个命令来弄清视图控制器与视图之间复杂的层级。表面上看是图片选择器的原因，因为其他用到摄像头组件的地方并没有这个 bug，其实摄像头组件对外部调用有一些依赖条件，一旦不满足就会产生 bug。最后更改拍照控件的实现，弃用了 `UIWindow` 和一些视图控制器，简化层级，从源头上消除了 bug。

#3.项目实践管理经验

在公司项目中我发现了有关项目资源管理的一些问题：

1. 图片资源使用文件夹管理
2. 文案 hardcode
3. 工程文件 project.pbxproj 冲突合并

##图片资源管理

我觉得图片最好是放在 xcassets 中，因为好处简直是一大堆。比如对多分辨率多设备的支持，矢量pdf图片的支持，类似安卓“9.png”的图片 slicing 支持，更改图片颜色和 Xcode7 新增的“On Demand Resource”等等。如果图片过多，还可以在 xcassets 中再建立 xcassets 嘛，如果有打包需要可以配合上 Bundle。

图片一旦用 Asset Catalog 管理后，在程序中加载图片只需要用图片名而无需后缀名，更不用关心几倍分辨率，是用2x 还是 3x？Xcode 全都帮我们搞定了！之前碰到过一个 iOS7 上图片被拉伸的 bug，原因就是没有使用 Asset Catalog 管理图片资源，而是直接用文件夹。而在代码中却写了图片文件的全名，带比如 “pic@2x.png”，本来贴心的 Xcode 会为我们在后缀名前自动加上 “@2x” 来寻找图片，于是去查找 “pic@2x@2x.png”，发现并没有这个二倍分辨率图片，Xcode 于是只好继续寻找一倍分辨率的图片，也就是 “pic@2x.png” 被当做了一倍分辨率的图片处理了，所以 `UIImage` 的 `size` 就变大了。

##文案管理

###文案是可复用的

**有很多文案可以重用，因为产品设计的文案大都是统一的**，比如所有需要展示网络出错的文案肯定都是一模一样的，如果每个 Alert 弹出的文案提示都不一样，那才是产品的失责。从不能 A 界面无网络，提示“断网啦”，B 界面无网络时提示“无法访问网络”，这样子的设计很少见。

###重复的文案在多处 hardcode 会降低效率 

基于上面这点“小聪明”，我觉得不同功能界面的文案完全是可以复用的，这在我以往的经验中也得到了验证。而项目当前是直接将文案硬编码到业务逻辑代码中，以后每次修改都要找到对应的逻辑，并进行修改。如果是维护自己代码中的文案或者是业务逻辑较为简单时还可以接受，因为只是一次次的重复劳动罢了，对个人来说微不足道。

一旦有一天我们的产品将要做国际化，加上英文，可能这对每个人负责的模块来说也只是替换下罢了。然而事情不能是这么任由发展的，先不说国际化中有一些诸如 XLIFF 文件的导入的标准和流程，一旦一个模块的文案全由另外一个不熟悉代码的人来修改，漏改或错改的风险会增加，这无疑增加了测试的时间成本。

###我的解决方案：文案与代码分离

为什么不建立一个对照表，将所有的文案列出来呢？比如TB001号文案内容是“取消”，我敢说肯定很多 AlertView 的按钮都会用到，直接在代码里使用这个编号对应的的 `NSString`变量（或许干脆变量名就是 `tb001`）。产品那边提供文案时也列一张映射表，将各个模块页面的文案都对应上编号，然后编号又映射到具体文案内容。

###解决方案的分析

可能这么做最开始会有一定的工作量，但趁着文案种类没有暴增时，这件事情做的越早越好。这会提高全组人的效率，因为以后再修改文案时，直接修改那个保存文案编码与内容的文件即可。如果需要变更代码中的编码，此时才需要涉及到查看代码逻辑，然而这种情况我相信是少数。

##project.pbxproj文件

关于工程文件 project.pbxproj 确实诟病已久，多人协作时总会蛋疼。每次有文件的增删操作时我们总是需要解决 svn 上与本地版本的冲突。我对它研究并不多，但发现了有人提供了一个解决方案：[xUnique](https://github.com/truebit/xUnique)，目前处于观望状态，还不敢尝试。

但我的设想是能够用一个脚本，每次 commit project.pbxproj 文件时可以自动屏蔽掉一些内容，比如证书等。但这种设想没有经过验证，可能还是无法解决根本问题。毕竟 project.pbxproj 文件格式可能还会有变化，苹果总是喜欢优化它被诟病的东西。
