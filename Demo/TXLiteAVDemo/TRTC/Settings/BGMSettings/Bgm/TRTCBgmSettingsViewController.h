/*
* Module:   TRTCBgmSettingsViewController
*
* Function: BGM设置页，用于控制BGM的播放，以及设置混响和变声效果
*
*    1. 通过TRTCCloudBgmManager来管理BGM播放，以及混响和变声的设置
*
*    2. BGM的操作定义在TRTCBgmSettingsCell中
*
*/

#import "TRTCSettingsBaseViewController.h"
#import "TRTCCloudBgmManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface TRTCBgmSettingsViewController : TRTCSettingsBaseViewController

@property (strong, nonatomic) TRTCCloudBgmManager *manager;
@property (nonatomic) BOOL useCppWrapper; // 若使用C++全平台接口，则不再显示变声器设置界面，因为不支持相关接口

@end

NS_ASSUME_NONNULL_END
