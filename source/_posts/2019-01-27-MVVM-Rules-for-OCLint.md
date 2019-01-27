---
title: 使用 OCLint 自定义 MVVM 规则 
date: 2019-01-27 19:00:51
tags:
- Objective-C
---

最近在搞 iOS MVVM 框架，虽说是 N 年前就老生常谈的知识了，但设计模式毕竟是只一种规范，无法约束项目中所有程序员都去遵循。我做了个 OCLint 的自定义规则，对 ViewModel 运行静态检查。

然而过程中踩了不少坑，OCLint 的官方 Repo 早已失效，可以使用我修改后基于 LLVM 7 的版本：https://github.com/yulingtianxia/oclint/tree/llvm-7.0

伸手党也可以使用我写的[脚本](https://github.com/yulingtianxia/oclint/releases/download/0.18.10/install-0.18.10)直接安装，已包含 MVVM 规则。

<!--more-->

## 编译 OCLint

编译 OCLint 时，会先下载 LLVM 等项目。由于 LLVM 源码废弃了在 SVN 上的版本管理，将其迁移到了 Git 上，所以目前各种版本的 OCLint 都无法编译了。而且最新版本的 OCLint 还是基于 LLVM 5 的！我从作者的 Repo 那发现有 LLVM 7 的 branch，依然无法编译，只好自己动手改了。

虽然 Git 上的提交与历史 SVN 提交记录有映射，但是经过实践发现并不精准可信。编译时需要用到 llvm-project 下的 llvm，cfe 和 compile-rt，而且三个 repo 的 release 版本一定要一致。然而  LLVM 在 Git 上同一个 release 的代码却无法编译通过。更离谱的是即便 LLVM 在 GitHub 上把整个 llvm-project 作为一个 repo，依然无法将其 release 版本编译通过。

算了，Git 不靠谱，还是改下 OCLint 的代码，从官网直接下以前打包好的吧。

```
llvm = 'http://releases.llvm.org/7.0.0/llvm'
clang = 'http://releases.llvm.org/7.0.0/cfe'
clang_rt = 'http://releases.llvm.org/7.0.0/compiler-rt'
```

我把最终可以正常编译的 0.18.10 版本发了个非官方的 release 包，macOS 亲测 ok：https://github.com/yulingtianxia/oclint/releases/tag/0.18.10

嫌麻烦不想编译的，可以直接跑我提供的脚本来安装已经编译好的 0.18.10 版本。以前安装过 OCLint 旧版本的可以先备份下，因为会被覆盖安装。

```
wget --no-check-certificate -O install-oclint https://github.com/yulingtianxia/oclint/releases/download/0.18.10/install-0.18.10
chmod +x install-oclint
./install-oclint
```

## 自定义规则

网上有很多介绍如何编写自定义规则的文章，这里假设已经成功编译好 OCLint，总体流程如下。

### 创建规则

使用 oclint-scripts 文件夹下的 scaffoldRule 脚本创建一个新规则，并指定模板。注意规则名不需要带 "Rule":

```
oclint-scripts/scaffoldRule MVVM -t ASTVisitor
```

### 生成调试工程

创建一个文件夹用于生成调试 Rule 的工程。我已经创建好了：https://github.com/yulingtianxia/oclint/tree/llvm-7.0/oclint-xcodeproject

运行 xcode-debug.sh 脚本即可使用 oclint-rules 文件夹的内容创建一个 Xcode 工程。因为这里是想调试刚刚创建的 MVVM 规则，所以选择 oclint-rules。理论上可以修改脚本参数使用其他文件夹创建 Xcode 工程。

```
#! /bin/sh -e

cmake -G Xcode -D CMAKE_CXX_COMPILER=../build/llvm-install/bin/clang++  -D CMAKE_C_COMPILER=../build/llvm-install/bin/clang -D OCLINT_BUILD_DIR=../build/oclint-core -D OCLINT_SOURCE_DIR=../oclint-core -D OCLINT_METRICS_SOURCE_DIR=../oclint-metrics -D OCLINT_METRICS_BUILD_DIR=../build/oclint-metrics -D LLVM_ROOT=../build/llvm-install/ ../oclint-rules
```

每个规则都有对应的 Scheme，选择我们自定义的 MVVMRule，添加启动参数。`-R` 传入自定义的规则名，这里使用调试工程生成的 Debug 目录。接着传入一个随便写的测试用文件 `TestViewModel.m`，此文件所依赖的 Framework 等环境参数也需要传入。别忘了需要把我贴的绝对路径修改成你电脑上的路径。

```
-R /Users/yangxiaoyu/Code/oclint/oclint-xcodeproject/rules.dl/Debug /Users/yangxiaoyu/Code/oclint/oclint-rules-test/OCLintTest/OCLintTest/TestViewModel.m  -- -x objective-c 
-isystem /Users/yangxiaoyu/Code/oclint/build/oclint-release/lib/clang/7.0.0/include
-iframework /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/System/Library/Frameworks
-isystem /Applications/Xcode.app/Contents/Developer/Platforms/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator.sdk/usr/include
```

为了能够调试运行，还需要在 Scheme 的 Info 下选择 Executable 为编译好的 oclint 的可执行文件。oclint-0.18.10 文件由于后缀名问题不允许被选择为 Executable，删掉后缀名的数字就可以了。这样就可以无需重新编译 OCLint 直接运行调试了！

### 实现规则

在 MVVM 设计模式下，我想让 ViewModel 的属性都是只读的。因为我只想通过与 Model 的数据绑定来更新 ViewModel 的值，或是在其内部更新状态。现在我需要实现一个规则来找出那些非只读属性。

先找几个自带的规则例子看看，结合 [Clang AST 文档](https://clang.llvm.org/doxygen/)学习下各种数据结构的定义。如果不知道自己的测试代码如何下手，可以用 `clang` 命令将测试代码转化为 [Clang AST](http://clang.llvm.org/docs/IntroductionToTheClangAST.html)：
 
```
clang -Xclang -ast-dump -fsyntax-only TestViewModel.m 
```

思路是遍历每个后缀名为 `ViewModel` 类的 Interface 中的所有 Property，判断每个 Property 的 Attribute，如果包含 `readwrite` 就触发 warning。提高优先级可以产生 error。

```
/* Visit ObjCImplementationDecl */
bool VisitObjCImplementationDecl(ObjCImplementationDecl *node)
{
    ObjCInterfaceDecl *interface = node->getClassInterface();
    
    bool isViewModel = interface->getName().endswith("ViewModel");
    if (!isViewModel) {
        return false;
    }
    for (auto property = interface->instprop_begin(),
         propertyEnd = interface->instprop_end(); property != propertyEnd; property++)
    {
        clang::ObjCPropertyDecl *propertyDecl = (clang::ObjCPropertyDecl *)*property;
        if (propertyDecl->getName().startswith("UI")) {
            addViolation(propertyDecl, this);
        }
        auto attrs = propertyDecl->getPropertyAttributes();
        bool isReadwrite = (attrs & ObjCPropertyDecl::PropertyAttributeKind::OBJC_PR_readwrite) > 0;
        if (isReadwrite && isViewModel) {
            addViolation(propertyDecl, this);
        }
    }
    return true;
}
```

## 集成到 Xcode

先放一张集成后的效果：

![](http://yulingtianxia.com/resources/QQ20190127-175054@2x.png)

在 CI 运行静态检查可以减少一部分人工 Code Review 的成本，缺点是发现问题滞后，解决问题有一定成本。而如果在本地 Xcode 运行静态检查，则可把问题扼杀在摇篮之中，缺点是占用开发机资源。

如何在 Xcode 中集成 OCLint 静态检查，官方有很详细的文档，图文并茂: https://oclint-docs.readthedocs.io/en/stable/guide/xcode.html

美中不足的是 Xcode Run Script 欠一点火候，可以参考下下面我提供的脚本：

```
if which oclint 2>/dev/null; then
echo 'oclint exist'
else
wget --no-check-certificate -O install-oclint https://github.com/yulingtianxia/oclint/releases/download/0.18.10/install-0.18.10
chmod +x install-oclint
./install-oclint
fi
if which xcpretty 2>/dev/null; then
echo 'xcpretty exist'
else
sudo gem install xcpretty
fi
source ~/.bash_profile
cd ${SRCROOT}
xcodebuild clean
xcodebuild | xcpretty -r json-compilation-database --output compile_commands.json
oclint-json-compilation-database -- -report-type xcode
```

## 后记

我只是简单的写了一个 ViewModel 的规则来跑通和验证整个流程，其实 MVVM 设计模式里还有更多的规则需要实现，比如 ViewModel 中不能引入 `UIKit` 等。欢迎有兴趣的同学提 PR！

## Reference

- [OCLint](http://oclint.org)
- [LLVM Download Page](http://releases.llvm.org/download.html#7.0.0)
- [llvm-project](https://github.com/llvm/llvm-project)
- [Introduction to the Clang AST](http://clang.llvm.org/docs/IntroductionToTheClangAST.html)