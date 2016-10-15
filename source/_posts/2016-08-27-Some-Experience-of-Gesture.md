---
title: 处理手势冲突和错乱的一点经验
date: 2016-08-29 10:53:51
tags:
- iOS

---

如果一个页面上包含着很多视图，而且界面上业务逻辑比较复杂，那么手势响应冲突或者错乱很容易发生。这时就得猥琐点啦，见招拆招。

<!--more-->

## 处理界面多变引发的手势冲突

### 分析问题

界面变化多意味着什么？负责的业务逻辑？不同机型适配？这都不是我要首先去重点考虑的，但有一点很重要，那就是要有一个完善的状态机！要透过现象看本质：手势冲突的原因？难道是因为那几个 `UIGestureRecognizerDelegate` 方法的实现有问题？或者是因为跨层级传递事件在 `hitTest:withEvent:` 里的业务逻辑太复杂没理清？其实这些就算都能弄得很明白，界面内容一变化就容易出问题。更有可能为了快速响应用户的操作而让一些视图常驻内存，而不是每次重新创建和添加，这增加了界面内容的复杂度。

举个栗子，我想让用户发图片前可以对图片进行编辑，比如加段文字、贴纸、滤镜、涂鸦之类的，甚至可以裁剪和加背景音乐。暂且不说如何展示编辑后的图片，但就编辑的界面就很复杂，毕竟好多种编辑模式要在同一个界面中完成。这少不了各种编辑模式入口的按钮，也少不了每种编辑模式对界面视图层级的叠加。起码滤镜要单独一层吧，每个贴纸和文字都是个视图，涂鸦也要一层视图。裁剪时整个图片包括编辑时添加的内容都要跟着一起缩放和旋转，切换滤镜需要滑动，文字和贴纸都要缩放平移旋转等操作。更别提添加文字、贴纸和背景音乐时要覆盖一个全屏的界面（不用新的 controller，而是添加视图），让用户编辑文字或选择素材。这些业务都在一个 controller 里放着，好多层视图叠加，而且变幻莫测。在什么时刻该响应哪个视图的哪个手势，靠什么判断？答案就是：**状态机**

状态机能解决的更多的是界面错乱的问题，但界面一旦错乱必将对手势判断带来致命影响。就算界面不错乱，也需要在 `UIGestureRecognizerDelegate` 方法或 `hitTest:withEvent:` 中知晓当前界面处于何种状态，然后才能准确判断选择哪个手势或哪个视图。这里展开叙述下我对未来可以使用状态机解决 UI 错乱以及因此而引发手势冲突的构想。

### 使用状态机的构想方案

可以认为每种编辑模式下都是一种状态，编辑完成之后也是种状态。还要考虑到初始状态或者无状态的情况。用户对图片上的贴纸和文字等元素进行操作时肯定也要设定一种状态。总之状态不求多，但一定要面面俱到无遗漏，要根据当前界面操作设计状态。某种状态下可能还会有子状态，比如涂鸦模式下可能会有画笔、橡皮擦、马赛克，并能选择粗细之类的功能。这些都属于涂鸦模式下界面中的其他小功能，如果把这些功能的对应的状态跟其他几种编辑模式对应的状态放在一起，能保证唯一性的话倒不是说不可以，但很不合适。

每种状态都要规定它的『下一个状态』的集合，比如涂鸦模式下可能会进入到编辑完成状态，也可能返回到初始状态，也可能进入到裁剪状态。。。这些规则要照着产品经理指定的业务逻辑来，做到调理清晰。制定好每种状态的『下一个状态』的集合后，一张有向图就会展现出来了，规则定了就好办了。不要把这些状态简单理解成『一个枚举』，要用面向对象的思想来实现。比如可以建立个表示状态的基类，再弄个 `isValidNextState:` 方法来判断输入的状态是否能当做此状态的『下一个状态』。苹果的 `GameplayKit` 中的状态机（`GKStateMachine`）就是个很不错的例子。

下一步就是状态的响应，在状态转换时驱动界面元素的变化。什么？不是应该在点击按钮时对界面做变更么？这种思维很局限，也是导致代码复用不高和 bug 频出的原因。能够改变编辑模式的不一定只有按钮点击，这要根据产品的业务。所以应该让界面变更依赖于状态的变化，这样更集中统一，不容易出差错。（但这样的缺点可能就是产品经理要求上报用户行为时无法获知用户何种操作导致状态变化，这里只能通过在状态类中加标志位判断了。）

