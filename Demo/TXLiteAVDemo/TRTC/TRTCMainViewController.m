/*
 * Module:   TRTCMainViewController
 *
 * Function: 使用TRTC SDK完成 1v1 和 1vn 的视频通话功能
 *
 *    1. 支持九宫格平铺和前后叠加两种不同的视频画面布局方式，该部分由 TRTCVideoViewLayout 来计算每个视频画面的位置排布和大小尺寸
 *
 *    2. 支持对视频通话的视频、音频等功能进行设置，该部分在 TRTCFeatureContainerViewController 中实现
 *       支持添加播放BGM和多种音效，该部分在 TRTCBgmContainerViewController 中实现
 *       支持对其它用户音视频的播放进行控制，该部分在 TRTCRemoteUserListViewController 中实现
 *
 *    3. 创建或者加入某一个通话房间，需要先指定 roomid 和 userid，这部分由 TRTCNewViewController 来实现
 *
 *    4. 对TRTC Engine的调用以及参数记录，定义在Settings/SDKManager目录中
 */

#import <AVFoundation/AVFoundation.h>
#import "TRTCRenderViewKeyManager.h"
#import "TRTCMainViewController.h"
#import "UIView+Additions.h"
#import "TRTCCloudDelegate.h"
#import "TRTCVideoViewLayout.h"
#import "TRTCVideoView.h"
#ifndef TRTC_INTERNATIONAL
#import "TXLivePlayer.h"
#endif
#import "TRTCCloudDef.h"
#import "ThemeConfigurator.h"
#import "TRTCFloatWindow.h"
#import "TRTCBgmContainerViewController.h"
#import "TRTCFeatureContainerViewController.h"
#ifndef TRTC_INTERNATIONAL
#import "TRTCCdnPlayerSettingsViewController.h"
#endif
#import "TRTCRemoteUserListViewController.h"
#ifdef ENABLE_TRTC_CPP
#import "TRTCCloudBgmManagerCpp.h"
#endif
#import "TRTCCloudBgmManager.h"
#import "TRTCEffectManager.h"
#import "TRTCAudioRecordManager.h"
#import "TRTCCdnPlayerManager.h"
#import "TRTCVideoConfig.h"
#import "UIButton+TRTC.h"
#import "Masonry.h"
#import <ReplayKit/ReplayKit.h>
#import "TRTCBroadcastExtensionLauncher.h"
#ifndef DISABLE_VOD
#import "TRTCVODViewController.h"
#endif
#import "PhotoUtil.h"

static NSString * const ScreenCaptureWating = @"📱屏幕分享(等待 Extension)";
static NSString * const ScreenCaptureBroadcasting = @"📱屏幕分享(直播中)";
static NSString * const ScreenCaptureStopped = @"📱屏幕分享(已停止)";
static NSString * const ScreenCapturePaused = @"📱屏幕分享(已暂停)";


@interface TRTCMainViewController() <
    TRTCCloudDelegate,
    TRTCAudioFrameDelegate,
    TRTCVideoViewDelegate,
    BeautyLoadPituDelegate,
    TRTCCloudManagerDelegate
#ifndef TRTC_INTERNATIONAL
    ,TXLivePlayListener
#endif
> {
    
    TRTCRenderViewKey                 *_mainViewUserId;     //视频画面支持点击切换，需要用一个变量记录当前哪一路画面是全屏状态的
    
    TRTCVideoViewLayout      *_layoutEngine;
    NSMutableDictionary<NSString *, TRTCVideoView *>*      _remoteViewDic;      //一个或者多个远程画面的view
    TRTCRenderViewKeymanager *renderViewKeymanager;

    NSInteger                _showLogType;         //LOG浮层显示详细信息还是精简信息
    NSInteger                _layoutBtnState;      //布局切换按钮状态
    CGFloat                  _dashboardTopMargin;
    UIButton                *_broadcastButton;
    UIButton                *_broadcastPauseButton;

#ifndef DISABLE_VOD
    TRTCVODViewController   *_vodVC;  // 点播控制器
#endif
    
    BOOL _enableAudioDump;
    FILE *_captureAudioDumpFile; // 保存回调的音频数据
    FILE *_mixAudioDumpFile;
}

@property (weak, nonatomic) IBOutlet UIView *holderView;
@property (weak, nonatomic) IBOutlet UIView *cdnPlayerView;
@property (weak, nonatomic) IBOutlet UIView *settingsContainerView;

@property (weak, nonatomic) IBOutlet UIButton *cdnPlayButton; //旁路播放切换
@property (weak, nonatomic) IBOutlet TCBeautyPanel *beautyPanel;

@property (weak, nonatomic) IBOutlet UIStackView *toastStackView;
@property (weak, nonatomic) IBOutlet UIButton *linkMicButton;
@property (weak, nonatomic) IBOutlet UIButton *logButton; //仪表盘开关，仪表盘浮层是SDK中覆盖在视频画面上的一系列数值状态
@property (weak, nonatomic) IBOutlet UIButton *cdnPlayLogButton; //CDN播放页的仪表盘开关
@property (weak, nonatomic) IBOutlet UIButton *layoutButton; //布局切换（九宫格 OR 前后叠加）
@property (weak, nonatomic) IBOutlet UIButton *beautyButton; //美颜开关
@property (weak, nonatomic) IBOutlet UIButton *cameraButton; //前后摄像头切换
@property (weak, nonatomic) IBOutlet UIButton *muteButton; //音频上行静音开关
@property (weak, nonatomic) IBOutlet UIButton *bgmButton; //BGM设置，点击打开TRTCBgmContainerViewController
@property (weak, nonatomic) IBOutlet UIButton *featureButton; //功能设置，点击打开TRTCFeatureContainerViewController
@property (weak, nonatomic) IBOutlet UIButton *cdnPlaySettingsButton; //Cdn播放设置，点击打开TRTCFeatureContainerViewController
@property (weak, nonatomic) IBOutlet UIButton *remoteUserButton; //远端用户设置，关联打开TRTCRemoteUserListViewController

@property (strong, nonatomic) TRTCVideoView* localView; //本地画面的view


// 设置页
@property (strong, nonatomic, nullable) UIViewController *currentEmbededVC;
@property (strong, nonatomic, nullable) TRTCFeatureContainerViewController *settingsVC;
@property (strong, nonatomic, nullable) TRTCBgmContainerViewController *bgmContainerVC;
#ifndef TRTC_INTERNATIONAL
@property (strong, nonatomic, nullable) TRTCCdnPlayerSettingsViewController *cdnPlayerVC;
@property (strong, nonatomic, nullable) TRTCCdnPlayerManager *cdnPlayer; //直播观众的CDN拉流播放页面
#endif
@property (strong, nonatomic, nullable) TRTCRemoteUserListViewController *remoteUserListVC;

@property (strong, nonatomic) TRTCCloudBgmManager *bgmManager;
@property (strong, nonatomic) TRTCEffectManager *effectManager;
@property (strong, nonatomic) TRTCAudioRecordManager *recordManager;

@property (nonatomic) BOOL isLivePlayingViaCdn;
@property (nonatomic) BOOL isLinkingMic;       //观众是否连麦中，用于处理UI布局

//子房间
@property (strong, atomic) NSMutableDictionary<NSString *, NSMutableArray<NSString *> *> *subRoomRemoteUserDic;//维护每个子房间内有哪些远程用户
@end

@implementation TRTCMainViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self observeKeyboard];

    _dashboardTopMargin = 0.15;
    [self.trtcCloudManager setTRTCDelegate:self];
    [self.trtcCloudManager setManagerDelegate:self];
    [self.trtcCloudManager setAudioFrameDelegate:self];
    self.beautyPanel.actionPerformer = [TCBeautyPanelActionProxy proxyWithSDKObject:[TRTCCloud sharedInstance]];
    [ThemeConfigurator configBeautyPanelTheme:self.beautyPanel];
