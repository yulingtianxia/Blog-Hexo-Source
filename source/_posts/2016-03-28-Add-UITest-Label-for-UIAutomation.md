title: 为 UIAutomation 添加自动化测试标签的探索
date: 2016-03-28 00:47:32
tags:
- iOS

---
UIAutomation 是苹果提供的自动化测试框架，iOS 不像 Android 那样可以在 xml 文件中自动生成唯一的 id 作为标签，需要我们手动为控件添加可访问性（Accessibility）。如何让一个控件的可访问标签在当前页面唯一且不变呢？当然纯手工在代码中插入加标签的逻辑代码肯定是可行的，但费时费力，所以我在这里做一些用程序自动化添加标签尝试性的探索。


<!--more-->
## 分析&方案

首先回顾下生成标签需要符合的必要条件：（**以下将“自动化测试标签”简称为“标签”**）：

1. 页面内唯一：页面内不同视图标签不重复。
2. 运行时恒定：每次运行应用中此页面时视图的标签始终恒定，无需修改测试脚本。

为了满足标签的必要条件，可以选择其在某个类中的属性名称作为标签，因为同一个类中是不可能有两个相同名称的属性的，并且属性名称都是固定在代码里的，也就是恒定不变的。在此总结下标签的策略流程：

1. 如果变量是某个类的属性，则可满足标签条件。因为代码没有改动，则标签也不会变化。即使代码有变动，也肯定是因为业务逻辑变更导致了界面上的变化，那么测试脚本肯定也是要改的，所以无需多虑此种情况。2.	如果是临时创建的局部变量，同一页面中很有可能有相同名字的局部变量。而且 Objective-C Runtime 无法获取局部变量名称，所以针对此种情况尽量采用其他来源的内容作为标签。
3. 获取代码中局部变量的变量名，并与其对象绑定起来。（绑定是指将标签赋给`accessibilityIdentifier` 之类的属性）

