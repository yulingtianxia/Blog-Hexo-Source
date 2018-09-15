title: 尝试实现 Web 上的看图模式
date: 2015-10-20 21:49:18
tags:
- iOS

---

iOS 上有很多浏览器都有“看图模式”这一功能，实现这一功能可能有很多种途径，最近接触到了这方面的工作，所以在此把我的思路记录下来。过程虽然比较简短，但日后可能会用到，如有更好的方案也可以对比下，取长补短。

<!--more-->

这次并不会用到什么新特性（比如 `WKWebView`）。而且方案很简单，分三步：

1. 获取网页中的图片（链接）
2. 将图片（链接）传给图片查看器
3. 完成点击图片的回调及动画

这里不可避免的会要用到 Javascript 来获取 `<img>` 元素内容，添加点击事件等。第一步很简单，几行 js 代码搞定：

```
function getAllImageUrl(){
   var imgs = document.getElementsByTagName("img");
   var urlArray = [];
   for (var i=0;i<imgs.length;i++){
       var src = imgs[i].src;
       urlArray.push(src);
   }
   return urlArray.toString();
}
```

第二步也不难，因为图片查看器可以用现成的第三方库，比如 `IDMPhotoBrowser`，只需要传入一个 `NSURL` 数组就行。

第三步需要绕个弯子。

首先是用 js 给图片添加点击事件，这个简单：

```
function setImage(){
   var imgs = document.getElementsByTagName("img");
   for (var i=0;i<imgs.length;i++){
       imgs[i].setAttribute("onClick","imageClick("+i+")");
   }
}
```
然后是动画，还好 `IDMPhotoBrowser` 提供了一个动画的接口：

```
- (id)initWithPhotos:(NSArray *)photosArray animatedFromView:(UIView*)view
```

这里需要传入一个 `view` 来作为动画的起始参数。我的做法是在 `webView` 上添加一个占位视图，并正好覆盖在被点击图片之上，将其作为动画的起始参数。这就需要从网页上获取被点击图片的 `frame`，还有图片的内容：

```
function getImageRect(i){
   var imgs = document.getElementsByTagName("img");
       var rect;
       rect = imgs[i].getBoundingClientRect().left+"::";
       rect = rect+imgs[i].getBoundingClientRect().top+"::";
       rect = rect+imgs[i].width+"::";
       rect = rect+imgs[i].height;
       return rect;
}
function getImageData(i){
   var imgs = document.getElementsByTagName("img");
   var img=imgs[i]; 
   var canvas=document.createElement("canvas"); 
   var context=canvas.getContext("2d"); 
   canvas.width=img.width; canvas.height=img.height; 
   context.drawImage(img,0,0,img.width,img.height); 
   return canvas.toDataURL("image/png") 
}
```

在获取图片内容时我并没有通过图片的 url 在 OC 代码中重新下载一次图片，而是选择将 web 中已经下载好的图片转成 png 格式传给 OC。但 `stringByEvaluatingJavaScriptFromString:` 方法返回的都是字符串，而且 js 返回的数据编码还是 base64 格式的。这里用到 `skpsmtpmessage` 这个第三方库将其解码为 `NSData`：

```
NSString *javascript = [NSString stringWithFormat:
                                @"getImageData(%d);", imgIndex];
NSString *stringData = [webView stringByEvaluatingJavaScriptFromString:javascript];
stringData = [stringData substringFromIndex:22]; // strip the string "data:image/png:base64,"
NSData *data = [NSData decodeWebSafeBase64ForString:stringData];
UIImage *image = [UIImage imageWithData:data];
```

嗯，最后完成图片点击事件的函数，在其中获取被点击图片的 frame，并拼凑成以 “clickgirl” 开头的 `url`，当然如果你喜欢用 “sexualgirl” 之类的也可以：

```
function imageClick(i){
   var rect = getImageRect(i);
   var url="clickgirl::"+i+"::"+rect;
   document.location = url;
}
```

上面的 `url` 在 `UIWebViewDelegate` 的 `- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType` 中会获取到，我贴上完整代码，顺便去掉下讨厌的百度推广。不要忘了在 `browser` 出现后将占位图片移除：

```
-(BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSString *requestString = [[request URL] absoluteString];
    if ([requestString hasPrefix:@"http://pos.baidu.com"]) {// ignore baidu ad
        return NO;
    }
    NSArray *components = [requestString componentsSeparatedByString:@"::"];
    if ([components[0] isEqualToString:@"clickgirl"]) {
        int imgIndex = [components[1] intValue];
        CGRect frame = CGRectMake([components[2] floatValue], [components[3] floatValue], [components[4] floatValue], [components[5] floatValue]);
        UIImageView *showView = [[UIImageView alloc] initWithFrame:frame];
        NSString *javascript = [NSString stringWithFormat:
                                @"getImageData(%d);", imgIndex];
        NSString *stringData = [webView stringByEvaluatingJavaScriptFromString:javascript];
        stringData = [stringData substringFromIndex:22]; // strip the string "data:image/png:base64,"
        NSData *data = [NSData decodeWebSafeBase64ForString:stringData];
        UIImage *image = [UIImage imageWithData:data];
        showView.image = image;
        [_webView addSubview:showView];
        
        NSString *urls = [_webView stringByEvaluatingJavaScriptFromString:@"getAllImageUrl();"];
        IDMPhotoBrowser *browser = [[IDMPhotoBrowser alloc] initWithPhotos:[IDMPhoto photosWithURLs:[urls componentsSeparatedByString:@","]] animatedFromView:showView];
        [browser setInitialPageIndex:imgIndex];
        browser.useWhiteBackgroundColor = YES;
        [self presentViewController:browser animated:YES completion:nil];
        [showView removeFromSuperview];
        
    }
    return YES;
}
```

其实有些网站只是在手机站上加了百度推广之类的，而在 PC 端可能并没有。至于符合查看手机上 web 的布局，可以在调试时打开 Mac 上的 Safari，点击“开发”菜单（我相信你肯定早已开启开发模式），选择你调试的那台设备，然后会看到你正在调试的程序和 `webview` 当前打开的域名。点击后可以展开 Web 检查器，使用方法跟 Mac 上 Safari 的 Web 检查器一样：  

![Web 检查器](http://yulingtianxia.com/resources/QQ20151022-0@2x.png)

这样就可以查看手机上的 Web 元素，方便我们 js 代码的编写。

其实在做公司项目时看了下 `IDMPhotoBrowser` 的代码，并做了一点儿优化和定制，尤其是在动画方面，这个控件还有很多流程和性能优化的空间。

最后放上 Demo 的 Github：https://github.com/yulingtianxia/WebViewImageClick
