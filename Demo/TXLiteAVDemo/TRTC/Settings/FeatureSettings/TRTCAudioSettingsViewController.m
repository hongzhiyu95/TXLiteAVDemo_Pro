/*
* Module:   TRTCAudioSettingsViewController
*
* Function: 音频设置页
*
*    1. 通过TRTCCloudManager来设置音频参数。
*
*    2. TRTCAudioRecordManager用来控制录音，demo录音停止后会弹出分享。
*
*/

#import "TRTCAudioSettingsViewController.h"

@interface TRTCAudioSettingsViewController()

@property (strong, nonatomic) TRTCSettingsButtonItem *recordItem;

@end

@implementation TRTCAudioSettingsViewController

- (NSString *)title {
    return @"音频";
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    TRTCAudioConfig *config = self.trtcCloudManager.audioConfig;
    __weak __typeof(self) wSelf = self;
    
    self.recordItem = [[TRTCSettingsButtonItem alloc] initWithTitle:@"音频录制"
                                      buttonTitle:self.recordManager.isRecording ? @"停止" : @"录制"
                                           action:^{
        [wSelf onClickRecordButton];
    }];
    
    self.items = @[
        [[TRTCSettingsSegmentItem alloc] initWithTitle:@"音量类型"
                                                 items:@[@"自动", @"媒体", @"通话"]
                                         selectedIndex:config.volumeType
                                                action:^(NSInteger index) {
            [wSelf onSelectVolumeTypeIndex:index];
        }],
        [[TRTCSettingsSliderItem alloc] initWithTitle:@"采集音量"
                                                value:self.trtcCloudManager.captureVolume min:0 max:150 step:1
                                           continuous:YES
                                               action:^(float volume) {
            [wSelf onUpdateCaptureVolume:(NSInteger)volume];
        }],
        [[TRTCSettingsSliderItem alloc] initWithTitle:@"播放音量"
                                                value:self.trtcCloudManager.playoutVolume min:0 max:150 step:1
                                           continuous:YES
                                               action:^(float volume) {
            [wSelf onUpdatePlayoutVolume:(NSInteger)volume];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"回声消除"
                                                 isOn:config.isAecEnabled
                                               action:^(BOOL isOn) {
            [wSelf onEnableAec:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"自动增益"
                                                 isOn:config.isAgcEnabled
                                               action:^(BOOL isOn) {
            [wSelf onEnableAgc:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"噪音消除"
                                                 isOn:config.isAnsEnabled
                                               action:^(BOOL isOn) {
            [wSelf onEnableAns:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启耳返"
                                                 isOn:config.isEarMonitoringEnabled
                                               action:^(BOOL isOn) {
            [wSelf onEnableEarMonitoring:isOn];
        }],
        [[TRTCSettingsSliderItem alloc] initWithTitle:@"耳返音量"
                                                value:100 min:0 max:150 step:1
                                           continuous:YES
                                               action:^(float volume) {
            [wSelf onUpdateEarMonitoringVolume:(NSInteger)volume];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"声音采集"
                                                 isOn:config.isEnabled
                                               action:^(BOOL isOn) {
            [wSelf onEnableAudio:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"免提模式"
                                                 isOn:config.route == TRTCAudioModeSpeakerphone
                                               action:^(BOOL isOn) {
            [wSelf onEnableHandsFree:isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"音量提示"
                                                 isOn:config.isVolumeEvaluationEnabled
                                               action:^(BOOL isOn) {
            [wSelf onEnableVolumeEvaluation:isOn];
        }],
        self.recordItem,
    ];
}

#pragma mark - Actions

- (void)onSelectVolumeTypeIndex:(NSInteger)index {
    TRTCSystemVolumeType type = (TRTCSystemVolumeType)index;
    [self.trtcCloudManager setVolumeType:type];
}

- (void)onUpdateCaptureVolume:(NSInteger)volume {
    [self.trtcCloudManager setCaptureVolume:volume];
}

- (void)onUpdatePlayoutVolume:(NSInteger)volume {
    [self.trtcCloudManager setPlayoutVolume:volume];
}

- (void)onEnableAec:(BOOL)isOn {
    [self.trtcCloudManager setAecEnabled:isOn];
}

- (void)onEnableAgc:(BOOL)isOn {
    [self.trtcCloudManager setAgcEnabled:isOn];
}

- (void)onEnableAns:(BOOL)isOn {
    [self.trtcCloudManager setAnsEnabled:isOn];
}

- (void)onEnableEarMonitoring:(BOOL)isOn {
    [self.trtcCloudManager setEarMonitoringEnabled:isOn];
}

- (void)onUpdateEarMonitoringVolume:(NSInteger)volume {
    [self.trtcCloudManager setEarMonitoringVolume:volume];
}

- (void)onEnableAudio:(BOOL)isOn {
    [self.trtcCloudManager setAudioEnabled:isOn];
}

- (void)onEnableHandsFree:(BOOL)isOn {
    TRTCAudioRoute route = isOn ? TRTCAudioModeSpeakerphone : TRTCAudioModeEarpiece;
//    [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeDefault options:101 error:nil];
//    [[AVAudioSession sharedInstance]setActive:YES error:nil];
    if (route == TRTCAudioModeSpeakerphone){
        
//
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideSpeaker error:nil];
        [[AVAudioSession sharedInstance]setActive:YES error:nil];
    }else{
//        [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeDefault options:109 error:nil];
        [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeDefault options:101 error:nil];
        [[AVAudioSession sharedInstance] overrideOutputAudioPort:AVAudioSessionPortOverrideNone error:nil];
        [[AVAudioSession sharedInstance]setActive:YES error:nil];
    }
    //[self.trtcCloudManager setAudioRoute:route];
}

- (void)onEnableVolumeEvaluation:(BOOL)isOn {
    [self.trtcCloudManager setVolumeEvaluationEnabled:isOn];
}

- (void)onClickRecordButton {
    if (self.recordManager.isRecording) {
        [self.recordManager stopRecord];
        [self shareAudioFile];
    } else {
        [self.recordManager startRecord];
    }
    self.recordItem.buttonTitle = self.recordManager.isRecording ? @"停止" : @"录制";
    [self.tableView reloadData];
}

- (void)shareAudioFile {
    if (self.recordManager.audioFilePath.length == 0) {
        return;
    }
    NSURL *fileUrl = [NSURL fileURLWithPath:self.recordManager.audioFilePath];
    UIActivityViewController *activityView =
    [[UIActivityViewController alloc] initWithActivityItems:@[fileUrl]
                                      applicationActivities:nil];
    [self presentViewController:activityView animated:YES completion:nil];
}

@end
