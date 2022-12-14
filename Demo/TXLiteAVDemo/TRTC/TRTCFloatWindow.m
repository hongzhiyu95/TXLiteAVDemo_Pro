//
//  TRTCFloatWindow.m
//  TXLiteAVDemo
//
//  Created by rushanting on 2019/5/15.
//  Copyright © 2019 Tencent. All rights reserved.
//

#import "TRTCFloatWindow.h"
#import "TXLiteAVSDK.h"
#import "TRTCMainViewController.h"
#import "TRTCRenderViewKeyManager.h"

@interface TRTCFloatWindow ()

@end

@implementation TRTCFloatWindow
{
    UIButton* _closeBtn;
}

+ (instancetype)sharedInstance {
    static TRTCFloatWindow *s_instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_instance = [TRTCFloatWindow new];
    });
    return s_instance;
}

- (instancetype)init
{
    if (self = [super init]) {
        _closeBtn = [UIButton buttonWithType:UIButtonTypeCustom];
        [_closeBtn setImage:[UIImage imageNamed:@"view_close"] forState:UIControlStateNormal];
        [_closeBtn addTarget:self action:@selector(closeBtnClick:) forControlEvents:UIControlEventTouchUpInside];
        [_closeBtn sizeToFit];
        _closeBtn.frame = CGRectMake(8, 8, _closeBtn.bounds.size.width, _closeBtn.bounds.size.height);
        _isFloating = NO;
    }
    
    return self;
}

/**
 * 浮窗显示
 */
- (void)show
{
    _isFloating = YES;
    UIWindow* window = [[UIApplication sharedApplication].delegate window];
    CGFloat width = window.frame.size.width / 2.5;
    CGFloat height = width * 16 / 9;
    _localView.frame = CGRectMake(window.frame.size.width - width, window.frame.size.height - height, width, height);

    //关闭本地预览view的网络状态标示和允许移动
    ((TRTCVideoView*)_localView).delegate = self;
    [((TRTCVideoView*)_localView) showNetworkIndicatorImage:NO];
    ((TRTCVideoView*)_localView).enableMove = YES;
    
    //添加关闭按钮
    [_localView addSubview:_closeBtn];
    
    //本地预览添加到浮窗显示
    [window addSubview:_localView];
    _localView.hidden = NO;
    
    //远端画面添加到浮窗显示
    [self addAndRelayoutRemoteView];
}

/**
 * 返回原界面
 */
- (void)back
{
    [self backBtnClick:nil];
}

/**
 * 隐藏浮窗显示
 */
- (void)hide
{
    //关闭按钮从预览view上移除
    [_closeBtn removeFromSuperview];
    
    [_localView removeFromSuperview];
    [((TRTCVideoView*)_localView) showNetworkIndicatorImage:YES];     //显示网络标示


    for (TRTCVideoView* view in _remoteViewDic.allValues) {
        [view showNetworkIndicatorImage:YES];     //显示网络标示
        [view showAudioVolume:YES];    //显示音量标示
        [view removeFromSuperview];
    }
}

/**
 * 关闭浮窗
 */
- (void)close
{
    [self closeBtnClick:nil];
}

/**
 * 顶层UINavigationController
 */
- (UINavigationController *)topNavigationController {
    UIWindow *window = [[UIApplication sharedApplication].delegate window];
    UIViewController *topViewController = [window rootViewController];
    while (true) {
        if (topViewController.presentedViewController) {
            topViewController = topViewController.presentedViewController;
        } else if ([topViewController isKindOfClass:[UINavigationController class]] && [(UINavigationController*)topViewController topViewController]) {
            topViewController = [(UINavigationController *)topViewController topViewController];
        } else if ([topViewController isKindOfClass:[UITabBarController class]]) {
            UITabBarController *tab = (UITabBarController *)topViewController;
            topViewController = tab.selectedViewController;
        } else {
            break;
        }
    }
    return topViewController.navigationController;
}

/**
 * 添加远端画面至浮窗去显示
 */
