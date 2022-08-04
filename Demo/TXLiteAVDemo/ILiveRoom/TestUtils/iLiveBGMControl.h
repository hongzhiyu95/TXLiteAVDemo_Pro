//
//  iLiveBGMControl.h
//  TXLiteAVDemo_ILiveRoom_Standard
//
//  Created by xiang zhang on 2018/10/29.
//  Copyright © 2018 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@protocol iLiveBGMControlDelegate <NSObject>

-(void)onBgmStart:(BOOL)loopback loopTimes:(int)loopTimes type:(int)type;

-(void)onBgmStop;

-(void)onMicVolume:(float)volume;

-(void)onBgmVolume:(float)volume;

-(void)onBgmSeek:(float)progress;

-(void)onBgmPitchClick:(NSInteger) index;

@end
@interface iLiveBGMControl : UIView
@property (nonatomic,weak) id<iLiveBGMControlDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
