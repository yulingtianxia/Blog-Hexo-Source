---
layout: post
title: "UIAlertController in iOS8"
date: 2014-09-29 20:29:28 +0800
comments: true
tags: 
- iOS

---
iOS8新推出的UIAlertController究竟是为了什么？已有的`UIActionSheet`和`UIAlertView`就这样被打酱油了么？其实不然。。。  
<!--more-->
##UIAlertController是什么
`UIAlertController`是iOS8中新加入的一个ViewController，其主要功能是提醒（Alert），并取代 `UIActionSheet`和`UIAlertView`向用户展示提醒消息。因为它是一个ViewController，所以可以用`presentViewController:animated:completion:`方法来弹出它。  
##为什么不直接使用`UIActionSheet`和`UIAlertView`
1. `UIAlertController`采用block异步回调的形式来代理按钮的动作和文本框的配置，这样显得更加代码紧凑，可读性高。这样就不用通过协议代理给其他类，使得同一个逻辑下本应在一起的代码分离开。  
2. `UIActionSheet`和`UIAlertView`执行的都是提醒功能，只是展现的位置略有不同，合并相似功能并上升到Controller的级别，这是一种进步。  
3. `UIAlertController`在添加按钮和文本框时更加灵活，而`UIAlertView`只提供了四种Style，局限性太大。  
4. `UIAlertController`在增加拓展性的基础上也限定了一些风格来进行约束，不过新增加的风格比`UIAlertView`更贴合实际应用。  

PS：其实最直接的原因就是博主想弹出个Alert，有俩文本框的（不要密码输入框），可惜`UIAlertView`做不到啊！！！  
##创建一个`UIAlertController`
创建很简单有木有：
```
convenience init(title title: String?,
         message message: String?,
  preferredStyle preferredStyle: UIAlertControllerStyle)
```

举个栗子：

``` js
let title = "Enter Choices of the Trouble"
let message = detailItem?.content
let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.Alert)
``` 
`title`和`message`自然不用说了吧，需要注意的是`preferredStyle`一旦设定好以后就不能改了哦，因为它就是区分`UIAlertController`到底是对应着`UIActionSheet`还是`UIAlertView`，一共就这两种Style：  
``` 
enum UIAlertControllerStyle : Int {
    case ActionSheet
    case Alert
}
``` 
##添加动作
以前的做法是给个按钮标题数组然后在实现协议的代理方法中判断下按钮序列，然后对应给出不同的处理流程。分散的逻辑和代码无疑增加了开发者的工作量，还要求对应的类实现代理协议，真是out了。  

这里介绍一个新的类：UIAlertAction，`UIAlertController`弱化了以前添加Button的概念，而是添加UIAlertAction。其实说白了就是将按钮和处理方法捏到一起成为一个“动作”：  

``` 
convenience init(title title: String,
           style style: UIAlertActionStyle,
         handler handler: ((UIAlertAction!) -> Void)!)
``` 
`title`就是按钮的文本内容；`style`是按钮的风格，一共有三种风格：Default，Cancel和Destructive，其中Destructive会使按钮文字变成红色；`handler`是处理按钮按下后的一个block，这段代码块与添加的按钮紧密结合成“动作”，最后通过`addAction:`方法将UIAlertAction添加到`UIAlertController`中：  

``` 
let cancelbtn = "Cancel"
let cancelAction = UIAlertAction(title: cancelbtn, style: .Cancel) { (action) -> Void in
//add some code...            
}
alert.addAction(cancelAction)
``` 
##添加文本框
这也是最令博主激动的地方，最然不能自定义Alert中的内容，但起码添加UITextField不受限制了。添加文本框的方法实在是简洁：  

``` 
func addTextFieldWithConfigurationHandler(_ configurationHandler: ((UITextField!) -> Void)!)
``` 
一个block就解决了！你只需要在block中配置下文本框的字体、键盘、代理等即可，举个栗子：  

``` 
alert.addTextFieldWithConfigurationHandler { (choiceNameTF) -> Void in
	  choiceNameTF.borderStyle = .None
	  choiceNameTF.placeholder = "An answer of your trouble"
	  choiceNameTF.delegate = self
	  choiceNameTF.becomeFirstResponder()
}
```
美中不足的是文本框的代理还需要在另外一个地方写代码来实现协议，这种历史遗留问题终将被block统统解决！  

##总结

`UIAlertController`的确是方便多了，无论是代码的简洁性还是可读性，都有了较大的提升。不过也有缺点，就是动用Controller的层级略显麻烦，尤其是使用`presentViewController:animated:completion:`方法来弹出Alert界面与之前的一个潇洒的`show`相比真是有些“霸气”。看个人喜好了，只要满足需求，咋方便咋用。  

最后，贴上一张效果图：  

![](http://yulingtianxia.qiniudn.com/IMG_0906.PNG)  

图片截取自[HardChoice](https://itunes.apple.com/cn/app/hardchoice/id923977271?mt=8)  
