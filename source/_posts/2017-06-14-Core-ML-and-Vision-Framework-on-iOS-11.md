---
title: Core ML and Vision Framework on iOS 11
date: 2017-06-14 15:15:41
tags:
- iOS
---

机器学习和计算机视觉在 iOS 上虽然早已有了系统级的支持，但 WWDC 17 发布的 iOS 11 将它们的使用门槛大大降低。苹果提供了设计合理且容易上手的 API，让那些对基础理论知识一窍不通的门外汉也能玩转高大上的前沿科技，这是苹果一贯的风格。

<!--more-->

这是一篇 WWDC 2017 Session 506，703 和 710 的学习笔记，以及分享自己尝试写的 Demo [Core-ML-Sample](https://github.com/yulingtianxia/Core-ML-Sample)。

## Core ML

Core ML 大大降低了开发者在苹果设备上使用机器学习技术预测模型的门槛和成本。苹果制定了自己的模型文件格式，统一的格式和全新的 API 设计使得 Core ML 支持苹果生态下多个平台。

![](http://7ni3rk.com1.z0.glb.clouddn.com/iOS11/coreml1.png)

数据经过预处理后输入 MLMODEL 文件，输出模型的预测结果。使用 Core ML 只需要很少的代码就可以完成，只需关注代码即可，无需关注模型的定义，网络的构成。这跟以前写 MPS 代码时构成了强烈的反差：开发者需要写大量 MPS 代码用于构建和描述一个完整的网络，而加载的文件仅仅是模型的权重而已。MLMODEL 文件包含了权重和模型结构等信息，并可以自动生成相关的代码，节省开发者大量时间。

![](http://7ni3rk.com1.z0.glb.clouddn.com/iOS11/coreml2.png)

苹果提供了一个 Python 工具，可以将业内一些常用的机器学习框架导出的 Model 转成 MLMODEL 文件。代码会编译成可执行二进制文件，而 MLMODEL 会编译成 Bundle 文件，在代码文件中可以直接调用 MLMODEL 生成的类，这些都是需要 Xcode 9 做支撑，也就是说，现阶段并不支持动态下发 MLMODEL 文件。Core ML 的预测过程全都在客户端进行，保证用户隐私不会泄露。

![](http://7ni3rk.com1.z0.glb.clouddn.com/iOS11/coreml4.png)

Core ML 支持 DNN,RNN,CNN,SVM,Tree ensembles,Generalized linear models,Pipeline models 等，对应的模型转换工具 [Core ML Tools](https://pypi.python.org/pypi/coremltools) 也支持了一些常用机器学习框架模型的转换。虽然目前没有直接支持 Google 的 TensorFlow，但可以使用 Keras 曲线救国。

![](http://7ni3rk.com1.z0.glb.clouddn.com/iOS11/coreml3.png)

![](http://7ni3rk.com1.z0.glb.clouddn.com/iOS11/coreml5.png)

![](http://7ni3rk.com1.z0.glb.clouddn.com/iOS11/coreml6.png)

## Vision

### 应用场景

1. 人脸检测：支持检测笑脸、侧脸、局部遮挡脸部、戴眼镜和帽子等场景，可以标记出人脸的矩形区域
2. 人脸特征点：可以标记出人脸和眼睛、眉毛、鼻子、嘴、牙齿的轮廓，以及人脸的中轴线
3. 图像配准
4. 矩形检测
5. 二维码/条形码检测
6. 文字检测
7. 目标跟踪：脸部，矩形和通用模板

### Vision 使用姿势

将各种功能的 Request 提供给一个 RequestHandler，Handler 持有图片信息，并将处理结果分发给每个 Request 的 completion Block 中。可以从 results 属性中得到 Observation 数组，然后进行更新 UI 等操作。因为 completion Block 所执行的队列跟 perform request 的队列相同，所以更新 UI 时记得使用主队列。

Vision 操作流水线分为两类：分析图片和跟踪队列。可以使用图片检测出的物体或矩形结果（Observation）来作为跟踪队列请求（Request）的参数。

![](http://7ni3rk.com1.z0.glb.clouddn.com/iOS11/506_vision_framework_building_on_core_ml_%E9%A1%B5%E9%9D%A2_36.png)

![](http://7ni3rk.com1.z0.glb.clouddn.com/iOS11/506_vision_framework_building_on_core_ml_%E9%A1%B5%E9%9D%A2_40.png)

Vision 支持的图片数据类型：

- CVPixelBufferRef
- CGImageRef
- CIImage
- NSURL
- NSData

这几乎涵盖了 iOS 中图片相关的 API，很实用很强大。

Vision 有三种 resize 图片的方式，无需使用者再次裁切缩放

- VNImageCropAndScaleOptionCenterCrop
- VNImageCropAndScaleOptionScaleFit
- VNImageCropAndScaleOptionScaleFill

Vision 与 iOS 上其他几种带人脸检测功能框架的对比：

![](http://7ni3rk.com1.z0.glb.clouddn.com/iOS11/506_vision_framework_building_on_core_ml_%E9%A1%B5%E9%9D%A2_72.png)

### 与 Core ML 集成

Core ML 具有更好的性能，Vision 可为其提供图片处理的流程。



### 总结

- Vision 是一个关于计算机视觉的顶层新框架。
- 一个界面，多重跟踪检测
- 集成 Core ML 轻松使用自己的 model



