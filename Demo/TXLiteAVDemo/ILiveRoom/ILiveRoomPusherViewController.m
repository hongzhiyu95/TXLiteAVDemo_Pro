//
//  ILiveRoomPusherViewController.m
//  TXLiteAVDemo
//
//  Created by lijie on 2018/9/14.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>
#import "ILiveRoomPusherViewController.h"
#import "UIView+Additions.h"
#import "ColorMacro.h"
#import "UIViewController+BackButtonHandler.h"
#import "ILiveRoomListViewController.h"
#import "ILiveRoomDef.h"
#import "ILiveRoomLogView.h"
#import "iLiveVideoCapture.h"
#import "iLiveBGMControl.h"
#import "iLiveEffectControl.h"
#import "iLiveMVReader.h"
#import "iLiveRenderView.h"
#import "TCHttpUtil.h"
#import "QRCode.h"
#import <CommonCrypto/CommonDigest.h>


@interface ILiveRoomPusherViewController () <TXILiveRoomDelegateAdapter,
TXILiveRoomAudioDelegateAdapter,
ILiveRoomLogViewDelegate,
ILiveVideoCaptureDelegate,
iLiveBGMControlDelegate,
iLiveEffectControlDelegate>
{
    UIView                   *_fullScreenView;
    NSMutableDictionary      *_playerViewDic;  // 小主播的画面，[userId, view]
    
    __weak IBOutlet UIButton *_btnSwitchRole;
    __weak IBOutlet UIButton *_btnPK;
    __weak IBOutlet UIButton *_btnMuteVideo;
    __weak IBOutlet UIButton *_btnMuteAudio;
    __weak IBOutlet UIButton *_btnSwitchHighCapture;
    __weak IBOutlet UIButton *_btnAutoSEI;
    __weak IBOutlet UIButton *_btnEarback;
    __weak IBOutlet UIButton *_btnCDNAddr;
    __weak IBOutlet UIButton *_btnTingtong;
    __weak IBOutlet UIButton *_btnSwitchCapture;
    
    __weak IBOutlet UIImageView *_ivSideFiv;
    __weak IBOutlet UIImageView *_ivPublishCDN;
    
    BOOL                     _mute_switch;
    BOOL                     _pure_switch;
    BOOL                     _muteAllRemoteAudio;
    BOOL                     _muteAllRemoteVideo;
    BOOL                     _isPK;
    
    BOOL                     _appIsInActive;
    BOOL                     _appIsBackground;
    BOOL                     _hasPendingRequest;
    BOOL                     _startMixAudio;
    BOOL                     _muteAllLocalAudio;
    
    UITextView               *_logView;
    UIView                   *_coverView;
    NSInteger                _log_switch;  // 0:隐藏log  1:显示SDK内部的log  2:显示业务层log
    
    CGPoint                  _touchBeginLocation;
    UIView                   *_touchPlayerView;
    UIView                   *_touchPlayerItemView;
    UITextView               *_toastView;
    
    ILiveRoomStatus          _roomStatus;
    ILiveRoomLogView         *_roomLogView;
    iLiveVideoCapture        *_videoCapture;
    iLiveBGMControl          *_iLiveBGMControl;
    iLiveEffectControl       *_iLiveEffectControl;
    iLiveMVReader            *_iLiveMVReader;
    iLiveRenderView          *_pusherRenderView;
    UILabel                  *_pusherVolumeLabel;
    dispatch_queue_t         _videoReadQueue;
    dispatch_queue_t         _audioReadQueue;
    NSMutableData            *_audioPlayBufferList;
    NSMutableData            *_audioSendBufferList;
    NSMutableArray           *_videoBufferList;
    UInt64                   _audioSendBufferLen;
    BOOL                     _audioReadFinished;
    BOOL                     _isMixLandscape;
    BOOL                     _loopSendHostMsg;       // 循环发送大主播的 SEI 消息
    BOOL                     _loopSendSEIMsg;        // 循环发送 SEI 消息
    BOOL                     _loopQueryAVStatistic; // 循环查询音视频统计数据
    
    NSMutableArray<NSNumber*> *_broadcasterArray; // 存放主播Id的，后续用于触发混流
    NSInteger                _volumeViewTag;
    
    NSString                 *_lastPkRoomName;
    NSString                 *_lastPKUserId;
}

@property (nonatomic, strong) OneSecAdapter        *iLiveRoom;

@end

@implementation ILiveRoomPusherViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    _volumeViewTag = 10086;
    _lastPkRoomName = @"";
    _lastPKUserId = @"";
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidEnterBackGround:) name:UIApplicationDidEnterBackgroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillEnterForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    
   
    if(_cdnURL != nil && [_cdnURL length] > 0) {
        _ivPublishCDN.image = [QRCode qrCodeWithString:_playURL size:_ivPublishCDN.frame.size];
        _ivPublishCDN.hidden = YES;
    }
    
    NSString *sideFlv = [NSString stringWithFormat:@"http://%d.liveplay.myqcloud.com/live/%@.flv",_bizId, [self getStreamId:[NSString stringWithFormat:@"%@_%u", _roomName, _roomId] userId:[NSString stringWithFormat:@"%llu", _userId]]];
    NSLog(@"%@", sideFlv);
    _ivSideFiv.image = [QRCode qrCodeWithString:sideFlv size:_ivSideFiv.frame.size];
    _ivSideFiv.hidden = YES;
    
    
    _playerViewDic = [[NSMutableDictionary alloc] init];
    
    _iLiveRoom = [[OneSecAdapter alloc] initWithSdkAppId:self.sdkAppId userId:self.userId];
    [_iLiveRoom setDelegate:self];
    [_iLiveRoom setAudioDelegate:self];
    
    _videoCapture = [[iLiveVideoCapture alloc] init];
    _videoCapture.delegate = self;
    
    _iLiveMVReader = [[iLiveMVReader alloc] initWithMP4PathAsset:[[NSBundle mainBundle] pathForResource:@"testMV" ofType:@"mp4"] videoReadFormat:VideoReadFormat_NV12];
    _audioSendBufferList = [NSMutableData data];
    _audioPlayBufferList = [NSMutableData data];
    _videoBufferList = [NSMutableArray array];
    _audioSendBufferLen = 0;
    _broadcasterArray = @[].mutableCopy;
    
    dispatch_queue_attr_t attr = NULL;
#if TARGET_OS_IPHONE
    if ([[[UIDevice currentDevice] systemVersion] compare:@"9.0" options:NSNumericSearch] != NSOrderedAscending)
    {
        attr = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_DEFAULT, 0);
    }
#endif
    _videoReadQueue = dispatch_queue_create("__ilivepusher_videoReadQueue__", attr);
    _audioReadQueue = dispatch_queue_create("__ilivepusher_audioReadQueue__", attr);
    
    _roomStatus = ILiveRoom_IDLE;
    _appIsInActive = NO;
    _appIsBackground = NO;
    _hasPendingRequest = NO;
        
    _btnSwitchCapture.tag = 1;

    [self sendHeadBeat];
    [self initUI];
    [self enterRoom];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSLog(@"ILiveRoomPusherViewController dealloc");
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.navigationController.navigationBar.hidden = NO;
    self.navigationController.interactivePopGestureRecognizer.enabled = NO;
}

/**
 * 检查当前APP是否已经获得摄像头和麦克风权限，没有获取边提示用户开启权限
 */
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
#if !TARGET_IPHONE_SIMULATOR
    //是否有摄像头权限
    AVAuthorizationStatus statusVideo = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (statusVideo == AVAuthorizationStatusDenied) {
        [self alertTips:@"提示" msg:@"获取摄像头权限失败，请前往隐私-相机设置里面打开应用权限" completion:^{
            [_iLiveRoom quitRoom];
            [self.navigationController popViewControllerAnimated:YES];
        }];
    }
    
    //是否有麦克风权限
    AVAuthorizationStatus statusAudio = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (statusAudio == AVAuthorizationStatusDenied) {
        [self alertTips:@"提示" msg:@"获取麦克风权限失败，请前往隐私-麦克风设置里面打开应用权限" completion:^{
            [_iLiveRoom quitRoom];
            [self.navigationController popViewControllerAnimated:YES];
        }];
    }
