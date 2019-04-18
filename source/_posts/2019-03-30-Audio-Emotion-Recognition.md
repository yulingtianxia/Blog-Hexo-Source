---
title: 音频情绪识别
date: 2019-03-30 21:30:46
tags:
- Machine Leaning
---

如何识别声音所蕴含的情绪呢？在大部分场景下，人声的情绪更有意义。可以先将人声转文字，再通过 NLP 分析语义情绪。不过人类语言博大精深，一句『卧槽』的不同语调和语境下会有很多种意义，真的是卧槽啊！

于是我从音频特征提取入手，将人声分类识别为八种情绪，实现了两个方案并都得到了测试集 70% 以上的准确率：

1. 使用 VGGish 网络做特征提取，输入自定义网络进行训练。
2. 使用音频库导出一系列特征作为输入向量，自定义网络进行训练。

Python 工程和 iOS Sample 开源在 GitHub 上了：https://github.com/yulingtianxia/AudioEmotion

<!--more-->

## Dataset

在音频领域数据集上，Google 提供的 AudioSet 很有名，数据量大标签也多。但是跟人声和情感的关联并不大。这里使用了 RAVDESS 数据，音频数据包含了说话和唱歌两大类数据，找了 24 位演员录制出 "neutral calm happy sad angry fearful disgust surprised" 八种情感。

## Turicreate Sound Classifier

苹果推出的机器学习框架 Turicreate 降低了门槛，即便没有相关经验也可以轻松上手。训练后的模型参数可以导出为 Core ML 所使用的 mlmodel 文件，更方便集成到苹果的平台上。刚发布的 5.4 版本新增了 Sound Classifier，这可用于声音情绪识别任务上。

Turicreate 的 Sound Classifier 实现分三个阶段：

1. 音频预处理：使用 Hamming 窗口对语音进行分帧，对每一帧做短时傅里叶变换，然后利用信号幅值计算声谱图。将声谱映射到 64 阶 mel 滤波器组中计算 mel 声谱。最后通过控制时长，输出一个 (96, 64) 的矩阵。
2. VGGish 特征提取：Google 训练好的 CNN，它是基于 VGG 的变种，可用于将声音提取成 128 维特征。Google 的 AudioSet 号称是声音届的 ImageNet，它所提供的数据类型就包含从 VGGish 提取的特征。而 VGGish 模型是使用 YouTube-8M 训练出来的。
3. 使用自定义神经网络训练，最后一层的节点数与标签数一致。

这里还需要了解一个音频处理领域的一个概念：梅尔倒谱系数（Mel-scale Frequency Cepstral Coefficients，简称 MFCC）是在 Mel 标度频率域提取出来的倒谱参数，Mel标度描述了人耳频率的非线性特性。网上关于 MFCC 的资料很多，还有很多基于它的优化算法。第一步音频预处理也用到了。

