//
//  ScreenPushViewController.m
//  TXLiteAVDemo
//
//  Created by rushanting on 2018/5/24.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "ScreenPushViewController.h"
#import "UIView+Additions.h"
#import "MBProgressHUD.h"
#import "TCHttpUtil.h"
#import "ScanQRController.h"
#import "ReplayKit2Define.h"
#ifndef DISABLE_VOD
#import "TXVodPlayer.h"
#endif
#import "TXLivePush.h"
#import "AddressBarController.h"
#import "AppDelegate.h"
#import <TXLiveBase.h>
#import <objc/message.h>

@interface ScreenPushViewController () <AddressBarControllerDelegate, ScanQRDelegate, TXLivePushListener
#ifndef DISABLE_VOD
, TXVodPlayListener
#endif
>
@property (nonatomic, retain) UISegmentedControl* rotateSelector;
@property (nonatomic, retain) UISegmentedControl* resolutionSelector;
@property (nonatomic, retain) UIButton* btnReplaykit;
@property (nonatomic, copy) NSString *playFlvUrl;
@property (nonatomic, retain) UIView* playerView;
@property (nonatomic, strong) TXLivePush *livePusher;
#ifndef DISABLE_VOD
@property (nonatomic, retain) TXVodPlayer* vodPlayer;
#endif
@property (nonatomic, retain) UIButton* playBtn;
@property (nonatomic, retain) UIButton* fullScreenBtn;
@property (nonatomic, strong) AddressBarController *addressBarController;

@end

@implementation ScreenPushViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _livePusher = [self createPusher];
    _livePusher.delegate = self;
    
    [self initUI];
}

// 创建推流器
- (TXLivePush *)createPusher {
    // config初始化
    TXLivePushConfig *config = [[TXLivePushConfig alloc] init];
    config.pauseFps = 10;
    config.pauseTime = 300;
    config.pauseImg = [UIImage imageNamed:@"pause_publish"];
    
    // 推流器初始化
    TXLivePush *pusher = [[TXLivePush alloc] initWithConfig:config];
    [pusher setVideoQuality:VIDEO_QUALITY_SUPER_DEFINITION adjustBitrate:YES adjustResolution:NO];
    
    // 修改软硬编需要在setVideoQuality之后设置config.enableHWAcceleration
    config.enableHWAcceleration = YES;
    [pusher setConfig:config];
    
    return pusher;
}

- (void)dealloc
{
    [self.livePusher stopPush];
#ifndef DISABLE_VOD
    [_vodPlayer stopPlay];
#endif
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = YES;
}


