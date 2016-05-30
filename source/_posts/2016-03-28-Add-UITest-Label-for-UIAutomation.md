title: 为 UIAutomation 添加自动化测试标签的探索
date: 2016-03-28 00:47:32
tags:
- iOS

---
UIAutomation 是苹果提供的自动化测试框架，但依然需要我们手动为控件添加可访问性（Accessibility）。如何让一个控件的可访问标签在当前页面唯一且不变呢？当然纯手工在代码中插入加标签的逻辑代码肯定是可行的，但费时费力，所以我在这里做一些用程序自动化添加标签尝试性的探索。

<!--more-->
## 分析&方案
首先回顾下标签的要素：

1. 唯一：同一页面不同视图标签不能重名
2. 不变：每次打开这个页面，视图的标签不能变，否则还得改测试脚本

初定方案：标签格式为：『superview标签』+『特殊标识』

也就是说这是个递归的方案，标签内容保留了视图层级，并用特殊标识保证了唯一性。那么重点自然在于特殊标识的选取了，为了满足标签唯一且不变的要素，最后选择代码中声明视图变量的变量名。如果有重名的视图变量，则需要手动添加代码设置其标签。

那么这里又引发了一些问题：

1. 如果变量是类的属性或实例变量，则可保证其命名的唯一性。如果代码没有改动，则标签也不会变化。即使代码有变化，也肯定是改变了 UI 业务逻辑，那么正常情况下测试脚本肯定也是要改的，所以不必考虑因为改动代码带来的标签变化。
2. 如果视图是局部变量，那么很有可能从全局来看某两处的局部变量重名。
3. 如何获取代码中局部变量的变量名，并与其对象绑定起来。（绑定指得是讲变量名赋值给 `accessibilityIdentifier` 之类的属性）

由于编译器对代码进行了词法分析、语法分析和语义分析，此时局部变量名早就消失了。运行的时候局部变量在内存里也只是个冰冷冷的对象罢了，不像类的实例变量或属性那样可以获取名称。既然编译阶段之后就已经拿不到局部变量名了，那只能从源码层面下手。比如在 `addSubview:` 的时候获取参数名，并将参数表与参数实例绑定。

从函数调用堆栈获取上一层调用函数在源码中的位置（比如文件名和行数），然后用正则匹配抓取 `addSubview:` 的参数名，看样子是个方案。获取函数调用栈对应源码位置可以用 [`backtrace_symbols`](http://stackoverflow.com/questions/3151779/how-its-better-to-invoke-gdb-from-program-to-print-its-stacktrace/4611112#4611112)，或者 `[NSThread callStackSymbols]` 等，但这都脱离了纯净的 iOS 环境，需要在 PC 中处理源码内容，无法将变量名关联到 iOS 运行环境中。当然也可以用脚本程序帮我们在源码指定位置中插入添加标签的逻辑代码，但这样的弊端有二：

1. 维护成本较高，脚本在向源码中插入加标签逻辑代码时需要判断是否已经插入过这段代码，增加了出错几率
2. 对代码内容变化的鲁棒性不高。因为重构等行为很可能把原有代码顺序弄乱，脚本需要考虑很多情况。每次新增代码都要重新跑一次脚本。

既然局部变量的名字可能重名并难于与实例绑定，不妨另辟蹊径寻求其他方法。这里提出一种假设：程序员写代码的时候之所以将一个视图变量声明为类的属性，是因为以后还会经常用到它。而那些被声明为局部变量的，肯定是临时用一次就不用了。这种用临时变量创建的视图添加到视图层级中内容极有可能就不会变了，其大部分应该是 `UILabel`、`UIButton`、`UIImageView` 以及被当做容器视图功能的 `UIView` 实例。针对这种情况可以将其视图的内容作为标签的『特殊标识』。比如 `UILabel` 的文本内容、`UIButton` 的文本内容加图片名以及 `UIImageView` 的图片名。

总之，针对局部变量，将其变量名作为『特殊标识』来组成标签是很不明智的（可能重名），且实现难度较大。如果无法生成唯一的『特殊标识』就只能采取手动写代码加标签的方案。

## 实践&探索

针对自动为类的属性和实例变量加标签，我采用 hook 和递归的方式。hook `UIView` 中的`accessibilityIdentifier` 的原因是此时的视图层级更全，并且是惰性生成标签。其实使用 `accessibilityLabel` 也是可以的，但对 VoiceOver 功能会有影响，毕竟变量名不像视图文字内容那样有实际意义。

PS：这里之所以不 hook `addSubview:` 是因为在添加 subview 时，视图层级树并不完整。虽然调用 `accessibilityIdentifier` 时视图层级也可能不完整（比如在 `addSubview:` 之前调用 `accessibilityIdentifier`），但这样的几率远远小于前者：很多时候是 `[a addSubview:b]`，但此时 `a` 还没有 `superview`，那么如果 hook `addSubview:`方法，就只能保留 `a` 以下的视图层级。这并不是我想看到的。

```
@implementation UIView (TBUIAutoTest)
+ (void)load {
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
	  [self swizzleSelector:@selector(accessibilityIdentifier) withAnotherSelector:@selector(tb_accessibilityIdentifier)];
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
    if (accessibilityIdentifier && accessibilityIdentifier.length>1) {
        if ([[accessibilityIdentifier substringToIndex:1] isEqualToString:@"("]) {
            return [self tb_accessibilityIdentifier];
        }
    }
    else if ([accessibilityIdentifier isEqualToString:@"null"]) {
        accessibilityIdentifier = @"";
    }
    // 通过实例对象获取其变量名
    NSString *labelStr = [self.superview findNameWithInstance:self];
    NSString *subLabelStr = @"";
    NSString *superLabelStr = @"";
    if (self.superview) {
        superLabelStr = self.superview.accessibilityIdentifier;
    }
    if (labelStr && ![labelStr isEqualToString:@""]) {
        subLabelStr = [NSString stringWithFormat:@"%@(%@)",superLabelStr,labelStr];
    }
    else {
        if ([self isKindOfClass:[UILabel class]]) {//UILabel 使用 text
            subLabelStr = [NSString stringWithFormat:@"%@(%@)",superLabelStr,((UILabel *)self).text];
        }
        else if ([self isKindOfClass:[UIImageView class]]) {//UIImageView 使用 image 的 imageName
            subLabelStr = [NSString stringWithFormat:@"%@(%@)",superLabelStr,((UIImageView *)self).image.accessibilityIdentifier];
        }
        else if ([self isKindOfClass:[UIButton class]]) {//UIButton 使用 button 的 text和图片的标签
            subLabelStr = [NSString stringWithFormat:@"%@(%@%@)",superLabelStr,((UIButton *)self).titleLabel.text,((UIButton *)self).imageView.image.accessibilityIdentifier];
        }
        else if (accessibilityIdentifier) {// 已有标签，则在此基础上再次添加更多信息
            subLabelStr = [NSString stringWithFormat:@"%@(%@)",superLabelStr,accessibilityIdentifier];
        }
        else {
            subLabelStr = [NSString stringWithFormat:@"%@",superLabelStr];
        }
        if ([self isKindOfClass:[UIButton class]]) {
            self.accessibilityValue = [NSString stringWithFormat:@"%@(%@)",superLabelStr,((UIButton *)self).currentBackgroundImage.accessibilityIdentifier];
        }
    }
    if ([subLabelStr isEqualToString:@"()"] || [subLabelStr isEqualToString:@"(null)"] || [subLabelStr isEqualToString:@"null"]) {
        subLabelStr = @"";
    }
    [self setAccessibilityIdentifier:subLabelStr];
    return subLabelStr;
}
@end
```

hook 那段代码很简单就不细说了，主要是 `tb_accessibilityIdentifier` 方法。标签字符串的准确格式为：『superview标签』（『特殊标识』），在这个格式中，括号代表了视图层级。因为是逐级向上获取标签，所以为了避免重复计算更上层视图的标签，当存在符合格式定义的 `accessibilityIdentifier` 时直接调用 `[self tb_accessibilityIdentifier]` 返回 `_accessibilityIdentifier` 的值，与之对应的是方法结尾的 ` [self setAccessibilityIdentifier:subLabelStr]` 用来给 `_accessibilityIdentifier` 赋值生成好的标签。

对于获取不到变量名的临时变量和视图层级中一些系统私有的视图变量，才去之前分析中提到的方案特殊处理。好一长串的 `if-else` 啊，为了处理这些特殊情况写一坨脏代码我也是醉了。最后别忘处理下无意义的字符串，比如 "null"。

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
    return name;
}