#ifdef ENABLE_TRTC_CPP
    if(self.useCppWrapper) {
        self.bgmManager = [[TRTCCloudBgmManagerCpp alloc] initWithTrtc:[TRTCCloud sharedInstance]];
    } else {
#endif
        self.bgmManager = [[TRTCCloudBgmManager alloc] initWithTrtc:[TRTCCloud sharedInstance]];
#ifdef ENABLE_TRTC_CPP
    }
#endif
    self.effectManager = [[TRTCEffectManager alloc] initWithTrtc:[TRTCCloud sharedInstance]];
    self.trtcCloudManager.remoteUserManager = self.remoteUserManager;
    self.recordManager = [[TRTCAudioRecordManager alloc] initWithTrtc:[TRTCCloud sharedInstance]];

    _remoteViewDic = [[NSMutableDictionary alloc] init];
    renderViewKeymanager = [[TRTCRenderViewKeymanager alloc] init];
    _subRoomRemoteUserDic = [[NSMutableDictionary alloc] init];
    _mainViewUserId = [renderViewKeymanager getRenderViewKeyWithUid:self.param.userId roomId:self.param.roomId strRoomId:self.param.strRoomId mainRoom:YES mainStream:YES];
    // 初始化 UI 控件
    [self initUI];
    self.trtcCloudManager.localVideoView = self.localView;
    if (!_enableCustomRender) {
        [self.trtcCloudManager updateLocalView:self.localView];
    }
    // 开始登录、进房
    [self enterRoom];
#ifndef DISABLE_VOD
    // 点播播放器
    _vodVC = nil;
#endif
    
    // 测试音频数据回调，平时不打开，只有验证回调数据时才开启
    _enableAudioDump = NO;
    _captureAudioDumpFile = NULL;
    _mixAudioDumpFile = NULL;
    if (_enableAudioDump) {
        char *captureFileName = "capture_dump.pcm";
        NSString* systemDocumentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString* filePath = [NSString stringWithFormat:@"%@/%s", systemDocumentPath, captureFileName];
        _captureAudioDumpFile = fopen([filePath UTF8String], "wb");
        
        char *mixFileName = "mix_dump.pcm";
        systemDocumentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        filePath = [NSString stringWithFormat:@"%@/%s", systemDocumentPath, mixFileName];
        _mixAudioDumpFile = fopen([filePath UTF8String], "wb");
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [[UIApplication sharedApplication] setIdleTimerDisabled:YES];
    _dashboardTopMargin = [UIApplication sharedApplication].statusBarFrame.size.height + self.navigationController.navigationBar.frame.size.height;
    [self relayout];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = YES;
    [[UIApplication sharedApplication] setIdleTimerDisabled:NO];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [self exitRoom];
    [self.trtcCloudManager exitAllSubRoom];
    [[TRTCFloatWindow sharedInstance] close];
}

- (void)setLocalView:(UIView *)localView remoteViewDic:(NSMutableDictionary *)remoteViewDic {
    [self.trtcCloudManager setTRTCDelegate:self];
    [self.trtcCloudManager setManagerDelegate:self];
    _localView = (TRTCVideoView*)localView;
    _localView.delegate = self;
    self.trtcCloudManager.localVideoView = self.localView;
    if (!_enableCustomRender) {
        [self.trtcCloudManager updateLocalView:self.localView];
    }
    _remoteViewDic = remoteViewDic;

    for (TRTCVideoView *playerView in [_remoteViewDic allValues]) {
        playerView.delegate = self;
    }
    [self onClickGird:nil];
    [self relayout];
}

- (void)dealloc {
    [self.trtcCloudManager exitRoom];
    [[TRTCFloatWindow sharedInstance] close];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
#ifndef DISABLE_VOD
    if (_vodVC) {
        [_vodVC stopPlay];
    }
#endif
    if (_enableAudioDump && _captureAudioDumpFile && _mixAudioDumpFile) {
        fclose(_captureAudioDumpFile);
        fclose(_mixAudioDumpFile);
        _enableAudioDump = NULL;
    }
}

- (void)observeKeyboard {
    __weak TRTCMainViewController *wSelf = self;
    [self.view tx_observeKeyboardOnChange:^(CGFloat keyboardTop, CGFloat height) {
        __strong TRTCMainViewController *sSelf = wSelf;
        CGFloat keyboardHeight = sSelf.view.size.height - keyboardTop;
        [sSelf.settingsContainerView mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(sSelf.view);
            make.centerY.equalTo(sSelf.view).offset(-keyboardHeight / 2);
            make.width.equalTo(sSelf.view).multipliedBy(0.95);
            make.height.mas_equalTo(keyboardTop * 0.88);
        }];
    }];
}

- (void)initUI {
    self.title = self.param.roomId ? @(self.param.roomId).stringValue : self.param.strRoomId;
    [self.cdnPlayButton setupBackground];
    // 布局底部工具栏
    [self relayoutBottomBar];

    // 本地预览view
    _localView = [TRTCVideoView newVideoViewWithType:VideoViewType_Local key:_mainViewUserId delegate:self];
    
    _layoutEngine = [[TRTCVideoViewLayout alloc] init];
    _layoutEngine.view = self.holderView;
    [self relayout];

    _beautyPanel.pituDelegate = self;
    if (self.trtcCloudManager.videoConfig.source == TRTCVideoSourceDeviceScreen ||
        self.trtcCloudManager.videoConfig.subSource == TRTCVideoSourceDeviceScreen) {
        [_localView showText:ScreenCaptureWating];
        if (@available(iOS 11, *)) {
            if (self.trtcCloudManager.videoConfig.source == TRTCVideoSourceDeviceScreen ||
                self.trtcCloudManager.videoConfig.subSource == TRTCVideoSourceDeviceScreen) {
                UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
                [button setTitle:@"开始屏幕分享" forState:UIControlStateNormal];
                [button setTitleColor:[UIColor cyanColor] forState:UIControlStateNormal];
                [button setTitle:@"停止屏幕分享" forState:UIControlStateSelected];
                [button setTitleColor:[UIColor redColor] forState:UIControlStateSelected];
                button.backgroundColor = [UIColor grayColor];
                [self.view addSubview:button];
                button.clipsToBounds = YES;
                button.layer.cornerRadius = 5.0;
                [button addTarget:self action:@selector(onClickScreenCastButton:) forControlEvents:UIControlEventTouchUpInside];
                [button mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.size.equalTo([NSValue valueWithCGSize: CGSizeMake(120, 50)]);
                    make.centerX.equalTo(self.view.mas_centerX);
                    make.bottom.equalTo(self.view.mas_bottomMargin).offset(-50);
                }];
                _broadcastButton = button;

                UIButton *pauseButton = [UIButton buttonWithType:UIButtonTypeCustom];
                [pauseButton setImage:[UIImage imageNamed:@"audio_pause"] forState:UIControlStateNormal];
                [pauseButton setImage:[UIImage imageNamed:@"audio_play"] forState:UIControlStateSelected];
                [pauseButton addTarget:self action:@selector(onClickScreenCastPauseButton:) forControlEvents:UIControlEventTouchUpInside];
                [self.view addSubview:pauseButton];
                [pauseButton mas_makeConstraints:^(MASConstraintMaker *make) {
                    make.left.equalTo(button.mas_right).offset(10);
                    make.centerY.equalTo(button.mas_centerY);
                }];
                pauseButton.hidden = YES;
                _broadcastPauseButton = pauseButton;
            }
        }
    }
    [TRTCFloatWindow sharedInstance].trtcCloudManager = self.trtcCloudManager;
    [TRTCFloatWindow sharedInstance].renderViewKeyManager = renderViewKeymanager;
    [TRTCFloatWindow sharedInstance].enableCustomRender = self.enableCustomRender;
    
}