- (void)initUI
{
    //主界面排版
    self.title = @"录屏直播";
    
    //    self.view.backgroundColor = UIColor.blackColor;
    [self.view setBackgroundImage:[UIImage imageNamed:@"background.jpg"]];
    
    HelpBtnUI(录屏直播)
    
    _addressBarController = [[AddressBarController alloc] initWithButtonOption:AddressBarButtonOptionNew | AddressBarButtonOptionQRScan];
    _addressBarController.qrPresentView = self.view;
    CGSize size = [[UIScreen mainScreen] bounds].size;
    int ICON_SIZE = (int) (size.width / 11);
    CGFloat topOffset = [UIApplication sharedApplication].statusBarFrame.size.height;
    topOffset += self.navigationController.navigationBar.height+5;
    _addressBarController.view.frame = CGRectMake(10, topOffset, self.view.width-20, ICON_SIZE);
    _addressBarController.view.textField.placeholder = @"请地址扫描二维码或点New生成地址";
//    _addressBarController.view.textField.text = @"rtmp://2157.livepush.myqcloud.com/live/2157_rst2?bizid=2157&txSecret=ab575be22fc2b6a95335c0bb9247824e&txTime=5B4234FF";
    _addressBarController.delegate = self;
    [self.view addSubview:_addressBarController.view];
    
    NSArray* rotations = @[@"竖屏", @"横屏"];
    self.rotateSelector = [[UISegmentedControl alloc] initWithItems:rotations];
    self.rotateSelector.center = CGPointMake(self.view.center.x, _addressBarController.view.bottom + 60);
    self.rotateSelector.bounds = CGRectMake(0, 0, self.view.width - 100, 40);
    self.rotateSelector.tintColor = UIColor.whiteColor;
    self.rotateSelector.selectedSegmentIndex = 0;
    [self.view addSubview:self.rotateSelector];
    [self.rotateSelector addTarget:self action:@selector(onSwitchRotation:) forControlEvents:UIControlEventValueChanged];
    
    NSArray* resolutions = @[@"超清", @"高清", @"标清"];
    self.resolutionSelector = [[UISegmentedControl alloc] initWithItems:resolutions];
    self.resolutionSelector.center = CGPointMake(self.view.center.x, self.rotateSelector.bottom + 50);
    self.resolutionSelector.bounds = CGRectMake(0, 0, self.view.width - 100, 40);
    self.resolutionSelector.tintColor = UIColor.whiteColor;
    self.resolutionSelector.selectedSegmentIndex = 0;
    [self.resolutionSelector addTarget:self action:@selector(onSwitchResolution:) forControlEvents:UIControlEventValueChanged];

    [self.view addSubview:self.resolutionSelector];
    
    self.btnReplaykit = [UIButton buttonWithType:UIButtonTypeCustom];
    self.btnReplaykit .center = CGPointMake(self.view.center.x - 100, self.resolutionSelector.bottom + 60);
    self.btnReplaykit .bounds = CGRectMake(0, 0, 100, 50);
    self.btnReplaykit.backgroundColor = UIColor.lightTextColor;
    self.btnReplaykit.layer.cornerRadius = 5;
    
    [self.btnReplaykit  setTitle:@"开始推流" forState:UIControlStateNormal];
    [self.btnReplaykit  addTarget:self action:@selector(clickStartReplaykit:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.btnReplaykit];
    
    UIButton *micControlButton = [UIButton buttonWithType:UIButtonTypeCustom];
    micControlButton.center = CGPointMake(self.view.center.x + 100, self.resolutionSelector.bottom + 60);
    micControlButton.bounds = CGRectMake(0, 0, 100, 50);
    micControlButton.backgroundColor = UIColor.lightTextColor;
    micControlButton.layer.cornerRadius = 5;
    [micControlButton setTitle:@"静音人声采集" forState:UIControlStateNormal];
    [micControlButton setTitle:@"打开人声采集" forState:UIControlStateSelected];
    [micControlButton addTarget:self action:@selector(clickMicControlButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:micControlButton];

    UILabel* labelTipTitle = [[UILabel alloc] initWithFrame:CGRectMake(10, self.btnReplaykit.bottom + 20, 200, 15)];
    labelTipTitle.textAlignment = NSTextAlignmentLeft;
    labelTipTitle.text = @"屏幕录制操作说明:";
    labelTipTitle.textColor = UIColor.whiteColor;
    [labelTipTitle sizeToFit];
    [self.view addSubview:labelTipTitle];
    UILabel* labelTip = [[UILabel alloc] initWithFrame:CGRectMake(10, labelTipTitle.bottom - 12 , self.view.width - self.rotateSelector.left - 20, 100)];
    labelTip.numberOfLines = 3;
    labelTip.textAlignment = NSTextAlignmentLeft;
    labelTip.textColor = UIColor.whiteColor;
    labelTip.font = [UIFont systemFontOfSize:14];
    labelTip.text = @"      请先到控制中心长按启动屏幕录制(若无此项请从设置中的控制中心里添加)->选择视频云工具包启动后再回到此界面开始推流:";
    NSMutableAttributedString *attributedString = [[NSMutableAttributedString alloc] initWithString:labelTip.text];
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
    [paragraphStyle setLineSpacing:6.f];//设置行间距
    [attributedString addAttribute:NSParagraphStyleAttributeName value:paragraphStyle range:NSMakeRange(0, labelTip.text.length)];
    labelTip.attributedText = attributedString;
    [self.view addSubview:labelTip];
    
    _playerView = [UIView new];
    _playerView.bounds = CGRectMake(0, 0, self.view.width, self.view.width * 9 / 16);
    _playerView.center = CGPointMake(self.view.center.x, self.view.bottom - self.view.width * 9 / 16 / 2);
    [self.view addSubview:_playerView];
    
    _playBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_playBtn setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
    [_playBtn addTarget:self action:@selector(onPlayBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    _playBtn.center = CGPointMake(_playerView.width / 2, _playerView.height / 2);
    _playBtn.bounds = CGRectMake(0, 0, 40, 40);
    [_playerView addSubview:_playBtn];
    
    _fullScreenBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [_fullScreenBtn setImage:[UIImage imageNamed:@"player_fullscreen"] forState:UIControlStateNormal];
    _fullScreenBtn.frame = CGRectMake(_playerView.width - 40, _playerView.height - 40, 40, 40);
//    _fullScreenBtn.backgroundColor = UIColor.redColor;
    [_fullScreenBtn addTarget:self action:@selector(onFullScreenClicked:) forControlEvents:UIControlEventTouchUpInside];
    [_playerView addSubview:_fullScreenBtn];
#ifndef DISABLE_VOD
    //播放演示视频
    _vodPlayer = [TXVodPlayer new];
    [_vodPlayer setIsAutoPlay:YES];
//    [_vodPlayer setLoop:YES];
    [_vodPlayer setupVideoWidget:_playerView insertIndex:0];
   // [_vodPlayer startPlay:@"http://1252463788.vod2.myqcloud.com/95576ef5vodtransgzp1252463788/1bfa444e7447398156520498412/v.f30.mp4"];
    float sdkVersion = [TXLiveBase getSDKVersionStr].floatValue;
    NSString *selString = @"startPlay:";
    if (sdkVersion > 10.7) {
        selString = @"startVodPlay:";
    
    }
    int result = ((int (*) (id, SEL, NSString *) )objc_msgSend) (_vodPlayer,
    NSSelectorFromString(selString),@"http://1252463788.vod2.myqcloud.com/95576ef5vodtransgzp1252463788/1bfa444e7447398156520498412/v.f30.mp4");
    _vodPlayer.vodDelegate = self;
#endif
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)onPlayBtnClicked:(UIButton*)button
{
#ifndef DISABLE_VOD

    if (_vodPlayer.isPlaying) {
        [_playBtn setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
        [_vodPlayer pause];
    }
    else {
        [_playBtn setImage:[UIImage imageNamed:@"suspend"] forState:UIControlStateNormal];
        [_vodPlayer resume];
    }
#endif

}

- (void)onFullScreenClicked:(UIButton*)button
{
#ifndef DISABLE_VOD

    if (_playerView.height != self.view.height) {
        _playerView.frame = self.view.bounds;
        [_vodPlayer setRenderRotation:HOME_ORIENTATION_RIGHT];
        _playBtn.center = self.view.center;
        _fullScreenBtn.frame = CGRectMake(_playerView.width - 40, _playerView.height - 40, 40, 40);
        _playBtn.transform = CGAffineTransformMakeRotation(M_PI / 2);
    }
    else {
        _playerView.bounds = CGRectMake(0, 0, self.view.width, self.view.width * 9 / 16);
        _playerView.center = CGPointMake(self.view.center.x, self.view.bottom - self.view.width * 9 / 16 / 2);
        _fullScreenBtn.frame = CGRectMake(_playerView.width - 40, _playerView.height - 40, 40, 40);
        _playBtn.center = CGPointMake(_playerView.width / 2, _playerView.height / 2);
        _playBtn.bounds = CGRectMake(0, 0, 40, 40);
        _playBtn.transform = CGAffineTransformIdentity;
        [_vodPlayer setRenderRotation:HOME_ORIENTATION_DOWN];
    }
#endif

}

- (void)addressBarControllerTapScanQR:(AddressBarController *)controller {

    ScanQRController *vc = [[ScanQRController alloc] init];
    vc.delegate = self;
    [self.navigationController pushViewController:vc animated:NO];
}

- (void)addressBarControllerTapCreateURL:(AddressBarController *)controller
{

    MBProgressHUD* hub = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    hub.mode = MBProgressHUDModeIndeterminate;
    hub.label.text = @"地址获取中";
    [hub showAnimated:YES];
    __weak ScreenPushViewController* weakSelf = self;
    [TCHttpUtil asyncSendHttpRequest:@"get_test_pushurl" httpServerAddr:kHttpServerAddr HTTPMethod:@"GET" param:nil handler:^(int result, NSDictionary *resultDict) {
        if (result != 0)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
//                _hub = [MBProgressHUD HUDForView:weakSelf.view];
                hub.mode = MBProgressHUDModeText;
                hub.label.text = @"获取推流地址失败";
                [hub showAnimated:YES];
                [hub hideAnimated:YES afterDelay:2];
            });
        }
        else
        {
            NSString* pusherUrl = nil;
            NSString* rtmpPlayUrl = nil;
            NSString* flvPlayUrl = nil;
            NSString* hlsPlayUrl = nil;
            NSString* accPlayUrl = nil;
            if (resultDict)
            {
                pusherUrl = resultDict[@"url_push"];
                rtmpPlayUrl = resultDict[@"url_play_rtmp"];
                flvPlayUrl = resultDict[@"url_play_flv"];
                hlsPlayUrl = resultDict[@"url_play_hls"];
                accPlayUrl = resultDict[@"url_play_acc"];
            }
            controller.text = pusherUrl;
            NSString *(^c)(NSString *x, NSString *y) = ^(NSString *x, NSString *y) {
                return [NSString stringWithFormat:@"%@,%@", x, y];
            };
            controller.qrStrings = @[c(@"rtmp", rtmpPlayUrl),
                                     c(@"flv", flvPlayUrl),
                                     c(@"hls", hlsPlayUrl),
                                     c(@"低延时", accPlayUrl)];
            NSString* playUrls = [NSString stringWithFormat:@"rtmp播放地址:%@\n\nflv播放地址:%@\n\nhls播放地址:%@\n\n低延时播放地址:%@", rtmpPlayUrl, flvPlayUrl, hlsPlayUrl, accPlayUrl];
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = playUrls;
            weakSelf.playFlvUrl = flvPlayUrl;
            dispatch_async(dispatch_get_main_queue(), ^{
//                _hub = [MBProgressHUD HUDForView:weakSelf.view];
                hub.mode = MBProgressHUDModeText;
                hub.label.text = @"获取地址成功";
                hub.detailsLabel.text = @"播放地址已复制到剪贴板";
                [hub showAnimated:YES];
                [hub hideAnimated:YES afterDelay:2];
//                controller.qrString = accPlayUrl;
            });
        }
    }];
}

- (void)clickMicControlButton:(UIButton *)btn {
    btn.selected = !btn.selected;
    // 录屏直播静音人声采集，需要采用设置音量的方式。
    // APP音量是通过mix到麦克风采集的声音中去，直接mute麦克风，会导致APP内部声音播放也被静音
    [[self.livePusher getAudioEffectManager] setVoiceVolume:btn.selected ? 0 : 100];
}

- (void)clickStartReplaykit:(UIButton*)btn
{
    if ([UIDevice currentDevice].systemVersion.floatValue < 11.0) {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"腾讯云录屏推流" message:@"录屏只支持iOS11以上系统，请升级！" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* action1 = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:action1];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    if (self.addressBarController.text.length < 1) {
        NSString* message = @"请输入推流地址";
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"腾讯云录屏推流" message:message preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* action1 = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:action1];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    NSString* btntitle = btn.currentTitle;
    BOOL isStart = [btntitle isEqualToString:@"开始推流"];
    
    if (isStart) {
        BOOL isCaptured = NO;
        if (@available(iOS 11, *)) {
            isCaptured = [UIScreen mainScreen].isCaptured;
        }
        if (!isCaptured) {
            NSString* message = @"请先到控制中心->长按启动屏幕录制";

            UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"腾讯云录屏推流" message:message preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* action1 = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            }];
            UIAlertAction* action2 = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:action1];
            [alert addAction:action2];
            [self presentViewController:alert animated:YES completion:nil];
            return;
        }
        else {
            UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"腾讯云录屏推流" message:@"确定要开启屏幕录制推流?" preferredStyle:UIAlertControllerStyleAlert];
            UIAlertAction* action1 = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                if (@available(iOS 11.0, *)) {
                    [self.livePusher startScreenCaptureByReplaykit:kReplayKit2AppGroupId];
                }
                [self refreshResolutionAndRotation];
                [self.livePusher startPush:self.addressBarController.text];
                [btn setTitle:@"结束推流" forState:UIControlStateNormal];
            }];
            UIAlertAction *action2 = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:nil];
            [alert addAction:action1];
            [alert addAction:action2];
            [self presentViewController:alert animated:YES completion:nil];
        }
    }
    else {
        UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"腾讯云录屏推流" message:@"确定要关闭录屏推流?" preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction* action1 = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            [self.livePusher stopPush];
            [btn setTitle:@"开始推流" forState:UIControlStateNormal];
        }];
        UIAlertAction *action2 = [UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleDefault handler:nil];
        [alert addAction:action1];
        [alert addAction:action2];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (void)onSwitchRotation:(UISegmentedControl*)segment
{
    [self refreshResolutionAndRotation];
}

