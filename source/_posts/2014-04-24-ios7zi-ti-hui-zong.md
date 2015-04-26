---
layout: post
title: "iOS添加字体汇总"
date: 2014-04-24 18:12:43 +0800
comments: true
tags: 
- iOS
- 字体

---
向iOS中添加第三方字体并获取其名称。    
<!--more-->
1. 将字体文件加入工程中  
2. 在XXX-Info.plist文件中（XXX为工程名）加入新的键“Fonts provided by application”，其值为一个数组，并在数组中添加字体文件的名称。  
3. 在工程->Targets(选一个target)->Build Phases->Copy Bundle Resources中加入字体文件  
4. 运行下面的代码可以获得所有的字体样式  

``` objc
		NSArray *familyNames = [UIFont familyNames];
        for( NSString *familyName in familyNames ){
            printf( "Family: %s \n", [familyName UTF8String] );
            NSArray *fontNames = [UIFont fontNamesForFamilyName:familyName];
            for( NSString *fontName in fontNames ){
                printf( "\tFont: %s \n", [fontName UTF8String] );
            }  
        }
``` 

在iOS7运行，获得结果如下，从中找出你新添加的字体名吧：  

 Family: Marion  
 Font: Marion-Italic  
 Font: Marion-Bold  
 Font: Marion-Regular  
 Family: Copperplate  
 Font: Copperplate-Light  
 Font: Copperplate  
 Font: Copperplate-Bold  
 Family: Heiti SC  
 Font: STHeitiSC-Medium  
 Font: STHeitiSC-Light  
 Family: Iowan Old Style  
 Font: IowanOldStyle-Italic  
 Font: IowanOldStyle-Roman  
 Font: IowanOldStyle-BoldItalic  
 Font: IowanOldStyle-Bold  
 Family: Courier New  
 Font: CourierNewPS-BoldMT  
 Font: CourierNewPS-ItalicMT  
 Font: CourierNewPSMT  
 Font: CourierNewPS-BoldItalicMT  
 Family: Apple SD Gothic Neo  
 Font: AppleSDGothicNeo-Bold  
 Font: AppleSDGothicNeo-Thin  
 Font: AppleSDGothicNeo-Regular  
 Font: AppleSDGothicNeo-Light  
 Font: AppleSDGothicNeo-Medium  
 Font: AppleSDGothicNeo-SemiBold  
 Family: Heiti TC  
 Font: STHeitiTC-Medium  
 Font: STHeitiTC-Light  
 Family: Gill Sans  
 Font: GillSans-Italic  
 Font: GillSans-Bold    
 Font: GillSans-BoldItalic  
 Font: GillSans-LightItalic  
 Font: GillSans  
 Font: GillSans-Light  
 Family: Thonburi  
 Font: Thonburi  
 Font: Thonburi-Bold  
 Font: Thonburi-Light  
 Family: Marker Felt  
 Font: MarkerFelt-Thin
 Font: MarkerFelt-Wide  
 Family: Avenir Next Condensed  
 Font: AvenirNextCondensed-BoldItalic  
 Font: AvenirNextCondensed-Heavy  
 Font: AvenirNextCondensed-Medium  
 Font: AvenirNextCondensed-Regular  
 Font: AvenirNextCondensed-HeavyItalic  
 Font: AvenirNextCondensed-MediumItalic  
 Font: AvenirNextCondensed-Italic  
 Font: AvenirNextCondensed-UltraLightItalic  
 Font: AvenirNextCondensed-UltraLight  
 Font: AvenirNextCondensed-DemiBold  
 Font: AvenirNextCondensed-Bold  
 Font: AvenirNextCondensed-DemiBoldItalic  
 Family: Tamil Sangam MN  
 Font: TamilSangamMN  
 Font: TamilSangamMN-Bold  
 Family: Helvetica Neue  
 Font: HelveticaNeue-Italic  
 Font: HelveticaNeue-Bold  
 Font: HelveticaNeue-UltraLight  
 Font: HelveticaNeue-CondensedBlack  
 Font: HelveticaNeue-BoldItalic  
 Font: HelveticaNeue-CondensedBold  
 Font: HelveticaNeue-Medium  
 Font: HelveticaNeue-Light    
 Font: HelveticaNeue-Thin  
 Font: HelveticaNeue-ThinItalic  
 Font: HelveticaNeue-LightItalic  
 Font: HelveticaNeue-UltraLightItalic  
 Font: HelveticaNeue-MediumItalicv
 Font: HelveticaNeue  
 Family: Gurmukhi MN  
 Font: GurmukhiMN-Bold  
 Font: GurmukhiMN  
 Family: Times New Roman  
 Font: TimesNewRomanPSMTv
 Font: TimesNewRomanPS-BoldItalicMT  
 Font: TimesNewRomanPS-ItalicMT  
 Font: TimesNewRomanPS-BoldMT  
 Family: Georgia  
 Font: Georgia-BoldItalic  
 Font: Georgia    
 Font: Georgia-Italic  
 Font: Georgia-Bold  
 Family: Apple Color Emoji  
 Font: AppleColorEmoji  
 Family: Arial Rounded MT Bold  
 Font: ArialRoundedMTBold  
 Family: Kailasa  
 Font: Kailasa-Bold  
 Font: Kailasa  
 Family: Sinhala Sangam MN  
 Font: SinhalaSangamMN-Bold  
 Font: SinhalaSangamMN  
 Family: Chalkboard SE  
 Font: ChalkboardSE-Bold  
 Font: ChalkboardSE-Light  
 Font: ChalkboardSE-Regular  
 Family: Superclarendon  
 Font: Superclarendon-Italic  
 Font: Superclarendon-Black  
 Font: Superclarendon-LightItalic
 Font: Superclarendon-BlackItalic  
 Font: Superclarendon-BoldItalic  
 Font: Superclarendon-Light  
 Font: Superclarendon-Regular  
 Font: Superclarendon-Bold  
 Family: Gujarati Sangam MN  
 Font: GujaratiSangamMN-Bold  
 Font: GujaratiSangamMN  
 Family: Geeza Pro  
 Font: GeezaPro-Light  
 Font: GeezaPro  
 Font: GeezaPro-Bold  
 Family: Noteworthy  
 Font: Noteworthy-Light  
 Font: Noteworthy-Bold  
 Family: Damascus  
 Font: DamascusBold  
 Font: DamascusSemiBold  
 Font: DamascusMedium  
 Font: Damascus
 Family: Avenir  
 Font: Avenir-Medium  
 Font: Avenir-HeavyOblique  
 Font: Avenir-Book  
 Font: Avenir-Light  
 Font: Avenir-Roman  
 Font: Avenir-BookOblique  
 Font: Avenir-Black  
 Font: Avenir-MediumOblique  
 Font: Avenir-BlackOblique  
 Font: Avenir-Heavy  
 Font: Avenir-LightOblique  
 Font: Avenir-Oblique  
 Family: Academy Engraved LET  
 Font: AcademyEngravedLetPlain  
 Family: Mishafi  
 Font: DiwanMishafi  
 Family: Futura  
 Font: Futura-CondensedMedium  
 Font: Futura-CondensedExtraBold  
 Font: Futura-Medium  
 Font: Futura-MediumItalicv
 Family: Farah  
 Font: Farah  
 Family: Kannada Sangam MN  
 Font: KannadaSangamMN  
 Font: KannadaSangamMN-Bold  
 Family: Arial Hebrew  
 Font: ArialHebrew-Bold  
 Font: ArialHebrew-Light  
 Font: ArialHebrew  
 Family: Arial  
 Font: ArialMT  
 Font: Arial-BoldItalicMT  
 Font: Arial-BoldMT  
 Font: Arial-ItalicMT  
 Family: Party LET  
 Font: PartyLetPlain  
 Family: Chalkduster  
 Font: Chalkduster  
 Family: Hiragino Kaku Gothic ProN  
 Font: HiraKakuProN-W6  
 Font: HiraKakuProN-W3    
 Family: Hoefler Text  
 Font: HoeflerText-Italicv
 Font: HoeflerText-Regular  
 Font: HoeflerText-Black  
 Font: HoeflerText-BlackItalicv
 Family: Optima  
 Font: Optima-Regular  
 Font: Optima-ExtraBlack  
 Font: Optima-BoldItalic  
 Font: Optima-Italic  
 Font: Optima-Bold  
 Family: Palatino  
 Font: Palatino-Bold  
 Font: Palatino-Roman  
 Font: Palatino-BoldItalic  
 Font: Palatino-Italic  
 Family: Malayalam Sangam MN  
 Font: MalayalamSangamMN-Bold  
 Font: MalayalamSangamMN  
 Family: Al Nile  
 Font: AlNile-Bold  
 Font: AlNile  
 Family: Bradley Hand  
 Font: BradleyHandITCTT-Bold  
 Family: Hiragino Mincho ProN  
 Font: HiraMinProN-W6  
 Font: HiraMinProN-W3  
 Family: Trebuchet MS  
 Font: Trebuchet-BoldItalic  
 Font: TrebuchetMS  
 Font: TrebuchetMS-Bold  
 Font: TrebuchetMS-Italic  
 Family: Helvetica  
 Font: Helvetica-Bold  
 Font: Helvetica  
 Font: Helvetica-LightOblique  
 Font: Helvetica-Oblique  
 Font: Helvetica-BoldOblique  
 Font: Helvetica-Light  
 Family: Courier  
 Font: Courier-BoldObliquev
 Font: Courier  
 Font: Courier-Bold  
 Font: Courier-Oblique  
 Family: Cochin  
 Font: Cochin-Bold  
 Font: Cochin  
 Font: Cochin-Italic  
 Font: Cochin-BoldItalic  
 Family: Devanagari Sangam MNv
 Font: DevanagariSangamMN  
 Font: DevanagariSangamMN-Bold  
 Family: Oriya Sangam MN  
 Font: OriyaSangamMN  
 Font: OriyaSangamMN-Bold  
 Family: Snell Roundhand  
 Font: SnellRoundhand-Bold  
 Font: SnellRoundhand  
 Font: SnellRoundhand-Black  
 Family: Zapf Dingbats  
 Font: ZapfDingbatsITC  
 Family: Bodoni 72  
 Font: BodoniSvtyTwoITCTT-Bold  
 Font: BodoniSvtyTwoITCTT-Book  
 Font: BodoniSvtyTwoITCTT-BookIta  
 Family: Verdana  
 Font: Verdana-Italic  
 Font: Verdana-BoldItalic  
 Font: Verdana  
 Font: Verdana-Bold  
 Family: American Typewriter  
 Font: AmericanTypewriter-CondensedLight  
 Font: AmericanTypewriter  
 Font: AmericanTypewriter-CondensedBold  
 Font: AmericanTypewriter-Light  
 Font: AmericanTypewriter-Bold  
 Font: AmericanTypewriter-Condensed  
 Family: Avenir Next  
 Font: AvenirNext-UltraLight  
 Font: AvenirNext-UltraLightItalic  
 Font: AvenirNext-Bold  
 Font: AvenirNext-BoldItalic  
 Font: AvenirNext-DemiBold  
 Font: AvenirNext-DemiBoldItalic  
 Font: AvenirNext-Medium  
 Font: AvenirNext-HeavyItalic  
 Font: AvenirNext-Heavy  
 Font: AvenirNext-Italic  
 Font: AvenirNext-Regular  
 Font: AvenirNext-MediumItalic  
 Family: Baskerville  
 Font: Baskerville-Italic  
 Font: Baskerville-SemiBold  
 Font: Baskerville-BoldItalic  
 Font: Baskerville-SemiBoldItalic  
 Font: Baskerville-Bold  
 Font: Baskerville  
 Family: Didot  
 Font: Didot-Italicv
 Font: Didot-Bold  
 Font: Didot  
 Family: Savoye LET  
 Font: SavoyeLetPlain  
 Family: Bodoni Ornaments  
 Font: BodoniOrnamentsITCTT  
 Family: Symbol  
 Font: Symbol  
 Family: Menlo  
 Font: Menlo-Italic  
 Font: Menlo-Bold  
 Font: Menlo-Regular  
 Font: Menlo-BoldItalic  
 Family: Bodoni 72 Smallcaps  
 Font: BodoniSvtyTwoSCITCTT-Book  
 Family: DIN Alternate  
 Font: DINAlternate-Bold  
 Family: Papyrus  
 Font: Papyrus  
 Font: Papyrus-Condensed  
 Family: Euphemia UCAS  
 Font: EuphemiaUCAS-Italic  
 Font: EuphemiaUCAS  
 Font: EuphemiaUCAS-Bold  
 Family: Telugu Sangam MN  
 Font: TeluguSangamMN  
 Font: TeluguSangamMN-Bold  
 Family: Bangla Sangam MN  
 Font: BanglaSangamMN-Bold  
 Font: BanglaSangamMN  
 Family: Zapfino  
 Font: Zapfino  
 Family: Bodoni 72 Oldstyle  
 Font: BodoniSvtyTwoOSITCTT-Book  
 Font: BodoniSvtyTwoOSITCTT-Bold  
 Font: BodoniSvtyTwoOSITCTT-BookIt  
 Family: DIN Condensed  
 Font: DINCondensed-Bold  