- (void)relayoutBottomBar {
    // 切换三种模式（主播，观众，连麦的观众）对应显示的button
    BOOL isAudience = _appScene == TRTCAppSceneLIVE && _param.role == TRTCRoleAudience;
    BOOL isLinkedMicAudience = _appScene == TRTCAppSceneLIVE && self.isLinkingMic;
    
    self.linkMicButton.hidden = !(isAudience || isLinkedMicAudience);
    self.layoutButton.hidden = isAudience;
    self.cdnPlayButton.hidden = !(isAudience || isLinkedMicAudience);
    //C++接口下不显示美颜相关UI
    self.beautyButton.hidden = isAudience || _useCppWrapper;
    self.cameraButton.hidden = isAudience;
    self.muteButton.hidden = isAudience;
    self.bgmButton.hidden = isAudience;
    self.featureButton.hidden = isAudience;

    // 切换观众模式下UDP或CDN观看直播对应的button
#ifndef TRTC_INTERNATIONAL
    BOOL isUsingCdnPlay = self.cdnPlayer.isPlaying;

    self.logButton.hidden = isUsingCdnPlay;
    self.remoteUserButton.hidden = isUsingCdnPlay;
    self.cdnPlayLogButton.hidden = !isUsingCdnPlay;
    self.cdnPlaySettingsButton.hidden = !isUsingCdnPlay;
#else
    self.logButton.hidden = YES;
    self.remoteUserButton.hidden = YES;
    self.cdnPlayLogButton.hidden = YES;
    self.cdnPlaySettingsButton.hidden = YES;
#endif
}

- (void)openFloatWindow {
    //打开浮窗
    [self.trtcCloudManager showDebugView:0];
    [TRTCFloatWindow sharedInstance].localView = _localView;
    self.trtcCloudManager.localVideoView = _localView;
    [TRTCFloatWindow sharedInstance].remoteViewDic = _remoteViewDic;
    for (TRTCVideoView* view in [_remoteViewDic allValues]) {
        [view removeFromSuperview];
    }
    [[TRTCFloatWindow sharedInstance] show];
}

/**
 * 视频窗口排布函数，此处代码用于调整界面上数个视频画面的大小和位置
 */
- (void)relayout {
    NSMutableArray *views = @[].mutableCopy;
    if ([_mainViewUserId.userId length] == 0 || [_mainViewUserId.userId isEqual:self.param.userId]) {
        [views addObject:_localView];
        _localView.enableMove = NO;
    } else if ([_remoteViewDic objectForKey:[_mainViewUserId getHash]] != nil) {
        [views addObject:_remoteViewDic[[_mainViewUserId getHash]]];
    }
    for (NSString *renderKeyStr in _remoteViewDic) {
        TRTCVideoView *playerView = [_remoteViewDic objectForKey:renderKeyStr];
        if ([[_mainViewUserId getHash] isEqualToString:renderKeyStr] ) {
            [views addObject:_localView];
            playerView.enableMove = NO;
            _localView.enableMove = YES;
        } else {
            playerView.enableMove = YES;
            [views addObject:playerView];
        }
    }
    
    [_layoutEngine relayout:views];
    
    //观众角色隐藏预览view
     _localView.hidden = NO;
    if (_appScene == TRTCAppSceneLIVE && _param.role == TRTCRoleAudience)
        _localView.hidden = YES;
    
    // 更新 dashboard 边距
    UIEdgeInsets margin = UIEdgeInsetsMake(_dashboardTopMargin,  0, 0, 0);
    if (_remoteViewDic.count == 0) {
        [self.trtcCloudManager setDebugViewMargin:self.param.userId margin:margin];
    } else {
        NSMutableArray *uids = [NSMutableArray arrayWithObject:self.param.userId];
        for (NSString *key in [_remoteViewDic allKeys]) {
            NSString *userId = [renderViewKeymanager getRenderViewKeyFromHash:key].userId;
            if (userId) [uids addObject:userId];
        }
        [uids removeObject:_mainViewUserId.userId];
        for (NSString *uid in uids) {
            [self.trtcCloudManager setDebugViewMargin:uid margin:UIEdgeInsetsZero];
        }
        
        [self.trtcCloudManager setDebugViewMargin:_mainViewUserId.userId margin:(_layoutEngine.type == TC_Float || _remoteViewDic.count == 0) ? margin : UIEdgeInsetsZero];
    }
}

- (void)enterRoom {
    [self toastTip:@"开始进房"];
    [self.trtcCloudManager enterRoom];
    [_beautyPanel resetAndApplyValues];
//    [_beautyPanel trigglerValues];
}

- (void)exitRoom {
    [self.trtcCloudManager exitRoom];
}

#pragma mark - Actions

- (IBAction)onClickLinkMicButton:(UIButton *)button {
#ifndef TRTC_INTERNATIONAL
    if (self.cdnPlayer.isPlaying) {
        [self toggleCdnPlay];
    }
#endif
    [self.trtcCloudManager setRole:self.isLinkingMic ? TRTCRoleAudience : TRTCRoleAnchor];
    self.isLinkingMic = !self.isLinkingMic;
    [self relayoutBottomBar];
    [self relayout];
}

- (IBAction)onClickLogButton:(UIButton *)button {
    _showLogType ++;
    if (_showLogType > 2) {
        _showLogType = 0;
        [button setImage:[UIImage imageNamed:@"log_b2"] forState:UIControlStateNormal];
    } else {
        [button setImage:[UIImage imageNamed:@"log_b"] forState:UIControlStateNormal];
    }
    
    [self.trtcCloudManager showDebugView:_showLogType];
}

- (IBAction)onClickCdnPlayLogButton:(UIButton *)button {
#ifndef TRTC_INTERNATIONAL
    button.selected = !button.selected;
    [self.cdnPlayer setDebugLogEnabled:button.selected];
#endif
}

- (IBAction)onClickGird:(UIButton *)button {
    const int kStateFloat       = 0;
    const int kStateGrid        = 1;
    const int kStateFloatWindow = 2;
    
    [self recreateVideoViews];
    
    if (_layoutBtnState == kStateFloat) {
        _layoutBtnState = kStateGrid;
        [_layoutButton setImage:[UIImage imageNamed:@"gird_b"] forState:UIControlStateNormal];
        _layoutEngine.type = TC_Gird;
        [self.trtcCloudManager setDebugViewMargin:_mainViewUserId.userId margin:UIEdgeInsetsZero];
    } else if (_layoutBtnState == kStateGrid){
        _layoutBtnState = kStateFloatWindow;
        [self openFloatWindow];
        return;
    } else if (_layoutBtnState == kStateFloatWindow) {
        [_layoutButton setImage:[UIImage imageNamed:@"float_b"] forState:UIControlStateNormal];
        _layoutBtnState = kStateFloat;
        _layoutEngine.type = TC_Float;
        [self.trtcCloudManager setDebugViewMargin:_mainViewUserId.userId margin:UIEdgeInsetsMake(_dashboardTopMargin, 0, 0, 0)];
    }
    
    [self.trtcCloudManager showDebugView:_showLogType];
}