#endif
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    self.navigationController.navigationBar.hidden = YES;
    self.navigationController.interactivePopGestureRecognizer.enabled = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self quitAndClean];
}

- (void) quitAndClean {
    if (_userId == _hostUserId) {
        [[ILiveRoomService sharedInstance] deleteRoom:self.roomId success:^(NSInteger code, NSString *msg) {
        } fail:^(NSError * _Nonnull error) {
        }];
    }
    [_iLiveRoom stopPublishCDNStream];
    [_iLiveRoom clearMixTranscodingConfig];
    [_iLiveRoom stopMusic];
    [_iLiveRoom stopAllEffect];
    [_iLiveRoom quitRoom];
    [self stopMV];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
    _loopSendSEIMsg = NO;
    _loopQueryAVStatistic = NO;
    _loopSendHostMsg = NO;
}

- (void)initUI {
    self.title = [NSString stringWithFormat:@"%@_%u", _roomName, _roomId];
    [self.view setBackgroundColor:UIColorFromRGB(0x333333)];
    
    CGSize size = [[UIScreen mainScreen] bounds].size;
    
    // log按钮
    
    // LOG界面
    _log_switch = 0;
    _logView = [[UITextView alloc] initWithFrame:CGRectMake(0, 80*kScaleY, size.width, size.height - 150*kScaleY)];
    _logView.backgroundColor = [UIColor clearColor];
    _logView.alpha = 1;
    _logView.textColor = [UIColor whiteColor];
    _logView.editable = NO;
    _logView.hidden = YES;
    [self.view addSubview:_logView];
    
    // 半透明浮层，用于方便查看log
    _coverView = [[UIView alloc] init];
    _coverView.frame = _logView.frame;
    _coverView.backgroundColor = [UIColor whiteColor];
    _coverView.alpha = 0.5;
    _coverView.hidden = YES;
    [self.view addSubview:_coverView];
    [self.view sendSubviewToBack:_coverView];
    
    //BGM Control
    _iLiveBGMControl = [[iLiveBGMControl alloc] initWithFrame:CGRectMake(0, 150, self.view.width, 200)];
    _iLiveBGMControl.hidden = YES;
    _iLiveBGMControl.delegate = self;
    [self.view addSubview:_iLiveBGMControl];

    
    //Effect Control
    _iLiveEffectControl = [[iLiveEffectControl alloc] initWithFrame:CGRectMake(0, 150, self.view.width, 130)];
    _iLiveEffectControl.hidden = YES;
    _iLiveEffectControl.delegate = self;
    [self.view addSubview:_iLiveEffectControl];
    
    // 提示
    _toastView = [[UITextView alloc] init];
    _toastView.editable = NO;
    _toastView.selectable = NO;
    
//    // 开启推流和本地预览
    _fullScreenView = [[UIView alloc] initWithFrame:self.view.frame];
    [_fullScreenView setBackgroundColor:UIColorFromRGB(0x262626)];
    _fullScreenView.tag = _hostUserId;
    [self.view insertSubview:_fullScreenView atIndex:0];
    UILabel *volumeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0,0, 200, 100)];
    volumeLabel.tag = _volumeViewTag;
    volumeLabel.textColor = UIColor.whiteColor;
    _pusherRenderView = [[iLiveRenderView alloc] initWithFrame:_fullScreenView.bounds];
     [_fullScreenView addSubview:_pusherRenderView];
    [_fullScreenView addSubview:volumeLabel];
    
    _roomLogView = [[ILiveRoomLogView alloc] initWithParentController:self];
    [_roomLogView addEventStatusItem:_userId];
    _roomLogView.delegate = self;
    
    if (_isBroadcaster) {
        _btnSwitchRole.hidden = YES;
    }
    [self updateBroadcasterLayout];
}

- (void)updateBroadcasterLayout {
    BOOL show = !_isBroadcaster;
    _btnPK.hidden = show;
    _btnMuteVideo.hidden = show;
    _btnMuteAudio.hidden = show;
    _btnSwitchHighCapture.hidden = show;
    _btnAutoSEI.hidden = show;
    _btnEarback.hidden = show;
    _btnTingtong.hidden = show;
    _btnCDNAddr.hidden = show;
}

- (void)relayout {
    // 重新布局小主播的画面
    int index = 0;
    int originX = self.view.width - 110;
    int originY = self.view.height - 200;
    int videoViewWidth = 100;
    int videoViewHeight = 150;
    
    _fullScreenView.frame = CGRectMake(0, 0, self.view.width, self.view.height);
    
    for (id userId in _playerViewDic) {
        UIView *playerView = [_playerViewDic objectForKey:userId];
        CGFloat x = originX;
        CGFloat y = originY - videoViewHeight * index;
        if (y < 0) {
            x = x - videoViewWidth - 20 * index;
            y = originY;
        }
        playerView.frame = CGRectMake(x, y, videoViewWidth, videoViewHeight);
        ++ index;
    }
}

- (void)enterRoom {
    OneSecAdapterParams *params = [[OneSecAdapterParams alloc] init];
    params.roomName = [NSString stringWithFormat:@"%@_%u", self.roomName, self.roomId];
    params.privateMap = self.privateMap;
    params.privateMapKey = self.privateMapKey;
    params.roomRole =  _isBroadcaster ? TXILiveRoomRoleBroadcaster : TXILiveRoomRoleAudience;
    params.appId = self.appId;
    params.sdkAppId = self.sdkAppId;
    params.bizId = self.bizId;
    params.userId = self.userId;
    params.userSig = self.userSig;
    params.roomScenario = TXILiveRoomScenarioLive;
    
    TXILiveRoomConfig *config = [[TXILiveRoomConfig alloc] init]; // 使用默认值即可
    config.pauseImg = [UIImage imageNamed:@"pause_publish.jpg"];
    config.videoResolution = TXILIVEROOM_VIDEO_RESOLUTION_TYPE_540_960;
    config.videoBitrate = 1000;
    config.autoSampleBufferSize = NO;
    // MV模式，使用自定义视频数据，其他情况使用SDK采集的视频
    if (_pushType == PushType_MV) {
        config.customModeType = TXILiveRoomCustomModeTypeVideo;
        config.sampleBufferSize = CGSizeMake(368, 640);
    } else {
        config.customModeType = TXILiveRoomCustomModeTypeNone;
    }
    
    if (_pushType == PushType_Camera) {
        config.videoFps = 15;
    }else{
        config.videoFps = _iLiveMVReader.fps;
    }
    config.audioEncQuality = self.audioEncQualityIndex;
    

    
    [self appendLog:_userId msg:[NSString stringWithFormat:@"version %@", [OneSecAdapter getSDKVersionStr]]];
    [self appendLog:_userId msg:@"开始进房"];
    
    // 进房带转推CDN，进房前优先调用转推CDN
    if (_isBroadcaster) {
        if(self.isEnterRoomWithCDN) {
            [_iLiveRoom startPublishCDNStream:self.cdnURL];
        }
        if (_enableSmallStream) {
            [_iLiveRoom enableEncSmallVideoStream:_enableSmallStream videoSize:CGSizeMake(192, 320) videoFps:config.videoFps videoBitrate:config.videoBitrate / 2];
        }
    }
    [_iLiveRoom joinRoom:params config:config];
}

- (void)hideToolButtons:(BOOL)bHide {

}

