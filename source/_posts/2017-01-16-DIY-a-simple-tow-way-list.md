---
title: DIY 双向滑动列表
date: 2017-01-16 13:23:17
tags:
---

公司项目中有个页面是双向滑动的列表，遂用 `UIScrollView` 手撸了之，把一些 UI 和数据上的心得记录下来。

<!--more-->

## 需求简介

UI 上的主要内容就是一个 `UITableView`，其中一些 cell 内会嵌套一个横向滑动的 `ListView`，`ListView` 中包含一些尺寸相同可点击的 ItemView，ItemView 中的图片内容需要从网络加载。

去掉一些跟本文内容无关的细枝末节，可以将原型抽象如下图：

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQStoryMemory/原型.png)

蓝色的为 ItemView，白色为 `ListView`，灰色为 TableView。

竖向滑动会有分页加载和转菊花停顿，横向滑动无分页加载停顿，要求细腻丝滑。

**如果只是单纯一个双向滑动列表，`UICollectionView` 完全可以胜任。**但是真正的需求里还掺杂着很多其他 UI 元素，所以只能 DIY 了。

## 数据请求

### 格式设计

因为主体 UI 为竖向列表嵌套横向列表，所以两个方向都需要有数据请求。

为了方便叙述，这里简化下数据格式。

ItemView 对应的数据 `ItemModel` 包含唯一标识符 `itemID` 和图片地址 `imageURL`：

```
@interface ItemModel: NSObject
@property (nonatomic, strong) NSString *itemID; // Item 唯一标识符
@property (nonatomic, strong) NSString *imageURL; // 封面图片 URL
@end
```

`ListView` 对应的数据 `ListModel` 包含分组唯一标识符 `listID`，首屏需要展现的 Item 数据 `items` 和列表所有 Item 的 ID `itemIDs`。

```
@interface ListModel: NSObject
@property (nonatomic, strong) NSString *listID; // List 唯一标识符
@property (nonatomic, strong) NSArray<ItemModel *> *items; // 包含首屏前几个 Item 数据
@property (nonatomic, strong) NSArray<NSString *> *itemIDs; // 包含整行 List 所有 Item 的 ID
@end
```

竖向滑动时，TableView 会从后台分页获取 `ListModel` 数组。`ListModel` 中的 `items` 填充了初始数据（此时不需要横向滑动拉取数据）。

之所以不干脆在 `ListModel` 装填所有 `ItemModel`，是为了节省一次请求的数据流量，降低失败率。因为第一次展示页面时只需要填充前几个 ItemView 的数据，等用户横向滑动后再继续根据 `itemIDs` 请求滑动到的 ItemView 对应数据。

### 请求时机

因为有了 `ListView` 中所有 ItemView 对应的 ID，所以横向滑动没有分页逻辑，就没有转菊花的停顿时间用来请求网络数据和等待接受处理数据。虽然可以用 ID 请求到对应的 `ItemModel`，但肯定不能在 `UITableView` 的 datasource 回调中为每个 cell 去单独请求数据。所以 `ListView` 即便直接使用 `UITableView` 或 `UICollectionView`，也无法享受到它带来的便捷，数据请求逻辑依然需要自己在 `UIScrollViewDelegate` 中实现。**所以 `ListView` 是继承 `UIScrollView` 自己 DIY 了一个横向滑动列表。如何合理控制数据请求次数成为了性能优化的重点**

*文中示例代码均经过简化，去除了无关信息，并使用 MRC。*