@end
```

因为我们并不知道某个视图对象在哪个类中充当了属性或成员变量，所以 `findNameWithInstance:` 方法会沿着响应链向上递归查找，范围不仅涵盖 `UIView`，连 `UIViewController` 都不能放过。每找一层就要调用 `nameWithInstance:` 方法用 [Objective-C Runtime](http://yulingtianxia.com/blog/2014/11/05/objective-c-runtime/) 遍历成员变量列表的方式查找变量名。

最后为了查看效果，我还 hook 了 `addSubview:` 方法，在其中添加长按手势。 `longPress:` 方法中主要是让长按的视图高亮并弹 Alert 显示自动化测试标签的内容，代码就不贴了。

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

`TBUIAutoTest` 这个单例功能是处理手势冲突，仅此而已：

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

**2016.04.13 更新**
在 UIAutomation 生成控件树时，大部分 `UIImageView` 无法通过 hook `accessibilityIdentifier` 来在控件树中获取到自动化测试标签，或者获得的标签不是属性名而是图片资源名。解决方案是 hook accessibilityLabel 方法，并在其中为 `UIImageView` 加自动化测试标签：

```
- (NSString *)tb_accessibilityLabel
{
    if ([self isKindOfClass:[UIImageView class]]) {
        NSString *name = [self.superview findNameWithInstance:self];
        self.accessibilityIdentifier = [NSString stringWithFormat:@"(%@)",name];
        //balabala...
    }
    return [self tb_accessibilityLabel];
}
```

## 感受&总结

我是杨(gu)阿莫，今天我给大家要讲的是一个月前测试帅哥要求加自动化测试标签后老大开会讨论方案组内高工一致不赞同手动加并要求自动加并在最后老大钦点这个事情就交给我了的故事。这其中还经历了方案的各种改，五子棋同学的实力参(jiao)谋(ji)，以及拉屎时把本该思考人生的时间花在了改进方案。这个月博客实在不知道该写啥眼看月底了再不更新怕以后再也不想更新了呢所以你会发现这篇文章水水的科科！

如果大家有更好的方案，或者觉得我的方案一开始就跑偏了，甚至是已经有一个不用手动加标签代码的现成的超屌超牛逼的 iOS 自动化测试框架，请告诉我！据说整个腾讯都是手动加自动化测试标签，老大说做有挑战的事情才有意思嘛。