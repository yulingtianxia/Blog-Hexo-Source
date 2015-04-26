---
layout: post
title: "Swift中的位运算符和溢出运算符"
date: 2014-07-11 15:15:59 +0800
comments: true
tags: 
- Swift

---
位运算符（Bitwise Operators），在各种语言中都存在，虽然用的有些少，但是在诸如类别判断，类型检测等方案中经常用位运算来实现。很多枚举类型的成员都是将`0x1`左移位来赋值，而不是从0递增，这其中就蕴含着位运算。而数值运算中的溢出也是一个不常遇到但又值得注意的地方，虽然很少有人用`Int8`来存储大数，但了解下Swift处理溢出的这一特性也是很有用的。   
<!--more-->
##基本位运算符
`~`,`&`,`|`,`^`分别为取反，与，或，异或运算：

``` 
let firstBit: UInt8 = 0b10000000
let lastBit: UInt8  = 0b00000001
let invertedBits = ~lastBit  // 等于 0b11111110
let noneBit = firstBit & lastBit  // 等于 0b00000000
let twoSideBits = firstBit | lastBit //等于 0b10000001
let middleSixBits = firstBit ^ lastBit //等于 0b10000001
``` 
左移运算符`<<`和右移运算符`>>`分别扮演着乘2和除2的角色，对于`UInt`来讲很简单，只需要填充0就行：  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/bitshiftUnsigned_2x.png)  

但对于有符号整型数，移位时需要考虑到符号位，第一个比特位表达这个整数是正数还是负数。0代表正数，1代表负数。也就是说`Int8`最大是127，因为只有7位存储实际值，而且负数采用补码来表示。

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/bitshiftSignedFour_2x.png)  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/bitshiftSignedMinusFour_2x.png)  

正数的补码是原码；负数的补码是符号位不变，数值位各位取反，最后整个数加1，补码之所以被机器采用是因为它符合机器的架构设计，只用加法就能算减法：  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/bitshiftSignedAddition_2x.png)  


有符号整型右移运算时用符号位填充：  

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/bitshiftSigned_2x.png)

这就确保了在右移的过程中，有符整型的符号不会发生变化。这称为算术移位。  

##溢出运算符

Swift中如果计算结果超出了它的类型能承载的范围，那么就会发生溢出错误，除非你已经使用溢出运算符来进行操作：  

- 溢出加法 `&+`
- 溢出减法 `&-`
- 溢出乘法 `&*`
- 溢出除法 `&/`
- 溢出求余 `&%`  


###值的上溢出

``` 
var willOverflow = UInt8.max
// willOverflow 等于UInt8的最大整数 255
willOverflow = willOverflow &+ 1
// 此时 willOverflow 等于 0
``` 

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/overflowAddition_2x.png)  

###值的下溢出

``` 
var willUnderflow = UInt8.min
// willUnderflow 等于UInt8的最小值0
willUnderflow = willUnderflow &- 1
// 此时 willUnderflow 等于 255
``` 

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/overflowUnsignedSubtraction_2x.png)  

有符整型也有类似的下溢出

``` 
var signedUnderflow = Int8.min
// signedUnderflow 等于最小的有符整数 -128
signedUnderflow = signedUnderflow &- 1
// 此时 signedUnderflow 等于 127
``` 

![](https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/Swift_Programming_Language/Art/overflowSignedSubtraction_2x.png)  

###除零溢出

一个数除以0，或者对0求余数，就会产生一个错误；使用它们对应的可溢出的版本的运算符`&/`和`&%`进行除0操作时就会得到0值。

``` 
let x = 1
let y = x &/ 0
// y 等于 0
``` 