最关键的是在正确的位置添加状态切换的代码，一定要覆盖全面毫无遗漏。这是保证整个状态机运行的关键！

说了这么多，也没看出状态机跟手势有多大关系啊？直观点讲，在涂鸦状态下是不会响应双指操作的手势的，因为只有单个手指的 Pan 和 Tap 手势；而在操作文字和贴纸的状态下 Pinch、Rotation 和 Pan 是可以同时响应的，因为用户可以旋转缩放视图的同时挪动视图位置，而 Tap 手势此时可能还会赋有其他的功能。总之状态机将复杂的业务逻辑所对应的手势操作划分开，提供了准确唯一的判断。

如果不使用状态机，（打个比方）而是根据界面上某个按钮的 `selected` 或者某个视图的 `hidden` 属性来判断下一步的操作，那肯定会出大乱子。因为 UI 控件的状态不可靠，能够改变它们的因素很多，而且会有多个 UI 状态同时存在导致冲突。唯有状态机牢牢把我在程序员的手里，唯一且准确。

## 处理界面复杂引发的手势错乱

### 情景还原

『你看贴纸这么多手指又太大缩放不灵敏真不怪我啊，臣妾真的办不到啊！』

『哎呀，本来想旋转某个贴纸的，结果两个手指分别在另外两个贴纸上。这么多小贴纸放这么密用户好变态啊！』

。。。真是乱，想操作 A 视图却意外操作了 B 视图。。。

### 分析问题

#### 对手势统一处理和分发

要是给每个视图内容都单独添加一套 Tap、Pan、LongPress、Pinch、Rotation 手势那真是找死啊，手势不错乱才怪呢！别再把手势错乱归结于界面上视图多，要怪就怪添加手势的姿势不对！

当界面内容数量较多时还是要尊崇大一统的思想，把各种手势全都添加到底层的全屏视图上，然后统一处理和分发结果。因为每种手势只有一个且都加在了底层视图，所以不会发生不同视图间的手势错乱。而不同种手势之间的冲突就需要在 `UIGestureRecognizerDelegate` 中根据业务逻辑来解决了。

那么该如何判断哪个视图响应了手势的操作呢？用户最希望的肯定是最顶层的且距离手指最近的视图。这里难在如何选择距离手指最近的视图。

#### 计算响应手势的视图

可以通过 `locationInView:` 获取手势的坐标，但这里决不能简单地计算手势坐标到视图 `center` 的距离并选取最近的视图。这里需要检测手势坐标处于哪个视图的**范围**内，包括『在视图区域内』（红色）和『在视图周围区域』（橙色）：

