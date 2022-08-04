/*
* Module:   TRTCMoreSettingsViewController
*
* Function: 其它设置页
*
*    1. 其它设置项包括: 流控方案、双路编码开关、默认观看低清、重力感应和闪光灯切换
*
*    2. 发送自定义消息和SEI消息，两种消息的说明可参见TRTC的文档或TRTCCloud.h中的接口注释。
*
*/

#import "TRTCMoreSettingsViewController.h"

@interface TRTCMoreSettingsViewController ()

@property (assign, nonatomic) BOOL enableVodAttachToTRTC;

@end

@implementation TRTCMoreSettingsViewController

- (NSString *)title {
    return @"其它";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    TRTCVideoConfig *config = self.trtcCloudManager.videoConfig;
    __weak __typeof(self) wSelf = self;
    self.items = @[
        [[TRTCSettingsSegmentItem alloc] initWithTitle:@"流控方案"
                                                 items:@[@"客户端控", @"云端流控"]
                                         selectedIndex:config.qosConfig.controlMode
                                                action:^(NSInteger index) {
            [wSelf onSelectQosControlModeIndex:index];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启双路编码"
                                                 isOn:config.isSmallVideoEnabled
                                               action:^(BOOL isOn) {
            [wSelf onEnableSmallVideo:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"默认观看低清"
                                                 isOn:config.prefersLowQuality
                                               action:^(BOOL isOn) {
            [wSelf onEnablePrefersLowQuality:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启重力感应"
                                                 isOn:config.isGSensorEnabled
                                               action:^(BOOL isOn) {
            [wSelf onEnableGSensor:isOn];
        }],
        [[TRTCSettingsButtonItem alloc] initWithTitle:@"切换闪光灯" buttonTitle:@"切换" action:^{
            [wSelf onToggleTorchLight];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启自动对焦"
                                                 isOn:config.isAutoFocusOn
                                               action:^(BOOL isOn) {
            [wSelf onEnableAutoFocus:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启点播播放器"
                                                 isOn:self.trtcCloudManager.enableVOD
                                               action:^(BOOL isOn) {
            // 推送至TRTC辅路按钮打开时，vod player销毁前进行dettach TRTC
            if (wSelf.enableVodAttachToTRTC && !isOn){
                [wSelf onEnableAttachVodToTRTC:NO];
            }
            [wSelf onEnableVOD:isOn];
            // 推送至TRTC辅路按钮打开时，vod player创建后进行attach至TRTC
            if (wSelf.enableVodAttachToTRTC && isOn){
                [wSelf onEnableAttachVodToTRTC:YES];
            }
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"推送点播流至TRTC辅路" isOn:NO action:^(BOOL isOn) {
            [wSelf onEnableAttachVodToTRTC:isOn];
            wSelf.enableVodAttachToTRTC = isOn;
        }],
        [[TRTCSettingsMessageItem alloc] initWithTitle:@"自定义消息" placeHolder:@"测试消息" action:^(NSString *message) {
            [wSelf sendMessage:message];
        }],
        [[TRTCSettingsMessageItem alloc] initWithTitle:@"SEI消息" placeHolder:@"测试SEI消息" action:^(NSString *message) {
            [wSelf sendSeiMessage:message];
        }],
        [[TRTCSettingsMessageItem alloc] initWithTitle:@"切换到字符串房间" placeHolder:@"字符串房间号" action:^(NSString *message) {
            [wSelf switchToStringRoom:message];
        }],
        [[TRTCSettingsMessageItem alloc] initWithTitle:@"切换到数字房间" placeHolder:@"数字房间号" action:^(NSString *message) {
            [wSelf switchToIntRoom:message];
        }],
        [[TRTCSettingsSegmentItem alloc] initWithTitle:@"录制类型"
                                                 items:@[@"MP4仅音频", @"MP4仅视频", @"MP4音视频"]
                                         selectedIndex:(int)self.trtcCloudManager.localRecordType
                                                action:^(NSInteger index) {
            [wSelf onLocalRecordTypeSelect:index];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启本地录制"
                                                 isOn:self.trtcCloudManager.enableLocalRecord
                                               action:^(BOOL isOn) {
            [wSelf onEnableLocalRecord:isOn];
        }],
    ];
}

#pragma mark - Actions

- (void)onSelectQosControlModeIndex:(NSInteger)index {
    [self.trtcCloudManager setQosControlMode:index];
}

- (void)onEnableSmallVideo:(BOOL)isOn {
    [self.trtcCloudManager setSmallVideoEnabled:isOn];
}

- (void)onEnablePrefersLowQuality:(BOOL)isOn {
    [self.trtcCloudManager setPrefersLowQuality:isOn];
}

- (void)onEnableGSensor:(BOOL)isOn {
    [self.trtcCloudManager setGSensorEnabled:isOn];
}

- (void)onEnableAutoFocus:(BOOL)isOn {
    [self.trtcCloudManager setAutoFocusEnabled:isOn];
}

- (void)onEnableVOD:(BOOL)isOn {
    [self.trtcCloudManager setEnableVOD:isOn];
}

- (void)onEnableAttachVodToTRTC:(BOOL)isOn{
    [self.trtcCloudManager setEnableAttachVodToTRTC:isOn];
}

- (void)onToggleTorchLight {
    [self.trtcCloudManager switchTorch];
}

- (void)sendMessage:(NSString *)message {
    [self.trtcCloudManager sendCustomMessage:message];
}

- (void)sendSeiMessage:(NSString *)message {
    [self.trtcCloudManager sendSEIMessage:message repeatCount:1];
}

- (void)switchToStringRoom:(NSString *)roomId {
    TRTCSwitchRoomConfig *cfg = [[TRTCSwitchRoomConfig alloc] init];
    cfg.roomId = 0;
    cfg.strRoomId = roomId;
    [self.trtcCloudManager switchRoom:cfg];
}

- (void)switchToIntRoom:(NSString *)roomId {
    TRTCSwitchRoomConfig *cfg = [[TRTCSwitchRoomConfig alloc] init];
    cfg.roomId = roomId.intValue;
    [self.trtcCloudManager switchRoom:cfg];
}

- (void)onLocalRecordTypeSelect:(NSInteger)index {
    TRTCRecordType type = TRTCRecordTypeBoth;
    switch (index) {
        case 0:
            type = TRTCRecordTypeAudio;
            break;
        case 1:
            type = TRTCRecordTypeVideo;
            break;
        case 2:
            type = TRTCRecordTypeBoth;
            break;
        default:
            break;
    }
    self.trtcCloudManager.localRecordType = type;
}

- (void)onEnableLocalRecord:(BOOL)isOn {
    if (isOn) {
        [self.trtcCloudManager startLocalRecording];
    } else {
        [self.trtcCloudManager stopLocalRecording];
    }
}

@end
