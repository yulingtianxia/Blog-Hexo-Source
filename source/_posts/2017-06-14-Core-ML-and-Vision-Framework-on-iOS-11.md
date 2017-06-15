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

![](http://7ni3rk.com1.z0.glb.clouddn.com/iOS11/coreml1.png)

![](http://7ni3rk.com1.z0.glb.clouddn.com/iOS11/coreml2.png)

![](http://7ni3rk.com1.z0.glb.clouddn.com/iOS11/coreml4.png)

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


### 与 Core ML 集成

Core ML 具有更好的性能，Vision 可为其提供图片处理的流程。

### 总结

- Vision 是一个关于计算机视觉的顶层新框架。
- 一个界面，多重跟踪检测
- 集成 Core ML 轻松使用自己的 model