对于上面第二条种的局部变量生成标签的策略，详细阐述如下：
由于编译器对代码进行了词法分析、语法分析和语义分析，此时局部变量名早就消失了。运行的时候局部变量在内存里也只是个冰冷冷的对象罢了，不像类的实例变量或属性那样可以获取名称。既然编译阶段之后就已经拿不到局部变量名了，所以只能对源代码进行文字处理来获取局部变量名。比如使用宏定义在 `addSubview:` 方法调用的时候传入参数名，并将参数表与参数实例绑定。但是这对 Swift 算是个方案，对于语法怪异的 Objective-C 来说是不可行的。
既然从方法外不能直接传入参数，那么尝试从方法内来获取函数调用堆栈。查找上一层函数在源码的位置，用正则表达式得到 `addSubview:` 的参数名称。从函数调用堆栈获取上一层调用函数在源码中的位置（比如文件名和行数），然后用正则匹配抓取 `addSubview:` 的参数名，看样子是个方案。获取函数调用栈对应源码位置可以用 [`backtrace_symbols`](http://stackoverflow.com/questions/3151779/how-its-better-to-invoke-gdb-from-program-to-print-its-stacktrace/4611112#4611112)，或者 `[NSThread callStackSymbols]` 等，但这些操作都不是在 iOS 系统内，不能将标签绑定到 iOS 运行环境中的实例。

当然也可以用脚本程序帮我们在源码指定位置中插入添加标签的逻辑代码，但这样的弊端有二：

1. 维护成本较高，脚本在向源码中插入加标签逻辑代码时需要判断是否已经插入过这段代码，增加了出错几率
2. 对代码内容变化的鲁棒性不高。因为重构等行为很可能把原有代码顺序弄乱，脚本需要考虑很多情况。每次新增代码都要重新跑一次脚本。

既然局部变量的名字可能重名并难于与实例绑定，不妨另辟蹊径寻求其他方法。这里提出一种假设：程序员写代码的时候之所以将一个视图变量声明为类的属性，是因为以后还会经常用到它。而那些被声明为局部变量的，肯定是临时用一次就不用了。这种用临时变量创建的视图添加到视图层级中内容极有可能就不会变了，其大部分应该是 `UILabel`、`UIButton`、`UIImageView` 以及被当做容器视图功能的 `UIView` 实例。针对这种情况可以将其视图的内容作为标签的『特殊标识』。针对这种情况可以将其视图的内容作为标签，比如 `UILabel` 的文本内容、`UIButton` 的背景图片资源名和文本内容以及 `UIImageView` 的图片资源名。基于以上的逻辑，最后采用基础控件内容作为局部变量的标签。

总结为一句话：如果视图是某个类的属性，就用属性名作为标签；否则使用其内容作为标签。

## 实践&探索

我采用 hook 的方式来在运行时生成标签。hook `UIView` 中的`accessibilityIdentifier` 的原因是此时的视图层级更全，并且是惰性生成标签。其实使用 `accessibilityLabel` 也是可以的，但对 VoiceOver 功能会有影响，毕竟变量名不像视图文字内容那样有实际意义。

PS：这里之所以不 hook `addSubview:` 是因为在添加 subview 时，视图层级树并不完整。虽然调用 `accessibilityIdentifier` 时视图层级也可能不完整（比如在 `addSubview:` 之前调用 `accessibilityIdentifier`），但这样的几率远远小于前者：很多时候是 `[a addSubview:b]`，但此时 `a` 还没有 `superview`，那么如果 hook `addSubview:`方法，就只能保留 `a` 以下的视图层级。这并不是我想看到的。所以在 `UIView` 中的 `accessibilityIdentifier` 方法中生成标签可以尽可能地保留完整的视图层级，并且是 lazy load 的方式，降低 CPU 使用峰值。

放个残缺版的代码，心情好的时候更新下，重要的还是思路：

```
@implementation UIView (TBUIAutoTest)
+ (void)load {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	  [self swizzleSelector:@selector(accessibilityIdentifier) withAnotherSelector:@selector(tb_accessibilityIdentifier)];
	  [self swizzleSelector:@selector(accessibilityLabel) withAnotherSelector:@selector(tb_accessibilityLabel)];
	});
}

+ (void)swizzleSelector:(SEL)originalSelector withAnotherSelector:(SEL)swizzledSelector
{
    Class aClass = [self class];
    
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
}

#pragma mark - Method Swizzling

- (NSString *)tb_accessibilityIdentifier
{
    NSString *accessibilityIdentifier = [self tb_accessibilityIdentifier];
    if (accessibilityIdentifier.length > 0 && [[accessibilityIdentifier substringToIndex:1] isEqualToString:@"("]) {
        return accessibilityIdentifier;
    }
    else if ([accessibilityIdentifier isEqualToString:@"null"]) {
        accessibilityIdentifier = @"";
    }
    
    NSString *labelStr = [self.superview findNameWithInstance:self];
    
    if (labelStr && ![labelStr isEqualToString:@""]) {
        labelStr = [NSString stringWithFormat:@"(%@)",labelStr];
    }
    else {
        if ([self isKindOfClass:[UILabel class]]) {//UILabel 使用 text
            labelStr = [NSString stringWithFormat:@"(%@)",((UILabel *)self).text?:@""];
        }
        else if ([self isKindOfClass:[UIImageView class]]) {//UIImageView 使用 image 的 imageName
            labelStr = [NSString stringWithFormat:@"(%@)",((UIImageView *)self).image.accessibilityIdentifier?:[NSString stringWithFormat:@"image%ld",(long)((UIImageView *)self).tag]];
        }
        else if ([self isKindOfClass:[UIButton class]]) {//UIButton 使用 button 的 text 和 image
            labelStr = [NSString stringWithFormat:@"(%@%@)",((UIButton *)self).titleLabel.text?:@"",((UIButton *)self).imageView.image.accessibilityIdentifier?:@""];
        }
        else if (accessibilityIdentifier) {// 已有 label，则在此基础上再次添加更多信息
            labelStr = [NSString stringWithFormat:@"(%@)",accessibilityIdentifier];
        }
        if ([self isKindOfClass:[UIButton class]]) {
            self.accessibilityValue = [NSString stringWithFormat:@"(%@)",((UIButton *)self).currentBackgroundImage.accessibilityIdentifier?:@""];
        }
    }
    if ([labelStr isEqualToString:@"()"] || [labelStr isEqualToString:@"(null)"] || [labelStr isEqualToString:@"null"]) {
        labelStr = @"";
    }
    [self setAccessibilityIdentifier:labelStr];
    return labelStr;
}

- (NSString *)tb_accessibilityLabel
{
    if ([self isKindOfClass:[UIImageView class]]) {//UIImageView 特殊处理
        NSString *name = [self.superview findNameWithInstance:self];
        if (name) {
            self.accessibilityIdentifier = [NSString stringWithFormat:@"(%@)",name];
        }
        else {
            self.accessibilityIdentifier = [NSString stringWithFormat:@"(%@)",((UIImageView *)self).image.accessibilityIdentifier?:[NSString stringWithFormat:@"image%ld",(long)((UIImageView *)self).tag]];
        }
    }
    if ([self isKindOfClass:[UITableViewCell class]]) {//UITableViewCell 特殊处理
        self.accessibilityIdentifier = [NSString stringWithFormat:@"(%@)",((UITableViewCell *)self).reuseIdentifier];
    }
    return [self tb_accessibilityLabel];
}
@end
```

在获取到变量名之后，还需要进行处理才能作为标签。首先在变量名外加一层括号，目的是区分下此标签是代码生成的而不是手动加上去的。方法结尾的 ` [self setAccessibilityIdentifier:subLabelStr]` 用来给 `_accessibilityIdentifier` 赋值生成好的标签。

对于获取不到变量名的临时变量和视图层级中一些系统私有的视图变量，才去之前分析中提到的方案特殊处理。好一长串的 `if-else` 啊，为了处理这些特殊情况写一坨脏代码我也是醉了。最后别忘处理下无意义的字符串，比如 "null"。

在 UIAutomation 生成控件树时，大部分 `UIImageView` 和 `UITableViewCell` 无法通过 hook `accessibilityIdentifier` 来在控件树中获取到自动化测试标签，或者获得的标签不是属性名而是图片资源名。解决方案是 hook accessibilityLabel 方法，并在其中为 `UIImageView` 和 `UITableViewCell` 加自动化测试标签。


为了将 `UIImage` 的图片资源名和实例绑定，我又 hook 了 `UIImage` 的 `imageNamed:` 类方法：

```
+ (UIImage *)tb_imageNamed:(NSString *)imageName{
    UIImage *image = [UIImage tb_imageNamed:imageName];
    image.accessibilityIdentifier = imageName;
    return image;
}
```

下面说下获取变量名的 `findNameWithInstance:` 方法的实现：

```
@implementation UIResponder (TBUIAutoTest)

-(NSString *)nameWithInstance:(id)instance {
    unsigned int numIvars = 0;
    NSString *key=nil;
    Ivar * ivars = class_copyIvarList([self class], &numIvars);
    for(int i = 0; i < numIvars; i++) {
        Ivar thisIvar = ivars[i];
        const char *type = ivar_getTypeEncoding(thisIvar);
        NSString *stringType =  [NSString stringWithCString:type encoding:NSUTF8StringEncoding];
        if (![stringType hasPrefix:@"@"]) {
            continue;
        }
        if ((object_getIvar(self, thisIvar) == instance)) {//此处 crash 不要慌！
            key = [NSString stringWithUTF8String:ivar_getName(thisIvar)];
            break;
        }
    }
    free(ivars);
    return key;
}

- (NSString *)findNameWithInstance:(UIView *) instance
{
    id nextResponder = [self nextResponder];
    NSString *name = [self nameWithInstance:instance];
    if (!name) {
        return [nextResponder findNameWithInstance:instance];
    }
    if ([name hasPrefix:@"_"]) {  //去掉变量名的下划线前缀
        name = [name substringFromIndex:1];
    }
    return name;
}
```

因为我们并不知道某个视图对象在哪个类中充当了属性或成员变量，所以 `findNameWithInstance:` 方法会沿着响应链向上递归查找，范围不仅涵盖 `UIView`，连 `UIViewController` 都不能放过。每找一层就要调用 `nameWithInstance:` 方法用 [Objective-C Runtime](http://yulingtianxia.com/blog/2014/11/05/objective-c-runtime/) 遍历成员变量列表的方式查找变量名。

别忘去掉开头的下划线，因为在Runtime中保存的其实是成员变量的名称，默认都是带有下划线前缀的。

因为 hook 的方法不是 `accessibilityLabel`，所以不能通过 Xcode 中的 View Debug 页面来查看加标签的效果。最好的方法还是通过 UIAutomation 抓取控件树，这样的效果比较真实。为了便于在真机上查看标签内容，我为所有视图增加了长按手势，长按视图后弹警告框显示自动化测试标签的内容。 

hook  `addSubview:` 方法，在其中添加长按手势。 `longPress:` 方法中主要是让长按的视图高亮并弹 Alert 显示自动化测试标签的内容，代码就不贴了。

```
- (void)tb_addSubview:(UIView *)view {
    if (!view) {
        return;
    }
    [self tb_addSubview:view];
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    longPress.delegate = [TBUIAutoTest sharedInstance];
    [self addGestureRecognizer:longPress];
}
```

创建 `TBUIAutoTest` 单例作为所有手势的委托，并在其中实现一些手势捕获优先级的逻辑，以此解决手势冲突带来的问题:

```
@implementation TBUIAutoTest

+ (instancetype)sharedInstance
{
    static dispatch_once_t onceToken;
    static TBUIAutoTest *_instance;
    dispatch_once(&onceToken, ^{
        _instance = [TBUIAutoTest new];
    });
    return _instance;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    if ([otherGestureRecognizer.view isDescendantOfView:gestureRecognizer.view]) {
        return YES;
    }
    if (![otherGestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        return YES;
    }
    return NO;
}
@end
```

## 感受&总结

~~我是杨(gu)阿莫，今天我给大家要讲的是一个月前测试帅哥要求加自动化测试标签后老大开会讨论方案组内高工一致不赞同手动加并要求自动加并在最后老大钦点这个事情就交给我了的故事。这其中还经历了方案的各种改，五子棋同学的实力参(jiao)谋(ji)，以及拉屎时把本该思考人生的时间花在了改进方案。这个月博客实在不知道该写啥眼看月底了再不更新怕以后再也不想更新了呢所以你会发现这篇文章水水的科科！~~

呵呵后来发现~~大部分人~~所有人都看不懂，但这个方案真的好用！

如果大家有更好的方案，或者觉得我的方案一开始就跑偏了，甚至是已经有一个不用手动加标签代码的现成的超屌超牛逼的 iOS 自动化测试框架，请告诉我！据说整个腾讯都是手动加自动化测试标签，老大说做有挑战的事情才有意思嘛。