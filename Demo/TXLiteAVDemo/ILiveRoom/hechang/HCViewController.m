//
//  HCViewController.m
//  TXLiteAVDemo_ILiveRoom_Smart
//
//  Created by hans on 2020/3/4.
//  Copyright © 2020 Tencent. All rights reserved.
//

#import "HCViewController.h"
#import "UIView+Additions.h"
#import "CLLrcView.h"
#import "CLLrcLabel.h"
#import "iLiveRenderView.h"
@interface HCViewController() <HeChangMusicDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>

@end

@implementation HCViewController {
    UIView                      *_mainView;
    UIView                      *_subView;
    HeChangAdapter              *_liveRoom;
    int                         _capWidth;
    int                         _capHeight;
    UITextView                  *_toastView;
    CLLrcView                   *_lrcView;
    CLLrcLabel                  *_lrcLabel;
    AVCaptureSession            *_captureSession;
    iLiveRenderView             *_mainPusherView;
    iLiveRenderView             *_subPusherView;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    NSString *strTitle = @"";
    switch (self.mode) {
        case HeChangDefaultMode:
            strTitle = @"音视频";
            break;
       case HeChangAudioMode:
            strTitle = @"纯音频";
            break;
        case HeChangVideoOnlyMixAudioMode:
            strTitle = @"音视频（只混音频）";
            break;
        default:
            break;
    }
    [self setTitle:[NSString stringWithFormat:@"%@-uid:%llu-role:%d", strTitle, self.userId, (int)self.role]];
    [self initView];
    [self initSDK];
    if ((_mode == HeChangDefaultMode || _mode == HeChangVideoOnlyMixAudioMode)&& ( _role == HeChangMainSingerRole || _role == HeChangSubSingerRole)) {
        [self openCapture];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
}

- (void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    [_liveRoom sendVideoSampleBuffer:sampleBuffer];
    if (_role == HeChangMainSingerRole) {
        [_mainPusherView renderFrame:sampleBuffer];
    } else if(_role == HeChangSubSingerRole) {
        [_subPusherView renderFrame:sampleBuffer];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewDidDisappear:(BOOL)animated {
    [_liveRoom destroy];
    [_captureSession stopRunning];
}

- (void)applicationWillResignActive:(NSNotification*)notification {
    [_captureSession stopRunning];
}

- (void)applicationDidBecomeActive:(NSNotification*)notification {
    [_captureSession startRunning];
}

- (void)openCapture {
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = AVCaptureSessionPreset1280x720;// 1280*720 和 960*540 等比，直接用 720 采集吧。
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    
    AVCaptureDevice *inputCamera = nil;
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if ([device position] == AVCaptureDevicePositionFront) {
            inputCamera = device;
        }
    }
    AVCaptureDeviceInput *captureDeviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:inputCamera error:nil];
    if ([_captureSession canAddInput:captureDeviceInput]) {
        [_captureSession addInput:captureDeviceInput];
    }
    
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    [captureOutput setAlwaysDiscardsLateVideoFrames:NO];
    [captureOutput setVideoSettings:[NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey]];
    [captureOutput setSampleBufferDelegate:self queue:queue];
    if ([_captureSession canAddOutput:captureOutput]) {
        [_captureSession  addOutput:captureOutput];
    }
    
    AVCaptureConnection *connection = [captureOutput connectionWithMediaType:AVMediaTypeVideo];
    [connection setVideoOrientation:AVCaptureVideoOrientationPortrait];
    
    [_captureSession startRunning];
}

- (void)initView {
    // 提示
    _toastView = [[UITextView alloc] init];
    _toastView.editable = NO;
    _toastView.selectable = NO;
    
    [self.view setBackgroundColor:UIColor.darkGrayColor];
    
    _capWidth = 540;
    _capHeight = 960;
    
    if (_role == HeChangMainSingerRole) {
        UIButton *btnStart = [UIButton buttonWithType:UIButtonTypeCustom];
        btnStart.frame = CGRectMake(40, self.view.height - 70, self.view.width - 80, 50);
        btnStart.layer.cornerRadius = 8;
        btnStart.layer.masksToBounds = YES;
        btnStart.layer.shadowOffset = CGSizeMake(1, 1);
        btnStart.layer.shadowOpacity = 0.8;
        [btnStart setTitle:@"开始合唱" forState:UIControlStateNormal];
        [btnStart addTarget:self action:@selector(onClickStart:) forControlEvents:UIControlEventTouchUpInside];
        [self.view addSubview:btnStart];
    }
    
    
//    UIButton *btnMute = [UIButton buttonWithType:UIButtonTypeCustom];
//    btnMute.frame = CGRectMake(40, self.view.height - 150, self.view.width - 80, 50);
//    btnMute.layer.cornerRadius = 8;
//    btnMute.layer.masksToBounds = YES;
//    btnMute.layer.shadowOffset = CGSizeMake(1, 1);
//    btnMute.layer.shadowOpacity = 0.8;
//    btnMute.tag = 0;
//    [btnMute setTitle:@"本地静音" forState:UIControlStateNormal];
//    [btnMute addTarget:self action:@selector(onClickMute:) forControlEvents:UIControlEventTouchUpInside];
//    [self.view addSubview:btnMute];
    
    CGSize size = [[UIScreen mainScreen] bounds].size;
    
    if (_role == HeChangSubSingerRole) {
        // 副播需要两个 View，其他人都是一个
        _mainView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width / 2, size.height/3)];
        [self.view addSubview:_mainView];
        
        _subPusherView = [[iLiveRenderView alloc] initWithFrame:CGRectMake(size.width / 2, 0, size.width / 2, size.height/3)];
        [self.view addSubview:_subPusherView];
    } else {
        if (_role == HeChangMainSingerRole) {
            _mainPusherView = [[iLiveRenderView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height/3)];
            [self.view addSubview:_mainPusherView];
        } else {
            if (_mode == HeChangDefaultMode) {
                _subView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height/3)];
                [self.view addSubview:_subView];
            } else if(_mode == HeChangVideoOnlyMixAudioMode) {
                _mainView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, size.width / 2, size.height/3)];
                [self.view addSubview:_mainView];
                
                _subView = [[UIView alloc] initWithFrame:CGRectMake(size.width/2, 0, size.width/2, size.height/3)];
                [self.view addSubview:_subView];
            }
        }
    }

    _lrcLabel = [[CLLrcLabel alloc] init];
    _lrcLabel.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
    _lrcLabel.textColor = [UIColor whiteColor];
    
    _lrcView = [[CLLrcView alloc] initWithFrame:CGRectMake(0, size.height/3, size.width, size.height/3)];
    _lrcView.lrcName = @"sing_word.lrc";
    
    [self.view addSubview:_lrcLabel];
    [self.view addSubview:_lrcView];
    _lrcView.currentTime = 0;
}

