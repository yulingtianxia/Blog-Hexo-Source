---
title: GitHub 虚假 Star 净网行动
date: 2018-09-16 16:20:55
tags:
- GitHub
- 瞎折腾
---

前一阵子看到一篇文章 [《石锤 github 买 star 行为》](https://juejin.im/post/5b8c9310f265da4361530560)，第一反应是很震惊。是真的很震惊，因为文章中提到的 CocoaDebug 我也 star 了，没想到竟然涉嫌购买 star 炒作，蒙蔽了好多人的双眼。没错，我就是跟风 star，看别的大神 star 啥就顺手 star。 也有的人看 Trending 上啥火顺手 star，甚至用脚本自动 star。

这条黑产背后到底隐藏着什么？GitHub 上还有哪些大笨蛋也曾靠买 Star 蒙蔽了大神们的双眼呢？我写了个简单的程序用于挖掘基于 Star 的关系链，并进行聚类分析。然后从 CocoaDebug 这个 repo 入手，沿着关系链一层层深挖下去。

用数据说话，结果一定也会让你大开眼界。正义可能会迟到，但绝不会缺席！

项目源码：[FuckFakeGitHubStars](https://github.com/yulingtianxia/FuckFakeGitHubStars)

<!--more-->

## 思路

1. 用 GitHub 的 API 获取 repo 有哪些用户 star 了，然后再看看这些用户都 star 了哪些 repo。
2. 将 star 行为相似的用户和 repo 聚类
3. 疑似黑产的用户集合一般数量较多，且每个用户 star 的 repo 并不多。将这种集合纳入黑名单。（肯定会有误判，但影响不大）
4. 计算 repo 的 star 中黑名单用户占比。
5. 继续遍历黑名单中的用户，挖掘下一层关系链，揪出更多花钱买 star 的 repo。

## 爆料

**郑重声明**：

1. 结果不一定准确，仅做参考，毕竟黑名单有误判。
2. 买 Star 都只是推测，没有交易记录就没有实锤。本文仅是分析 GitHub 社区这一有趣而又奇妙的的现象。
3. 不排除有人恶意给别人的 Repo 买 Star 的情况，也说不定有人注册了一堆账号喜欢没事给别人 Star 呢！
4. 由于脚本是广度优先搜索，每个 batch 跑完结果都会更准确。跑完整个 GitHub 需要巨长的时间。跑的 batch 越多，有些 Repo 就越能露出马脚。

由于数据量实在是太大了，而且也受限于 GitHub API 请求频率的限制和 CPU 计算的耗时，在上面思路中的第五步中只运行了一部分。当然，全部深挖都只是时间问题，无奈数据量级的恐怖，先把阶段性成果输出下。

1. 从 CocoaDebug 入手挖掘出的疑似黑产账号达到了900左右。
2. CocoaDebug 有 30% 左右的 Star 可能是买的。
3. 在 [《石锤 github 买 star 行为》](https://juejin.im/post/5b8c9310f265da4361530560) 文章中跟 CocoaPods 一起被揭露的『难兄难弟』所购买的 Star 更为夸张，超过了半数：

    ```
    repo owner/name: baoleiji/QilinBaoleiji stargazer num: 1447 black percent:0.5770559778852798
    repo owner/name: 3348375016/ITSecrets stargazer num: 1589 black percent:0.5173064820641913
    ```
    当然，再深挖跑一轮数据可能会发现这个比例更大。
4. Jinxiansen 的 SwiftServerSide-Vapor 曾在 8 月 5 日登上了 Trending，当日收获 104个 Star。如果我没记错的话，mattt 大神也 star 并 follow 过（现在发现又取关了，果然即便蒙蔽了大神的双眼那也只是暂时的事儿）。神奇的是，这个 repo 中有 105 个 Star 疑似来自黑产。附上[这篇 V 站的贴子更有趣](https://www.v2ex.com/t/471479)。这哥们写的另外一个 JHUD 也是同理。

    ```
    repo owner/name: Jinxiansen/SwiftServerSide-Vapor stargazer num: 583 black percent:0.18010291595197256
    ```
5. UCodeUStory 的 S-MVP，你慢慢涨 Star 就能逃得了么？

    ```
    repo owner/name: UCodeUStory/S-MVP stargazer num: 1103 black percent:0.28014505893019037
    ```
6. 买一个 Star 到底要多少钱啊，有的 repo 还不到一百个 Star，占比还不低呢，也不多买点，真抠啊（我甚至怀疑是黑产为了伪装自己的账号，随意 star 了一些没花钱买 star 的库）：

    ```
    repo owner/name: jianhaod/Kaggle stargazer num: 37 black percent:0.5945945945945946
    repo owner/name: whsgzcy/DEMOS_TO_MySelf_Android stargazer num: 63 black percent:0.4603174603174603
    ```
    
7. 搞区块链的？7月7日那天涨了 246 个 star，一算比例还真差不多：

    ```
    repo owner/name: DeuroIO/erc20-ico-onchain-technical-analysis stargazer num: 512 black percent:0.427734375
    ```
    
8. 仿豆瓣的、仿知乎的。MelonRice 还有个放虎扑的，我脚本还没扫到它，手动点进去一看 star 的人，还是那尿性，也都 star 了前面那位 Jinxiansen。

    ```
    repo owner/name: jianxiaoBai/douban stargazer num: 288 black percent:0.3715277777777778
    repo owner/name: MelonRice/zhihudaily_flutter stargazer num: 163 black percent:0.2085889570552147
    ```

因为找出来的数据太多了，这里就不逐个去看了，这里只是随便拎几个出来。

要是 GitHub API 没有请求限频，再搞个云服务器成天跑，再做个前端页面支持查找，就完美了。要是家里有矿，说不定还能上 GPU 搞神经网络在线学习？！

我好担心被这些人报复啊。

## 使用方法

直接看 [README.md](https://github.com/yulingtianxia/FuckFakeGitHubStars/blob/master/README.md) 吧。

因为 GitHub API 用到的 token 没有上传，所以需要填你自己的 token 才可以抓数据。而且我只上传了部分数据，生成的 json 文件太大了，又懒得用数据库。

最终的可读性比较强的信息输出在 log 里，没有上传。有兴趣的可以自己跑下。

## 技术实现

技术栈就是 python3 + GraphQL。

`REPOSITORY_STARGAZERS.json` 存储了 repo 有哪些用户 star 了。`USER_STAR_REPOSITORIES.json` 存储了用户 star 了哪些 repo。repo 或用户都是一个 node，都有唯一的 node ID。这样就构成了一张有向图。再根据节点的出度或入度集合将节点使用 Jaccard 相似度进行聚类。节点的详细信息以及与其他节点的相似度信息都保存在 `NODE_ID_CONTENT.json` 中。整理出的疑似黑产黑名单用户保存在 `BLACK_LIST.json`。

最初的设想是在这张巨大的有向图中广度优先遍历，层层扒皮。后来迫于面对现实，就只跑了两层，先有个阶段性结论。可以分析单个 repo star 的黑产占比，想把全网数据一网打尽需要耗费更多的时间成本。

本项目用到的技术都是现学现卖，纯粹是玩票性质，代码烂的一逼，求轻喷。某大神都深入 Python 底层实现原理开课赚钱了，我还在这边查语法边写垃圾代码，差距太大了哎！

## 后记

愿以后 GitHub 能够清静些，虽然我大清自有国情在，但也别让一些别有用心之人一条臭鱼坏了一坨粥。

写这篇文章的时候，强台风『山竹』还在蹂躏着深圳。

