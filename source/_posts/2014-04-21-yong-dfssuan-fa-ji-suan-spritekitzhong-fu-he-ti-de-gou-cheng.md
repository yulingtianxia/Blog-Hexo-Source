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

```
//
//  Graph.h
//  ColorAtom
//
//  Created by 杨萧玉 on 14-4-21.
//  Copyright (c) 2014年 杨萧玉. All rights reserved.
//
 
#import <Foundation/Foundation.h>
@import SpriteKit;
@interface Graph : NSObject
@property NSMutableArray *nodes;//节点数组
@property NSMutableArray *sets;//子图（联通图）数组，数组每个元素都是个集合，集合中包含这个子图中所有的node
-(id) initWithNodes:(NSArray*) nodeArr;
-(void)DFSVisitNode:(SKSpriteNode *) node;
@end
```

```
//
//  Graph.m
//  ColorAtom
//
//  Created by 杨萧玉 on 14-4-21.
//  Copyright (c) 2014年 杨萧玉. All rights reserved.
//
 
#import "Graph.h"
 
@implementation Graph
@synthesize nodes;
@synthesize sets;
-(id) initWithNodes:(NSArray*) nodeArr{
    if (self=[super init]) {
        //初始化所有节点，将其访问信息设置为未被访问
        nodes = [NSMutableArray arrayWithArray:nodeArr];
        sets = [NSMutableArray array];
        for (int i=0; i<[nodes count]; i++) {
//            The userData property is initially nil. You have to create a dictionary and assign it first
            ((SKSpriteNode *)nodes[i]).userData = [NSMutableDictionary dictionary];
            [((SKSpriteNode *)nodes[i]).userData setObject:@"WHITE" forKey:@"visited"];
            
        }
        //遍历数组nodes中所有节点，如果节点未被访问，则调用深度优先搜索算法访问之
        for (int i=0; i<[nodes count]; i++) {
            if ([[((SKSpriteNode *)nodes[i]).userData objectForKey:@"visited"] isEqualToString:@"WHITE"]) {
                [sets addObject:[NSMutableSet setWithObject:nodes[i]]];
                [self DFSVisitNode:nodes[i]];
            }
        }
    }
    return self;
}
//深度优先搜索算法
-(void)DFSVisitNode:(SKSpriteNode *) node{
    [node.userData setObject:@"GRAY" forKey:@"visited"];//将节点node标记为正在访问
    NSArray *adj = node.physicsBody.joints;//获得节点node的所有的边
    for (int i = 0; i<[adj count]; i++) {
        //根据边adj[i]来找到与节点node相连的另一个节点v
        SKPhysicsJoint *joint = adj[i];
        SKSpriteNode *v;
        if ([joint.bodyA isEqual:node.physicsBody]) {
            v = (SKSpriteNode *)joint.bodyB.node;
        }
        else{
            v = (SKSpriteNode *)joint.bodyA.node;
        }
        //如果v没被访问过，那就将其纳入节点node所在的集合，并记录节点v的父节点为node
        if ([[v.userData objectForKey:@"visited"] isEqualToString:@"WHITE"]) {
            [v.userData setObject:node forKey:@"parent"];
            for (int j=0; j<[sets count]; j++) {
                if ([sets[j] containsObject:node]) {
                    [sets[j] addObject:v];
                }
            }
            [self DFSVisitNode:v];//递归访问节点v的子结点
        }
    }
    [node.userData setObject:@"BLACK" forKey:@"visited"];//将节点node标记为访问结束
}
 
@end
```


可以在任意你需要的时候获取联通图信息：  

```objc

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

