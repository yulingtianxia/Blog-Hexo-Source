---
title: Colorful Rounded Rect Dash Border
date: 2018-04-30 17:25:44
tags:
---


产品经理要求做个能展示进度的分段彩色外环，大概长这样：

![](https://github.com/yulingtianxia/YXYDashLayer/blob/master/Assets/YXYDashLayer.gif?raw=true)

花了两天左右来实现和优化，记录下踩坑经历。

组件已经开源，取个名字叫 `YXYDashLayer` 吧：https://github.com/yulingtianxia/YXYDashLayer

<!-- more -->

## 接口设计

因为考虑到要做成稍微通用一些的组件，最底层的 `YXYMaskDashLayer` 接口设计如下。其他类的属性也都是对它的封装。

```
/**
 分段的间隙
 */
@property (nonatomic) CGFloat dashGap;
/**
 线宽
 */
@property (nonatomic) CGFloat dashWidth;
/**
 矩形的圆角半径
 */
@property (nonatomic) CGFloat dashCornerRadius;
/**
 分段总数
 */
@property (nonatomic) NSUInteger totalCount;
/**
 需要显示哪些分段的 index
 */
@property (nonatomic) NSArray<NSNumber *> *showIndexes;

/**
 刷新整个Layer
 */
- (void)refresh;

/**
 仅刷新 Dash 的 totalCount、dashGap 和 showIndexes
 */
- (void)refreshDash;
```

因为有些属性改变后并不需要重新绘制 path，为了实现更好的性能，所以还提供了一个只刷新 dash 数据的接口 `refreshDash`。

具体使用的例子可以运行 Demo 程序。

## 思路很重要

之前的样式是个圆形的分段外环，而且是纯色的，看了下以前的代码，是按照弧度均分后，从顶部开始按顺时针一段一段 path 组合起来的。用 `UIBezierPath` 的 `+ bezierPathWithArcCenter:radius:startAngle:endAngle:clockwise:` 方法即可画出来。

然而现在改成了圆角矩形的，要按照周长均分来画分段，实现方式完全不同。因为圆形只是圆角矩形的一种特殊情况，所以需要另一种更通用的实现方式。因为借鉴了圆形分段一段段画的思想，最开始想到的也是一段段画圆角矩形，需要把整个圆角矩形划分成 9 个区域（四个四分之一圆弧，四条直线，顶部直线需要分成两块），还要对圆角和直线部分的边界处理，涉及到大量的计算。我刚开始要这么干的时候，觉得这么做有点笨，肯定有更简单的方案。

`CAShapeLayer` 的 `lineDashPattern` 和 `lineDashPhase` 属性就可以实现这个需求了，之前一直被旧代码的方案限制了思路。真是退一步海阔天空啊。原本跟产品说这有 5 天工作量，结果半个小时就写出个 demo，哈哈。然后用剩下的时间继续完善打磨，做成通用组件。

## 技术实现

1. 先用贝塞尔曲线画一个圆角矩形(就叫 `path` 吧)
2. `path.CGPath` 赋值给 `CAShapeLayer` 实例（就叫 `maskLayer` 吧）
3. 根据线宽、分段间隙、`path` 周长、总分段数、要展示的分段 index，可计算出 `lineDashPattern` 和 `lineDashPhase` 的值，刷新 `maskLayer`
4. 将 `maskLayer` 赋值给 `CAGradientLayer` 实例的 `mask`。调整 `colors` 等属性即可实现一个彩色渐变分段圆角矩形外圈。
5. 将多个这样的 `CAGradientLayer` 实例重叠在一起，即可实现个别分段『高亮』效果。比如一个 layer 当做底色，另一个放上面当做灰色进度条。（PS：本文最开始的 gif 就是这样）

这里面踩坑最多的就是前 3 个步骤，计算时需要考虑到一些边界条件。

### 画圆角矩形的坑

`+ bezierPathWithRoundedRect:cornerRadius:` 方法是可以直接画出一个圆角矩形的，但是路径的起始点并没确定。表面上看上去是从顶部直线左端开始顺时针画，然而会有向右的一些偏差。这样就无法精确计算出 `lineDashPhase` 的值，导致画出来的效果不对称了。

于是我这里干脆自己画个圆角矩形，代码也很简单。由于要考虑到线宽，所以需要计算下真正的圆角半径和外接矩形尺寸，顺时针画四段直线四段四分之一圆弧即可。下面的代码是写在 `CAShapeLayer` 子类里的：

```
UIBezierPath *path = [UIBezierPath bezierPath];
self.dashRect = CGRectInset(self.bounds, self.dashWidth / 2, self.dashWidth / 2);
CGFloat width = self.dashRect.size.width;
CGFloat height = self.dashRect.size.height;
self.realDashCornerRadius = MIN(self.dashCornerRadius - self.dashWidth / 2, width / 2);
self.realDashCornerRadius = MAX(0, self.realDashCornerRadius);
CGPoint center = CGPointMake(self.frame.size.width / 2, self.frame.size.height / 2);
    
[path moveToPoint:CGPointMake(center.x - width / 2 + self.realDashCornerRadius, center.y - height / 2)];
    
[path addLineToPoint:CGPointMake(center.x + width / 2 - self.realDashCornerRadius, center.y - height / 2)];
    
[path addArcWithCenter:CGPointMake(center.x + width / 2 - self.realDashCornerRadius, center.y - height / 2 + self.realDashCornerRadius) radius:self.realDashCornerRadius startAngle:M_PI_2 * 3 endAngle:0 clockwise:YES];
    
[path addLineToPoint:CGPointMake(center.x + width / 2, center.y + height / 2 - self.realDashCornerRadius)];
    
[path addArcWithCenter:CGPointMake(center.x + width / 2 - self.realDashCornerRadius, center.y + height / 2 - self.realDashCornerRadius) radius:self.realDashCornerRadius startAngle:0 endAngle:M_PI_2 clockwise:YES];
    
[path addLineToPoint:CGPointMake(center.x - width / 2 + self.realDashCornerRadius, center.y + height / 2)];
    
[path addArcWithCenter:CGPointMake(center.x - width / 2 + self.realDashCornerRadius, center.y + height / 2 - self.realDashCornerRadius) radius:self.realDashCornerRadius startAngle:M_PI_2 endAngle:M_PI clockwise:YES];
    
[path addLineToPoint:CGPointMake(center.x - width / 2, center.y - height / 2 + self.realDashCornerRadius)];
    
[path addArcWithCenter:CGPointMake(center.x - width / 2 + self.realDashCornerRadius, center.y - height / 2 + self.realDashCornerRadius) radius:self.realDashCornerRadius startAngle:M_PI endAngle:M_PI_2 * 3 clockwise:YES];

self.totalLength = (width + height) * 2 - self.realDashCornerRadius * 8 + M_PI * self.realDashCornerRadius * 2;
    
self.lineWidth = self.dashWidth;
    
self.path = path.CGPath;
```

上面的代码也计算出了周长，用于下一步的分段长度计算。

### 处理边界值

圆角矩形的周长已经算出来了，外部提供了 `dashGap`，但是绘制时真正的分段间隙是需要考虑到线宽和分段总数的。因为线的边缘会有个半圆，半径为二分之一线宽。当只有一个分段的时候画一个完整的圆角矩形，不需要有间隙了。如果分段总数过多导致计算的分段长度 `pieceLength` 小于 0，需要计算能展示出来分段数的最大值 `realTotalCount`，并重新计算分段长度 `pieceLength`。

```
CGFloat realDashGap = (self.totalCount == 1) ? 0 : self.dashGap + self.dashWidth;
NSUInteger realTotalCount = self.totalCount;
CGFloat pieceLength = self.totalLength / self.totalCount - realDashGap;
if (pieceLength < 0) {
   pieceLength = 0;
   realTotalCount = self.totalLength / realDashGap;
   pieceLength = self.totalLength / realTotalCount - realDashGap;
   NSLog(@"Can't show! Reduce total count or dash gap! Real Total Count: %lu, Real Dash Gap:%ff", (unsigned long)realTotalCount, realDashGap);
}
```

### Dash 策略

`lineDashPhase` 可以理解为 dash 距离 path 起始点的距离，想让 dash 从顶部中间开始，需要设置初始值：二分之一外接矩形宽度的减去圆角半径，再加上二分之一 `realDashGap`。

```
self.lineDashPhase = - (self.dashRect.size.width / 2 - self.realDashCornerRadius + realDashGap / 2);
```

然后就是顺时针画需要展示的分段。输入是一个 `showIndexes` 数组，比如一共有 10 个分段，想展示的是前两个和最后一个分段，那么 `showIndexes` 的内容就是 `@[@0, @1, @9]`。此时 `lineDashPattern` 的值就应该是（`pieceLength` 就是每个分段的长度）：

```
@[@pieceLength, @realDashGap, @pieceLength, @(realDashGap * 8 + pieceLength * 7), @pieceLength, @realDashGap]
```

如果 `showIndexes` 的内容是 `@[@1, @2, @9]`，可不可以让 `lineDashPattern` 数组前面填 `@0` 呢？

```
@[@0, @(pieceLength + realDashGap), @pieceLength, @realDashGap, @pieceLength, @(realDashGap * 7 + pieceLength * 6), @pieceLength, @realDashGap]
```

因为把 `lineCap` 设为了 `kCALineCapRound`，即便长度为 0 路径也会展示成为一个圆点，半径就是线宽。然而安卓系统对应的 API 在这种情况就不会绘制出圆点。为此 iOS 更麻烦一点，需要再次调整`lineDashPhase` 的值来『越过』前面几个分段。具体的实现代码如下：

```
NSMutableArray<NSNumber *> *dashPattern = [NSMutableArray arrayWithCapacity:2 * realTotalCount];
NSInteger needsMovePhaseCount = 0;
for (int i = 0; i < realTotalCount; i ++) {
   if ([self.showIndexes containsObject:@(i)]) {
       [dashPattern addObject:@(pieceLength)];
       [dashPattern addObject:@(realDashGap)];
   }
   else {
       if (dashPattern.count > 0) {
           dashPattern[dashPattern.count - 1] = @(dashPattern[dashPattern.count - 1].doubleValue + pieceLength + realDashGap);
       }
       else {
           self.lineDashPhase -= (pieceLength + realDashGap);
           needsMovePhaseCount ++;
       }
   }
}
if (needsMovePhaseCount > 0 && dashPattern.count > 0) {
   dashPattern[dashPattern.count - 1] = @(dashPattern[dashPattern.count - 1].doubleValue + (pieceLength + realDashGap) * needsMovePhaseCount);
}
    
if (self.showIndexes.count > 0) {
   self.lineDashPattern = dashPattern;
}
```

## 总结

一开始做这种需求我是拒绝的，交互有点复杂啊，用户看不懂啊，说白了还是不知道咋实现心里没底啊！然而要是没有这种需求，也就没有这篇月末大水文了。

我真是越来越水了，只会写 UI 了，还是搞底层的逆向大佬们牛逼啊！Hank 老师教教我！

