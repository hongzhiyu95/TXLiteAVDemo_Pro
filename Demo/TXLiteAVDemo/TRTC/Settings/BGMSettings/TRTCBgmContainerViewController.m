/*
* Module:   TRTCBgmContainerViewController
*
* Function: BGM设置弹出页，包含两个子页面：BGM和音效
*
*/

#import "TRTCBgmContainerViewController.h"
#import "TRTCBgmSettingsViewController.h"
#import "TRTCEffectSettingsViewController.h"

@interface TRTCBgmContainerViewController ()

@property (strong, nonatomic) TRTCBgmSettingsViewController *bgmVC;
@property (strong, nonatomic) TRTCEffectSettingsViewController *effectVC;

@end

@implementation TRTCBgmContainerViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.bgmVC = [[TRTCBgmSettingsViewController alloc] init];
    self.bgmVC.manager = self.bgmManager;
    self.bgmVC.useCppWrapper = _useCppWrapper;
    
    self.effectVC = [[TRTCEffectSettingsViewController alloc] init];
    self.effectVC.manager = self.effectManager;
    //C++接口不支持音效播放
    self.settingVCs = _useCppWrapper ? @[ self.bgmVC ] : @[ self.bgmVC, self.effectVC ];
}

@end
