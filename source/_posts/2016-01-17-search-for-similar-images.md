title: 如何自制一款寻找相似图片的 Mac 工具
date: 2016-01-17 15:13:18
tags:

- Algorithm
- macOS

---

这周花了一天半的时间做了个 Mac OS X 上的小工具，用来查找相似内容的图片。起因是公司的 iOS 项目中已有的图片管理混乱，有些图片文件名不规范，还有一些内容重复但文件名不同的图片。现在视觉要给出一些 3x 分辨率的图片，如何与已有的低分辨率图片匹配，这又是个问题。人工一个个去找固然好，但这种技术含量低的体力活很浪费精力和时间。

Github 地址：https://github.com/yulingtianxia/SimilarImageHunter

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20160117-2.png)

<!--more-->

最新 Release 下载：https://github.com/yulingtianxia/SimilarImageHunter/releases

我开发的这款工具可以在目标路径中找出与原始路径中图片最为相似的图片。如果目标路径中有多张图片相似度相同且最大，这些图片都会被列出来。树形列表第一列的父节点内容为原始路径中的图片，子节点为目标路径中匹配到的最佳相似内容图片。列表第二列为相似度。双击图片路径即可打开该图片。点击 “HUNT” 按钮开始寻找相似图片，第一次使用时处理图片信息耗时较长，可在中途点击 “CANCEL” 按钮取消当前任务。“CLEAR” 按钮则可清除当前界面信息。

## 获取图片路径
因为会一点 shell，所以第一反应是一行脚本：

```
find $1 -name '*.jpg' -or -name '*.png'
```

接下来用 `NSTask` 跑脚本太 esay 就不细说了。

## 算法实现

### AspectRatio

因为不用考虑一张图片包含另一张图片等复杂情况，此处的场景是寻找内容相同分辨率不同的图片，所以比较图片的宽高比自然是一个重要的环节。在相似度的计算上，我设定宽高比的相似度权重占到总体相似度的30%。（这个阈值以后可能还会调整）

### 像素 RGBA 信息

把不同格式的图片解压成位图，就可以得到所有像素最原始的信息。我这里使用的色彩空间是 RGBA，每个像素用 32 bit 大端模式存储。然后统计每种颜色(RGBA)的像素数量，并计算其占像素总数的比例。比较两张图片相同颜色像素比例的差异就行了。

### 像素位置信息

光有颜色信息还是不够的，因为有一些图片可能宽高比相似，大体的色彩也差不多，但是相同颜色的像素排列却不一样。所以也需要考虑到每个像素所处图片中的位置。这个位置信息也是采用比例的方式来计算，而不是像素到原点的绝对距离。**把像素位置信息加入到比较颜色相似度的过程中，大大提升了准确度。**

### 构造指纹向量

在实际统计中会发现使用原始的 “RGBA+像素位置” 信息并不理想，因为这会使得统计结果更加分散。更致命的是在实验中我尝试调整了一张图片的尺寸后，其色彩空间也发生了很大变化。比如原图只有 100 种 RGBA 值，而处理后的图片则有 1000 种 RGBA 值！虽然肉眼上看起来两张图片内容一样，但实际上后者却有很多颜色相似的像素被分散开了，而在比较相同颜色的像素比例时，因为后者的像素数量被稀释成了多种相似的颜色，使得计算后的相似度大幅降低。

所以需要将相似颜色的像素归为一类，RGBA 四个通道共 32 bit，每个通道占 8 bit，数值范围是 0~127，我将其划分为 8 个区间，这样总共只有 8^4 个组合（要知道这在简化之前可是 2^32 个组合！）：

```
#define Mask8(x) ( (x) & 0xFF )
#define R(x) ( Mask8(x) )
#define G(x) ( Mask8(x >> 8 ) )
#define B(x) ( Mask8(x >> 16) )
#define A(x) ( Mask8(x >> 24) )

-(UInt32)fingerprintOfColor:(UInt32)color
{
    return [self areaOfComponent:R(color)]*1000+[self areaOfComponent:G(color)]*100+[self areaOfComponent:B(color)]*10+[self areaOfComponent:A(color)];
}

-(UInt32)areaOfComponent:(UInt32)component
{
    return component/8;
}
```

像素的位置信息也同样需要简化，我采用 9 宫格的方案：即将图片按比例划分成九宫格，并将每个方格从 1 到 9标记。这样就直接把像素的位置比例简化为两个数字（x 和 y），只有 9^2 个组合：

```
-(UInt32)areaOfX:(NSUInteger)x y:(NSUInteger)y width:(NSUInteger)width height:(NSUInteger)height
{
    UInt32 result = 0;
    if (x<=width/3) {
        result+=0;
    }
    else if (x<=2*width/3) {
        result+=3;
    }
    else {
        result+=6;
    }
    
    
    if (y<=height/3) {
        result+=1;
    }
    else if (y<=2*height/3) {
        result+=2;
    }
    else {
        result+=3;
    }
    
    return result;
}
```