```
@interface `ListView` : UIScrollView
@property (nonatomic, retain) ListModel *model;
@property (nonatomic, retain) NSMutableArray<ItemModel *> *itemModels;
@end

@implementation

const static CGFloat itemWidth = 80; // ItemView 宽度
const static CGFloat itemHeight = 128; // ItemView 高度
const static CGFloat itemGap = 2; // ItemView 间距
const static CGFloat itemFirstToLeft = 0; // 最左边的 ItemView 的 leftMargin

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    if (scrollView.contentSize.width == 0) {
        return;
    }
    // 计算滚动的区间
    NSInteger indexLeft = floorf((scrollView.contentOffset.x - itemFirstToLeft) / (itemWidth + itemGap)) - 1;
    indexLeft = MAX(indexLeft, 0);
    indexLeft = MIN(indexLeft, self.model.itemIDs.count - 1);
    
    NSInteger indexRight = ceilf((scrollView.contentOffset.x - itemFirstToLeft + scrollView.width) / (itemWidth + itemGap));
    indexRight = MAX(indexRight, 0);
    indexRight = MIN(indexRight, self.model.itemIDs.count - 1);
    
    NSInteger length = indexRight - indexLeft + 1;
    length = MAX(length, 0);
    length = MIN(length, self.model.itemIDs.count);
    
    // 加载区间内的 Item
    [self loadItems:NSMakeRange(indexLeft, length)];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    [self reloadItemModels];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    [self reloadItemModels];
}

/**
 在指定范围内加载可重用 Item
 针对本地没有数据的 itemID 请求数据
 @param range 加载的范围
 */
- (void)loadItems:(NSRange)range
{
// 省略...
}

/**
 刷新页面数据，如果页面上有数据缺失，则再次请求数据
 */
- (void)reloadItemModels
{
// 省略...
}
// 省略一堆逻辑...
@end
```

在 `ListView` 中直接请求数据的位置有三处，但 `loadItems:` 和 `reloadItemModels` 这两个方法会被其他地方调用，所以可能间接请求数据的时机还是很多的。`reloadItemModels` 方法也会在接收到网络数据时被调用。`loadItems:` 计算滚动时屏幕上包含 `ItemView` 的区间的方法完全是根据 frame 坐标来计算的，并且会预留出屏幕外左右各一个 `ItemView`。`reloadItemModels` 方法只是重新装载下数据，因为 `itemID` 列表是完整的，但每个 `itemID` 不一定都缓存到了对应的 `ItemModel`，所以这个方法还对缺失数据进行请求，可以理解为『强刷』。

`UIScrollViewDelegate` 中实现策略如下：

1. 在列表滚动过程中计算当前显示在屏幕上的 ItemView 的区间，并调用 `loadItems:`
2. 在列表即将开始滚动和停止滚动的时刻，调用 `reloadItemModels` 重新加载数据

在计算需要加载的 `range` 的时候需要注意一些边界数值的处理，擅用 `floorf` 和 `ceilf` 函数进行取舍，并用 `MAX()` 和 `MIN()` 来检查边界值合法性。

## 可重用的 `ItemView`

需要自己实现一个类似 `UICollectionView` 的 item 重用机制。

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQStoryMemory/reusableitem.png)

在用户横向滑动列表时，需要更新此时某个区间的 UI 和数据。这个任务是在 `loadItems:` 中实现的，原理是计算出需要被加载的 itemID 数组，并与已有的数据进行比较。将不再需要显示在屏幕上的 `ItemView` 进行回收（enqueue），并从根据 itemID 添加 `ItemView` 对象（dequeue）。因为一开始只加载了首屏的 `ItemModel` 数组，所以还需要对本地缓存中缺失的数据进行请求。

```
/**
 在指定范围内加载可重用 Item
 针对本地没有数据的 itemID 请求数据
 @param range 加载的范围
 */
- (void)loadItems:(NSRange)range
{
    NSMutableArray<NSString *> *itemIDsToLoad = [[self.model.itemIDs subarrayWithRange:range] mutableCopy];
    NSMutableArray<ItemView *> *itemsToEnqueue = [NSMutableArray array];
    // 比较需要加载的 itemID 数组和已经显示过的 itemID 数组，计算出需要新添加的 itemID 和不再需要显示而被回收的 Item
    for (ItemView *item in self.visibleItems) {
        NSString *itemIDAlreadyLoad = nil;
        for (NSString *itemIDToLoad in itemIDsToLoad) {
            if ([itemIDToLoad isEqualToString:item.itemID]) {
                itemIDAlreadyLoad = itemIDToLoad;
            }
        }
        if (!itemIDAlreadyLoad) {
            [itemsToEnqueue addObject:item];
        }
        else {
            [itemIDsToLoad removeObject:itemIDAlreadyLoad];
        }
    }
    // 回收不需要显示的 Item
    for (ItemView *item in itemsToEnqueue) {
        [item removeFromSuperview];
        [self.visibleItems removeObject:item];
        [self enqueueReusableItem:item];
    }
    // 添加需要显示的 Item
    NSMutableArray<NSString *> *itemIDsToRequest = [NSMutableArray array];
    for (NSString *itemID in itemIDsToLoad) {
        if (![self addItemViewWithID:itemID]) {
            [itemIDsToRequest addObject:itemID];
        }
    }
    // 针对本地没有数据的 itemID 请求数据
    if (itemIDsToRequest.count > 0) {
        // 向后台请求 itemIDsToRequest 对应数据
    }
    [itemIDsToLoad release];
}
```

