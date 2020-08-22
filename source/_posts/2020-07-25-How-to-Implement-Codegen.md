---
title: 如何实现一行命令自动生成 Flutter 插件
date: 2020-07-25 00:04:27
tags:
- Dart
- Flutter
- NodeJS
---

在上一篇文章[《告别 Flutter Channel，调用 Native API 仅需一行代码！》](http://yulingtianxia.com/blog/2020/06/25/Codegen-for-DartNative/) 发出后，收到了很多关注。仔细想想，其实不是仅仅只需一行代码的，还需要敲一行 [codegen](https://github.com/dart-native/codegen) 命令来生成 Dart 代码。这回就简单讲下自动生成代码这块的设计和实现原理。

<!--more-->

## 为何要做代码生成工具

一开始技术架构的搭建自底向上的。当我做出 Flutter 与 Native 之间的[高性能通道](https://github.com/dart-native/dart_native)后，自然而然地去想要提升易用性，降低开发者的使用门槛。当你从使用者角度去审视自己的产品时，就会自顶向下去设计一些 Feature 去满足目标用户的诉求。

最终我决定开发一款命令行工具。它可以解析 Native 代码中的 API，生成对应的 Dart 代码，再进而支持生成 Flutter Plugin/Package 工程。生成的 Flutter 工程会通过 pub 依赖 [DartNative](https://github.com/dart-native/dart_native):

![](http://yulingtianxia.com/resources/DartObjC/codegen_workflow.png)

工具需要满足以下需求：

1. 兼容性：能够支持 Native 多种语言代码的转换，如 Objective-C，Java，Swift，Kotlin 等
2. 易用性：开发者能够很方便地安装和使用工具

## 技术方案

为了满足兼容性，在实现『解析代码生成 AST』的技术方案上，是基于第三方开源框架 [antlr](https://www.antlr.org) 来实现。命令行工具使用 NodeJS 实现，开发者可以通过 npm 很方便地安装工具。

如果基于 Clang 来实现的话，性能和稳定性都有保证，但是需要 link 到所需的代码或 framework。且 Clang 对多语言的支持比较局限，也不方便提供给开发者去安装。

关于 antlr 的使用，这里不再赘述，可以直接查看官方文档。（毕竟作者是靠卖书赚钱的）。这里需要将源语言的 grammer 生成 JS 版本的 Runtime 文件，在遍历 AST 的 callback 中收集所需的元数据，转换成为生成 Dart 自定义格式的 AST。最后遍历 Dart AST，生成 Dart 代码。

这里的方案概括为如下步骤：

1. 查找出包含客户端 API 的 Native 代码文件，如 `.h` 和 `.java` 文件
2. 通过 antlr parser 生成 Native 语言的 AST
3. 将 Native AST 转换成 Dart 语言所需的 AST
4. 通过 Dart AST 生成 dart 代码

![](http://yulingtianxia.com/resources/DartObjC/codegen_theory.png)

## 遇到的坑

### 词法分析失败

官方提供的 Objective-C 的 [grammer](https://github.com/antlr/grammars-v4) 有很多问题，生成的 lexer 还是 parser 都会在词法分析阶段就抛异常。这里就比较坑了，需要修改 lexer 和 parser 的 g4 文件。可能是 grammer 太久没更新了，很多分词阶段就抛异常了，比如 `@import` 都不支持，真是一言难尽。而且这种只针对单个文件的词法分析程序，很难像 Clang 那样可以 link 其他文件做到的严谨性。经过一系列的修复工作，已经可以 parse iOS Foundation 库的所有头文件。

### 语法特性映射

这一步发生在 AST 的 transform。虽说不同语言之间有很多语法设计都是想通的，但是依然会有一些难以映射的语法特性。比如 Java 的重载方法，OC 奇葩的方法名。转换成 Dart 的方法命名应该遵循哪方的语言规范？OC 的 `Protocol` 在 Dart 中如何表示？Dart 类的静态方法不会被继承，那么 `Protocol` 中的类方法怎么办？Dart 的 `enum` 不支持自定义 `int` 值，来自 OC 的 `enum` 如何转换成 Dart？区分何时生成 Dart 的 `import` 或 `export`？。。。

类似这些操蛋的问题数不胜数。。。需要不断细化，思考，打磨。。。

### 批量处理

当要处理的文件有很多时，一个一个地串行处理显然会让开发者等得不耐烦。NodeJS 本来不是为 CPU 密集型操作服务的，但是在 v10.5.0 引入 [worker_threads](https://nodejs.org/api/worker_threads.html) 后，实现了真·多线程，解决了 CPU 密集型操作的痛点。

在处理一些稍大点的文件时，需要注意上调 NodeJS VM 老生代内存的阈值。

### 多种使用场景

考虑到不同的使用场景，[codegen](https://github.com/dart-native/codegen) 所生成的策略也会不一样：

1. 将 App 的 Native 代码转为 Dart 代码，直接在 Flutter 中使用
2. 将 Native 系统库转成 Flutter Package
3. 将 Native 第三方库转成 Flutter Plugin

这三种场景的共同点：如果 Native 代码依赖了其他库，也需要向 pubspec.yaml 中插入这个依赖库的 Dart 版本。

第 2 和 3 个场景需要用 `flutter create` 命令生成新的 Flutter 工程，并将生成的 Dart 代码挪到工程里。
更进一步是将生成代码所需的 Native 文件也挪到 Flutter 工程里，并更新 podspec 和 gradle （PS：待实现）。

## 总结

在做 [codegen](https://github.com/dart-native/codegen) 之前，我一直觉得有 [dart_native](https://github.com/dart-native/dart_native) 超级通道就足够了。毕竟是自己开发的轮子自己熟悉，认为手写一层 Dart Wrapper 也没啥麻烦的，其实并不然。当给未接触过的开发者使用后，的确是有上手门槛和开发量的。在调研的过程中也发现 bang 神的 JSPatch 也有个 Converter 工具用来把 OC 代码转为 JS 代码，同样用的也是 antlr 解析 AST，在此也十分感谢 JSPatch 提供的思路。超级通道加工具辅助方可实现了**运行性能和开发效率的双提升**。

## Reference

[antlr](https://www.antlr.org)
[grammers-v4](https://github.com/antlr/grammars-v4)
[JSPatch Convertor 实现原理详解](https://blog.cnbang.net/tech/2915/)