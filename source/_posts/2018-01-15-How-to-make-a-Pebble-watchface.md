---
title: How to make a Pebble watchface
date: 2018-01-15 00:00:17
tags:

- 瞎折腾

---

之前的 leader 送了我一块 Pebble 智能手表，俗话说『穷玩车，富玩表』，希望自己能在 2018 年里『变有钱』，那就多玩玩表吧！

<!-- more -->

首先简单介绍下 pebble。这个系列的智能手表虽然没有触屏，甚至有的型号是黑白背光屏，但提供了四个硕大的按钮用于上滚、下滚，进入和退出操作。它的数据传输需要依赖于手机的蓝牙连接，相当于一块副屏。但能在手表上独立运行 app，不像 watchOS 1 那样必须依赖手机上的 host app。其优势是续航性和性价比。pebble 曾一度跟安卓和 iOS 系统有三分天下之势，国外很多 geek 都喜欢搞搞 pebble。它甚至提供了云端编程环境，开发者很容易上手，查文档也十分便捷。经历一些固件升级后，开发语言也从 C 语言拓展到了 JS。 发布 app 的流程也很简单，geek 们可以在上面搞些有趣的事情了。

你可以在 pebble 上安装各种 app，比如查看 evernote，玩一些小游戏。用户输入只有四个按钮，以及重力感应传感器、健康相关传感器等。功能上略差，但能续航一周。它也解决了大部分关于时间的刚需，比如定制表盘，接收通知，计时器等。

出于对 pebble 的好奇以及感叹时间从自己身边流逝，时刻提醒自己把握当下珍惜每一秒，我做了一个简单有趣的 watchface。

![](https://github.com/yulingtianxia/Pebble-MoHa/blob/master/watchface.gif?raw=true)

戴着黑框眼镜的程序员哥哥在手表中仿佛看到了自己，并时刻提醒着我们珍惜每一秒的光阴。pebble 以超长续航能力著称，于是我索性将电池电量一直显示满格，满足一切强迫症患者！同样以『超长待机』著称的英国女王伊丽莎白二世出生于 1926 年，有了来自女王的 buff 加持，你的 pebble 将会更持久更耐用！

为了展现上面 GIF 的效果，我设置了个定时器每秒回调下面的函数：

```
static void update_time() {
// 获取当地时间戳
  time_t temp = time(NULL);
  struct tm *tick_time = localtime(&temp);
// 时间戳转字符串：时，分，显示到 label 上
  static char s_hour_buffer[4];
  strftime(s_hour_buffer, sizeof(s_hour_buffer), clock_is_24h_style() ?
                                          "%H" : "%I", tick_time);
  text_layer_set_text(s_left_time_layer, s_hour_buffer);
  static char s_minute_buffer[4];
  strftime(s_minute_buffer, sizeof(s_minute_buffer), "%M", tick_time);
  text_layer_set_text(s_right_time_layer, s_minute_buffer);
// 每隔一秒切换下显示状态
  if (tick_time->tm_sec % 2 == 0) {
    layer_set_hidden((Layer *)s_eye_layer, true);
    layer_set_hidden((Layer *)s_left_time_layer, false);
    layer_set_hidden((Layer *)s_right_time_layer, false);
    bitmap_layer_set_bitmap(s_nose_layer, s_nose_empty_bitmap);
  } else {
    layer_set_hidden((Layer *)s_eye_layer, false);
    layer_set_hidden((Layer *)s_left_time_layer, true);
    layer_set_hidden((Layer *)s_right_time_layer, true);
    bitmap_layer_set_bitmap(s_nose_layer, s_nose_bitmap);
  }
// 显示每日金句
  static char *s_words[] = {"You Naive!", "I'm angry!", "2 young 2 simple", "Wearing 3 watch", "Apply for Professor", "Excited!", "Sometimes naive!"};
  text_layer_set_text(s_word_layer, s_words[tick_time->tm_wday]);
}
```

最终实现的代码只有一百多行，GitHub 地址： https://github.com/yulingtianxia/Pebble-MoHa

这里说几个开发时需要注意的地方：

1. 显示带 alpha 通道的 png 图片时需要参照下[这篇指引](https://developer.pebble.com/blog/2015/05/13/tips-and-tricks-transparent-images/)，我 P 图的时候干脆搞成不透明的了。
2. 位图无法缩放，但可以设置其在 `BitmapLayer` 中的对齐策略。
3. 加载资源时需要加上 `RESOURCE_ID_` 前缀。
4. 系统自带的字体并不是所有字号都有的，种类很有限。
5. 圆形手表的 `Window` 的 `bounds.size` 是外接矩形，有内建方法判断是否是圆形手表。
6. 真机调试需要打开手机上 Pebble 官方 App，打开开发者模式，开启开发者连接，保持蓝牙连接，让电脑与手机在同一个子网内。

我选择使用云端开发工具 [CloudPebble](https://cloudpebble.net/ide/) 而不是本地 sdk，主要是因为 CloudPebble 集成了一套创建和管理工程、托管代码和资源、在真机或模拟器编译运行、持续集成以及支持同步 GitHub 的开发环境。很适合初学者快速上手，敏捷开发。

开发语言选择 C 语言，并不是为了装逼，也不是因为我不会 JS，而是因为 leader 送我的手表所支持固件最新版本目前为 v3.12.3，而使用 JS 开发需要依赖 Rocky.js，要求固件版本 v4.x。

强烈建议看这篇[官方开发者教程](https://developer.pebble.com/tutorials/watchface-tutorial/)来快速入门。不得不说 pebble 的开发者博客里无论是文档还是教程都很赞，就是有些 demo 的 github 连接失效了。不过按照教程一步步去做终归还是很容易搞定的。

使用 [Pebble C SDK](https://developer.pebble.com/docs/c/) 的 API 时会用到各种功能的函数，监听回调也都是传入自定义函数指针。跟 UI 相关的 API 跟移动开发很类似，也会提供 `Window`，`Layer`，`GBitmap` 等类型。因为不涉及到 UI 的点击，所以会简单很多。但要注意的是对象的生命周期，每次调用 xxx_create 方法一定要对应调用 xxx_destroy 方法。`Layer` 有很多子类，比如 `TextLayer`,`BitmapLayer` 等。这些子类可以很方便地显示文字和图片等内容。对于这次我做的 watchface 来说，图片和文字已经够用了。构建 `Layer` 的层级关系也很简单，比如用 `layer_add_child()` 就能往一个 `Layer` 上添加其他 `Layer`。

目前 pebble 项目所支持的图片资源种类很少，且对二进制和资源大小均有限制。毕竟手表上能发挥的空间有限，所以将大部分逻辑放在手机上。通过蓝牙将数据传输给手表，手表上只负责展示一些比较及时的数据，做一些简单的操作同步数据给手机。所以 pebble 也提供了 iOS 和 Android 对应的 sdk。

pebble 推出了好几款手表，所以一个项目对应的 target 也有五种之多。所幸的是 CloudPebble 的模拟器提供了这五种 target 的模拟器，在网页中编程也有较好的编程体验，支持高亮和查看文档。管理资源更是简单，每种 target 都提供预览。项目配置也都是可视化操作，十分容易上手。

以上内容就是开发一款 pebble watchface 的基本法则，喜欢的话可以去主页点个赞：https://apps.getpebble.com/applications/5a4b9bfc0dfc329496001b60