- (void)onSwitchResolution:(UISegmentedControl*)segment
{
    [self refreshResolutionAndRotation];
}

- (void)refreshResolutionAndRotation
{
    TXLivePushConfig *config = self.livePusher.config;
    config.homeOrientation = HOME_ORIENTATION_DOWN;
    
    if (2 == self.resolutionSelector.selectedSegmentIndex) {
        config.videoResolution = VIDEO_RESOLUTION_TYPE_360_640;
        config.videoBitrateMin = 400;
        config.videoBitratePIN = 800;
        config.videoBitrateMax = 1200;
        config.videoFPS = 20;
    } else if (1 == self.resolutionSelector.selectedSegmentIndex) {
        config.videoResolution = VIDEO_RESOLUTION_TYPE_540_960;
        config.videoBitrateMin = 800;
        config.videoBitratePIN = 1400;
        config.videoBitrateMax = 1800;
        config.videoFPS = 24;
    } else {
        config.videoResolution = VIDEO_RESOLUTION_TYPE_720_1280;
        config.videoBitrateMin = 1600;
        config.videoBitratePIN = 2400;
        config.videoBitrateMax = 3000;
        config.videoFPS = 48;
    }
    if (self.rotateSelector.selectedSegmentIndex) {
        config.homeOrientation = HOME_ORIENTATION_RIGHT;
    }
    [self.livePusher setConfig:config];
}