- (void)recreateVideoViews {
    [self.localView removeFromSuperview];
    
    TRTCRenderViewKey *renderKey = [renderViewKeymanager getRenderViewKeyWithUid:self.trtcCloudManager.params.userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId mainRoom:YES mainStream:YES];
    self.localView = [TRTCVideoView newVideoViewWithType:VideoViewType_Local key:renderKey delegate:self];
    self.trtcCloudManager.localVideoView = self.localView;
    if (!_enableCustomRender) {
        [self.trtcCloudManager updateLocalView:self.localView];
    }
    for (NSString *renderKeyStr in _remoteViewDic.allKeys) {
        TRTCVideoView *remoteView = _remoteViewDic[renderKeyStr];
        [remoteView removeFromSuperview];
        TRTCRenderViewKey *renderKey = [renderViewKeymanager getRenderViewKeyFromHash:renderKeyStr];
        TRTCVideoView *newRemoteView = [TRTCVideoView newVideoViewWithType:VideoViewType_Remote key:renderKey delegate:self];
        newRemoteView.streamType = remoteView.streamType;
        _remoteViewDic[renderKeyStr] = newRemoteView;
        if (!renderKey.isMainRoom) {
            [self.trtcCloudManager updateSubRoomRemoteView:newRemoteView roomId:[@(renderKey.roomId) stringValue] streamType:newRemoteView.streamType forUser:renderKey.userId];
        } else if (!_enableCustomRender) {
                [self.trtcCloudManager updateRemoteView:newRemoteView streamType:newRemoteView.streamType forUser:renderKey.userId];
        } else {
            [self.trtcCloudManager updateCustomRenderView:newRemoteView forUser:renderKey.userId];
        }
    }
    
    [self relayout];
}

- (IBAction)onClickCdnPlayButton:(UIButton *)button {
    [self.trtcCloudManager setRole:TRTCRoleAudience];
    [self toggleCdnPlay];
}

- (IBAction)onClickBeautyButton:(UIButton *)button {
    _beautyPanel.hidden = !_beautyPanel.hidden;
}

- (IBAction)onClickSwitchCameraButton:(UIButton *)button {
    [self.trtcCloudManager switchCamera];
}

- (IBAction)onClickMuteButton:(UIButton *)button {
    button.selected = !button.selected;
    NSString *mainRoomId = self.param.roomId ? [@(self.param.roomId) stringValue] : self.param.strRoomId;
    if ([self.trtcCloudManager.currentPublishingRoomId isEqualToString:mainRoomId]) {
        //若当前在主房间中推流，则调用TRTCCloud切换声音上行
        [self.trtcCloudManager setAudioMuted:button.selected];
    } else {
        //否则找到对应的TRTCSubCloud切换上行
        [self.trtcCloudManager pushAudioStreamInSubRoom:self.trtcCloudManager.currentPublishingRoomId push:
         !button.selected];
    }
}

- (IBAction)onClickBgmSettingsButton:(UIButton *)button {
    if (!self.bgmContainerVC) {
        self.bgmContainerVC = [[TRTCBgmContainerViewController alloc] init];
        self.bgmContainerVC.bgmManager = self.bgmManager;
        self.bgmContainerVC.effectManager = self.effectManager;
        self.bgmContainerVC.useCppWrapper = _useCppWrapper;
    }
    [self toggleEmbedVC:self.bgmContainerVC];
}

- (IBAction)onClickFeatureSettingsButton:(UIButton *)button {
    if (!self.settingsVC) {
        self.settingsVC = [[TRTCFeatureContainerViewController alloc] init];
        self.settingsVC.trtcCloudManager = self.trtcCloudManager;
        self.settingsVC.recordManager = self.recordManager;
    }
    [self toggleEmbedVC:self.settingsVC];
}

- (IBAction)onClickCdnPlaySettingsButton:(UIButton *)button {
#ifndef TRTC_INTERNATIONAL
    if (!self.cdnPlayerVC) {
        self.cdnPlayerVC = [[TRTCCdnPlayerSettingsViewController alloc] init];
        self.cdnPlayerVC.manager = self.cdnPlayer;
    }
    [self toggleEmbedVC:self.cdnPlayerVC];
#endif
}

- (IBAction)onClickRemoteUserSettingsButton:(UIButton *)button {
    if (!self.remoteUserListVC) {
        self.remoteUserListVC = [[TRTCRemoteUserListViewController alloc] init];
        self.remoteUserListVC.userManager = self.remoteUserManager;
    }
    [self toggleEmbedVC:self.remoteUserListVC];
}

- (IBAction)onClickScreenCastButton:(UIButton *)button {
    if (button.selected) {
        if (self.trtcCloudManager.videoConfig.source == TRTCVideoSourceDeviceScreen) {
            [self.trtcCloudManager setVideoEnabled:NO streamType:TRTCVideoStreamTypeBig];
        } else if (self.trtcCloudManager.videoConfig.subSource == TRTCVideoSourceDeviceScreen) {
            [self.trtcCloudManager setVideoEnabled:NO streamType:TRTCVideoStreamTypeSub];
        }
    } else {
        [_localView showText:ScreenCaptureWating];
        if (self.trtcCloudManager.videoConfig.source == TRTCVideoSourceDeviceScreen) {
            [self.trtcCloudManager setVideoEnabled:YES streamType:TRTCVideoStreamTypeBig];
        } else if (self.trtcCloudManager.videoConfig.subSource == TRTCVideoSourceDeviceScreen) {
            [self.trtcCloudManager setVideoEnabled:YES streamType:TRTCVideoStreamTypeSub];
        }
        
        if (@available(iOS 12.0, *)) {
            [TRTCBroadcastExtensionLauncher launch];
        }
    }
}

- (IBAction)onClickScreenCastPauseButton:(UIButton *)button {
    [self.trtcCloudManager pauseScreenCapture:!button.selected];
    button.selected = !button.selected;
}

#pragma mark - Settings ViewController Embeding

- (void)toggleEmbedVC:(UIViewController *)vc {
    if (self.currentEmbededVC != vc) {
        [self embedChildVC:vc];
    } else {
        [self unembedChildVC:vc];
    }
}

- (void)embedChildVC:(UIViewController *)vc {
    if (self.currentEmbededVC) {
        [self unembedChildVC:self.currentEmbededVC];
    }

    UINavigationController *naviVC = [[UINavigationController alloc] initWithRootViewController:vc];
    [self addChildViewController:naviVC];
    [self.settingsContainerView addSubview:naviVC.view];
    [naviVC.view mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.settingsContainerView);
    }];
    [naviVC didMoveToParentViewController:self];

    self.settingsContainerView.hidden = NO;
    self.currentEmbededVC = vc;
#ifndef DISABLE_VOD
    _vodVC.view.hidden = YES;
#endif
}

- (void)unembedChildVC:(UIViewController * _Nullable)vc {
    if (!vc) { return; }
    [vc.navigationController willMoveToParentViewController:nil];
    [vc.navigationController.view removeFromSuperview];
    [vc.navigationController removeFromParentViewController];
    self.currentEmbededVC = nil;
    self.settingsContainerView.hidden = YES;
#ifndef DISABLE_VOD
    _vodVC.view.hidden = NO;
#endif
}

#pragma mark - Live Player

- (void)toggleCdnPlay {
#ifndef TRTC_INTERNATIONAL
    if (!self.cdnPlayer) {
        self.cdnPlayer = [[TRTCCdnPlayerManager alloc] initWithContainerView:self.cdnPlayerView delegate:self];
    }

    self.isLivePlayingViaCdn = !self.isLivePlayingViaCdn;
    self.isLinkingMic = NO;
    self.cdnPlayerView.hidden = !self.isLivePlayingViaCdn;
    self.cdnPlayButton.selected = self.isLivePlayingViaCdn;

    if (self.isLivePlayingViaCdn) {
        [self exitRoom];
        NSString *anchorId = _mainViewUserId.userId.length > 0 ? _mainViewUserId.userId : self.remoteUserManager.remoteUsers.allKeys.firstObject;
        [self.cdnPlayer startPlay:[self.trtcCloudManager getCdnUrlOfUser:anchorId]];
    } else {
        [self.cdnPlayer stopPlay];
        [self enterRoom];
    }
    [self relayoutBottomBar];
    [self relayout];
#endif
}