![选择响应手势的视图](http://7ni3rk.com1.z0.glb.clouddn.com/SomeExperienceofGesture/WhichViewShouldResponseToGesture.png)

策略是先看手势坐标处于哪些视图的『视图区域』中，如果没找到，就再扩大查找范围至『周围区域』。最后如果有多个视图满足要求，就选择最顶层的视图。如果没有任何视图满足要求，可以不做任何处理；也可以根据产品策略对界面上唯一的视图进行操作。这里就看业务怎么规定的了。

至于『周围区域』该如何划定，具体参数就看产品制定的策略进行微调了。总之传入一个 `UIEdgeInsets` 就能搞定。

在用代码实现的时候可以优化逻辑来减少遍历的时间复杂度：从最顶层视图到最底层视图开始遍历，如果手势坐标命中『视图区域』内，则直接得出结果。否则如果手势坐标命中『周围区域』内，就计算手势到视图中心距离并在遍历完成后得到距离最近的视图。

### 解决问题

#### 处理 Pinch 手势

在视图被缩放时，一般是改变 `transform` 属性。关于 `CGAffineTransform` 的知识这里不再赘述。

##### 分辨率

当对含有矢量内容的视图进行缩放时会有模糊和锯齿出现，这时递归需要改变 `UIView` 的 `contentScaleFactor` 和 `CALayer` 的 `contentsScale` 属性：

```
- (void)updateForZoomScale:(CGFloat)zoomScale {
    CGFloat screenAndZoomScale = zoomScale * [UIScreen mainScreen].scale;
    // Walk the layer and view hierarchies separately. We need to reach all tiled layers.
    [self applyScale:screenAndZoomScale toView:self];
    [self applyScale:screenAndZoomScale toLayer:self.layer];
}

- (void)applyScale:(CGFloat)scale toView:(UIView *)view {
    view.contentScaleFactor = scale;
    for (UIView *subview in view.subviews) {
        [self applyScale:scale toView:subview];
    }
}

- (void)applyScale:(CGFloat)scale toLayer:(CALayer *)layer {
    layer.contentsScale = scale;
    for (CALayer *sublayer in layer.sublayers) {
        [self applyScale:scale toLayer:sublayer];
    }
}
```

##### 坐标

视图的 `transform` 属性是不会修改视图的 `bounds` 的，但 `frame` 作为计算属性还是会变化的。也就是说无论视图放大了多少倍，视图内部的子视图的 `frame` 不会变。

总之，`transform` 属性改变的是视图的 `frame`，而 `bounds` 和子视图的 `frame` 都不会变。也就是**视图内部的坐标系不会改变**。记住这点，很有用。

![改变 transform 后的坐标系](http://7ni3rk.com1.z0.glb.clouddn.com/SomeExperienceofGesture/transform%E5%AF%B9%E6%AF%94%E5%9D%90%E6%A0%87.png)

上图展示的是缩放后的坐标变换，也同样适用于旋转。都是相对坐标系的知识罢了。

#### 处理 Rotation 手势

之前一直用『视图区域』而不直接用 `frame` 来描述手势判断依据，是因为当视图旋转（90°倍数除外）之后 `frame` 并不等于『视图区域』：

![旋转后的视图](http://7ni3rk.com1.z0.glb.clouddn.com/SomeExperienceofGesture/Rotation%E5%8C%BA%E5%9F%9F%E5%88%A4%E6%96%AD.png)

也就是说如果按照 `frame` 来判断『视图区域』是偏大的，会遮挡住其他视图。所以我专门写了个方法用于判断某个点是否在『视图区域』内，还提供了 `UIEdgeInsets` 参数用于满足判断『周围区域』的要求：

```
/**
 *  判断某个点是否在视图区域内，针对 transform 做了转换计算，并提供 UIEdgeInsets 缩放区域的参数
 *
 *  @param point  要判断的点坐标
 *  @param view   传入的视图，一定要与本视图处于同一视图树中
 *  @param insets UIEdgeInsets参数可以调整判断的边界
 *
 *  @return BOOL类型，返回点坐标是否位于视图内
 */

- (BOOL)checkPoint:(CGPoint) point inView:(UIView *)view withInsets:(UIEdgeInsets)insets
{
	 // 将点坐标转化为视图内坐标系的点，消除 transform 带来的影响
    CGPoint convertedPoint = [self convertPoint:point toView:view];
    CGAffineTransform viewTransform = view.transform;
    // 计算视图缩放比例
    CGFloat scale = sqrt(viewTransform.a * viewTransform.a + viewTransform.c * viewTransform.c);
    // 将 UIEdgeInsets 除以缩放比例，以便得到真实的『周围区域』
    UIEdgeInsets scaledInsets = (UIEdgeInsets){insets.top/scale,insets.left/scale,insets.bottom/scale,insets.right/scale};
    CGRect resultRect = UIEdgeInsetsInsetRect(view.bounds, scaledInsets);
    // 判断给定坐标点是否在区域内
    if (CGRectContainsPoint(resultRect, convertedPoint)) {
        return YES;
    }
    return NO;
}
```

经过此方法处理后会使得区域判断更准确，那些旋转过的视图带来的手势失效也得以解决。

## 总结

其实如果所有手势都交给一个底层视图统一处理的话，上层那一坨视图是不需要响应触摸事件的，有些甚至可以用 Layer 来做。

`UIGestureRecognizerDelegate` 和 `hitTest:withEvent:` 的用法官方文档中有详细阐述，能够解决手势问题的前提是熟悉文档，然后才是一些思想和架构层面的解决方案。比如 Tap 手势要先让 Pan 手势失败之类的手势冲突就可以用 `UIGestureRecognizerDelegate` 处理，不再列举。

我碰到的应用场景有限，经验不够多，还请大家补充经验！ 

## Reference

http://stackoverflow.com/questions/5927223/scaling-uitextview-using-contentscalefactor-property