#ifndef DISABLE_VOD
#pragma mark - VodDelegate

- (void)onPlayEvent:(TXVodPlayer *)player event:(int)EvtID withParam:(NSDictionary*)param {
    if (EvtID == PLAY_EVT_PLAY_END) {
        [_playBtn setImage:[UIImage imageNamed:@"start"] forState:UIControlStateNormal];
        [_vodPlayer pause];
    } else if (EvtID == PLAY_EVT_RCV_FIRST_I_FRAME) {
        [_vodPlayer pause];
    }
}

- (void)onNetStatus:(TXVodPlayer *)player withParam:(NSDictionary*)param {
}
#endif

#pragma mark - ScanQRDelegate

- (void)onScanResult:(NSString *)result {
    self.addressBarController.text = result;
}

#pragma mark - tool func
- (NSString *)dictionary2JsonString:(NSDictionary *)dict {
    // 转成Json数据
    if ([NSJSONSerialization isValidJSONObject:dict]) {
        NSError *error = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
        if(error) {
            NSLog(@"[%@] Post Json Error", [self class]);
        }
        NSString* jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return jsonString;
    } else {
        NSLog(@"[%@] Post Json is not valid", [self class]);
    }
    return nil;
}

#pragma mark - TXLivePushListener

- (void)onPushEvent:(int)EvtID withParam:(NSDictionary *)param {
}

- (void)onNetStatus:(NSDictionary *)param {
}

- (void)onScreenCaptureStarted {
}

- (void)onScreenCapturePaused:(int)reason {
}

- (void)onScreenCaptureResumed:(int)reason {
}

- (void)onScreenCaptureStoped:(int)reason {
    [self.livePusher stopPush];
    [_btnReplaykit setTitle:@"开始推流" forState:UIControlStateNormal];
}

@end