- (void)setIsLinkingMic:(BOOL)isLinkingMic {
    _isLinkingMic = isLinkingMic;
    self.linkMicButton.selected = isLinkingMic;
}

#pragma mark - TRTCVideoViewDelegate

- (void)onMuteVideoBtnClick:(TRTCVideoView *)view stateChanged:(BOOL)stateChanged {
    if (view.streamType == TRTCVideoStreamTypeSub) {
        if (stateChanged) {
            [self.trtcCloudManager stopRemoteSubStreamView:view.userId];
        } else {
            [self.trtcCloudManager startRemoteSubStreamView:view.userId view:view];
        }
    } else {
        [self.remoteUserManager setUser:view.userId isVideoMuted:stateChanged];
    }
}

- (void)onMuteAudioBtnClick:(TRTCVideoView *)view stateChanged:(BOOL)stateChanged {
    [self.remoteUserManager setUser:view.userId isAudioMuted:stateChanged];
}

- (void)onScaleModeBtnClick:(TRTCVideoView *)view stateChanged:(BOOL)stateChanged {
    [self.remoteUserManager setUser:view.userId fillMode:stateChanged ? TRTCVideoFillMode_Fill : TRTCVideoFillMode_Fit];
}

- (void)onViewTap:(TRTCVideoView *)view {
    if (_layoutEngine.type == TC_Gird) {
        return;
    }
    if (view == _localView) {
        _mainViewUserId = [renderViewKeymanager getRenderViewKeyWithUid:self.param.userId roomId:_mainViewUserId.roomId strRoomId:_mainViewUserId.strRoomId mainRoom:_mainViewUserId.isMainRoom mainStream:_mainViewUserId.isMainRoom];
    } else {
        for (NSString *renderKeyStr in _remoteViewDic) {
            UIView *pw = [_remoteViewDic objectForKey:renderKeyStr];
            if (view == pw ) {
                _mainViewUserId = [renderViewKeymanager getRenderViewKeyFromHash:renderKeyStr];
            }
        }
    }
    [self relayout];
    self.localView.hidden = NO;
}

#pragma mark - TRTCCloudDelegate

/**
 * WARNING 大多是一些可以忽略的事件通知，SDK内部会启动一定的补救机制
 */
- (void)onWarning:(TXLiteAVWarning)warningCode warningMsg:(nullable NSString *)warningMsg extInfo:(nullable NSDictionary*)extInfo {
    NSLog(@"%@", extInfo);
    [self toastTip:@"WARNING: %@, %@", @(warningCode), warningMsg];
}

/**
 * 大多是不可恢复的错误，需要通过 UI 提示用户
 */
- (void)onError:(TXLiteAVError)errCode errMsg:(NSString *)errMsg extInfo:(nullable NSDictionary *)extInfo {
    // 有些手机在后台时无法启动音频，这种情况下，TRTC会在恢复到前台后尝试重启音频，不应调用exitRoom。
    BOOL isStartingRecordInBackgroundError =
        errCode == ERR_MIC_START_FAIL &&
        [UIApplication sharedApplication].applicationState != UIApplicationStateActive;
    BOOL isHEVCHardwareDecoderFailed = errCode == 0;
    if (!isStartingRecordInBackgroundError && !isHEVCHardwareDecoderFailed) {
        NSString *msg = [NSString stringWithFormat:@"发生错误: %@ [%d]", errMsg, errCode];
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"TRTC OnError"
                                                                                 message:msg
                                                                          preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"确定"
                                                            style:UIAlertActionStyleDefault
                                                          handler:nil]];
        [self presentViewController:alertController animated:YES completion:nil];
    }
}

- (void)onEnterRoom:(NSInteger)result {
    if (result >= 0) {
        [self toastTip:[NSString stringWithFormat:@"[%@]进房成功[roomId:%@ strRoomId:%@]: elapsed[%@]",
                        self.param.userId,
                        @(self.param.roomId),
                        self.param.strRoomId,
                        @(result)]];
    } else {
        [self exitRoom];
        [self toastTip:[NSString stringWithFormat:@"进房失败: [%ld]", (long)result]];
    }
}


- (void)onExitRoom:(NSInteger)reason {
    NSString *msg = [NSString stringWithFormat:@"离开房间[roomId:%@ strRoomId:%@]: reason[%ld]", @(self.param.roomId), self.param.strRoomId, (long)reason];
    [self toastTip:msg];
}

- (void)onSwitchRole:(TXLiteAVError)errCode errMsg:(NSString *)errMsg {
    self.isLinkingMic = self.param.role == TRTCRoleAnchor;
    [self toastTip:[NSString stringWithFormat:@"切换到%@身份",
                    self.param.role == TRTCRoleAnchor ? @"主播" : @"观众"]];
}
-(void)onConnectionLost
{
    
}
-(void)onConnectionRecovery
{
    
}
- (void)onConnectOtherRoom:(NSString *)userId errCode:(TXLiteAVError)errCode errMsg:(NSString *)errMsg {
    [self toastTip:[NSString stringWithFormat:@"连麦结果:%u %@", errCode, errMsg]];
    if (errCode != 0) {
        [self.remoteUserManager removeUser:userId];
    }
}

- (void)onSwitchRoom:(TXLiteAVError)errCode errMsg:(nullable NSString *)errMsg {
    if (errCode == ERR_NULL) {
        //切换房间后更新房间号标题栏
        NSString *roomId = _param.roomId ? @(_param.roomId).stringValue : _param.strRoomId;
        [self toastTip:[NSString stringWithFormat:@"切换到房间%@", roomId]];
        self.title = roomId;
        //清空上个房间的所有残留视频位
        for (NSString *viewKey in [_remoteViewDic allKeys]) {
            TRTCRenderViewKey *renderKey = [renderViewKeymanager getRenderViewKeyFromHash:viewKey];
            if ([[TRTCFloatWindow sharedInstance] respondsToSelector:@selector(onRemoteUserLeaveRoom:reason:)] && [TRTCFloatWindow sharedInstance].isFloating) {
                [[TRTCFloatWindow sharedInstance] onRemoteUserLeaveRoom:renderKey.userId reason:0];
            }
            [self.remoteUserManager removeUser:renderKey.userId];
            
            NSArray<NSString *> *deletedKey = [renderViewKeymanager unRegisterViewKey:renderKey.userId roomId:renderKey.roomId strRoomId:renderKey.strRoomId];
            for (NSString *viewKey in deletedKey) {
                UIView *view = [_remoteViewDic objectForKey:viewKey];
                if (view) {
                    [view removeFromSuperview];
                }
            }
            [_remoteViewDic removeObjectsForKeys:deletedKey];
            // 如果该成员是大画面，则当其离开后，大画面设置为本地推流画面
            if ([renderKey.userId isEqualToString:_mainViewUserId.userId]){
                _mainViewUserId = [renderViewKeymanager getRenderViewKeyWithUid:self.trtcCloudManager.params.userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId mainRoom:YES mainStream:YES];
            }
        }
        [self relayout];
    }
}
- (void)onStartPublishMediaStream:(NSString *)taskId code:(int)code message:(NSString *)message extraInfo:(NSDictionary *)extraInfo{
    NSLog(@"onStartPublishMediaStream:%@ code:%@, message:%@",taskId,@(code),message);
}
/**
 * 有新的用户加入了当前视频房间
 */
