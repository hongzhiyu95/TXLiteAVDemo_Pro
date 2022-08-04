//
//  CLLrcView.h
//  QQMusic
//
//  Created by 杨博兴 on 16/10/19.
//  Copyright © 2016年 xx_cc. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CLLrcLabel;

@interface CLLrcView : UIView

/** 歌词文件名字 */
@property(nonatomic,strong)NSString *lrcName;

/** 当前播放的时间 */
@property (nonatomic,assign) NSTimeInterval currentTime;

@end

