---
title: 使用 Metal 和 Core ML 评价照片质量
date: 2018-11-30 22:53:14
tags:
- Machine Leaning
- Metal
---

如何评价一张照片的质量呢？

用算法可以客观地评价照片质量，也可以人为主观地给照片打分，并运用机器学习来训练模型。

我用 Swift 写了个 [Demo](https://github.com/yulingtianxia/PhotoAssessment)。用苹果的 Metal 跑一些算法得出客观评分，再用 Core ML 预测主观评分。得到照片评分后，就可以检测相似照片，并从中挑选最优的照片推荐给用户。

[Demo](https://github.com/yulingtianxia/PhotoAssessment) 中展示了图片在 NIMA 模型预测结合人脸识别的主观评分、图片的 HSB 色彩空间、以及边缘检测结果的平均值和方差。代码兼容 iOS 和 macOS。下面示例图片拍摄自胡里山炮王和西塘。

![](http://yulingtianxia.com/resources/PhotoAssessment/AssessmentResult1.png)![](http://yulingtianxia.com/resources/PhotoAssessment/AssessmentResult2.png)

<!--more-->

## 常规算法

目前业界有很多衡量照片质量的维度，可以通过调整各个维度占的权重来计算照片的最终得分。常用的衡量维度都是一些图形学上的客观因素：

- 饱和度（HSB/HSV 色彩空间中的 S）
- 亮度（HSB/HSV 色彩空间中的 B/V）
- 模糊度（边缘检测、二维离散傅里叶）
- 颜色分布（线性直方图分布）

得出的结果可能还需要设定阈值来过滤掉一些质量比较差的照片，然后做归一化和调整加权系数，最终得到照片的评分。具体权重值没有统一的参考标准，需根据业务的需求不断调试和摸索。以上列的这些标准都可以找到一些通用的算法实现，甚至用 OpenCV 分分钟的事儿。但是对于移动客户端来说，OpenCV 可能并不是个好的选择。苹果的 `Metal` 技术更适合发挥其软硬件结合的优势，在性能和安装包上均有优势。

iOS 无法直接创建 HSB 色彩空间，需要借助 `UIColor` 等 API 将其他色彩空间颜色转换成 HSB 对应的值。于是我尝试使用 `Metal` 实现边缘检测算法，相关代码可以在 [PhotoMPSProcessor.swift](https://github.com/yulingtianxia/PhotoAssessment/blob/master/PhotoAssessment-Sample/Sources/PhotoMPSProcessor.swift) 上找到。

边缘检测有很多种实现，这里我使用的是 Sobel 算子。MPS 提供了很多 对图片做卷积运算的 Filter，其中就包含 `MPSImageSobel`。MPS 也提供了 `MPSImageLaplacian`，不过 Laplacian 算子对噪声处理较差，实际效果不好。各种算子的原理和介绍可以参考这篇简介：[数字图像 - 边缘检测原理 - Sobel, Laplace, Canny算子](https://www.jianshu.com/p/2334bee37de5)

苹果的 `MetalKit` 拥有更简洁的 API，可以更方便地应用 `Metal` 技术。比如加载图片可以通过 `MTKTextureLoader` 几行代码轻松搞定。然而在实际应用中却发现是个大坑，比如 rgba16 格式的图片就会报错："Image decoding failed"。`MTKTextureLoader` 应该是只能加载单通道 8 bit 的图片数据，毕竟外部没有传每个像素字节数，解析时估计写死了这个值。所以还是老老实实的用 `MTLTextureDescriptor` 描述好 Filter 的数据输入输出格式，并创建好对应的 `MTLTexture` 吧。

Sobel 算子卷积运算后的方差值可以用来检测模糊程度。下面的代码用了两个 Filter 串联起来，三种格式的数据：rgba8[w*h]->r8[w*h]->r8[2*1]。也就是 RGBA 色彩空间图片转成含有边缘信息的灰度图（如下所示），最后出计算均值和方差。

![PhotoAssessment](http://yulingtianxia.com/resources/PhotoAssessment/SobelImageFilter.png)

```
@objc public func edgeDetect(imagePixels: [Int32], width: Int, height: Int, _ block: @escaping (_ mean: Int8, _ variance: Int8) -> Void) -> Void {
    
    // Make sure the current device supports MetalPerformanceShaders.
    guard MPSSupportsMTLDevice(device) else {
        print("Metal Performance Shaders not Supported on current Device")
        block(0, 0)
        return
    }
    
    var pixels = imagePixels
    
    // TextureDescriptors
    let sobelSrcTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Snorm, width: width, height: height, mipmapped: false)
    sobelSrcTextureDescriptor.usage = [.shaderWrite, .shaderRead]
    
    let sobelDesTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Snorm, width: width, height: height, mipmapped: false)
    sobelDesTextureDescriptor.usage = [.shaderWrite, .shaderRead]
    
    let varianceTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r8Snorm, width: 2, height: 1, mipmapped: false)
    varianceTextureDescriptor.usage = [.shaderWrite, .shaderRead]
    
    // Textures
    guard let sobelSrcTexture: MTLTexture = device?.makeTexture(descriptor: sobelSrcTextureDescriptor) else {
        print("make sobelSrcTexture failed")
        block(0, 0)
        return
    }
    
    guard let sobelDesTexture: MTLTexture = device?.makeTexture(descriptor: sobelDesTextureDescriptor) else {
        print("make sobelDesTexture failed")
        block(0, 0)
        return
    }
    
    guard let varianceTexture: MTLTexture = device?.makeTexture(descriptor: varianceTextureDescriptor) else {
        print("make varianceTexture failed")
        block(0, 0)
        return
    }
    
    // Fill sobelSrcTexture with pixels
    let sobelRegion = MTLRegionMake2D(0, 0, width, height)
    sobelSrcTexture.replace(region: sobelRegion, mipmapLevel: 0, withBytes: &pixels, bytesPerRow: 4 * width)
    
    // Run Image Filters
    if let commandBuffer = commandQueue?.makeCommandBuffer() {
        sobel?.encode(commandBuffer: commandBuffer, sourceTexture: sobelSrcTexture, destinationTexture: sobelDesTexture)
        meanAndVariance?.encode(commandBuffer: commandBuffer, sourceTexture: sobelDesTexture, destinationTexture: varianceTexture)
        commandBuffer.addCompletedHandler { (buffer) in
            
            var result = [Int8](repeatElement(0, count: 2))
            let region = MTLRegionMake2D(0, 0, 2, 1)
            
            varianceTexture.getBytes(&result, bytesPerRow: 1 * 2, from: region, mipmapLevel: 0)
            block(result.first!, result.last!)
            
//                let grayImage = self.imageOf(grayTexture: sobelDesTexture)
        }
        commandBuffer.commit()
    }
    else {
        print("make CommandBuffer failed")
        block(0, 0)
    }
}
```

常规做法都是利用客观评价指标来打分，可以通过设定阈值来过滤掉不符合要求的照片，但没能像大脑一样通过读懂图片的内容来评判质量。

## 机器学习

Google AI Blog 在 2017 年底发表过一篇博客：[Introducing NIMA: Neural Image Assessment](https://ai.googleblog.com/2017/12/introducing-nima-neural-image-assessment.html)。讲述了通过神经网络迁移学习来预测图片评分方法。损失函数为 EMD (earth mover's distance)，分数分布范围是 1-10 分。先用一些已有的模型在 ImageNet 上预训练，再加个 10 节点的全连接层使用 AVA 等数据集 fune-tune。预测结果是 10 个分数的分布，而不是直接给出评分，所以可以进一步计算出期望分和方差等。

虽然论文没有给出源码或者训练好的模型，但是网上可以搜到一些第三方的实现。最后使用苹果提供的 coremltools 将其他机器学习框架的模型转成苹果的 Core ML 模型。

在网上搜索到了几个还算不错的开源实现：

- [idealo/image-quality-assessment](https://github.com/idealo/image-quality-assessment)：使用 Keras + Docker + AWS 实现，MobileNet 的完成度较高，提供了 aesthetic 和 technical 两种训练好的评分模型。Keras 模型可以直接转成 mlmodel。
- [titu1994/neural-image-assessment](https://github.com/titu1994/neural-image-assessment)：使用 Keras 实现，提供了训练好的几种模型。效果最好的为 NASNet Mobile，loss = 0.067。Keras 模型可以直接转成 mlmodel。
- [truskovskiyk/nima.pytorch](https://github.com/truskovskiyk/nima.pytorch)：使用 pytorch 实现，完成度一般，只提供了 MobileNetV2 模型（loss = 0.08）。pytorch  模型需要先转为 ONNX，然后再转成 mlmodel 格式。

经过反复试验与对比结果，最终使用了第一个开源实现的 MobileNet。在这个过程中踩了不少坑：

1. 机器学习涉及到的 python 库更新幅度较大，甚至连官方文档更新都严重滞后，更别提网上找的 demo 了。想跑通网上找的代码？不存在的。
2. 既然官方文档不可信，只能看代码中的注释，在摸索中写。依然会有各种各样的报错，大部分都是版本兼容问题。虽然 coremltools 官网有说兼容的最低版本，但也千万不要直接用最高版本的 Keras 和 TensorFlow。我用的 Keras 2.1.3 和 TensorFlow 1.10，亲测 OK。
3. pytorch 转 ONNX 再转 mlmodel 更是麻烦，不得不吐槽机器学习相关的 python 库版本兼容性是真的差，API 说改就改，以为自己是 Swift 么？对于新手来说很不友好，过程几乎就是：改->报错->Google->改->继续报错。。。官网 demo 从来没跑通过，跟没有一样，不存在的。

转换模型和权重使用的 python 代码放在这里：[nima.py](https://github.com/yulingtianxia/PhotoAssessment/blob/master/ConvertMLModel/NIMA/nima.py)

最后转化的 mlmodel 包含在 PhotoAssessment-Sample 工程中：[MobileNet.mlmodel](https://github.com/yulingtianxia/PhotoAssessment/blob/master/PhotoAssessment-Sample/Sources/MobileNet.mlmodel)

在得到 mlmodel 后，可以使用苹果的 Vision 框架加载模型，用 `VNImageRequestHandler` 请求处理静态图片。串联上 Vision 框架的 `VNDetectFaceRectanglesRequest` 可以顺便检测出人脸，为照片评分提供更多的参考。比如有人脸的照片可能是个加分项。

PS: 这里原本还加入了神经网络识别面部表情，但是由于准确率不高且不同表情的评分难以主观衡量，所以最后去掉了。

这部分的代码实现在这里： [PhotoMLProcessor.swift](https://github.com/yulingtianxia/PhotoAssessment/blob/master/PhotoAssessment-Sample/Sources/PhotoMLProcessor.swift)

## 照片相似度

我 2016 年曾经写过一篇文章：[如何自制一款寻找相似图片的 Mac 工具](http://yulingtianxia.com/blog/2016/01/17/search-for-similar-images/)，原理是通过 RGBA 色彩空间和像素相对位置构造出一个特征向量，然后计算特征向量之间的余弦相似度作为照片的相似度。这种做法在处理移动客户端照片时可以进一步优化：

1. 手机拍照可以去掉 alpha 通道
2. 需要对照片降采样，降低计算量
3. 手机拍照的尺寸相同，宽高比因素可以去掉
4. 手机拍照具有时序性，只计算比较时间相邻的照片的相似度

计算特征向量的实现如下：

```
@objc public class func fingerprintFor(imagePixels: [Int32], width: Int, height: Int) -> [UInt32: Double] {
    
    func downsample(component: UInt8) -> UInt32 {
        return UInt32(component / 16)
    }
    
    func downsample(x: Int, y: Int) -> UInt32 {
        let rowCount: Int = min(4, height)
        let countPerRow: Int = min(4, width)
        let hStep = width / countPerRow
        let vStep = height / rowCount
        let row = y / vStep
        let col = x / hStep
        return UInt32(row * countPerRow + col);
    }
    
    var bucket = [UInt32: UInt]()
    
    for j in 0 ..< height {
        for i in 0 ..< width {
            let color = imagePixels[width * j + i]
            let r = downsample(component: color.r()) << 24
            let g = downsample(component: color.g()) << 16
            let b = downsample(component: color.b()) << 8
            let location = downsample(x: i, y: j) << 12
            let fingerprint = r | g | b | location
            bucket[fingerprint] = (bucket[fingerprint] ?? 0) + 1
        }
    }
    let result: [UInt32: Double] = bucket.mapValues { (oldValue) -> Double in
        let newValue = Double(oldValue) / Double(imagePixels.count)
        return newValue
    }
    return result
}
```

因为输入都是像素数组，降采样使用 `MPSImageBilinearScale`，实现细节类似于上面讲的边缘检测。代码在 [PhotoMPSProcessor.swift](https://github.com/yulingtianxia/PhotoAssessment/blob/master/PhotoAssessment-Sample/Sources/PhotoMPSProcessor.swift) 里。

## 总结

算法可以通过调整阈值来平衡准确度与性能。比如降采样的尺寸和相似度阈值都是可以影响到最终结果和性能开销的。这里不再展开讨论。使用 Vision + Core ML 预测图片和人脸识别依然耗时较久，处理 500 张图片可能要几十秒，在生产环境下批量处理图片时需要注意。

## Reference

- [yulingtianxia/PhotoAssessment](https://github.com/yulingtianxia/PhotoAssessment)
- [数字图像 - 边缘检测原理 - Sobel, Laplace, Canny算子](https://www.jianshu.com/p/2334bee37de5)
- [idealo/image-quality-assessment](https://github.com/idealo/image-quality-assessment)
- [titu1994/neural-image-assessment](https://github.com/titu1994/neural-image-assessment)
- [truskovskiyk/nima.pytorch](https://github.com/truskovskiyk/nima.pytorch)
- [NIMA: Neural Image Assessment](https://arxiv.org/abs/1709.05424)
- [Introducing NIMA: Neural Image Assessment](https://ai.googleblog.com/2017/12/introducing-nima-neural-image-assessment.html)
- [Core ML](https://developer.apple.com/documentation/coreml)
- [apple/coremltools](https://github.com/apple/coremltools)
- [MTKTextureLoader fails for 16-big images](https://forums.developer.apple.com/thread/97218)