- (void)onRemoteUserEnterRoom:(NSString *)userId {
    if ([[TRTCFloatWindow sharedInstance] respondsToSelector:@selector(onRemoteUserEnterRoom:)] && [TRTCFloatWindow sharedInstance].isFloating) {
        [[TRTCFloatWindow sharedInstance] onRemoteUserEnterRoom:userId];
    }
    NSLog(@"onRemoteUserEnterRoom: %@", userId);
    //若数字型房间号不为0，则取数字房间号，反之取字符串房间号
    NSString *roomId = self.param.roomId ? [NSString stringWithFormat:@"%@", @(self.param.roomId)] : self.param.strRoomId;
    [self.remoteUserManager addUser:userId roomId:roomId];
}
/**
 * 有用户离开了当前视频房间
 */
- (void)onRemoteUserLeaveRoom:(NSString *)userId reason:(NSInteger)reason {
    if ([[TRTCFloatWindow sharedInstance] respondsToSelector:@selector(onRemoteUserLeaveRoom:reason:)] && [TRTCFloatWindow sharedInstance].isFloating) {
        [[TRTCFloatWindow sharedInstance] onRemoteUserLeaveRoom:userId reason:reason];
    }
    NSLog(@"onRemoteUserLeaveRoom: %@", userId);
    [self.remoteUserManager removeUser:userId];
    
    NSArray<NSString *> *deletedKey = [renderViewKeymanager unRegisterViewKey:userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId];
    for (NSString *viewKey in deletedKey) {
        UIView *view = [_remoteViewDic objectForKey:viewKey];
        if (view) {
            [view removeFromSuperview];
        }
    }
    [_remoteViewDic removeObjectsForKeys:deletedKey];
    // 如果该成员是大画面，则当其离开后，大画面设置为本地推流画面
    if ([userId isEqualToString:_mainViewUserId.userId]){
        _mainViewUserId = [renderViewKeymanager getRenderViewKeyWithUid:self.trtcCloudManager.params.userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId mainRoom:YES mainStream:YES];
    }

    [self relayout];
    [self.trtcCloudManager updateCloudMixtureParams];
}

- (void)onUserAudioAvailable:(NSString *)userId available:(BOOL)available {
    NSLog(@"onUserAudioAvailable:userId:%@ available:%u", userId, available);
    [self.remoteUserManager updateUser:userId isAudioEnabled:available];
    TRTCRenderViewKey *renderKey = [renderViewKeymanager getRenderViewKeyWithUid:userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId mainRoom:YES mainStream:YES];
    TRTCVideoView *playerView = [_remoteViewDic objectForKey:[renderKey getHash]];
    if (!available) {
        [playerView setAudioVolumeRadio:0.f];
    }
}

- (void)onUserVideoAvailable:(NSString *)userId available:(BOOL)available {
    NSLog(@"onUserVideoAvailable:userId:%@ available:%u", userId, available);
    [self.remoteUserManager updateUser:userId isVideoEnabled:available];
    TRTCRenderViewKey *renderKey = [renderViewKeymanager getRenderViewKeyWithUid:userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId mainRoom:YES mainStream:YES];
    if (userId != nil) {
        TRTCVideoView* remoteView = [_remoteViewDic objectForKey:[renderKey getHash]];
        if (available) {
            if (remoteView) {
                // 须移除之前的remoteView
                [remoteView removeFromSuperview];
                [_remoteViewDic removeObjectForKey:[renderKey getHash]];
            }
            // 创建一个新的 View 用来显示新的一路画面
            remoteView = [TRTCVideoView newVideoViewWithType:VideoViewType_Remote key:renderKey delegate:self];
            if (!self.trtcCloudManager.audioConfig.isVolumeEvaluationEnabled) {
                [remoteView showAudioVolume:NO];
            }
            [_remoteViewDic setObject:remoteView forKey:[renderKey getHash]];

            // 将新进来的成员设置成大画面
            _mainViewUserId = renderKey;
            [self relayout];
            [self.trtcCloudManager updateCloudMixtureParams];
            if (_enableCustomRender) {
                //使用自定义渲染
                [self.trtcCloudManager playCustomVideoOfUser:userId inView:remoteView];
            } else {
                //使用SDK渲染
                [self.trtcCloudManager startRemoteView:userId streamType:TRTCVideoStreamTypeBig view:remoteView];
            }
            [self.trtcCloudManager setRemoteViewFillMode:userId mode:TRTCVideoFillMode_Fit];
        }
        else {
            [self.trtcCloudManager stopRemoteView:userId streamType:TRTCVideoStreamTypeBig];
        }

        [remoteView showVideoCloseTip:!available];
    }
}

- (void)onUserSubStreamAvailable:(NSString *)userId available:(BOOL)available {
    NSLog(@"onUserSubStreamAvailable:userId:%@ available:%u", userId, available);
    TRTCRenderViewKey *renderKey = [renderViewKeymanager getRenderViewKeyWithUid:userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId mainRoom:YES mainStream:NO];
    if (available) {
        TRTCVideoView *remoteView = [TRTCVideoView newVideoViewWithType:VideoViewType_Remote key:renderKey delegate:self];
        remoteView.streamType = TRTCVideoStreamTypeSub;
        if (!self.trtcCloudManager.audioConfig.isVolumeEvaluationEnabled) {
            [remoteView showAudioVolume:NO];
        }
        [_remoteViewDic setObject:remoteView forKey:[renderKey getHash]];
        
        [self.trtcCloudManager startRemoteSubStreamView:userId view:remoteView];
        [self.trtcCloudManager setRemoteSubStreamViewFillMode:userId mode:TRTCVideoFillMode_Fit];
    }
    else {
        UIView *playerView = [_remoteViewDic objectForKey:[renderKey getHash]];
        [playerView removeFromSuperview];
        [_remoteViewDic removeObjectForKey:[renderKey getHash]];
        [self.trtcCloudManager stopRemoteSubStreamView:userId];
        
        if ([renderKey hash] == [_mainViewUserId hash]) {
            _mainViewUserId = [renderViewKeymanager getRenderViewKeyWithUid:self.trtcCloudManager.params.userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId mainRoom:YES mainStream:NO];
        }
    }
    [self relayout];
}

- (void)onFirstVideoFrame:(NSString *)userId streamType:(TRTCVideoStreamType)streamType width:(int)width height:(int)height {
    NSLog(@"onFirstVideoFrame userId:%@ streamType:%@ width:%d height:%d", userId, @(streamType), width, height);
}

- (void)onNetworkQuality:(TRTCQualityInfo *)localQuality remoteQuality:(NSArray<TRTCQualityInfo *> *)remoteQuality {
    
    [_localView setNetworkIndicatorImage:[self imageForNetworkQuality:localQuality.quality]];
    for (TRTCQualityInfo* qualityInfo in remoteQuality) {
        NSArray<TRTCRenderViewKey *> *keys = [renderViewKeymanager remoteRenderKeysFromUserId:qualityInfo.userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId];
        for (TRTCRenderViewKey *key in keys) {
            TRTCVideoView* remoteVideoView = [_remoteViewDic objectForKey:[key getHash]];
            if (remoteVideoView) {
                [remoteVideoView setNetworkIndicatorImage:[self imageForNetworkQuality:qualityInfo.quality]];
            }
        }
    }
}

- (void)onStatistics:(TRTCStatistics *)statistics {
    NSLog(@"statistic:%@", statistics);
}

- (void)onAudioRouteChanged:(TRTCAudioRoute)route fromRoute:(TRTCAudioRoute)fromRoute {
    NSLog(@"TRTC onAudioRouteChanged %@ -> %@", @(fromRoute), @(route));
}