- (void)addAndRelayoutRemoteView
{
    int index = 0;
    for (TRTCVideoView *view in _remoteViewDic.allValues) {
        [view hideButtons:YES];
        [view showNetworkIndicatorImage:NO];
        [view showAudioVolume:NO];
        CGFloat width = (_localView.frame.size.width - 3) / 3;
        CGFloat height = width * 16 / 9;
        if (index < 3) {
            view.frame = CGRectMake(_localView.frame.size.width - width, _localView.frame.size.height - (index + 1) * (height + 1), width, height);
        }
        else if (index >= 3) {
            int fixIndex = index - 3;
            view.frame = CGRectMake(0, _localView.frame.size.height - (fixIndex + 1) * (height + 1), width, height);
        }
        index++;
        view.userInteractionEnabled = NO;
        [_localView addSubview:view];
    }
}

/**
 * 点击浮窗关闭按钮
 */
- (void)closeBtnClick:(UIButton*)button
{
    _isFloating = NO;
    //隐藏浮窗关清理资源持有
    [self hide];
    _localView = nil;
    _remoteViewDic = nil;
}

/**
 * 返回原界面
 */
- (void)backBtnClick:(UIButton*)button
{
    //隐藏浮窗
    [self hide];
    _localView = nil;
    _remoteViewDic = nil;
}

/**
 * 有用户进入当前视频房间
 */
- (void)onRemoteUserEnterRoom:(NSString *)userId {
    TRTCRenderViewKey *key = [_renderViewKeyManager getRenderViewKeyWithUid:userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId mainRoom:YES mainStream:YES];
    // 创建一个新的 View 用来显示新的一路画面
    TRTCVideoView *remoteView = [TRTCVideoView newVideoViewWithType:VideoViewType_Remote key:key delegate:nil];

    [_remoteViewDic setObject:remoteView forKey:[key getHash]];
    
    if (_enableCustomRender) {
        //使用自定义渲染
        [self.trtcCloudManager playCustomVideoOfUser:userId inView:remoteView];
    } else {
        //启动远程画面的解码和显示逻辑，FillMode 可以设置是否显示黑边
        [self.trtcCloudManager startRemoteView:userId streamType:TRTCVideoStreamTypeBig
                                          view:remoteView];
    }
    [self.trtcCloudManager setRemoteViewFillMode:userId mode:TRTCVideoFillMode_Fit];

    [self addAndRelayoutRemoteView];
}

/**
 * 有用户离开了当前视频房间
 */
- (void)onRemoteUserLeaveRoom:(NSString *)userId reason:(NSInteger)reason {
    NSArray<NSString *> *deletedKey = [_renderViewKeyManager unRegisterViewKey:userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId];
    for (NSString *viewKey in deletedKey) {
        UIView *view = [_remoteViewDic objectForKey:viewKey];
        if (view) {
            [view removeFromSuperview];
        }
    }
    [_remoteViewDic removeObjectsForKeys:deletedKey];
    [self addAndRelayoutRemoteView];
}

/**
 * 子房间有用户视频
 */
- (void)onSubRoomUserVideoAvailable:(NSString *)roomId userId:(NSString *)userId available:(BOOL)available {
    TRTCRenderViewKey *renderKey = [_renderViewKeyManager getRenderViewKeyWithUid:userId roomId:roomId.intValue strRoomId:nil mainRoom:NO mainStream:YES];
    // 创建一个新的 View 用来显示新的一路画面
    TRTCVideoView *remoteView = [TRTCVideoView newVideoViewWithType:VideoViewType_Remote key:renderKey delegate:nil];

    [_remoteViewDic setObject:remoteView forKey:[renderKey getHash]];
    
    if (_enableCustomRender) {
        //使用自定义渲染
        [self.trtcCloudManager playCustomVideoOfUser:userId inView:remoteView];
    } else {
        //启动远程画面的解码和显示逻辑，FillMode 可以设置是否显示黑边
        [self.trtcCloudManager startRemoteView:userId streamType:TRTCVideoStreamTypeBig
                                          view:remoteView];
    }
    [self.trtcCloudManager setRemoteViewFillMode:userId mode:TRTCVideoFillMode_Fit];

    [self addAndRelayoutRemoteView];
}

@end