- (void)initSDK {
    _liveRoom = [[HeChangAdapter alloc] init];
    _liveRoom.musicDelegate = self;
    if(_mode == HeChangDefaultMode || _mode == HeChangVideoOnlyMixAudioMode) {
        UIView *view = nil;
        if (_role == HeChangMainSingerRole) {
            view = _mainView;
        } else if (_role == HeChangSubSingerRole) {
            view = _subView;
        }
        if(view != nil) {
//            [_adapter startLocalPreivew];
        }
    }
    OneSecAdapterParams *params = [[OneSecAdapterParams alloc] init];
    params.roomName = self.roomName;
    params.privateMap = 255;
    params.userSig = self.userSign;
    params.roomRole = TXILiveRoomRoleAudience;
    params.sdkAppId = self.sdkAppId;
    params.userId = self.userId;
    
    TXILiveRoomConfig *config = [[TXILiveRoomConfig alloc] init]; // 使用默认值即可
    config.pauseImg = [UIImage imageNamed:@"pause_publish.jpg"];
    config.videoResolution = TXILIVEROOM_VIDEO_RESOLUTION_TYPE_540_960;
    config.videoBitrate = 1000;
    config.autoSampleBufferSize = NO;
    // MV模式，使用自定义视频数据，其他情况使用SDK采集的视频
    config.customModeType = TXILiveRoomCustomModeTypeVideo;
    config.sampleBufferSize = CGSizeMake(540, 960);
    config.videoFps = 15;

    [_liveRoom joinRoom:params config:config];
    [self updateHCConfig:_mode == HeChangDefaultMode || _mode == HeChangVideoOnlyMixAudioMode];
}

- (void)updateHCConfig:(BOOL)useView {
    NSMutableDictionary<NSNumber*,HeChangRoleConfig*> *roleConfig = [[NSMutableDictionary alloc] init];
    
    for (NSNumber *key in [self.rolePair allKeys]) {
        HeChangRole role = (HeChangRole)[[self.rolePair objectForKey:key] intValue];
        HeChangRoleConfig *config = [[HeChangRoleConfig alloc] init];
        config.role = role;
        config.userId = [key longLongValue];
        if(role == HeChangMainSingerRole) {
            config.renderView = useView ? _mainView : nil;
            config.width = _capWidth;
            config.height = _capHeight;
        } else if(role == HeChangSubSingerRole){
            config.renderView = useView ? _subView : nil;
            config.width = _capWidth;
            config.height = _capHeight;
        }
        [roleConfig setObject:config forKey:key];
    }
    [_liveRoom updateHCConfig:_mode role:_role roleConfig:roleConfig targetVideoWidth:_capWidth * 2 targetVideoHeight:_capHeight];
}

- (void)onClickStart:(UIButton *)sender {
    [_liveRoom playMusic:[[NSBundle mainBundle] pathForResource:@"sing" ofType:@"mp3"] loopback:NO times:1];
}

- (void)onClickMute:(UIButton *)sender {
    if (sender.tag == 0) {
        sender.tag = 1;
        [_liveRoom muteLocalAudio:YES];
    } else {
        sender.tag = 0;
        [_liveRoom muteLocalAudio:NO];
    }
}


- (void)onMusicPlayBegin {
    [self toastTip:@"BGM 播放开始" time:1];
}

- (void)onMusicPlayProgress:(long)progress {
    dispatch_async(dispatch_get_main_queue(), ^{
       // UI更新代码
       _lrcView.currentTime = progress;
    });
}

- (void)onMusicPlayFinish {
    [self toastTip:@"BGM 播放完毕" time:1];
}

- (void)onMusicPlayError:(int)code {
    [self toastTip:[NSString stringWithFormat:@"BGM 播放失败 coe:%d", code] time:1];
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

- (float)heightForString:(UITextView *)textView andWidth:(float)width {
    CGSize sizeToFit = [textView sizeThatFits:CGSizeMake(width, MAXFLOAT)];
    return sizeToFit.height;
}

@end