最后将两者相结合，构造一个多维向量，`pixels` 为指向图片像素数组 RGBA 信息的 `UInt32` 类型指针：

```
NSMutableDictionary<NSNumber *,NSNumber *> *pixelBucket = [NSMutableDictionary dictionary];
UInt32 * currentPixel = pixels;
for (NSUInteger j = 0; j < height; j++) {
   for (NSUInteger i = 0; i < width; i++) {
       UInt32 color = *currentPixel;
       UInt32 fingerprint = [self fingerprintOfColor:color]*10+[self areaOfX:i y:j width:width height:height];
       
       pixelBucket[@(fingerprint)] = @(pixelBucket[@(fingerprint)].intValue+1);
       currentPixel++;
   }
}
    
free(pixels);
    
[pixelBucket enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSNumber * _Nonnull obj, BOOL * _Nonnull stop) {
   pixelBucket[key] = @(obj.doubleValue/(height * width));
}];
```

`pixelBucket` 最多有 8^4*9^2 个键值对，也就是指纹向量最大的维度。

### 计算向量相似性

这里我采用了向量的[余弦相似性](https://zh.wikipedia.org/wiki/余弦相似性)：计算结果越接近于 1，两张图片内容越相似：

```
__block double similarityOfPixelVector = 0;
__block double targetRank = 0;
__block double sourceRank = 0;
[sourcePixelVector enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSNumber * _Nonnull obj, BOOL * _Nonnull stop) {
   NSNumber *targetObj = targetPixelVector[key];
   if (targetObj) {
       similarityOfPixelVector += obj.doubleValue*targetObj.doubleValue;
   }
   sourceRank += obj.doubleValue * obj.doubleValue;
}];
    
sourceRank = sqrt(sourceRank);
    
[targetPixelVector enumerateKeysAndObjectsUsingBlock:^(NSNumber * _Nonnull key, NSNumber * _Nonnull obj, BOOL * _Nonnull stop) {
   targetRank += obj.doubleValue * obj.doubleValue;
}];

targetRank = sqrt(targetRank);
    
similarityOfPixelVector = similarityOfPixelVector/(sourceRank*targetRank);
```

采用余弦相似性的主要原因是我它的结果范围是 0~1，而且向量越相似结果越接近于 1，刚好满足我的计算要求。而欧氏距离和杰卡德相似性度量都不太满足我的计算方法上的要求。余弦相似性有个缺点就是只能比较向量的角度，而不能比较距离。也就是说，两个向量角度固定后，长度若有变化，向量末端的绝对距离（也就是欧氏距离）也会变，但余弦相似性不变。但这在本例中恰巧克服了这个缺点。因为图片指纹向量所有维度的值之和为 1，也就是说向量的方向固定后，长度也就固定了。如果你还不懂，看下面这张图。将问题简化到三维空间，所有三维向量起点都是原点，终点都在绿色平面上：

![](http://7ni3rk.com1.z0.glb.clouddn.com/QQ20160117-3.png)

最后的图片相似性结合了长宽比相似性与指纹向量相似性：

```
double similarityOfAspectRatio = 1-fabs(sourceAspectRatio-targetAspectRatio)/sourceAspectRatio;
result = similarityOfAspectRatio*weightOfAspectRatio + similarityOfPixelVector*(1-weightOfAspectRatio);
```

这里的 `similarityOfAspectRatio` 可能为负值，这并不是我一时疏忽，而是有意为之：我的初衷是想匹配视觉提供的不同分辨率的图片素材，如果连长宽比都差很多，那绝逼不是我要的结果。那为何我不直接加个判断，如果长宽比不一样，就直接判断不符合要求，直接 pass 呢？这里原因有二：

1. 我曾经发现过视觉切图的像素尺寸不精确，尤其是小图。甚至还发现过本应是正方形的图，长和宽竟然不相同。所以这里需要容错，计算长宽比的相似度，即便我想要的结果理论上应该相同，而不是相似。
2. 为了给出两张图片的相似度，需要有个全面的分析，光用长宽比得不出数据。这点又与初衷违背，牺牲了效率，只为了最后给出结果装个逼。

## UI 实现

我对 Cocoa 也不熟，自然会踩一些坑的。其中主要是为了展现树形列表而踩了 `NSOutlineView` 的坑：

1. `NSOutlineView` 的数据来源：[极简教程](http://stackoverflow.com/questions/6664898/nsoutlineview-example)
2. [NSTableView only displaying “Table View Cell”](http://stackoverflow.com/questions/7533682/nstableview-only-displaying-table-view-cell)

双击文件路径名自动打开图片，使用 `NSWorkspace` 即可。

注意用内存缓存上次计算的指纹向量，这样可以大大减少下次 UI 的更新时间。

毛玻璃效果、后台异步任务、Autolayout 之类的常识这些就不细说了。更多的细节还是看源码吧：[SimilarImageHunter](https://github.com/yulingtianxia/SimilarImageHunter)

至于之后的一键替换文件名等功能，虽然是刚需，但是还需等安全可靠的替换策略制定出之后才可以祭出。

我现在看太阳都是绿色的。