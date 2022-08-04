/*
* Module:   TRTCBgmSettingsCell
*
* Function: BGM Cell, 包含播放、暂停、继续、停止操作，以及播放进度的显示
*
*    1. playButton根据BGM的播放状态，来切换播放、暂停和继续操作。
*
*    2. progressView用来显示BGM的播放进度
*
*/

#import "TRTCSettingsBaseCell.h"
#import "TRTCCloudBgmManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface TRTCBgmSettingsCell : TRTCSettingsBaseCell

@end


@interface TRTCBgmSettingsItem : TRTCSettingsBaseItem

@property (strong, nonatomic) TRTCCloudBgmManager *bgmManager;

- (instancetype)initWithTitle:(NSString *)title bgmManager:(TRTCCloudBgmManager *)bgmManager;

@end

NS_ASSUME_NONNULL_END