- (IBAction)onClickSwitchRole:(UIButton *)sender {
    _isBroadcaster = !_isBroadcaster;
    if (_isBroadcaster) {
        [_iLiveRoom switchRole:TXILiveRoomRoleBroadcaster];
        [_iLiveRoom enableAudioPreview:YES];
    } else {
        [_iLiveRoom switchRole:TXILiveRoomRoleAudience];
    }
    [self updateBroadcasterLayout];
}

- (IBAction)clickSendSEI:(UIButton *)btn {
    if (btn.tag == 0) {
        btn.tag = 1;
        [self toastTip:@"启动自动发送SEI" time:1];
        _loopSendSEIMsg = YES;
        [self sendCustomMsgLoop];
    } else {
        [self toastTip:@"关闭自动发送SEI" time:1];
        btn.tag = 0;
        _loopSendSEIMsg = NO;
    }
}

- (void)sendCustomMsgLoop {
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5.0/*延迟执行时间*/ * NSEC_PER_SEC));
    dispatch_after(delayTime, dispatch_get_main_queue(), ^{
        if (_loopSendSEIMsg && _iLiveRoom) {
            [_iLiveRoom sendStreamMessage:1 data:[@"stream msg from ios" dataUsingEncoding:NSUTF8StringEncoding] reliable: YES ordered:YES];
            [_iLiveRoom sendMessageEx:[@"sei msg from ios" dataUsingEncoding:NSUTF8StringEncoding]];
            [self sendCustomMsgLoop];
        }
    });
}

- (IBAction)clickAVStatistic:(UIButton *)btn {
    if (btn.tag == 0) {
        btn.tag = 1;
        [self toastTip:@"启动自动查询音视频数据" time:1];
        _loopQueryAVStatistic = YES;
        [self queryAVStatistic];
    } else {
        [self toastTip:@"关闭自动查询音视频数据" time:1];
        btn.tag = 0;
        _loopQueryAVStatistic = NO;
    }
}

- (void)queryAVStatistic {
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0/*延迟执行时间*/ * NSEC_PER_SEC));
    dispatch_after(delayTime, dispatch_get_main_queue(), ^{
        if (_loopQueryAVStatistic && _iLiveRoom) {
            TXILiveRoomAVStatistic *statistic = [_iLiveRoom getAVStatistic];
            if (statistic != nil) {
                for (int i = 0; i < [statistic.userAVStatistics count]; i++) {
                    TXILiveRoomUserAVStatistic *userStatistic = [statistic.userAVStatistics objectAtIndex:i];
                    NSString *log = @"";
                    if (userStatistic.userId == _userId) {
                        // 说明我是我自己
                         log = [NSString stringWithFormat:@"TotalAudio: %ld TotalVideo: %ld \n CapAudio: %ld EncAudio: %ld EncVideo: %ld EncFrameCount: %ld", userStatistic.audioTotalBytes,userStatistic.videoTotalBytes, statistic.audioCapTotalBytes, statistic.audioEncTotalBytes, statistic.videoEncTotalBytes, statistic.videoEncFrameTotalCount];
                    } else {
                        // 远端流
                        log = [NSString stringWithFormat:@"TotalAudio: %ld TotalVideo: %ld", userStatistic.audioTotalBytes,userStatistic.videoTotalBytes];
                    }
                    [_roomLogView addAVStatistic:userStatistic.userId status:log];
                }
            }
            [self queryAVStatistic];
        }
    });
}

- (IBAction)onClickEarBack:(UIButton *)btn {
    if (btn.tag == 0) {
        btn.tag = 1;
        [_iLiveRoom enableAudioPreview:NO];
        [self toastTip:@"关闭耳返" time:1];
    } else {
        btn.tag = 0;
        [_iLiveRoom enableAudioPreview:YES];
        [self toastTip:@"开启耳返" time:1];
    }
}

// 静音
- (IBAction)onClickMuteLocalAudio:(UIButton *)btn {
    if (btn.tag == 0) {
        btn.tag = 1;
        [_iLiveRoom muteLocalAudio:YES];
        [self toastTip:@"关闭音频上行" time:1];
    } else {
        btn.tag = 0;
        [_iLiveRoom muteLocalAudio:NO];
        [self toastTip:@"开启音频上行" time:1];
    }
}

//静画
- (IBAction)onClickMuteLocalVideo:(UIButton *)btn {
    if (btn.tag == 0) {
        btn.tag = 1;
        [_iLiveRoom muteLocalVideo:YES];
        [self toastTip:@"关闭视频上行" time:1];
    } else {
        btn.tag = 0;
        [_iLiveRoom muteLocalVideo:NO];
        [self toastTip:@"开启视频上行" time:1];
    }
}

- (void)onShowPlayerView:(uint64_t)userId {
    [self setPlayerViewHighlight:userId];
}

- (IBAction)onClickLog:(UIButton *)btn {
    if (btn.tag == 0) {
        btn.tag = 1;
        _roomLogView.hidden = NO;
        [self setPlayerViewHighlight:-1];
    }
    else {
        btn.tag = 0;
        _roomLogView.hidden = YES;
    }
    [_roomLogView freshCurrentEvtStatusView];
}

- (IBAction)onClickTingtong:(UIButton *)sender {
    if (sender.tag == 0) {
        sender.tag = 1;
        [_iLiveRoom setAudioMode:TXILiveRoomAudioModeEarpiece];
    } else {
        sender.tag = 0;
        [_iLiveRoom setAudioMode:TXILiveRoomAudioModeSpeakerphone];
    }
}

- (IBAction)clickBGM:(UIButton *)btn {
    _iLiveBGMControl.hidden = !_iLiveBGMControl.hidden;
}

- (IBAction)clickEffect:(UIButton *)btn {
    _iLiveEffectControl.hidden = !_iLiveEffectControl.hidden;
}

- (IBAction)clickMuteAllRemoteAudio:(UIButton *)btn {
    if (btn.tag == 0) {
        btn.tag = 1;
        [_iLiveRoom muteAllRemoteAudio:YES];
        [self toastTip:@"远端全部静音" time:1];
    } else {
        btn.tag = 0;
        [_iLiveRoom muteAllRemoteAudio:NO];
        [self toastTip:@"恢复远端全部声音" time:1];
    }
}

- (IBAction)clickMuteAllRemoteVideo:(UIButton *)btn {
    if (btn.tag == 0) {
        btn.tag = 1;
        [_iLiveRoom muteAllRemoteVideo:YES];
        [self toastTip:@"远端全部静画" time:1];
    } else {
        btn.tag = 0;
        [_iLiveRoom muteAllRemoteVideo:NO];
        [self toastTip:@"恢复远端全部画面" time:1];
    }
}

- (IBAction)clickChangeMixResolution:(UIButton *)btn {
    if (btn.tag == 0) {
        btn.tag = 1;
        [_iLiveRoom muteAllRemoteVideo:YES];
        [self toastTip:@"混流改为：横屏" time:1];
    } else {
        btn.tag = 0;
        [_iLiveRoom muteAllRemoteVideo:NO];
        [self toastTip:@"混流改为：竖屏" time:1];
    }
    [self doMix:btn.tag];
}

- (IBAction)clickMuteAllLocalAudio:(UIButton *)btn {
    if (btn.tag == 0) {
        btn.tag = 1;
        [_iLiveRoom setPlaybackVolume:0];
        [self toastTip:@"本地音量设置为：0" time:1];
    } else {
        btn.tag = 0;
        [_iLiveRoom setPlaybackVolume:1];
        [self toastTip:@"本地音量设置为：1" time:1];
    }
}

