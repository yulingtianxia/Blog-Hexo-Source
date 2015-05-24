---
layout: post
title: "iOS8自动调整UITableView和UICollectionView布局"
date: 2014-08-17 16:57:42 +0800
comments: true
tags: 
- iOS

---

本文讲述了`UITableView`、`UICollectionView`实现self-sizing cell布局的知识，以及如何用InvalidationContext优化`UICollectionView`布局的更新。  

<!--more-->

##背景

iOS越来越人性化了，用户可以在设置-通用-辅助功能中动态调整字体大小了。你会发现所有iOS自带的APP的字体大小都变了，可惜我们开发的第三方APP依然是以前的字体。在iOS7之后我们可以用`UIFont`的`preferredFontForTextStyle:`类方法来指定一个样式，并让字体大小符合用户设定的字体大小。目前可供选择的有六种样式:

```
UIFontTextStyleHeadline
UIFontTextStyleBody
UIFontTextStyleSubheadline
UIFontTextStyleFootnote
UIFontTextStyleCaption1
UIFontTextStyleCaption2
```

iOS会根据样式的用途来合理调整字体。  

问题来了，诸如字体大小这种“动态类型”，我们需要对其进行动态的UI调整，否则总是觉得我们的界面怪怪的：  

![](http://yulingtianxia.qiniudn.com/image-DCBF_53F0DDDB.jpg)  

我们想要让Cell的高度随着字体大小而作出调整：  
 
![](http://yulingtianxia.qiniudn.com/image-0D8C_53F0DDDB.jpg)  

总之，还会有其他动态因素导致我们需要修改布局。  

##解决方案

###UITableView

有三种策略可以调节Cell（或者是Header和Footer）的高度：  

- 调节Height属性
- 通过委托方法`tableView: heightForRowAtIndexPath:`
- Cell的“自排列”（self-sizing）

前两种策略都是我们所熟悉的，后面将介绍第三种策略。`UITableViewCell`和`UICollectionViewCell`都支持self-sizing  

在iOS7中，`UITableViewDelegate`新增了三个方法来满足用户设定Cell、Header和Footer预计高度的方法:

```
- tableView:estimatedHeightForRowAtIndexPath:
- tableView:estimatedHeightForHeaderInSection:
- tableView:estimatedHeightForFooterInSection:
```

当然对应这三个方法`UITableView`也`estimatedRowHeight`、` estimatedSectionHeaderHeight`和`estimatedSectionFooterHeight`三个属性，局限性在于只能统一定义所有行和节的高度。    

以Cell为例，iOS会根据给出的预计高度来创建一个Cell，但等到真正要显示它的时候，iOS8会在self-sizing计算得出新的Size并调整table的`contentSize`后，将Cell绘制显示出来。关键在于如何得出Cell新的Size，iOS提供了两种方法：  

- 自动布局
	这个两年前推出的神器虽然在一开始表现不佳，但随着Xcode的越来越给力，在iOS7中自动布局俨然成了默认勾选的选项，通过设定一系列约束来使得我们的UI能够适应各种尺寸的屏幕。如果你有使用约束的经验，想必已经有了解决思路：向Cell的`contentView`添加约束。iOS会先调用`UIView`的`systemLayoutSizeFittingSize:`方法来根据约束计算新的Size，如果你没实现约束，`systemLayoutSizeFittingSize:`会接着调用`sizeThatFits:`方法。  
- 人工代码
	我们可以重写`sizeThatFits:`方法来自己定义新的Size，这样我们就不必学习约束相关的知识了。  
	
下面我给出了一个用Swift语言写的Demo-[HardChoice](http://hardchoice.yulingtianxia.com)，使用自动布局来调整`UITableViewCell`的高度。我通过实现一个`UITableViewCell`的子类`DynamicCell`来实现自动布局，你可以再GitHub上下载[源码](https://github.com/yulingtianxia/HardChoice)：  

```
import UIKit

class DynamicCell: UITableViewCell {

    required init(coder: NSCoder) {
        super.init(coder: coder)
        if textLabel != nil {
            textLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)
            textLabel.numberOfLines = 0
        }
        if detailTextLabel != nil {
            detailTextLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
            detailTextLabel.numberOfLines = 0
        }
    }
    
    override func constraints() -> [AnyObject] {
        var constraints = [AnyObject]()
        if textLabel != nil {
            constraints.extend(constraintsForView(textLabel))
        }
        if detailTextLabel != nil {
            constraints.extend(constraintsForView(detailTextLabel))
        }
        constraints.append(NSLayoutConstraint(item: contentView, attribute: NSLayoutAttribute.Height, relatedBy: NSLayoutRelation.GreaterThanOrEqual, toItem: contentView, attribute: NSLayoutAttribute.Height, multiplier: 0, constant: 44))
        contentView.addConstraints(constraints)
        return constraints
    }
    
    func constraintsForView(view:UIView) -> [AnyObject]{
        var constraints = [NSLayoutConstraint]()
        constraints.append(NSLayoutConstraint(item: view, attribute: NSLayoutAttribute.FirstBaseline, relatedBy: NSLayoutRelation.Equal, toItem: contentView, attribute: NSLayoutAttribute.Top, multiplier: 1.8, constant: 30.0))
        constraints.append(NSLayoutConstraint(item: contentView, attribute: NSLayoutAttribute.Bottom, relatedBy: NSLayoutRelation.GreaterThanOrEqual, toItem: view, attribute: NSLayoutAttribute.Baseline, multiplier: 1.3, constant: 8))
        return constraints
    }
    
}
```

上面的代码需要注意的是，Objective-C中的类在Swift中都可以被当做`AnyObject`，这在类型兼容问题上很管用。  

别忘了在相应的UITableViewController中的viewDidLoad方法中加上：  

```
self.tableView.estimatedRowHeight = 44
```

自适应效果如下：  

![](http://yulingtianxia.qiniudn.com/140833033058.gif)  

###UICollectionView

`UITableView` 和 `UICollectionView` 都是 data-source 和 delegate 驱动的。`UICollectionView`在此之上进行了进一步抽象。它将其子视图的位置，大小和外观的控制权委托给一个单独的布局对象。通过提供一个自定义布局对象，你几乎可以实现任何你能想象到的布局。布局继承自 `UICollectionViewLayout` 抽象基类。iOS6 中以 `UICollectionViewFlowLayout` 类的形式提出了一个具体的布局实现。在`UICollectionViewFlowLayout`中，self-sizing同样适用：  

![](http://yulingtianxia.qiniudn.com/image-05D4_53F0E00F.jpg?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)  

采用self-sizing后：  

![](http://yulingtianxia.qiniudn.com/image-B1E8_53F0DDDB.jpg?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)    

Demo下载地址：https://github.com/yulingtianxia/Self-Sizing-CollectionView-Demo  

`UICollectionView`实现self-sizing不仅可以通过在Cell的`contentView`上加约束和重写`sizeThatFits:`方法，也能在Cell层面（以前都是在`contentSize`上进行self-sizing）上做文章：重写`UICollectionReusableView`的`preferredLayoutAttributesFittingAttributes:`方法来在self-sizing计算出Size之后再修改，这样就达到了对Cell布局属性（`UICollectionViewLayoutAttributes`）的全面控制。  

PS：`preferredLayoutAttributesFittingAttributes:`方法默认调整Size属性来适应self-sizing Cell，所以重写的时候需要先调用父类方法，再在返回的`UICollectionViewLayoutAttributes`对象上做你想要做的修改。  

由此我们从最经典的`UICollectionViewLayout`强制计算属性（还记得`UICollectionViewLayoutAttributes`的一系列工厂方法么？）到使用self-sizing来根据我们需求调整属性中的Size，再到重写`UICollectionReusableView`（`UICollectionViewCell`也是继承于它）的`preferredLayoutAttributesFittingAttributes:`方法来从Cell层面对所有属性进行修改：  

![](http://yulingtianxia.qiniudn.com/image-95BA_53F0DDDB.jpg?imageView2/2/w/800/q/75|watermark/2/text/eXVsaW5ndGlhbnhpYQ==/font/Y29taWMgc2FucyBtcw==/fontsize/500/fill/I0VGRUZFRg==/dissolve/100/gravity/SouthEast/dx/10/dy/10)      

下面来说说如何在`UICollectionViewFlowLayout`实现self-sizing：  

首先，`UICollectionViewFlowLayout`增加了`estimatedItemSize`属性，这与`UITableView`中的"`estimated...Height`"很像（注意我用省略号囊括那三种属性），但毕竟`UICollectionView`中的Item都需要约束Height和Width的，所以它是个`CGSIze`，除了这点它与`UITableView`中的"`estimated...Height`"用法没区别。  

其次。。。没有其次，在`UICollectionView`中实现self-sizing，只需给`estimatedItemSize`属性赋值（不能是`CGSizeZero`），一行代码足矣。  

###InvalidationContext

假如设备屏幕旋转，或者需要展示一些其妙的效果（比如CoverFlow），我们需要将当前的布局失效，并重新计算布局。当然每次计算都有一定的开销，所以我们应该谨慎的仅在我们需要的时候调用`invalidateLayout`方法来让布局失效。  

在iOS6时代，有的人会“聪明地”这样做：  

```
- (BOOL)shouldInvalidateLayoutForBoundsChange:(CGRect)newBounds
{
    CGRect oldBounds = self.collectionView.bounds;
    if (CGRectGetWidth(newBounds) != CGRectGetWidth(oldBounds)) {
        return YES;
    }
        return NO;
}
```

而iOS7新加入的`UICollectionViewLayoutInvalidationContext`类声明了在布局失效时布局的哪些部分需要被更新。当数据源变更时，`invalidateEverything`和`invalidateDataSourceCounts`这两个只读Bool属性标记了`UICollectionView`数据源“全部过期失效”和“Section和Item数量失效”，`UICollectionView`会将它们自动设定并提供给你。  

你可以调用`invalidateLayoutWithContext:`方法并传入一个`UICollectionViewLayoutInvalidationContext`对象，这能优化布局的更新效率。

当你自定义一个`UICollectionViewLayout`子类时，你可以调用`invalidationContextClass`方法来返回一个你定义的`UICollectionViewLayoutInvalidationContext`的子类，这样你的Layout子类在失效时会使用你自定义的InvalidationContext子类来优化更新布局。  

你还可以重写`invalidationContextForBoundsChange:`方法，在实现自定义Layout时通过重写这个方法返回一个InvalidationContext对象。  

综上所述都是iOS7中新加入的内容，并且还可以应用在`UICollectionViewFlowLayout`中。在iOS8中，`UICollectionViewLayoutInvalidationContext`也被用在self-sizing cell上。  

iOS8中`UICollectionViewLayoutInvalidationContext`新加入了三个方法使得我们可以更加细致精密地使某一行某一节Item（Cell）、Supplementary View或Decoration View失效：

```
invalidateItemsAtIndexPaths:
invalidateSupplementaryElementsOfKind:atIndexPaths:
invalidateDecorationElementsOfKind:atIndexPaths:
```

对应着添加了三个只读数组属性来标记上面那三种组件：  

```
invalidatedItemIndexPaths
invalidatedSupplementaryIndexPaths
invalidatedDecorationIndexPaths
```

iOS自带的照片应用会将每一节照片的信息（时间、地点）停留显示在最顶部，实现这种将Header粘在顶端的功能其实就是将那个Index的Supplementary View失效，就这么简单。    

`UICollectionViewLayoutInvalidationContext`新加入的`contentOffsetAdjustment`和`contentSizeAdjustment`属性可以让我们更新CollectionView的content的位移和尺寸。  

此外`UICollectionViewLayout`还加入了一对儿方法来帮助我们使用self-sizing：  

```
shouldInvalidateLayoutForPreferredLayoutAttributes:withOriginalAttributes:
invalidationContextForPreferredLayoutAttributes:withOriginalAttributes:
```

当一个self-sizing Cell发生属性发生变化时，第一个方法会被调用，它询问是否应该更新布局（即原布局失效），默认为NO；而第二个方法更细化的指明了哪些属性应该更新，需要调用父类的方法获得一个InvalidationContext对象，然后对其做一些你想要的修改，最后返回。

试想，如果在你自定义的布局中，一个Cell的Size因为某种原因发生了变化（比如由于字体大小变化），其他的Cell会由于self-sizing而位置发生变化，你需要实现上面两个方法来让指定的Cell更新布局中的部分属性；别忘了整个CollectionView的`contentSize`和`contentOffset`因此也会发生变化，你需要给`contentOffsetAdjustment`和`contentSizeAdjustment`属性赋值。  