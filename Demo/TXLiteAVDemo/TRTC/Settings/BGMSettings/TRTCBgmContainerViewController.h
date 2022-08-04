/*
* Module:   TRTCBgmContainerViewController
*
* Function: BGM设置弹出页，包含两个子页面：BGM和音效
*
*/

#import "TRTCSettingsContainerViewController.h"
#import "TRTCCloudBgmManager.h"
#import "TRTCEffectManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface TRTCBgmContainerViewController : TRTCSettingsContainerViewController

@property (strong, nonatomic) TRTCCloudBgmManager *bgmManager;
@property (strong, nonatomic) TRTCEffectManager *effectManager;
@property (nonatomic) BOOL useCppWrapper; // 若使用C++全平台接口，则不再显示音效播放界面，因为相关接口已废弃

@end

NS_ASSUME_NONNULL_END