// 推流过程中修改分辨率，目前仅用于自定义数据采集
- (IBAction)clickChangeResolution:(UIButton *)btn {
    if (btn.tag == 0) {
        btn.tag = 1;
        [self toastTip:@"切换到高采集" time:1];
        [_iLiveRoom setCustomVideoParam: CGSizeMake(368, 640) videoBitrate:1000];
    } else {
        btn.tag = 0;
        [self toastTip:@"切换到低采集" time:1];
        [_iLiveRoom setCustomVideoParam: CGSizeMake(172, 196) videoBitrate:200];
    }
}

- (IBAction)clickAEC:(UIButton*)btn
{
    if (btn.tag == 0) {
        btn.tag = 1;
        [self toastTip:@"切换到媒体音量" time:1];
        [_iLiveRoom setVolumeType:TXILiveRoomAudioVolumeTypeMedia];
    } else if(btn.tag == 1){
        btn.tag = 2;
        [self toastTip:@"切换到自动音量，麦上通话麦下媒体" time:1];
        [_iLiveRoom setVolumeType:TXILiveRoomAudioVolumeTypeAuto];
    } else {
        btn.tag = 0;
        [self toastTip:@"切换到通话音量" time:1];
        [_iLiveRoom setVolumeType:TXILiveRoomAudioVolumeTypeCommunication];
    }
}

- (IBAction)clickChangeStream:(UIButton*)btn
{
    if (btn.tag == 0) {
        btn.tag = 1;
        [self toastTip:@"切换到小流" time:1];
        
        // 大主播切换流
        if(_userId != _hostUserId) {
            [_iLiveRoom setRemoteVideoStreamType:_hostUserId type:TXILiveRoomStreamTypeSmall];
        }
        
        // 小主播列表
        for (NSNumber* userId in _playerViewDic) {
            [_iLiveRoom setRemoteVideoStreamType:userId.unsignedLongLongValue type:TXILiveRoomStreamTypeSmall];
        }
    }
    else {
        btn.tag = 0;
        [self toastTip:@"切换到大流" time:1];
        
        // 大主播切换流
        if(_userId != _hostUserId) {
            [_iLiveRoom setRemoteVideoStreamType:_hostUserId type:TXILiveRoomStreamTypeBig];
        }
        
        for (NSNumber* userId in _playerViewDic) {
            [_iLiveRoom setRemoteVideoStreamType:userId.unsignedLongLongValue type:TXILiveRoomStreamTypeBig];
        }
    }
}

- (IBAction)clickPK:(UIButton *)btn {
    if (_isPK) {
        [_iLiveRoom disconnectOtherRoom];
        return;
    }
    
    UIAlertController *pkInputVC = [UIAlertController alertControllerWithTitle:@"PK输入" message:@"请输入相关信息" preferredStyle:UIAlertControllerStyleAlert];
    [pkInputVC addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"房间名";
        textField.text = self->_lastPkRoomName;
    }];
    [pkInputVC addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.placeholder = @"用户ID";
        textField.text = self->_lastPKUserId;
    }];
    
    __weak __typeof(self) weakSelf = self;
    [pkInputVC addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    [pkInputVC addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        NSArray<UITextField*>* textFields = pkInputVC.textFields;
        NSString* roomNameStr = textFields[0].text;
        NSString* userIdStr = textFields[1].text;
        self->_lastPkRoomName = roomNameStr;
        self->_lastPKUserId = userIdStr;
        if (!roomNameStr.length || !userIdStr.length) {
            [weakSelf toastTip:@"房间名和用户ID不能为空" time:2];
            return;
        }
        [weakSelf.iLiveRoom connectOtherRoom:roomNameStr userId:[userIdStr longLongValue]];
    }]];
    
    [self presentViewController:pkInputVC animated:YES completion:nil];
}

- (IBAction)onClickCDNURL:(UIButton *)sender {
    if(sender.tag == 0) {
        sender.tag = 1;
        _ivSideFiv.hidden = NO;
        _ivPublishCDN.hidden = NO;
    } else {
        sender.tag = 0;
        _ivSideFiv.hidden = YES;
        _ivPublishCDN.hidden = YES;
    }
}

#pragma mark iLiveBGMControlDelegate

-(void)onBgmPitchClick:(NSInteger)index
{
    [_iLiveRoom setMusicPitch:index];
}
-(void)onBgmStart:(BOOL)loopback loopTimes:(int)loopTimes type:(int)type
{
    [_iLiveRoom stopMusic];
    if (type == 2) {
        [_iLiveRoom playMusicWithUrl:@"http://bgm-1252463788.cosgz.myqcloud.com/Flo%20Rida%20-%20Whistle.mp3" loopback:loopback repeat:loopTimes];
    } else if (type == 0){
        [_iLiveRoom playMusicWithUrl:[[NSBundle mainBundle] pathForResource:@"Me" ofType:@"mp3"] loopback:loopback repeat:loopTimes];
    } else if (type == 1) {
        [_iLiveRoom playMusicWithUrl:[[NSBundle mainBundle] pathForResource:@"langrensha" ofType:@"mp3"] loopback:loopback repeat:loopTimes];
    }
}

-(void)onBgmStop
{
    [_iLiveRoom stopMusic];
}

-(void)onMicVolume:(float)volume
{
    [_iLiveRoom setMicVolume:volume];
}

-(void)onBgmVolume:(float)volume
{
    [_iLiveRoom setMusicVolume:volume];
}

- (void)onBgmSeek:(float)progress {
    [_iLiveRoom setMusicPosition:(progress*[_iLiveRoom getMusicDuration])];
}


#pragma mark iLiveEffectControlDelegate

-(void)onEffectStart:(int)effectId isLoop:(BOOL)isLoop publish:(BOOL)isPublish
{
    NSString *url = @"";
    if (effectId == 1) {
        url = [[NSBundle mainBundle] pathForResource:@"onMic" ofType:@"caf"];
    }else if (effectId == 2){
        url = [[NSBundle mainBundle] pathForResource:@"vchat_cheers" ofType:@"m4a"];
    }
    [_iLiveRoom playEffectWithId:effectId url:url loop:isLoop publish:isPublish];
}

-(void)onEffectStop:(int)effectId
{
    [_iLiveRoom stopEffectWithId:effectId];
}

-(void)onEffectVolume:(int)effectId volume:(float)volume
{
    if (effectId == 0) {
        [_iLiveRoom setEffectsVolume:volume];
    }else{
        [_iLiveRoom setVolumeOfEffect:effectId withVolume:volume];
    }
}

#pragma mark - TXILiveRoomDelegate

- (void)onError:(UInt64)userId errCode:(TXILiveRoomErrorCode)errCode errMsg:(NSString *)errMsg {
    NSString *msg = [NSString stringWithFormat:@"errCode[%d] %@", (int)errCode, errMsg];
    [self appendLog:userId msg:msg];
    
    // 简单起见，全部退房处理
    [_iLiveRoom quitRoom];
    [self alertTips:@"提示" msg:msg completion:^{
        [self.navigationController popViewControllerAnimated:YES];
    }];
}

- (void)onWarning:(UInt64)userId warningCode:(TXILiveRoomWarningCode)warningCode warningMsg:(NSString *)warningMsg {
    NSString *msg = [NSString stringWithFormat:@"warningCode[%d] %@", (int)warningCode, warningMsg];
    [self appendLog:userId msg:msg];
}

- (void)onEvent:(UInt64)userId eventId:(TXILiveRoomEventCode)eventId eventMsg:(NSString *)eventMsg {
    NSString *msg = [NSString stringWithFormat:@"eventId[%d] %@", (int)eventId, eventMsg];
    [self appendLog:userId msg:msg];
}

- (void)onStatus:(NSString *)roomName statusArray:(NSArray *)statusArray {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (TXILiveRoomStatus *status in statusArray) {
            [self addStatusDescriptionLog:status];
        }
    });
}

