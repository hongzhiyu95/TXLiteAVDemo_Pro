//
//  ILiveRoomPlayerItemView.h
//  TXLiteAVDemo
//
//  Created by rushanting on 2018/9/17.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface ILiveRoomPlayerItemView : UIView
@property(nonatomic,strong) UILabel *volumeLabel;
- (void)startLoadingAnimation;
- (void)stopLoadingAnimation;
- (void)setHighlight:(BOOL)enable;
@end