`addItemViewWithID:` 负责从 reusable items 获取 `ItemView` 并设置 `frame` 添加到 `ListView` 中。因为 `ItemView` 是重用的，所以如果 dequeue 出的对象正好是上一次刚刚 enqueue 的对象，那么就不用重新填充数据了；否则需要重置 `ItemView` 的占位图，并填充新数据。`ItemView` 被填充了数据后会对数据进行处理，比如异步拉取图片资源。

当无法向 `ItemView` 填充数据时，`addItemViewWithID:` 会返回 `NO`，暗示调用方需要用该 itemID 请求数据。

```
/**
 添加 itemID 对应的 Item

 @param itemID @param itemID 视频 ID
 @return 是否成功向 Item 填充数据
 */
- (BOOL)addItemViewWithID:(NSString *)itemID
{
    ItemView *item = [self dequeueReusableItem];
    NSUInteger index = [self.model.itemIDs indexOfObject:itemID];
    
    CGFloat originX = itemFirstToLeft + index * (itemWidth + itemGap);
    item.frame = CGRectMake(originX, 0, itemWidth, itemHeight);
    [self addSubview:item];
    [self.visibleItems addObject:item];
    if ([item.itemID isEqualToString:itemID]) {
        return YES;
    }
    [item useDefaultCover];
    item.itemID = itemID;
    
    for (ItemModel *model in self.itemModels)
    {
        if ([model.itemID isEqualToString:itemID])
        {
            item.model = model;
            return YES;
        }
    }
    return NO;
}
```

可重用 Item 列表的 dequeue 和 enqueue 操作实现如下，dequeue 也负责在可重用列表不够用时创建新的 `ItemView`：

```
/**
 从可重用队列中回收 Item
 @param item  回收的 Item
 */
- (void)enqueueReusableItem:(ItemView *)item
{
    [self.reusableItems addObject:item];
}

/**
 从可重用队列中取出 Item
 @return  取出的 Item
 */
- (ItemView *)dequeueReusableItem
{
    ItemView *item = [self.reusableItems.firstObject retain];
    if (item) {
        [self.reusableItems removeObject:item];
    }
    else {
        item = [ItemView new];
    }
    return [item autorelease];
}
```

## 感受

不得不承认一开始想 DIY 个列表还是有装逼嫌疑的，但后来发现还是 DIY 来的爽，好多事情都掌握在自己手里，批量请求数据也更方便（虽说直接用 `UICollectionView` 也可以办到，只是有些绕，且依然得自己实现 `UIScrollViewDelegate`）。最大的收获就是对 `UIScrollView` 的理解更深刻，对 `UITableView` 的实现机制有了掌握。

还有就是在做之前把一些事情想的太简单了，然后开始动工后就会发现：卧槽还真就是这么简单！23333333

其实还是遇到了一些项目中的 API 上的坑的，比如工程里的异步加载图片 ImageView 会忽略第二次相同的 url 请求，导致调试时花了些时间。

曾经还设想把可重用的范围扩大到整个屏幕，也就是屏幕上所有横向滑动的 `ListView` 全都共用一个可重用列表。但后来计算一下这样做收益不高，毕竟横向滑动的 `ListView` 在正常滑动时可重用列表中会有一到两个 `ItemView` 对象，而全屏最多同时存在 5 个 `ListView`，节省的内存很有限。

其实还有许多细节实现没有叙述，比如记录 `ListView` 上次横向滑动位置，因为 `ListView` 是加在全屏 TableView 的每个 cell 中，而 cell 也是重用的，所以上次滑动偏移是需要每次 cell 消失时记录和 cell 出现时刷新的。

在公司项目用了快半年的 MRC，有时还要切换到 ARC 做做其他事情，或者来一发 Swift 玩票儿，真是一种奇(dan)妙(teng)的体验。