- (void)onJoinRoomSuccess:(NSString *)roomName {
    _roomStatus = ILiveRoom_ENTERED;

    //开启音量回调
    [_iLiveRoom setAudioVolumeIndication:500];

    [self toastTip:@"进房成功!" time:2];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    
    [_broadcasterArray addObject:[NSNumber numberWithLongLong:_userId]];
    
    if (_isBroadcaster) {
        if(!self.isEnterRoomWithCDN) {
            [_iLiveRoom startPublishCDNStream:self.cdnURL];
        }
        //SDK Camera采集
         if (_pushType == PushType_Camera) {
             [_iLiveRoom startPreview:YES view:_fullScreenView];
         }
         //开启MV
         if (_pushType == PushType_MV) {
             [self startMV];
         }
         [_iLiveRoom enableAudioPreview:YES];
    }
}

- (void)onRoomRoleChanged:(NSString *)roomName oldRole:(TXILiveRoomRole)oldRole newRole:(TXILiveRoomRole)newRole {
    if (newRole == TXILiveRoomRoleBroadcaster) {
        UIView *view = [[UIView alloc] init];
        UILabel *volumeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0,0, 200, 100)];
        volumeLabel.tag = _volumeViewTag;
        volumeLabel.textColor = UIColor.whiteColor;
        [view addSubview:volumeLabel];
        [_playerViewDic setObject:view forKey:@(_userId)];
        [view setBackgroundColor:UIColorFromRGB(0x262626)];
        [self.view addSubview:view];
        if (_pushType == PushType_Camera) {
            [_iLiveRoom startPreview:YES view:view];
        }
    } else {
        if (_pushType == PushType_Camera) {
            [_iLiveRoom stopPreview];
        }
        UIView *view = [_playerViewDic objectForKey:@(_userId)];
        [view removeFromSuperview];
        [_playerViewDic removeObjectForKey:@(_userId)];
    }
    [self relayout];
}

- (void)onKickOut:(NSString *)roomName userId:(UInt64)userId {
    [self alertTips:@"你被踢出房间" msg:@"" completion:^{
        [self quitAndClean];
        [self.navigationController popViewControllerAnimated:YES];
    }];
}

- (void)onJoinRoomFailed:(NSString *)roomName errCode:(TXILiveRoomErrorCode)errCode errMsg:(NSString *)errMsg {
    _roomStatus = ILiveRoom_IDLE;
    [_iLiveRoom quitRoom];
    
    NSString *msg = [NSString stringWithFormat:@"进房失败 errCode[%d] %@", (int)errCode, errMsg];
    NSLog(@"%@", msg);
    
    [self alertTips:@"提示" msg:msg completion:^{
        [self.navigationController popViewControllerAnimated:YES];
    }];
}

- (void)onQuitRoomSuccess:(NSString *)roomName {
    NSLog(@"退房成功");
    _roomStatus = ILiveRoom_IDLE;
    [self stopMV];
    [_iLiveRoom setAudioVolumeIndication:0];
}

- (void)onQuitRoomFailed:(NSString *)roomName errCode:(TXILiveRoomErrorCode)errCode errMsg:(NSString *)errMsg {
    NSString *msg = [NSString stringWithFormat:@"退房失败 errCode[%d] %@", (int)errCode, errMsg];
    NSLog(@"%@", msg);
    [self stopMV];
    [_iLiveRoom setAudioVolumeIndication:0];
}

- (void)onConnectOtherRoom:(UInt64)userId errCode:(NSInteger)errCode errMsg:(NSString *)errMsg {
    if (errCode == 0) {
        _isPK = YES;
        [self toastTip:@"跨房连麦成功" time:2];
    } else {
        [self alertTips:@"跨房连麦失败" msg:[NSString stringWithFormat:@"errCode[%ld] errMsg[%@]", errCode, errMsg] completion:nil];
    }
}

- (void)onDisconnectOtherRoom:(NSInteger)errCode errMsg:(NSString *)errMsg {
    _isPK = NO;
    if (errCode == 0) {
        [self toastTip:@"跨房连麦断开成功" time:2];
    } else {
        [self alertTips:@"跨房连麦断开失败" msg:[NSString stringWithFormat:@"errCode[%ld] errMsg[%@]", errCode, errMsg] completion:nil];
    }
}

- (void)onRoomBroadcasterIn:(NSString *)roomName userId:(UInt64)userId {
    UIView *playerView = nil;
    if (userId == _hostUserId) {
        playerView = _fullScreenView;
    } else {
        playerView = [[UIView alloc] init];
        [_playerViewDic setObject:playerView forKey:@(userId)];
        [playerView setBackgroundColor:UIColorFromRGB(0x262626)];
        [self.view addSubview:playerView];
        UILabel *volumeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0,0, 100, 100)];
        volumeLabel.textColor = UIColor.whiteColor;
        volumeLabel.tag = _volumeViewTag;
        [playerView addSubview:volumeLabel];
    }

    [_roomLogView addEventStatusItem:userId];
    
    // 重新布局
    [self relayout];
    
    [_iLiveRoom startRemoteRender:userId view:playerView];
    [_roomLogView freshCurrentEvtStatusView];
    
    NSString *msg = [NSString stringWithFormat:@"onRoomBroadcasterIn: %llu", userId];
    [self appendLog:_userId msg:msg];
    
    [_broadcasterArray addObject:[NSNumber numberWithLongLong:userId]];
    [self doMix:_isMixLandscape];
}

- (void)onRoomBroadcasterOut:(NSString *)roomName userId:(UInt64)userId reason:(TXILiveRoomOfflineReason)reason {
    if (userId == _hostUserId) {
        [self alertTips:@"提示" msg:@"主播退出房间" completion:^{
            [self.navigationController popViewControllerAnimated:YES];
            [self quitAndClean];
        }];
        return;
    }
    UIView *playerView = [_playerViewDic objectForKey:@(userId)];
    [playerView removeFromSuperview];
    [_playerViewDic removeObjectForKey:@(userId)];
    
    [_roomLogView delEventStatusItem:userId];
    [_roomLogView freshCurrentEvtStatusView];
    [self relayout];
        
    NSString *msg = [NSString stringWithFormat:@"onRoomBroadcasterOut: %llu reason[%d]", userId, (int)reason];
    [self appendLog:_userId msg:msg];
    
    [_broadcasterArray removeObject:[NSNumber numberWithLongLong:userId]];
    [self doMix:_isMixLandscape];
}

- (void)onRoomVideoQosChanged:(NSString *)roomName fps:(NSInteger)fps bitrate:(NSInteger)bitrate {
   NSString *logMsg = [NSString stringWithFormat:@"onRoomVideoQosChanged: fps[%ld] bitrate[%ld]", fps, bitrate];
   [self appendLog:_userId msg:logMsg];
}

- (void)onRoomVideoMuted:(NSString *)roomName userId:(UInt64)userId muted:(BOOL)muted {
    NSString *msg = [NSString stringWithFormat:@"onRoomVideoMuted: %llu muted[%d]", userId, muted];
    [self appendLog:_userId msg:msg];
}

- (void)onRoomAudioMuted:(NSString *)roomName userId:(UInt64)userId muted:(BOOL)muted {
    NSString *msg = [NSString stringWithFormat:@"onRoomAudioMuted: %llu muted[%d]", userId, muted];
    [self appendLog:_userId msg:msg];
}

- (void)onRecvMessage:(NSString *)roomName userId:(UInt64)userId msg:(NSData *)msg {
    NSString *newMsg = [[NSString alloc] initWithData:msg encoding:NSUTF8StringEncoding];
    if (![newMsg containsString:@"from host ts"]) {
        // 不包含host ts关键字的sei再打印出来
        // 大主播会默认发的
        NSString *logMsg = [NSString stringWithFormat:@"sei msg: userId[%llu] msg[%@]", userId, newMsg];
        [self appendLog:_userId msg:logMsg];
    }
}