- (void)onUserVoiceVolume:(NSArray<TRTCVolumeInfo *> *)userVolumes totalVolume:(NSInteger)totalVolume {
    [_remoteViewDic enumerateKeysAndObjectsUsingBlock:^(NSString *  _Nonnull key, TRTCVideoView * _Nonnull obj, BOOL * _Nonnull stop) {
        [obj setAudioVolumeRadio:0.f];
        [obj showAudioVolume:NO];
    }];
    for (TRTCVolumeInfo* volumeInfo in userVolumes) {
        NSArray<TRTCRenderViewKey *> *keys = [renderViewKeymanager remoteRenderKeysFromUserId:volumeInfo.userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId];
        for (TRTCRenderViewKey *key in keys) {
            TRTCVideoView* remoteVideoView = [_remoteViewDic objectForKey:[key getHash]];
            if (remoteVideoView) {
                float radio = ((float)volumeInfo.volume) / 100;
                [remoteVideoView setAudioVolumeRadio:radio];
                [remoteVideoView showAudioVolume:radio > 0];
            }
        }
    }
}

- (void)onRecvCustomCmdMsgUserId:(NSString *)userId cmdID:(NSInteger)cmdID seq:(UInt32)seq message:(NSData *)message {
    NSString *msg = [[NSString alloc] initWithData:message encoding:NSUTF8StringEncoding];
    [self toastTip:[NSString stringWithFormat:@"%@: %@", userId, msg]];
}

- (void)onRecvSEIMsg:(NSString *)userId message:(NSData*)message {
    NSString *msg = [[NSString alloc] initWithData:message encoding:NSUTF8StringEncoding];
    [self toastTip:[NSString stringWithFormat:@"%@: %@", userId, msg]];
}

- (void)onSetMixTranscodingConfig:(int)err errMsg:(NSString *)errMsg {
    NSLog(@"onSetMixTranscodingConfig err:%d errMsg:%@", err, errMsg);
}

- (void)onAudioEffectFinished:(int)effectId code:(int)code {
    [self.effectManager stopEffect:effectId];
}

- (void)onScreenCaptureStarted {
    if (self.trtcCloudManager.videoConfig.source == TRTCVideoSourceDeviceScreen) {
        [self.trtcCloudManager setVideoEnabled:YES streamType:TRTCVideoStreamTypeBig];
        [self.localView showText:ScreenCaptureBroadcasting];
        _broadcastButton.selected = YES;
    } else if (self.trtcCloudManager.videoConfig.subSource == TRTCVideoSourceDeviceScreen) {
        [self.trtcCloudManager setVideoEnabled:YES streamType:TRTCVideoStreamTypeSub];
        [self.localView showText:ScreenCaptureBroadcasting];
        _broadcastButton.selected = YES;
    }
    _broadcastPauseButton.hidden = NO;
    [self toastTip:@"屏幕分享开始"];
}

- (void)onScreenCapturePaused:(int)reason {
    [self.localView showText:ScreenCapturePaused];
    [self toastTip:@"屏幕分享暂停"];
}

- (void)onScreenCaptureResumed:(int)reason {
    [self.localView showText:ScreenCaptureBroadcasting];
    [self toastTip:@"屏幕分享继续"];
}

- (void)onScreenCaptureStoped:(int)reason {
    if (self.trtcCloudManager.videoConfig.source == TRTCVideoSourceDeviceScreen) {
        [self.trtcCloudManager setVideoEnabled:NO streamType:TRTCVideoStreamTypeBig];

        [self.localView showText:ScreenCaptureStopped];
        _broadcastButton.selected = NO;
    } else if (self.trtcCloudManager.videoConfig.subSource == TRTCVideoSourceDeviceScreen) {
        [self.trtcCloudManager setVideoEnabled:NO streamType:TRTCVideoStreamTypeSub];
        
        [self.localView showText:ScreenCaptureStopped];
        _broadcastButton.selected = NO;
    }
    
    _broadcastPauseButton.hidden = YES;
    [self toastTip:@"屏幕分享中止: %@", @(reason)];
}

- (void)onLocalRecordBegin:(NSInteger)errCode storagePath:(NSString*)storagePath {
    if (errCode == 0) {
        [self toastTip:@"开始本地录制成功"];
    } else {
        [self toastTip:@"开始本地录制失败，错误码：%d", errCode];
    }
}

- (void)onLocalRecordComplete:(NSInteger)errCode storagePath:(NSString*)storagePath {
    if (errCode == -1) {
        [self toastTip:@"本地录制异常结束，错误码：%d", errCode];
        return;
    }
    if (errCode == -2) {
        [self toastTip:@"分辨率改变或横竖屏切换导致本地录制结束"];
    }
    if (self.trtcCloudManager.localRecordType == TRTCRecordTypeAudio) {
        NSURL *fileUrl = [NSURL fileURLWithPath:storagePath];
        UIActivityViewController *activityView =
        [[UIActivityViewController alloc] initWithActivityItems:@[fileUrl]
                                          applicationActivities:nil];
        [self presentViewController:activityView animated:YES completion:nil];
    } else {
        __weak __typeof(self) weakSelf = self;
        [PhotoUtil saveAssetToAlbum:[NSURL fileURLWithPath:storagePath]
                         completion:^(BOOL success, NSError * _Nullable error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (success) {
                    [weakSelf toastTip:@"录制文件写入相册成功！"];
                } else {
                    [weakSelf toastTip:@"录制文件写入相册失败！"];
                }
            });
        }];
    }
}

- (void)onLocalRecording:(NSInteger)duration storagePath:(NSString *)storagePath {
//     NSLog(@"====== duration: %ld", (long)duration); // 自测duration是否正常输出
}


- (UIImage*)imageForNetworkQuality:(TRTCQuality)quality
{
    UIImage* image = nil;
    switch (quality) {
        case TRTCQuality_Down:
        case TRTCQuality_Vbad:
            image = [UIImage imageNamed:@"signal5"];
            break;
        case TRTCQuality_Bad:
            image = [UIImage imageNamed:@"signal4"];
            break;
        case TRTCQuality_Poor:
            image = [UIImage imageNamed:@"signal3"];
            break;
        case TRTCQuality_Good:
            image = [UIImage imageNamed:@"signal2"];
            break;
        case TRTCQuality_Excellent:
            image = [UIImage imageNamed:@"signal1"];
            break;
        default:
            break;
    }
    
    return image;
}

- (void)toastTip:(NSString *)toastInfo, ... {
    va_list args;
    va_start(args, toastInfo);
    NSString *log = [[NSString alloc] initWithFormat:toastInfo arguments:args];
    va_end(args);
    __block UITextView *toastView = [[UITextView alloc] init];
    
    toastView.userInteractionEnabled = NO;
    toastView.scrollEnabled = NO;
    toastView.text = log;
    toastView.backgroundColor = [UIColor whiteColor];
    toastView.alpha = 0.5;

    [self.toastStackView addArrangedSubview:toastView];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [toastView removeFromSuperview];
    });
}

#pragma mark - BeautyLoadPituDelegate
- (void)onLoadPituStart
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self toastTip:@"开始加载资源"];
    });
}
- (void)onLoadPituProgress:(CGFloat)progress
{
//    dispatch_async(dispatch_get_main_queue(), ^{
//        [self toastTip:[NSString stringWithFormat:@"正在加载资源%d %%",(int)(progress * 100)]];
//    });
}
- (void)onLoadPituFinished
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self toastTip:@"资源加载成功"];
    });
}
- (void)onLoadPituFailed
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self toastTip:@"资源加载失败"];
    });
}
#ifndef TRTC_INTERNATIONAL
#pragma mark - TXLivePlayListener

- (void)onPlayEvent:(int)EvtID withParam:(NSDictionary *)param {
    if (EvtID == PLAY_ERR_NET_DISCONNECT) {
        [self toggleCdnPlay];
        [self toastTip:(NSString *) param[EVT_MSG]];
    } else if (EvtID == PLAY_EVT_PLAY_END) {
        [self toggleCdnPlay];
    } else if (EvtID == EVT_PLAY_GET_MESSAGE) {
        NSData *msgData = param[@"EVT_GET_MSG"];
        NSString *msg = [[NSString alloc] initWithData:msgData encoding:NSUTF8StringEncoding];
        if (msg) {
            [self toastTip:msg];
        }
    }
}
#endif
#pragma mark - TRTCCloudManagerDelegate

