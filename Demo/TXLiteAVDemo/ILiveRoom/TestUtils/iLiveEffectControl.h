//
//  iLiveEffectControl.h
//  TXLiteAVDemo_ILiveRoom_Standard
//
//  Created by xiang zhang on 2018/11/6.
//  Copyright © 2018 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol iLiveEffectControlDelegate <NSObject>

-(void)onEffectStart:(int)effectId isLoop:(BOOL)isLoop publish:(BOOL)isPublish;

-(void)onEffectStop:(int)effectId;

-(void)onEffectVolume:(int)effectId volume:(float)volume;

@end

@interface iLiveEffectControl : UIView
@property (nonatomic,weak) id<iLiveEffectControlDelegate> delegate;
-(void)reset:(int)effectId;
@end

NS_ASSUME_NONNULL_END