- (void)onRecvStreamMessage:(NSString *)roomName userId:(UInt64)userId streamId:(NSInteger)streamId message:(NSData *)message {
    NSString *newMsg = [[NSString alloc] initWithData:message encoding:NSUTF8StringEncoding];
    NSString *logMsg = [NSString stringWithFormat:@"stream msg: userId[%llu] streamId[%ld] msg[%@]", userId, streamId, newMsg];
    [self appendLog:_userId msg:logMsg];
}

- (void)onStreamMessageError:(NSString *)roomName userId:(UInt64)userId streamId:(NSInteger)streamId errCode:(NSInteger)errCode missed:(NSInteger)missed {
    NSString *logMsg = [NSString stringWithFormat:@"streamMsg missed: userId[%llu] streamId[%ld] missed[%ld]", userId, streamId, missed];
    [self appendLog:_userId msg:logMsg];
}


#pragma mark - TXILiveRoomAudioDelegateAdapter

- (BOOL)onRecordAudioFrame:(TXILiveRoomAudioFrame *)audioFrame
{
    if (!_appIsInActive && !_appIsBackground) {
        [self mixMV:audioFrame isSendVideo:YES];  //混MV音频数据发送
    }
    return YES;
}

- (BOOL)onPlaybackAudioFrame:(TXILiveRoomAudioFrame *)audioFrame
{
    if (!_appIsInActive && !_appIsBackground) {
        [self mixMV:audioFrame isSendVideo:NO];  //播放MV音频数据
    }
    return YES;
}

- (BOOL)onPlayPcmData:(UInt64)userId audioFrame:(TXILiveRoomAudioFrame *)audioFrame
{
    return YES;
}

- (void)onReportAudioVolumeIndicationOfSpeakers:(NSArray<TXILiveRoomAudioVolumeInfo *> * _Nonnull)speakers
{
    
    for (TXILiveRoomAudioVolumeInfo *info in speakers) {
        UIView *view = nil;
        if (_fullScreenView.tag == info.userId) {
            view = _fullScreenView;
        } else {
            view = [_playerViewDic objectForKey:@(info.userId)];
        }
        if (view != nil) {
            UILabel *volumeLabel = [view viewWithTag:_volumeViewTag];
            if (volumeLabel) {
                volumeLabel.text = [NSString stringWithFormat:@"%f", info.volume];
            }
        }
    }
}

- (void)onMusicPlayBegin
{
    NSLog(@"music play begin");
    [self toastTip:@"音乐开始播放" time:1];
}

- (void)onMusicPlayFinish
{
    NSLog(@"music play finish");
    [self toastTip:@"音乐播放结束" time:1];
}

- (void)onMusicPlayError:(TXILiveRoomErrorCode)error
{
    NSLog(@"music play error code : %ld",(long)error);
    [self toastTip:@"音乐播放失败" time:1];
}

- (void)onEffectPlayFinish:(int)effectId
{
    [self toastTip:[NSString stringWithFormat:@"音效播放结束 id:%d", effectId] time:1];
    [_iLiveEffectControl reset:effectId];
    NSLog(@"effectId :%d play finish",effectId);
}

- (void)onEffectPlayError:(int)effectId error:(TXILiveRoomErrorCode)error
{
    NSLog(@"effectId :%d play error code : %ld",effectId,(long)error);
}

- (void)onStartPublishCDNStream:(int)err errMsg:(NSString *)errMsg {
    NSLog(@"onStartPublishCDNStream err:%d errMsg:%@",err, errMsg);
    
}

- (void)onStopPublishCDNStream:(int)err errMsg:(NSString *)errMsg {
    NSLog(@"onStopPublishCDNStream err:%d errMsg:%@",err, errMsg);
    
}

- (void)onStartMixTranscoding:(int)err errMsg:(NSString *)errMsg {
    NSLog(@"onStartMixTranscoding err:%d errMsg:%@",err, errMsg);
    
}

- (void)onStopMixTranscoding:(int)err errMsg:(NSString *)errMsg {
    NSLog(@"onStopMixTranscoding err:%d errMsg:%@",err, errMsg);
    
}
#pragma mark - 混流
- (void) doMix:(BOOL)isLandscape {
    int sVideoWidth = 120;
    int sVideoHeight = 160;
    
    TXILiveRoomTranscodingConfig *config = [[TXILiveRoomTranscodingConfig alloc] init];
    config.videoFramerate = 10;
    config.videoBitrate = 300;
    config.videoGOP = 1;
    config.videoWidth = isLandscape ? 640 : 480;
    config.videoHeight = isLandscape ? 480 : 640;
    
    config.audioBitrate = 128;
    config.audioChannels = 2;
    config.audioSampleRate = 44100;
    
    config.backgroundPicUrl = isLandscape ?@"https://momo-1254340397.cos.ap-guangzhou.myqcloud.com/193a3464c8ba4713ac2d3f2fb93829c7.jpeg"
    : @"https://momo-1254340397.cos.ap-guangzhou.myqcloud.com/1b4c510fd9f9d72a1177f4e8d92a2834349bbb30_meitu_2.png";
    
    NSMutableArray<TXILiveRoomMixUser *> *mutableArray = @[].mutableCopy;
    
    for (int i = 0; i < [_broadcasterArray count]; i++) {
        int x = i < 3 ? 0 : config.videoWidth - sVideoWidth;
        int y =  sVideoHeight * (i % 3);
        int zOrder = i + 1;// zOrder ： 1 ~ 16
        CGRect rect = CGRectMake(x, y, sVideoWidth, sVideoHeight);
        TXILiveRoomMixUser *mixUser = [[TXILiveRoomMixUser alloc] init];
        mixUser.rect = rect;
        mixUser.zOrder = zOrder;
        mixUser.userId = [[_broadcasterArray objectAtIndex:i] longValue];
        mixUser.roomId = [NSString stringWithFormat:@"%@_%u", self.roomName, self.roomId];
        [mutableArray addObject:mixUser];
    }
    config.mixUsers = mutableArray;
    
    if (_iLiveRoom != nil) {
        [_iLiveRoom setMixTranscodingConfig:config];
    }
}

#pragma mark - ILiveVideoCaptureDelegate
- (void)onCaptureFrame:(CMSampleBufferRef)sampleBuffer{
    [_iLiveRoom sendVideoSampleBuffer:sampleBuffer];
}

#pragma mark - MV Read
- (void)startMV
{
    //readVideo
    [_iLiveMVReader startVideoRead];
    dispatch_async(_videoReadQueue, ^{
        __weak __typeof(self) wSelf = self;
        [_iLiveMVReader readVideoFrameFromTime:0 toTime:[self getTime:_iLiveMVReader.duration] readOneFrame:^(CMSampleBufferRef sampleBuffer) {
            __typeof(self) self = wSelf;
            [self writeVideoSampleBufferToList:sampleBuffer];
        } readFinished:^{
            
        }];
    });
    
    //readAudio
    [_iLiveMVReader startAudioRead];
    _audioReadFinished = NO;
    _startMixAudio = NO;
    dispatch_async(_audioReadQueue, ^{
        __weak __typeof(self) wSelf = self;
        [_iLiveMVReader readAudioFrameFromTime:0 toTime:[self getTime:_iLiveMVReader.duration] readOneFrame:^(CMSampleBufferRef sampleBuffer) {
            __typeof(self) self = wSelf;
            [self writeAudioSampleBufferToList:sampleBuffer];
            CFRelease(sampleBuffer);
        } readFinished:^{
            __typeof(self) self = wSelf;
            self->_audioReadFinished = YES;
        }];
    });
}

