---
title: Parallel Computation using MPS
date: 2019-02-28 01:50:50
tags:
- Metal
---

在照片质量评分组件 [PhotoAssessment](https://github.com/yulingtianxia/PhotoAssessment) 项目上，有些算法的实现是使用 CPU 运行的。通过使用 MPS(Metal Performance Shader) 在 GPU 上并行计算，显著提升了性能，算法执行耗时降低了 99.9% 以上。震惊，呵呵。随着性能上成百上千倍的提升，可以在相等时间内处理更大尺寸的图片，进而提升组件的准确度和用户体验。

至此，几乎所有图像处理与计算任务都交由 GPU 完成。之前利用 Sobel 算子边缘检测是使用了苹果封装好的 MPS 类，剩余的色彩分布指纹向量和饱和度均值当然都是需要自己写 Shader 的，现在终于补齐了。Metal Shading Language 与 GLSL 使用习惯和理念很相似，只不过 Metal Shader 的语法是基于 C++ 14 的。

关于整个组件的实现思路，可以查阅[『使用 Metal 和 Core ML 评价照片质量』](http://yulingtianxia.com/blog/2018/11/30/Photo-Assessment/)。本篇文章所涉及到的 [Shader 代码](https://github.com/yulingtianxia/PhotoAssessment/blob/master/PhotoAssessment-Sample/Sources/PhotoAssessmentShaders.metal) 也在其中。

<!--more-->

工程升级到 Swift 5 结果 CI 不支持，编不过哎。

## 性能对比

对一张 4032x3024 彩色图片在 iPhone 8 Plus 上进行测试的 Benchmark 如下（单位：秒）：

计算平均饱和度：（耗时降低 99.90%）
CPU meanSaturation cost: 27.276064038276672
GPU meanSaturation cost: 0.02604210376739502

计算指纹向量算法：（耗时降低 99.28%）
CPU fingerprint cost: 8.9078871011734
GPU fingerprint cost: 0.06412196159362793

优化后的耗时降低幅度也跟图片本身有关，色彩分布更广的图片优化效果会更好。图片尺寸越大，优化效果越好。

再来看看 500x500 尺寸下的数据：

500x500 降采样到 50x50（包含降采样耗时）
cpu total cost: 0.3883340358734131
gpu total cost: 0.0030889511108398438

直接处理 500x500 尺寸图片
gpu total cost: 0.008553862571716

可以看出，降采样有一定耗时。即便是降采样到 50x50 这种很小的尺寸，在 CPU 上运行算法也会有较多的耗时。**相比之下，直接 GPU 处理 500x500 尺寸图片具有更大的优势：耗时远小于降采样后跑 CPU，略高于降采样后跑 GPU，但能够处理更大尺寸更多信息，相当于有更高的准确率。**

实现这两个功能的 Shader kernel 函数分别封装成 Swift 类： [`MPSSaturationKernel`](https://github.com/yulingtianxia/PhotoAssessment/blob/master/PhotoAssessment-Sample/Sources/MPSSaturationKernel.swift) 和 [`MSPFingerprintImageKernel`](https://github.com/yulingtianxia/PhotoAssessment/blob/master/PhotoAssessment-Sample/Sources/MSPFingerprintImageKernel.swift)。

## Shader 的实现

Command Encoder 会使用 Texture、Buffer、Sampler、Pipeline 等内容构建出 Command，并装载到 Command Buffer 上。

![from Apple Doc](https://raw.githubusercontent.com/yulingtianxia/Blog-Hexo-Source/master/source/resources/MPS/command structure0.png)

从 CPU 各个线程创建的 Command Buffer 都将会传入 Command Queue。运行在 GPU 上的 Shader 代码会处理这些 Command。

![from Apple Doc](https://raw.githubusercontent.com/yulingtianxia/Blog-Hexo-Source/master/source/resources/MPS/command structure1.png)

Command Encoder 有三种：Render、Compute 和 Blit。区别在于用途和用法，但创建的 Command 都可以放入同一个 Command Buffer 中。

![from Apple Doc](https://raw.githubusercontent.com/yulingtianxia/Blog-Hexo-Source/master/source/resources/MPS/Cmd-Model-threads.png)

为了在 GPU 上并行计算图片的饱和度和指纹向量，需要用到 Compute Command Encoder，并传入以下几个参数构建 Command：

1. Texture：输入或输出用到的图像纹理
2. Buffer：可作为额外的入参或结果，可设定 CPU 和 GPU 间共享
3. Compute Pipeline State：用于配置 Shader 函数名，也可用于计算 threadgroup 相关信息。

### Threadgroup

GPU 并行计算时，每条线程处理一个像素。整个 Texture 看做一个 Grid，可以进一步划分成多个 threadgroup。

![from Apple Doc](https://raw.githubusercontent.com/yulingtianxia/Blog-Hexo-Source/master/source/resources/MPS/threadgroups.png)

threadgroup 还会按照 GPU 能同时执行的线程数 `threadExecutionWidth` 被划分为 SIMD group。

![from Apple Doc](https://raw.githubusercontent.com/yulingtianxia/Blog-Hexo-Source/master/source/resources/MPS/SIMD group.png)

为了达到更好的性能，需要将 threadgroup 包含的线程数量设定为 `threadExecutionWidth` 的整数倍。

```
let w = computePipelineState.threadExecutionWidth;
let h = computePipelineState.maxTotalThreadsPerThreadgroup / w;
threadGroupSize = MTLSize(width: w, height: h, depth: 1);
```

在编写 Shader 时，可以通过参数获取到当前处理的像素所处的相对位置。在 C++ 14 中是使用属性的方式来标记参数用途。比如 `thread_position_in_grid` 指的是当前线程处理的像素在 Grid 中的位置。类似的属性很多，比如 `threadgroup_position_in_grid`, `thread_position_in_threadgroup`,
`threads_per_threadgroup`, `simdgroup_index_in_threadgroup`, `thread_index_in_simdgroup` ...

```
kernel void
rgb2hsvKernelNonuniform(texture2d<float, access::read> inTexture [[texture(0)]],
              texture2d<float, access::write> outTexture [[texture(1)]],
              uint2 gid [[thread_position_in_grid]])
{
    float4 pixel = inTexture.read(gid);
    // 省略部分代码
}
```

比如传入的 `gid` 为 (9, 10)，那么就可以从 `inTexture` 中读取到此位置像素的数据。因为 Grid 坐标系是基于这个 Texture 的。

![from Apple Doc](https://raw.githubusercontent.com/yulingtianxia/Blog-Hexo-Source/master/source/resources/MPS/grid coordinates.png)

### Non-uniform Threadgroup Size

Command Encoder 需要知道要处理的 Grid 的分组情况，比如Grid 包含多少 threadgroup，每个 threadgroup 包含多少 thread。

```
let w = threadGroupSize.width;
let h = threadGroupSize.height;
let threadgroupsPerGrid = MTLSize(width: (sourceTexture.width + w - 1) / w, height: (sourceTexture.height + h - 1) / h, depth: 1);
encoder?.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadGroupSize)
```

确定好这些信息后，GPU 就会开始按分组矩阵批量处理像素。但是因为 Grid 的尺寸是 Texture 的尺寸，长和宽不一定都能整除 threadgroup，所以处理到图片边缘的 threadgroup 时，会有一部分调用传入的 `gid` 超出了范围。此时要在 Shader 中做边界保护逻辑：

```
kernel void
rgb2hsvKernel(texture2d<float, access::read> inTexture [[texture(0)]],
              texture2d<float, access::write> outTexture [[texture(1)]],
              uint2 gid [[thread_position_in_grid]])
{
    if((gid.x >= outTexture.get_width()) || (gid.y >= outTexture.get_height()))
    {
        return;
    }
    
    rgb2hsv(inTexture, outTexture, gid);
}
```

也就是超范围的调用都被 `return` 掉了，GPU 的一些线程没利用上，造成了浪费:

![from Apple Doc](https://raw.githubusercontent.com/yulingtianxia/Blog-Hexo-Source/master/source/resources/MPS/underutilization of threads.png)

为了提升性能，Metal 在部分 GPU 特性集上支持了 "Non-uniform Threadgroup Size"。可以允许存在不同 size 的 threadgroup：

![from Apple Doc](https://raw.githubusercontent.com/yulingtianxia/Blog-Hexo-Source/master/source/resources/MPS/nonuniform threadgroups.png)

这样只需要传入 Grid 的 size，以及 threadgroup 的 size，Metal 就会自动划分边缘部分的 threadgroup size，充分利用好 GPU 的运算效率。

```
let threadsPerGrid = MTLSize(width: sourceTexture.width, height: sourceTexture.height, depth: 1);
encoder?.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadGroupSize)
```

这样一来 Shader 部分的代码就不需要加边界判断了：

```
kernel void
rgb2hsvKernelNonuniform(texture2d<float, access::read> inTexture [[texture(0)]],
              texture2d<float, access::write> outTexture [[texture(1)]],
              uint2 gid [[thread_position_in_grid]])
{
    rgb2hsv(inTexture, outTexture, gid);
}
```

不过并不是所有系统和设备都支持这项特性。目前支持 Non-uniform Threadgroup Size 的 GPU Feature Set 如下：

- iOS11 GPUFamily4_v1
- iOS12 GPUFamily4_v2
- iOS12 GPUFamily5_v1
- macOS13 GPUFamily1_v3
- macOS14 GPUFamily1_v4
- macOS14 GPUFamily2_v1

所以目前我的策略是先判断是否支持 Non-uniform Threadgroup Size，然后决定使用的 Shader 函数版本、以及 Encoder 分发线程的方式。

### 原子操作生成 Histogram

在计算指纹向量的时，并行将每个像素的内容处理完后，还需要统计成柱状图。比如处理完的像素种类一共有 `HistogramBufferSize` 种，需要统计每种类型的像素数量，可以声明一个 Buffer，包含长度为 `HistogramBufferSize` 的数组 `bucket`，将其传入 Shader 函数用于统计。

下面是用 Shader 实现的指纹向量生成代码，MPS 实现了部分 C++ 原子操作的接口，`atomic_fetch_add_explicit` 用于原子累加操作。

```
typedef struct
{
    atomic_int bucket[HistogramBufferSize];
} PAHistogramBuffer;

void fingerprint(texture2d<uint, access::read> inTexture [[texture(0)]],
                 device PAHistogramBuffer &buffer [[buffer(0)]],
                 uint2 gid [[thread_position_in_grid]])
{
    uint4 c = inTexture.read(gid);
    uint width = inTexture.get_width();
    uint height = inTexture.get_height();
    uint blockCount = 2;
    uint rowCount = min(blockCount, height);
    uint countPerRow = min(blockCount, width);
    uint hStep = width / countPerRow;
    uint vStep = height / rowCount;
    uint row = gid.y / vStep;
    uint col = gid.x / hStep;
    
    // |-3bit-|-3bit-|-3bit-|-2bit-|
    uint result = (row * countPerRow + col) + ((c.y >> 5) << 2) + ((c.z >> 5) << 5) + ((c.w >> 5) << 8);
    atomic_fetch_add_explicit(&buffer.bucket[result], 1, memory_order_relaxed);
}
```

MPS 支持的原子操作值类型很有限，无法选择占用内存更低的类型，只好忍受 `atomic_int` 带来的 4 Byte 吧。只要控制好 `HistogramBufferSize`，问题应该不大。

### 踩坑

MPS 中获取向量内容的方式可谓是方便，但是也是有坑在里面的。比如要注意无论是 `xyzw` 还是 `rgba` 分量获取的内容都是从低地址到高地址排列的。比如传入的像素格式是 RGBA，那么 `rgba` 获取的值正好是反过来的。

```
RGBA
wzyx  // x低 w 高
abgr  // r低 a 高
```

同样向 Texture 写数据的时候也要注意构造向量的时候，从左往右也是从低到高。

```
// 0x04030201
outTexture.write(1, 2, 3, 4), gid); 
```

## Reference

- https://developer.apple.com/metal/Metal-Shading-Language-Specification.pdf
- https://developer.apple.com/metal/Metal-Feature-Set-Tables.pdf
- https://stackoverflow.com/questions/47738441/passing-textures-with-uint8-component-type-to-metal-compute-shader
- https://stackoverflow.com/questions/15095909/from-rgb-to-hsv-in-opengl-glsl