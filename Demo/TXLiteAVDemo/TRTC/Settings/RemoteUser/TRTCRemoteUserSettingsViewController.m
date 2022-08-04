/*
* Module:   TRTCRemoteUserSettingsViewController
*
* Function: 房间内其它用户（即远端用户）的设置页
*
*    1. 通过TRTCRemoteUserManager来管理各项设置
*
*/

#import "TRTCRemoteUserSettingsViewController.h"
#import "ColorMacro.h"
#import "MBProgressHUD.h"

@implementation TRTCRemoteUserSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.title = self.userId;
    self.view.backgroundColor = UIColorFromRGB(0x262626);
    
    TRTCRemoteUserConfig *userSettings = self.userManager.remoteUsers[self.userId];
    __weak __typeof(self) wSelf = self;
    self.items = @[
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启视频"
                                                 isOn:!userSettings.isVideoMuted
                                               action:^(BOOL isOn) {
            [wSelf onMuteVideo:!isOn];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启音频"
                                                 isOn:!userSettings.isAudioMuted
                                               action:^(BOOL isOn) {
            [wSelf onMuteAudio:!isOn];
        }],
        [[TRTCSettingsSegmentItem alloc] initWithTitle:@"填充模式"
                                                 items:@[@"填充", @"自适应"]
                                         selectedIndex:userSettings.renderParams.fillMode == TRTCVideoFillMode_Fill ? 0 : 1
                                                action:^(NSInteger index) {
            [wSelf onSelectFillModeIndex:index];
        }],
        [[TRTCSettingsSegmentItem alloc] initWithTitle:@"画面旋转"
                                                 items:@[@"0", @"90", @"180", @"270"]
                                         selectedIndex:userSettings.renderParams.rotation
                                                action:^(NSInteger index) {
            [wSelf onSelectRotationIndex:index];
        }],
        [[TRTCSettingsSwitchItem alloc] initWithTitle:@"开启镜像"
                                                 isOn:userSettings.renderParams.mirrorType == TRTCVideoMirrorTypeEnable
                                               action:^(BOOL isOn) {
            [wSelf onEnableMirror:isOn];
        }],
        [[TRTCSettingsSliderItem alloc] initWithTitle:@"音量大小"
                                                value:userSettings.volume
                                                  min:0
                                                  max:100
                                                 step:1
                                           continuous:YES
                                               action:^(float volume) {
            [wSelf onChangeVolume:volume];
        }],
        [[TRTCSettingsSelectorItem alloc] initWithTitle:@"截图" items:@[@"视频流截图", @"画面截图"] selectedIndex:0 action:^(NSInteger index) {
            [wSelf snapshotVideoWithType:TRTCVideoStreamTypeBig sourceIndex:index];
        }],
        [[TRTCSettingsSelectorItem alloc] initWithTitle:@"辅流截图" items:@[@"视频流截图", @"画面截图"] selectedIndex:0 action:^(NSInteger index) {
            [wSelf snapshotVideoWithType:TRTCVideoStreamTypeSub sourceIndex:index];
        }],
    ];
}

#pragma mark - Actions

- (void)onMuteVideo:(BOOL)isMuted {
    [self.userManager setUser:self.userId isVideoMuted:isMuted];
}

- (void)onMuteAudio:(BOOL)isMuted {
    [self.userManager setUser:self.userId isAudioMuted:isMuted];
}

- (void)onSelectFillModeIndex:(NSInteger)index {
    TRTCVideoFillMode mode = index == 0 ? TRTCVideoFillMode_Fill : TRTCVideoFillMode_Fit;
    [self.userManager setUser:self.userId fillMode:mode];
}

- (void)onSelectRotationIndex:(NSInteger)index {
    [self.userManager setUser:self.userId rotation:index];
}

- (void)onEnableMirror:(BOOL)isEnabled {
    [self.userManager setUser:self.userId isMirrorEnabled:isEnabled];
}

- (void)onChangeVolume:(NSInteger)volume {
    [self.userManager setUser:self.userId volume:volume];
}

- (void)snapshotVideoWithType:(TRTCVideoStreamType)type sourceIndex:(NSInteger)index {
    __weak __typeof(self) wSelf = self;
    [self.userManager.trtc snapshotVideo:self.userId
                                    type:type
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

- (void)shareImage:(UIImage *)image {
    UIActivityViewController *vc = [[UIActivityViewController alloc]
                                    initWithActivityItems:@[image]
                                    applicationActivities:nil];
    [self presentViewController:vc animated:YES completion:nil];
}

@end