-(void)writeVideoSampleBufferToList:(CMSampleBufferRef )sampleBuffer
{
    while(!_audioReadFinished && _videoBufferList.count >= 10) {
        usleep(10 * 1000);
    }
    
    if (_audioReadFinished) {
        CFRelease(sampleBuffer);
        return;
    }
    
    @synchronized (self) {
        [_videoBufferList addObject:(__bridge id)sampleBuffer];
    }
}

-(void)writeAudioSampleBufferToList:(CMSampleBufferRef)sampleBuffer
{
    const long Threshold = 8192 * 2 * 5;
    
    AudioBuffer audioBuffer = [self getAudioBuffer:sampleBuffer];
    
    while(!_audioReadFinished && _audioSendBufferList.length >= Threshold) {
        usleep(10 * 1000);
    }
    
    if (_audioReadFinished) {
        return;
    }
    
    @synchronized (self) {
        [_audioSendBufferList appendBytes:(unsigned char *)audioBuffer.mData length:audioBuffer.mDataByteSize];
        [_audioPlayBufferList appendBytes:(unsigned char *)audioBuffer.mData length:audioBuffer.mDataByteSize];
    }
}

-(void)stopMV
{
    _audioReadFinished = YES;
    _audioSendBufferLen = 0;
    [_iLiveMVReader stopVideoRead];
    [_iLiveMVReader stopAudioRead];
    @synchronized (self) {
        for (NSObject *obj in _videoBufferList) {
            CMSampleBufferRef sampleBuffer = (__bridge CMSampleBufferRef)obj;
            if (sampleBuffer) CFRelease(sampleBuffer);
        }
        [_videoBufferList removeAllObjects];
        [_audioSendBufferList replaceBytesInRange:NSMakeRange(0, _audioSendBufferList.length) withBytes:NULL length:0];
        [_audioPlayBufferList replaceBytesInRange:NSMakeRange(0, _audioPlayBufferList.length) withBytes:NULL length:0];
    }
}

-(void)mixMV:(TXILiveRoomAudioFrame *)audioFrame isSendVideo:(BOOL)isSendData
{
    @synchronized (self) {
        //缓存一定视频帧和音频帧再开始发送，防止饥饿
        if (_audioSendBufferList.length >= 8192 * 5 && _videoBufferList.count > 5) {
            _startMixAudio = YES;
        }
        if (!_startMixAudio) {
            return;
        }
        // 播放音频缓存队列和发送音频缓存队列不是一个队列，所以需要判断
        NSMutableData *audioBufferList = isSendData ? _audioSendBufferList : _audioPlayBufferList;
        NSData *audioData = audioFrame.audioData;
        NSInteger readBufferLen = 0;
        if (_iLiveMVReader.audioChannels >0 && audioFrame.audioChannels > 0) {
            readBufferLen = audioData.length * _iLiveMVReader.audioChannels / audioFrame.audioChannels;
        }else{
            NSLog(@"channel error!");
            return;
        }
        if (audioBufferList.length >= readBufferLen && _videoBufferList.count > 0) {
            //单双声道转换
            NSMutableData *audioBuffer = [NSMutableData data];
            if (_iLiveMVReader.audioChannels == 1 && audioFrame.audioChannels == 2){
                for (int i = 0 ; i < readBufferLen ; i += 2) {
                    [audioBuffer appendBytes:(unsigned char *)audioBufferList.bytes + i length:2];
                    [audioBuffer appendBytes:(unsigned char *)audioBufferList.bytes + i length:2];
                }
            }
            else if (_iLiveMVReader.audioChannels == 2 && audioFrame.audioChannels == 1){
                for (int i = 0 ; i < readBufferLen ; i += 4) {
                    [audioBuffer appendBytes:(unsigned char *)audioBufferList.bytes + i length:2];
                }
            }
            else{
                [audioBuffer appendBytes:(unsigned char *)audioBufferList.bytes length:audioBufferList.length];
            }
            
            //混音
            short *audioData_short = (short *)audioData.bytes;
            short *audioBuffer_short = (short *)audioBuffer.bytes;
            for (int i = 0 ; i < audioData.length / 2 ; i++) {
                audioData_short[i] = PA_CLAMP_UNLIKELY((int)audioData_short[i] + (int)audioBuffer_short[i], -0x8000, 0x7FFF);
            }
            
            //发视频数据
            if (isSendData) {
                CGFloat audioPts = _audioSendBufferLen / (audioFrame.audioSampleRate * audioFrame.audioChannels * 2.0);
                _audioSendBufferLen += audioData.length;
                
                NSMutableArray *sendVideoBufferList = [NSMutableArray array];
                for (int i = 0 ; i < _videoBufferList.count ; i ++) {
                    CMSampleBufferRef sampleBuffer = (__bridge CMSampleBufferRef)_videoBufferList[i];
                    if ([self getPts:sampleBuffer] <= audioPts) {
                        [sendVideoBufferList addObject:_videoBufferList[i]];
                    }
                }
                
                //发最近的视频帧
                if (sendVideoBufferList.count > 0) {
                    CMSampleBufferRef sampleBuffer = (__bridge CMSampleBufferRef)sendVideoBufferList[sendVideoBufferList.count -1];
                    [_pusherRenderView renderFrame:sampleBuffer];
                    [_iLiveRoom sendVideoSampleBuffer:sampleBuffer];
                }
                for (NSObject *obj in sendVideoBufferList) {
                    CMSampleBufferRef sampleBuffer = (__bridge CMSampleBufferRef)obj;
                    if (sampleBuffer) CFRelease(sampleBuffer);
                }
                [_videoBufferList removeObjectsInArray:sendVideoBufferList];
            }
            [audioBufferList replaceBytesInRange:NSMakeRange(0, readBufferLen) withBytes:NULL length:0];
        }
    }
}

#pragma mark - utils

- (AudioBuffer)getAudioBuffer:(CMSampleBufferRef)sampleBuffer
{
    AudioBufferList audioBufferList;
    CMBlockBufferRef blockBuffer;
    OSStatus state =  CMSampleBufferGetAudioBufferListWithRetainedBlockBuffer(sampleBuffer, NULL, &audioBufferList, sizeof(audioBufferList), NULL, NULL, 0, &blockBuffer);
    
    AudioBuffer audioBuffer = {0};
    audioBuffer.mDataByteSize = 0;
    if (state == 0) {
        if (audioBufferList.mNumberBuffers == 1) {
            audioBuffer = audioBufferList.mBuffers[0];//仅仅处理了左声道
        }
        if(blockBuffer != nil) CFRelease(blockBuffer);
    }
    return audioBuffer;
}

- (float)getTime:(CMTime)time
{
    return (float)time.value / time.timescale;
}

- (float)getPts:(CMSampleBufferRef)sampleBuffer;
{
    CMTime time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    return (float)time.value / time.timescale;
}

- (void)alertTips:(NSString *)title msg:(NSString *)msg completion:(void(^)())completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (completion) {
                completion();
            }
        }]];
        
        [self.navigationController presentViewController:alertController animated:YES completion:nil];
    });
}

#pragma NSNotification
- (void)onAppWillResignActive:(NSNotification*)notification {
//    _appIsInActive = YES;
//    if (_pushType == PushType_Camera) {
//        [_iLiveRoom pause];
//    }
}

- (void)onAppDidBecomeActive:(NSNotification*)notification {
//    _appIsInActive = NO;
//    if (_pushType == PushType_Camera) {
//        if (!_appIsBackground && !_appIsInActive) {
//            [_iLiveRoom resume];
//        }
//    }
}

- (void)onAppDidEnterBackGround:(NSNotification *)notification {
//    _appIsBackground = YES;
//    if (_pushType == PushType_Camera) {
//        [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
//
//        }];
//        [_iLiveRoom pause];
//    }
    
    [_iLiveRoom muteLocalAudio:YES];
    [_iLiveRoom muteAllRemoteAudio:YES];
}

