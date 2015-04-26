---
layout: post
title: "用DFS算法计算SpriteKit中复合体的构成"
date: 2014-04-21 21:06:55 +0800
comments: true
tags: 
- iOS
- SpriteKit
- Algorithm

---

在使用Sprite Kit开发iOS游戏的时候，有时我们需要把一些`SKNode`(或者其子类)的物理体(`SKPhysicsBody`)通过某种方式连在一起组合成一个`SKPhysicsJoint`，这样就可以让这个连接体在物理世界一起被模拟。例如我们可以将两个`SKNode`用绳子(`SKPhysicsJointLimit`)，弹簧(`SKPhysicsJointSpring`)，胶水(`SKPhysicsJointFixed`)，钉子(`SKPhysicsJointPin`)，滑轨(`SKPhysicsJointSliding`)组合在一起。  

想象一些复杂的情况，比如玩家需要将游戏中多个相同的`SKNode`按照某种规则组合到一起，每个组合体包含`SKNode`的多少甚至形状(树或是环)都是游戏衡量玩家得分的标准。举个简单的例子：游戏里有好多彩色的球，玩家操作小球把它们粘在一起，将5个球粘在一起那么就能获得一份奖励  

但是每个`SKPhysicsJoint`只负责将两个`SKPhysicsBody`连在一起  

<!--more-->
其实这个问题可以简单归结为求图论中的联通图  
我写了个`Graph`类，只需在初始化的时候传入想要参加计算的`SKNode`数组即可，主要是用递归实现`DFS(深度优先搜索)`，维护N个集合(`NSSet`)，N的个数就是游戏中子图的个数，最小的子图就是一个`SKNode`。

代码：  

<script src="https://gist.github.com/yulingtianxia/11142742.js"></script>

可以在任意你需要的时候获取联通图信息：  

``` objc

NSMutableArray *nodes = [NSMutableArray array];
[thisAtom.scene enumerateChildNodesWithName:AtomName usingBlock:^(SKNode *node, BOOL *stop) {
        [nodes addObject:node];
    }];
Graph *graph = [[Graph alloc] initWithNodes:nodes];
for (int i=0; i<[graph.sets count]; i++) {
    NSLog(@"%@",graph.sets[i]);
}
```         

完整代码在[这里](https://github.com/yulingtianxia/MyFirstGame.git)的`ColorAtom`工程  
在向`SKSpriteNode.userdata`写键值对的时候，发现写进去后再读取依然是nil，这是因为`userdata`属性完全归用户随意使用，苹果甚至在SKSpriteNode初始化的时候干脆默认`userdata`是`nil`，所以需要初始化下：  

```
((SKSpriteNode *)nodes[i]).userData = [NSMutableDictionary dictionary];
``` 
感谢StackOverFlow网友的回答：http://stackoverflow.com/questions/19073199/sprite-kit-ios7-sknode-userdata-property-not-storing-values