- (void)roomSettingsManager:(TRTCCloudManager *)manager didSetVolumeEvaluation:(BOOL)isEnabled {
    for (TRTCVideoView* videoView in _remoteViewDic.allValues) {
        [videoView setAudioVolumeRadio:0];
        [videoView showAudioVolume:isEnabled];
    }
}

- (void)roomSettingsManager:(TRTCCloudManager *)manager enableVOD:(BOOL)isEnabled {
#ifndef DISABLE_VOD
    if (isEnabled) {
        if (_vodVC == nil) {
            _vodVC = [[TRTCVODViewController alloc] init];
            [self.view addSubview:_vodVC.view];
        }
    } else {
        if (_vodVC) {
            [_vodVC stopPlay];
            [_vodVC.view removeFromSuperview];
            _vodVC = nil;
        }
    }
#endif
}

- (void)roomSettingsManager:(TRTCCloudManager *)manager enableVODAttachToTRTC:(BOOL)isEnabled {
#ifndef DISABLE_VOD
    if (_vodVC) {
        [_vodVC setEnableAttachVodToTRTC:isEnabled trtcCloud:self.trtcCloudManager.trtc];
    }
#endif
}

- (void)onMuteLocalAudio:(BOOL)isMute {
    self.muteButton.selected = isMute;
}

#pragma mark - TRTCCloudManagerDelegate SubRoom

- (void)onEnterSubRoom:(NSString *)roomId result:(NSInteger)result {
    
}

- (void)onExitSubRoom:(NSString *)roomId reason:(NSInteger)reason {
    //当退出子房间时，清除该子房间下的所有视频渲染控件
    NSMutableArray *allUsers = [self.subRoomRemoteUserDic objectForKey:roomId];
    for (int i = 0; i < allUsers.count; i ++) {
        NSString *userId = allUsers[i];
        NSArray<NSString *> *deletedKey = [renderViewKeymanager unRegisterViewKey:userId roomId:roomId.intValue strRoomId:nil];//目前子房间UI入口只适配了数字类型的房间号
        for (NSString *viewKey in deletedKey) {
            UIView *view = [_remoteViewDic objectForKey:viewKey];
            if (view) {
                [view removeFromSuperview];
                // 必须移除，否则`view`依然不会及时释放且占位布局
                [_remoteViewDic removeObjectForKey:viewKey];
            }
        }
        //如果该成员是大画面，则当其离开后，大画面设置为本地推流画面
        if ([deletedKey containsObject:[_mainViewUserId getHash]]) {
            _mainViewUserId = [renderViewKeymanager getRenderViewKeyWithUid:self.trtcCloudManager.params.userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId mainRoom:YES mainStream:YES];
        }
    }
    [self relayout];
    self.localView.hidden = NO;
    [self.trtcCloudManager updateCloudMixtureParams];
    [self.subRoomRemoteUserDic removeObjectForKey:roomId];
}

- (void)onSubRoomUserAudioAvailable:(NSString *)roomId userId:(NSString *)userId available:(BOOL)available {
    
}

- (void)onSubRoomUserVideoAvailable:(NSString *)roomId userId:(NSString *)userId available:(BOOL)available {
    [self.remoteUserManager updateUser:userId isVideoEnabled:available];
    TRTCRenderViewKey *renderKey = [renderViewKeymanager getRenderViewKeyWithUid:userId roomId:roomId.intValue strRoomId:nil mainRoom:NO mainStream:YES];//目前子房间UI入口只适配了数字类型的房间号
    if (userId != nil) {
        TRTCVideoView* remoteView = [_remoteViewDic objectForKey:[renderKey getHash]];
        if (available) {
            if (!remoteView) {
                //创建一个新的 View 用来显示新的一路画面
                remoteView = [TRTCVideoView newVideoViewWithType:VideoViewType_Remote key:renderKey delegate:self];
            }
            if (!self.trtcCloudManager.audioConfig.isVolumeEvaluationEnabled) {
                [remoteView showAudioVolume:NO];
            }
            [_remoteViewDic setObject:remoteView forKey:[renderKey getHash]];

            //将新进来的成员设置成大画面
            _mainViewUserId = renderKey;

            [self relayout];
            [self.trtcCloudManager updateCloudMixtureParams];
            //子房间的远端画面直接使用SDK渲染
            [self.trtcCloudManager startSubRoomRemoteView:userId roomId:roomId streamType:TRTCVideoStreamTypeBig view:remoteView];
        }
        else {
            [self.trtcCloudManager stopSubRoomRemoteView:userId roomId:roomId streamType:TRTCVideoStreamTypeBig];
        }
        [remoteView showVideoCloseTip:!available];
    }
}

- (void)onSubRoomRemoteUserEnterRoom:(NSString *)roomId userId:(NSString *)userId {
    NSMutableArray *array = [self.subRoomRemoteUserDic objectForKey:roomId];
    if (!array) {
        array = [[NSMutableArray alloc] init];
    }
    [array addObject:userId];
    if (array) {
        [self.subRoomRemoteUserDic setObject:array forKey:roomId];
    }
    [self.remoteUserManager addUser:userId roomId:roomId];
}

- (void)onSubRoomRemoteUserLeaveRoom:(NSString *)roomId userId:(NSString *)userId reason:(NSInteger)reason {
    NSMutableArray *array = [self.subRoomRemoteUserDic objectForKey:roomId];
    [array removeObject:userId];
    if (array) {
        [self.subRoomRemoteUserDic setObject:array forKey:roomId];
    }
    NSArray<NSString *> *deletedKey = [renderViewKeymanager unRegisterViewKey:userId roomId:roomId.intValue strRoomId:nil];//目前子房间UI入口只适配了数字类型的房间号
    for (NSString *viewKey in deletedKey) {
        UIView *view = [_remoteViewDic objectForKey:viewKey];
        if (view) {
            [view removeFromSuperview];
        }
    }
    [_remoteViewDic removeObjectsForKeys:deletedKey];
    // 如果该成员是大画面，则当其离开后，大画面设置为本地推流画面
    if ([userId isEqualToString:_mainViewUserId.userId]){
        _mainViewUserId = [renderViewKeymanager getRenderViewKeyWithUid:self.trtcCloudManager.params.userId roomId:self.trtcCloudManager.params.roomId strRoomId:self.trtcCloudManager.params.strRoomId mainRoom:YES mainStream:YES];
    }
    [self relayout];
    [self.trtcCloudManager updateCloudMixtureParams];
}


#pragma mark - TRTCCloudDelegate Audio

- (void)onCapturedRawAudioFrame:(TRTCAudioFrame *)frame {
    if (_enableAudioDump && _captureAudioDumpFile) {
        fwrite(frame.data.bytes, 1, frame.data.length, _captureAudioDumpFile);
    }
}

- (void)onLocalProcessedAudioFrame:(TRTCAudioFrame *)frame {
    
}

- (void)onRemoteUserAudioFrame:(TRTCAudioFrame *)frame userId:(NSString *)userId {
    
}

- (void)onMixedPlayAudioFrame:(TRTCAudioFrame *)frame {
    if (_enableAudioDump && _mixAudioDumpFile) {
        fwrite(frame.data.bytes, 1, frame.data.length, _mixAudioDumpFile);
    }
}

- (void)onFirstAudioFrame:(NSString*)userId {
    
}

- (void)onSendFirstLocalAudioFrame {
    
}

@end