- (void)onAppWillEnterForeground:(NSNotification *)notification {
//    _appIsBackground = NO;
//    if (_pushType == PushType_Camera) {
//        if (!_appIsBackground && !_appIsInActive) {
//            [_iLiveRoom resume];
//        }
//    }
    
    if (!_mute_switch) {
        [_iLiveRoom muteLocalAudio:NO];
    }
    if (!_muteAllRemoteAudio) {
        [_iLiveRoom muteAllRemoteAudio:NO];
    }    
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self hideToolButtons:NO];
    
    // 拖动小主播画面
    _touchBeginLocation = [[[event allTouches] anyObject] locationInView:self.view];
    
    UIView *view = [[[event allTouches] anyObject] view];
    CGRect rect = [view convertRect:view.frame toView:self.view];
    
    _touchPlayerView = nil;
    for (id userId in _playerViewDic) {
        UIView *playerView = [_playerViewDic objectForKey:userId];
        if (CGRectEqualToRect(playerView.frame, rect)) {
            _touchPlayerView = playerView;
            break;
        }
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    if (!_touchPlayerView) {
        return;
    }
    
    CGPoint location = [[[event allTouches] anyObject] locationInView:self.view];
    CGRect rect = CGRectMake(_touchPlayerView.frame.origin.x + location.x - _touchBeginLocation.x,
                             _touchPlayerView.frame.origin.y + location.y - _touchBeginLocation.y,
                             _touchPlayerView.frame.size.width,
                             _touchPlayerView.frame.size.height);
    
    _touchPlayerView.frame = rect;
    _touchPlayerItemView.center = _touchPlayerView.center;
    _touchBeginLocation = location;
}


#pragma mark - hearbeat
- (void)sendHeadBeat
{
    if (_isBroadcaster) {
        [[ILiveRoomService sharedInstance] hearBeat:self.roomId success:nil fail:^(NSError * _Nonnull error) {
            //        [self alertTips:@"提示" msg:@"心跳发送失败"];
            NSLog(@"心跳发送失败");
        }];
        
        [self performSelector:@selector(sendHeadBeat) withObject:nil afterDelay:5.0];
        _loopSendHostMsg = YES;
    
        [self loopSendHostSEI];
    }
}

- (void)loopSendHostSEI {
    dispatch_time_t delayTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0/*延迟执行时间*/ * NSEC_PER_SEC));
    __weak __typeof(self) wSelf = self;
    dispatch_after(delayTime, dispatch_get_main_queue(), ^{
        if (!wSelf) { return; }
        __typeof(self) self = wSelf;
        if (self->_loopSendHostMsg && self->_iLiveRoom) {
            [self->_iLiveRoom sendMessageEx:[[NSString stringWithFormat:@"sei from host ts:%llu", [[NSDate date] timeIntervalSince1970]*1000] dataUsingEncoding:NSUTF8StringEncoding]];
        }
        [self loopSendHostSEI];
    });
}

- (void)setPlayerViewHighlight:(uint64_t)userId {
    
    [self setHightLight:_fullScreenView enable:_fullScreenView.tag == userId];
    for (id item in _playerViewDic) {
        [self setHightLight:_playerViewDic[item] enable:userId == [item unsignedLongLongValue]];
    }
}

- (void)setHightLight:(UIView*)view enable:(BOOL)enable
{
    if (enable) {
        view.layer.borderWidth = 1;
        view.layer.borderColor = UIColor.redColor.CGColor;
    }
    else {
        view.layer.borderWidth = 0;
        view.layer.borderColor = UIColor.clearColor.CGColor;
    }
}

- (void)addStatusDescriptionLog:(TXILiveRoomStatus *)status {
    NSString *log = [NSString stringWithFormat:
                     @"UserId:%llu  IP:%@\n"
                     @"CPU:%d%%|%d%%  Res:%dx%d  Speed:%dkb/s\n"
                     @"FPS:%d  GOP:%ds  ARA:%dkb/s  VRA:%dkb/s  FEC:%d|%d%%\n"
                     @"QUE:%d|%d  SendQue:%d|%d  RTT:%dms  Loss:%d%%\n"
                     @"TotalAudio:%ld  TotalVideo:%ld\n"
                     @"CapAudio:%ld EncAudio:%ld  EncVideo:%ld\n"
                     @"AudioExpand:%ld  AudioExpandBlock:%ld\n"
                     @"AudioBlock:%ld\n",
                     status.userId, status.serverAddr,
                     (int)status.appCpu, (int)status.sysCpu, (int)status.videoWidth, (int)status.videoHeight, (int)status.netspeed,
                     (int)status.videoFps, (int)status.videoGop, (int)status.audioBitrate, (int)status.videoBitrate,(int)status.audioFecRatio, (int)status.videoFecRatio,
                     (int)status.audioCacheDuration, (int)status.videoCacheDuration, (int)status.audioUpCacheFrames, (int)status.videoUpCacheFrames, (int)status.rtt, (int)status.upLossRate,
                     status.audioTotalBytes, status.videoTotalBytes,
                     status.audioCaptureBytes, status.audioEncodeBytes, status.videoEncodeBytes,
                     status.audioExpandCnt, status.audioExpandBlockCnt,
                     status.audioBlockCnt];
    [_roomLogView addStatus:status.userId status:log];
}

- (void)appendLog:(UInt64)userId msg:(NSString *)msg {
    NSDateFormatter *format = [[NSDateFormatter alloc] init];
    format.dateFormat = @"hh:mm:ss.SSS";
    NSString *strTime = [format stringFromDate:[NSDate date]];
    
    NSString *eventMsg = [NSString stringWithFormat:@"[%@] %@", strTime, msg];
    
    [_roomLogView addEvent:userId event:eventMsg];
}


/**
 @method 获取指定宽度width的字符串在UITextView上的高度
 @param textView 待计算的UITextView
 @param width 限制字符串显示区域的宽度
 @result float 返回的高度
 */
- (float)heightForString:(UITextView *)textView andWidth:(float)width {
    CGSize sizeToFit = [textView sizeThatFits:CGSizeMake(width, MAXFLOAT)];
    return sizeToFit.height;
}

- (void)toastTip:(NSString *)toastInfo time:(NSInteger)time {
    dispatch_async(dispatch_get_main_queue(), ^{
        [_toastView removeFromSuperview];
        
        CGRect frameRC = [[UIScreen mainScreen] bounds];
        frameRC.origin.y = frameRC.size.height - 110;
        frameRC.size.height -= 110;
        frameRC.size.height = [self heightForString:_toastView andWidth:frameRC.size.width];
        
        _toastView.frame = frameRC;
        
        _toastView.text = toastInfo;
        _toastView.backgroundColor = [UIColor whiteColor];
        _toastView.alpha = 0.5;
        
        [self.view addSubview:_toastView];
        
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
        
        dispatch_after(popTime, dispatch_get_main_queue(), ^() {
            [_toastView removeFromSuperview];
        });
    });
}


- (NSString *)getMD5:(NSString *)string {
    const char *cStr = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];

    CC_MD5(cStr, (CC_LONG) strlen(cStr), digest);

    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02x", digest[i]];
    }

    return result;
}

- (NSString *)getStreamId:(NSString *)roomId userId:(NSString *)userId {
    NSString *str = @"";
    if (_bizId == 35476) {
        str = [NSString stringWithFormat:@"%d_%@_%@_main", _sdkAppId, roomId, userId];
    } else {
        str = [NSString stringWithFormat:@"%@_%@_main", roomId, userId];
    }
    return [NSString stringWithFormat:@"%d_%@", _bizId, [self getMD5:str]];
}

@end
