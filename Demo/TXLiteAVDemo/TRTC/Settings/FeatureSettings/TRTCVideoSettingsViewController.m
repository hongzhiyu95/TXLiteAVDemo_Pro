/*
* Module:   TRTCVideoSettingsViewController
*
* Function: 视频设置页
*
*    1. 通过TRTCCloudManager来设置视频参数
*
*    2. 设置分辨率后，码率的设置范围以及默认值会根据分辨率进行调整
*
*/

#import "TRTCVideoSettingsViewController.h"
#import "MBProgressHUD.h"

@interface TRTCVideoSettingsViewController ()

@property (strong, nonatomic) TRTCSettingsSliderItem *bitrateItem;
@property (strong, nonatomic) TRTCSettingsSliderItem *subStreamBitrateItem;
@property (strong, nonatomic) TRTCSettingsSwitchItem *pushVideoItem;
@property (assign, nonatomic) CGSize blackNalSize;

@end

@implementation TRTCVideoSettingsViewController

- (NSString *)title {
    return @"视频";
}

- (void)viewDidLoad {
    [super viewDidLoad];

    TRTCVideoConfig *config = self.trtcCloudManager.videoConfig;
    __weak __typeof(self) wSelf = self;
    
    self.bitrateItem = [[TRTCSettingsSliderItem alloc]
                        initWithTitle:@"主路码率"
                        value:0 min:0 max:0 step:0
                        continuous:NO
                        action:^(float bitrate) {
        [wSelf onSetBitrate:bitrate];
    }];
    
    self.subStreamBitrateItem = [[TRTCSettingsSliderItem alloc]
                                 initWithTitle:@"辅路码率"
                                 value:0 min:0 max:0 step:0
                                 continuous:NO
                                 action:^(float bitrate) {
        [wSelf onSetSubStreamBitrate:bitrate];
    }];
    
    self.pushVideoItem = [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启推送视频"
                                                                  isOn:!config.isMuted
                                                                action:^(BOOL isOn) {[wSelf onMuteVideo:!isOn];}];
    
    self.items = @[
        [[TRTCSettingsSelectorItem alloc] initWithTitle:@"主路分辨率"
                                                  items:TRTCVideoConfig.resolutionNames
                                          selectedIndex:config.resolutionIndex
                                                 action:^(NSInteger index) {
            [wSelf onSelectResolutionIndex:index];
        }],
        [[TRTCSettingsSelectorItem alloc] initWithTitle:@"辅路分辨率"
                                                  items:TRTCVideoConfig.resolutionNames
                                          selectedIndex:config.resolutionIndex
                                                 action:^(NSInteger index) {
            [wSelf onSelectSubStreamResolutionIndex:index];
        }],
        [[TRTCSettingsSelectorItem alloc] initWithTitle:@"主路帧率"
                                                  items:TRTCVideoConfig.fpsList
                                          selectedIndex:config.fpsIndex
                                                 action:^(NSInteger index) {
            [wSelf onSelectFpsIndex:index];
        }],
        [[TRTCSettingsSelectorItem alloc] initWithTitle:@"辅路帧率"
                                                  items:TRTCVideoConfig.fpsList
                                          selectedIndex:config.fpsIndex
                                                 action:^(NSInteger index) {
            [wSelf onSelectSubStreamFpsIndex:index];
        }],
        self.bitrateItem,
        self.subStreamBitrateItem,
        [[TRTCSettingsSegmentItem alloc] initWithTitle:@"画质偏好"
                                                 items:@[@"优先流畅", @"优先清晰"]
                                         selectedIndex:config.qosPreferenceIndex
                                                action:^(NSInteger index) {
            [wSelf onSelectQosPreferenceIndex:index];
        }],
        [[TRTCSettingsSegmentItem alloc] initWithTitle:@"画面方向"
                                                 items:@[@"横屏模式", @"竖屏模式"]
                                         selectedIndex:config.videoEncConfig.resMode
                                                action:^(NSInteger index) {
            [wSelf onSelectResolutionModelIndex:index];
        }],
        [[TRTCSettingsSegmentItem alloc] initWithTitle:@"填充模式"
                                                 items:@[@"充满", @"适应"]
                                         selectedIndex:config.localRenderParams.fillMode
                                                action:^(NSInteger index) {
            [wSelf onSelectFillModeIndex:index];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启265硬编"
                                                 isOn:config.isH265Enabled
                                               action:^(BOOL isOn) {
            [wSelf onEnableHEVCEncode:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"更改本地265编解码能力"
                                                 isOn:config.enableHEVCAbility
                                               action:^(BOOL isOn) {
            [wSelf onEnableHEVCAbility:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启视频采集"
                                                 isOn:config.isEnabled
                                               action:^(BOOL isOn) {
            [wSelf onEnableVideo:isOn];
        }],
        self.pushVideoItem,
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"暂停屏幕采集"
                                                 isOn:config.isScreenCapturePaused
                                               action:^(BOOL isOn) {
            [wSelf onPauseScreenCapture:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启垫片"
                                                 isOn:config.isScreenCapturePaused
                                               action:^(BOOL isOn) {
            [wSelf onEnableVideoMuteImage:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启黑帧"
                                                 isOn:NO
                                               action:^(BOOL isOn) {
            [wSelf onEnableBlackNal:isOn];
        }],
        [[TRTCSettingsSegmentItem alloc] initWithTitle:@"黑帧比例"
                                                 items:@[@"默认64*64", @"竖屏16比9"]
                                         selectedIndex:0
                                                action:^(NSInteger index) {
            [wSelf onBlackNalSizeIndex:index];
        }],
        [[TRTCSettingsSegmentItem alloc] initWithTitle:@"开启预览镜像"
                                                 items:TRTCVideoConfig.localMirrorTypeNames
                                         selectedIndex:config.localRenderParams.mirrorType
                                                action:^(NSInteger index) {
            [wSelf onSelectLocalMirror:index];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启远程镜像"
                                                 isOn:config.isRemoteMirrorEnabled
                                               action:^(BOOL isOn) {
            [wSelf onEnableRemoteMirror:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启视频水印" isOn:NO action:^(BOOL isOn) {
            [wSelf onEnableWatermark:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"清晰度增强" isOn:YES action:^(BOOL isOn) {
            [wSelf onEnableSharpnessEnhancement:isOn];
        }],
        [[TRTCSettingsSegmentItem alloc] initWithTitle:@"美颜回调"
                                                 items:TRTCVideoConfig.formatNames
                                         selectedIndex:config.formatIndex
                                                action:^(NSInteger index) {
            [wSelf onUpdatePreprocessFormatIndex:index];
        }],
        [[TRTCSettingsSliderItem alloc] initWithTitle:@"画面亮度"
                                                value:config.brightness min:-1 max:1 step:0.1
                                           continuous:YES
                                               action:^(float brightness) {
            [wSelf onUpdateBrightness:brightness];
        }],
        [[TRTCSettingsSelectorItem alloc] initWithTitle:@"截图" items:@[@"视频流截图", @"画面截图"] selectedIndex:0 action:^(NSInteger index) {
            [wSelf snapshotLocalVideo:index];
        }],
    ];
    
    [self updateBitrateItemWithResolution:config.videoEncConfig.videoResolution];
}

- (void)viewWillAppear:(BOOL)animated {
    self.pushVideoItem.isOn = !self.trtcCloudManager.videoConfig.isMuted;
    [self.tableView reloadData];
}

#pragma mark - Actions

- (void)onSelectResolutionIndex:(NSInteger)index {
    TRTCVideoResolution resolution = [TRTCVideoConfig.resolutions[index] integerValue];
    [self.trtcCloudManager setResolution:resolution];
    [self updateBitrateItemWithResolution:resolution];
}

- (void)onSelectSubStreamResolutionIndex:(NSInteger)index {
    TRTCVideoResolution resolution = [TRTCVideoConfig.resolutions[index] integerValue];
    [self.trtcCloudManager setSubStreamResolution:resolution];
    [self updateSubStreamBitrateItemWithResolution:resolution];
}

- (void)onSelectFpsIndex:(NSInteger)index {
    [self.trtcCloudManager setVideoFps:[TRTCVideoConfig.fpsList[index] intValue]];
}

- (void)onSelectSubStreamFpsIndex:(NSInteger)index {
    [self.trtcCloudManager setSubStreamVideoFps:[TRTCVideoConfig.fpsList[index] intValue]];
}

- (void)onSetBitrate:(float)bitrate {
    [self.trtcCloudManager setVideoBitrate:bitrate];
}

- (void)onSetSubStreamBitrate:(float)bitrate {
    [self.trtcCloudManager setSubStreamVideoBitrate:bitrate];
}

- (void)onSelectQosPreferenceIndex:(NSInteger)index {
    TRTCVideoQosPreference qos = index == 0 ? TRTCVideoQosPreferenceSmooth : TRTCVideoQosPreferenceClear;
    [self.trtcCloudManager setQosPreference:qos];
}

- (void)onSelectResolutionModelIndex:(NSInteger)index {
    TRTCVideoResolutionMode mode = index == 0 ? TRTCVideoResolutionModeLandscape : TRTCVideoResolutionModePortrait;
    [self.trtcCloudManager setResolutionMode:mode];
}

- (void)onSelectFillModeIndex:(NSInteger)index {
    TRTCVideoFillMode mode = index == 0 ? TRTCVideoFillMode_Fill : TRTCVideoFillMode_Fit;
    [self.trtcCloudManager setVideoFillMode:mode];
}

- (void)onEnableHEVCEncode:(BOOL)isOn {
    [self.trtcCloudManager enableHEVCEncode:isOn];
}

- (void)onEnableHEVCAbility:(BOOL)isOn {
    if ([self isSupportEncodeH265] && [self isSupportDecodeH265]) {
        [self.trtcCloudManager enableHEVCAbility:isOn];
    } else {
        NSLog(@"不支持265编解码，无法变跟能力进行测试");
    }
}

- (BOOL)isSupportEncodeH265
{
    if (@available(iOS 11.0, macOS 10.13, *)) {
        static BOOL isSupported = NO;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            isSupported = [[AVAssetExportSession allExportPresets] containsObject:AVAssetExportPresetHEVCHighestQuality];
        });
        return isSupported;
    }
    return NO;
}

- (BOOL)isSupportDecodeH265
{
#if defined(__MAC_10_13) || defined(__IPHONE_11_0)
    if (@available(iOS 11.0, macOS 10.13, *)) {
       return YES;
    }
#endif
    return NO;
}

- (void)onEnableVideo:(BOOL)isOn {
    [self.trtcCloudManager setVideoEnabled:isOn];
}

- (void)onMuteVideo:(BOOL)isMuted {
    NSString *mainRoomId = self.trtcCloudManager.params.roomId ?
    [@(self.trtcCloudManager.params.roomId) stringValue] : self.trtcCloudManager.params.strRoomId;
    if ([self.trtcCloudManager.currentPublishingRoomId isEqualToString:mainRoomId]) {
        //若当前在主房间中推流，则调用TRTCCloud切换视频上行
        [self.trtcCloudManager setVideoMuted:isMuted];
    } else {
        //否则找到对应的TRTCSubCloud切换上行
        [self.trtcCloudManager pushVideoStreamInSubRoom:self.trtcCloudManager.currentPublishingRoomId push:
         !isMuted];
    }
}

- (void)onPauseScreenCapture:(BOOL)isPaused {
    [self.trtcCloudManager pauseScreenCapture:isPaused];
}

- (void)onEnableVideoMuteImage:(BOOL)isEnabled {
    [self.trtcCloudManager enableVideoMuteImage:isEnabled];
}

- (void)onEnableBlackNal:(BOOL)isEnable {
    [self.trtcCloudManager enableBlackStream:isEnable size:self.blackNalSize];
}

- (void)onBlackNalSizeIndex:(NSInteger)index {
    self.blackNalSize = index == 0 ? CGSizeZero : CGSizeMake(90, 160);
}

- (void)onSelectLocalMirror:(NSInteger)index {
    [self.trtcCloudManager setLocalMirrorType:index];
}

- (void)onEnableRemoteMirror:(BOOL)isOn {
    [self.trtcCloudManager setRemoteMirrorEnabled:isOn];
}

- (void)onEnableWatermark:(BOOL)isOn {
    if (isOn) {
        UIImage *image = [UIImage imageNamed:@"watermark"];
        [self.trtcCloudManager setWaterMark:image inRect:CGRectMake(0.7, 0.1, 0.2, 0)];
    } else {
        [self.trtcCloudManager setWaterMark:nil inRect:CGRectZero];
    }
}

- (void)onEnableSharpnessEnhancement:(BOOL)isOn {
    [self.trtcCloudManager enableSharpnessEnhancement:isOn];
}

- (void)onUpdatePreprocessFormatIndex:(NSInteger)index {
    TRTCVideoPixelFormat format = [TRTCVideoConfig.formats[index] integerValue];
    [self.trtcCloudManager setCustomProcessFormat:format];
}

- (void)onUpdateBrightness:(CGFloat)brightness {
    [self.trtcCloudManager setCustomBrightness:brightness];
}

- (void)snapshotLocalVideo:(NSInteger)index {
    __weak __typeof(self) wSelf = self;
    [self.trtcCloudManager.trtc snapshotVideo:nil
                                        type:TRTCVideoStreamTypeBig
                                   sourceType:(TRTCSnapshotSourceType)index
                             completionBlock:^(TXImage *image) {
        if (image) {
            [wSelf shareImage:image];
        } else {
            MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
            hud.mode = MBProgressHUDModeText;
            hud.label.text = @"无图片";
            [hud showAnimated:YES];
            [hud hideAnimated:YES afterDelay:1];
        }
    }];
}

- (void)updateBitrateItemWithResolution:(TRTCVideoResolution)resolution {
    TRTCBitrateRange *range = [TRTCVideoConfig bitrateRangeOf:resolution
                                                        scene:self.trtcCloudManager.scene];
    self.bitrateItem.maxValue = range.maxBitrate;
    self.bitrateItem.minValue = range.minBitrate;
    self.bitrateItem.step = range.step;
    self.bitrateItem.sliderValue = range.defaultBitrate;
    
    [self.trtcCloudManager setVideoBitrate:(int)range.defaultBitrate];
    [self.tableView reloadData];
}

- (void)updateSubStreamBitrateItemWithResolution:(TRTCVideoResolution)resolution {
    TRTCBitrateRange *range = [TRTCVideoConfig bitrateRangeOf:resolution
                                                        scene:self.trtcCloudManager.scene];
    self.subStreamBitrateItem.maxValue = range.maxBitrate;
    self.subStreamBitrateItem.minValue = range.minBitrate;
    self.subStreamBitrateItem.step = range.step;
    self.subStreamBitrateItem.sliderValue = range.defaultBitrate;
    
    [self.trtcCloudManager setSubStreamVideoBitrate:(int)range.defaultBitrate];
    [self.tableView reloadData];
}

- (void)shareImage:(UIImage *)image {
    UIActivityViewController *vc = [[UIActivityViewController alloc]
                                    initWithActivityItems:@[image]
                                    applicationActivities:nil];
    [self presentViewController:vc animated:YES completion:nil];
}

@end
