//
//  TRTCFloatWindow.h
//  TXLiteAVDemo
//
//  Created by rushanting on 2019/5/15.
//  Copyright © 2019 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "TRTCCloudManager.h"
#import "TRTCVideoView.h"

NS_ASSUME_NONNULL_BEGIN

@interface TRTCFloatWindow : NSObject<TRTCVideoViewDelegate, TRTCCloudDelegate, TRTCCloudManagerDelegate>

@property (nonatomic, retain) UIView* localView;    //本地预览view
@property (nonatomic, retain) NSMutableDictionary<NSString *, TRTCVideoView *>* remoteViewDic;   //远端画面
@property (nonatomic) TRTCCloudManager *trtcCloudManager;   //TRTCCloudManager
@property (nonatomic) TRTCRenderViewKeymanager *renderViewKeyManager; // TRTCRenderViewKeymanager
@property (nonatomic) BOOL enableCustomRender; // 是否使用自定义渲染
@property (nonatomic) BOOL isFloating; // 是否使用悬浮窗

+ (instancetype)sharedInstance;

//浮窗显示
- (void)show;

//返回backController
- (void)back;

//关闭浮窗
- (void)close;

@end

NS_ASSUME_NONNULL_END