其实数据预处理和特征提取的结果是可以复用的，在第一个版本发布后已经进行了优化： [Sound Classifier: Allow Reusing Deep Features](https://github.com/apple/turicreate/commit/e9b7ac6cad5a28894815aa4c5c9282163b97775b)

Turicreate 固然爽，但是还存在一些问题。接下来详细讲一下：

### 加载音频文件

Turicreate 的 `load_audio` 方法加载音频文件时，很多 wav 会报错: " Incomplete wav chunk"。导致训练样本大大减少。

看了下源码，是使用 `scipy` 的 `wavfile` 库读 wav 文件的，将其替换成 `librosa` 就 OK 了。

```
data, sample_rate = librosa.load(cur_file_path, sr=None, res_type='scipy')
data = data * 32768
# sample_rate, data = _wavfile.read(cur_file_path)
```

之所以还需要把 `data` 乘 32768 是为了将 (-1, 1) 的浮点数转为 16bit 整数表示。这样保证替换加载音频文件的接口后，结果数据不会有影响。

这段代码来自于 `audio_analysis.py`，我已经将修改后的版本提交了。

### 自定义神经网络

Turicreate 自定义的神经网络结构为两层 100 个节点使用 RELU 激活函数的全连接层，最后接一层 label 个数节点的 softmax。这样简单的结构在官方 Demo 的 "ESC-10" 数据分类任务上表现还 OK，但是在声音情感预测上效果并不是很好。

既然是基于 VGGish 做 fine-tune，那就直接改 Turicreate 源码吧，在 `sound_classifier.py` 文件里。主要是改神经网络定义和导出模型到 Core ML 的方法。

在原有的网络结构上，增加了全连接层数和 BN 层，并使用 Dropout 层减轻过拟合的情况。当然，网络结构可以不断调整来得到更加的效果。

```
def _build_custom_neural_network(num_inputs, num_labels):
    from mxnet.gluon import nn
    net = nn.Sequential(prefix='custom_')
    with net.name_scope():
        net.add(nn.Dense(512, in_units=num_inputs, activation='relu', prefix='dense0_'))
        net.add(nn.BatchNorm())
        net.add(nn.Dropout(0.5))
        net.add(nn.Dense(256, activation='relu', prefix='dense1_'))
        net.add(nn.BatchNorm())
        net.add(nn.Dropout(0.5))
        net.add(nn.Dense(128, activation='relu', prefix='dense2_'))
        net.add(nn.BatchNorm())
        net.add(nn.Dropout(0.5))
        net.add(nn.Dense(64, activation='relu', prefix='dense3_'))
        net.add(nn.BatchNorm())
        net.add(nn.Dropout(0.5))
        net.add(nn.Dense(num_labels, prefix='dense4_'))
    return net
```

由于增加了 BN 和 Dropout，所以在生成 Core ML 模型文件的时候，需要判断下层的类型。增加对 BN 层的支持，忽略 Dropout 层。这里构建 Core ML 所需网络描述的 `builder` 是 coremltools 的 `NeuralNetworkBuilder`。

```
input_name, output_name = input_name, 0
import mxnet as _mx
for i, cur_layer in enumerate(self._custom_classifier):
output_name = str(i)
if type(cur_layer) == _mx.gluon.nn.basic_layers.Dense:
    W = cur_layer.weight.data(ctx).asnumpy()
    nC, nB = W.shape
    Wb = cur_layer.bias.data(ctx).asnumpy()

    builder.add_inner_product(name='inner_product_'+str(i),
                              W=W,
                              b=Wb,
                              input_channels=nB,
                              output_channels=nC,
                              has_bias=True,
                              input_name=input_name,
                              output_name='inner_product_'+output_name)
    if cur_layer.act:
        builder.add_activation("activation"+str(i), 'RELU', 'inner_product_'+output_name, output_name)
elif type(cur_layer) == _mx.gluon.nn.basic_layers.BatchNorm:
    zeros = _np.zeros(nC)
    ones = _np.ones(nC)
    builder.add_batchnorm(name='bn_layer_'+str(i),
                          channels=nC,
                          gamma=ones,
                          beta=zeros,
                          mean=zeros,
                          variance=ones,
                          input_name=input_name,
                          output_name=output_name)
elif type(cur_layer) == _mx.gluon.nn.basic_layers.Dropout:
    continue
input_name = output_name

last_output = builder.spec.neuralNetworkClassifier.layers[-1].output[0]
builder.add_softmax('softmax', last_output, self.target)
```

### 部署到 Core ML

虽然生成了 mlmodel 模型文件，但是模型文件不包含第一步预处理的算法。需要依赖官方提供的 `libAudioPreprocessing.dylib`，只支持 64 位。 在使用 Core ML 预测之前，需要将 wav 文件按照输入格式切割，官方给了实例代码，但是有 bug。建议使用我提供的 iOS Sample。

## Put features to Keras

在这个方案中，先是提取出音频文件的一系列特征组成一个 26 维向量，再输入自定义神经网络中进行训练。这些音频特征包括：chromagram、RMS、spectral centroid、spectral bandwidth、spectral rolloff、zero-crossing rate、MFCC。

将音频特征提取后，与文件名和 label 一起保存在一个 csv 文件中。这部分代码实现在 `extract_audio_feature.py` 里。

然后使用 Keras 搭建一个比较简单的神经网络进行训练，这部分的逻辑与 Turicreate 中第三步类似，实现代码在 `train_audio.py` 里。

此方案参照了一个音乐分类的 Python Book 代码：[Music_genre_classification.ipynb](https://gist.github.com/parulnith/7f8c174e6ac099e86f0495d3d9a4c01e)

## Reference

[梅尔频率倒谱系数](https://zh.wikipedia.org/wiki/梅尔频率倒谱系数)

[AudioSet](https://research.google.com/audioset/download.html)

[Models for AudioSet: A Large Scale Dataset of Audio Events](https://github.com/tensorflow/models/tree/master/research/audioset)

[Sound Classifier](https://apple.github.io/turicreate/docs/userguide/sound_classifier/)

[The Ryerson Audio-Visual Database of Emotional Speech and Song (RAVDESS)](https://zenodo.org/record/1188976)

[Music Genre Classification with Python](https://towardsdatascience.com/music-genre-classification-with-python-c714d032f0d8)