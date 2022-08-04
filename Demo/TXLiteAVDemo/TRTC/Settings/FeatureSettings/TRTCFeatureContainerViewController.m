/*
* Module:   TRTCFeatureContainerViewController
*
* Function: 音视频设置弹出页，包含五个子页面：视频、音频、混流、跨房PK和其它
*
*/

#import "TRTCFeatureContainerViewController.h"
#import "TRTCVideoSettingsViewController.h"
#import "TRTCAudioSettingsViewController.h"
#import "TRTCStreamSettingsViewController.h"
#import "TRTCPKSettingsViewController.h"
#import "TRTCMoreSettingsViewController.h"
#import "TRTCSubRoomSettingsViewController.h"

@interface TRTCFeatureContainerViewController ()

@property (strong, nonatomic) TRTCVideoSettingsViewController *videoVC;
@property (strong, nonatomic) TRTCAudioSettingsViewController *audioVC;
@property (strong, nonatomic) TRTCStreamSettingsViewController *streamVC;
@property (strong, nonatomic) TRTCPKSettingsViewController *pkVC;
@property (strong, nonatomic) TRTCMoreSettingsViewController *moreVC;
@property (strong, nonatomic) TRTCSubRoomSettingsViewController *subRoomVC;

@end

@implementation TRTCFeatureContainerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.videoVC = [[TRTCVideoSettingsViewController alloc] init];
    self.videoVC.trtcCloudManager = self.trtcCloudManager;
    
    self.audioVC = [[TRTCAudioSettingsViewController alloc] init];
    self.audioVC.trtcCloudManager = self.trtcCloudManager;
    self.audioVC.recordManager = self.recordManager;
    
    self.streamVC = [[UIStoryboard storyboardWithName:@"TRTCSettings" bundle:nil]
                     instantiateViewControllerWithIdentifier:@"TRTCStreamSettingsViewController"];
    self.streamVC.trtcCloudManager = self.trtcCloudManager;

    self.pkVC = [[UIStoryboard storyboardWithName:@"TRTCSettings" bundle:nil]
                 instantiateViewControllerWithIdentifier:@"TRTCPKSettingsViewController"];
    self.pkVC.manager = self.trtcCloudManager;

    self.moreVC = [[TRTCMoreSettingsViewController alloc] init];
    self.moreVC.trtcCloudManager = self.trtcCloudManager;

    self.subRoomVC = [[TRTCSubRoomSettingsViewController alloc] init];
    self.subRoomVC.trtcCloudManager = self.trtcCloudManager;
    
    self.settingVCs = @[
        self.videoVC,
        self.audioVC,
        self.streamVC,
        self.pkVC,
        self.moreVC,
        self.subRoomVC
    ];
}

@end
