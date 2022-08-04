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

#import "TRTCBgmSettingsViewController.h"
#import "TRTCBgmSettingsCell.h"

@interface TRTCBgmSettingsViewController()

@property (nonatomic, strong) TRTCSettingsSliderItem *bgmPlayoutVolumeItem;

@property (nonatomic, strong) TRTCSettingsSliderItem *bgmPublishVolumeItem;

@end

@implementation TRTCBgmSettingsViewController

- (NSString *)title {
    return @"BGM";
}

- (void)makeCustomRegistrition {
    [self.tableView registerClass:TRTCBgmSettingsItem.bindedCellClass
           forCellReuseIdentifier:TRTCBgmSettingsItem.bindedCellId];
}

- (NSArray<NSString *> *)voiceChanger {
    return @[
        @"关闭变声",
        @"熊孩子",
        @"萝莉",
        @"大叔",
        @"重金属",
        @"感冒",
        @"外国人",
        @"困兽",
        @"死肥仔",
        @"强电流",
        @"重机械",
        @"空灵",
    ];
}

- (NSArray<NSString *> *)reverbs {
    return @[
        @"关闭混响",
        @"KTV",
        @"小房间",
        @"大会堂",
        @"低沉",
        @"洪亮",
        @"金属声",
        @"磁性",
    ];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    __weak __typeof(self) wSelf = self;
    
    self.bgmPlayoutVolumeItem = [[TRTCSettingsSliderItem alloc] initWithTitle:@"本地音量"
                                            value:[self.manager getBgmPlayoutVolume]
                                              min:0
                                              max:100
                                             step:1
                                       continuous:YES
                                           action:^(float value) {
        [wSelf onChangeBgmPlayoutVolume:(NSInteger) value];
    }];
    
    self.bgmPublishVolumeItem = [[TRTCSettingsSliderItem alloc] initWithTitle:@"远程音量"
                                            value:[self.manager getBgmPublishVolume]
                                              min:0
                                              max:100
                                             step:1
                                       continuous:YES
                                           action:^(float value) {
        [wSelf onChangeBgmPublishVolume:(NSInteger) value];
    }];
    
    if (_useCppWrapper) {
        self.items = @[
            [[TRTCBgmSettingsItem alloc] initWithTitle:@"BGM" bgmManager:self.manager],
            [[TRTCSettingsSliderItem alloc] initWithTitle:@"BGM音量"
                                                    value:[self.manager getBgmVolume]
                                                      min:0
                                                      max:100
                                                     step:1
                                               continuous:YES
                                                   action:^(float value) {
                [wSelf onChangeBgmVolume:(NSInteger) value];
            }],
            self.bgmPlayoutVolumeItem,
            self.bgmPublishVolumeItem,
            [[TRTCSettingsSliderItem alloc] initWithTitle:@"BGM音调"
                                                    value:[self.manager getBgmPitch]
                                                      min:-1
                                                      max:1
                                                     step:0.1
                                               continuous:YES
                                                   action:^(float value) {
                [wSelf onChangeBgmPitch:value];
            }],
            [[TRTCSettingsSliderItem alloc] initWithTitle:@"BGM速率"
                                                    value:[self.manager getBgmSpeed]
                                                      min:0.5
                                                      max:2
                                                     step:0.1
                                               continuous:YES
                                                   action:^(float value) {
                [wSelf onChangeBgmSpeed:value];
            }],
            [[TRTCSettingsSliderItem alloc] initWithTitle:@"MIC音量"
                                                    value:[self.manager getMicVolume]
                                                      min:0
                                                      max:100
                                                     step:1
                                               continuous:YES
                                                   action:^(float value) {
                [wSelf onChangeMicVolume:(NSInteger) value];
            }],
            [[TRTCSettingsSelectorItem alloc] initWithTitle:@"混响设置"
                                                      items:[self reverbs]
                                              selectedIndex:[self.manager getReverb]
                                                     action:^(NSInteger index) {
                [wSelf onSelectReverbIndex:index];
            }],
            [[TRTCSettingsButtonItem alloc] initWithTitle:@"BGM连播" buttonTitle:@"开始" action:^{
                [wSelf onSelectContinousPlay];
            }]
        ];
    } else {
        self.items = @[
            [[TRTCBgmSettingsItem alloc] initWithTitle:@"BGM" bgmManager:self.manager],
            [[TRTCSettingsSliderItem alloc] initWithTitle:@"BGM音量"
                                                    value:[self.manager getBgmVolume]
                                                      min:0
                                                      max:100
                                                     step:1
                                               continuous:YES
                                                   action:^(float value) {
                [wSelf onChangeBgmVolume:(NSInteger) value];
            }],
            self.bgmPlayoutVolumeItem,
            self.bgmPublishVolumeItem,
            [[TRTCSettingsSliderItem alloc] initWithTitle:@"BGM音调"
                                                    value:[self.manager getBgmPitch]
                                                      min:-1
                                                      max:1
                                                     step:0.1
                                               continuous:YES
                                                   action:^(float value) {
                [wSelf onChangeBgmPitch:value];
            }],
            [[TRTCSettingsSliderItem alloc] initWithTitle:@"BGM速率"
                                                    value:[self.manager getBgmSpeed]
                                                      min:0.5
                                                      max:2
                                                     step:0.1
                                               continuous:YES
                                                   action:^(float value) {
                [wSelf onChangeBgmSpeed:value];
            }],
            [[TRTCSettingsSliderItem alloc] initWithTitle:@"MIC音量"
                                                    value:[self.manager getMicVolume]
                                                      min:0
                                                      max:100
                                                     step:1
                                               continuous:YES
                                                   action:^(float value) {
                [wSelf onChangeMicVolume:(NSInteger) value];
            }],
            [[TRTCSettingsSelectorItem alloc] initWithTitle:@"混响设置"
                                                      items:[self reverbs]
                                              selectedIndex:[self.manager getReverb]
                                                     action:^(NSInteger index) {
                [wSelf onSelectReverbIndex:index];
            }],
            [[TRTCSettingsSelectorItem alloc] initWithTitle:@"变声设置"
                                                      items:[self voiceChanger]
                                              selectedIndex:[self.manager getVoiceChanger]
                                                     action:^(NSInteger index) {
                [wSelf onSelectVoiceChangerIndex:index];
            }],
            [[TRTCSettingsButtonItem alloc] initWithTitle:@"BGM连播" buttonTitle:@"开始" action:^{
                [wSelf onSelectContinousPlay];
            }]
        ];
    }
}

#pragma mark - Actions

- (void)onChangeBgmVolume:(NSInteger)volume {
    [self.manager setBgmVolume:volume];
    self.bgmPlayoutVolumeItem.sliderValue = volume;
    self.bgmPublishVolumeItem.sliderValue = volume;
}

- (void)onChangeBgmPlayoutVolume:(NSInteger)volume {
    [self.manager setBgmPlayoutVolume:volume];
}

- (void)onChangeBgmPublishVolume:(NSInteger)volume {
    [self.manager setBgmPublishVolume:volume];
}

- (void)onChangeBgmPitch:(float)pitch {
    [self.manager setBgmPitch:pitch];
}

- (void)onChangeBgmSpeed:(float)speed {
    [self.manager setBgmSpeed:speed];
}

- (void)onChangeMicVolume:(NSInteger)volume {
    [self.manager setMicVolume:volume];
}

- (void)onSelectReverbIndex:(NSInteger)index {
    [self.manager setReverb:index];
}

- (void)onSelectVoiceChangerIndex:(NSInteger)index {
    [self.manager setVoiceChanger:index];
}

- (void)onSelectContinousPlay {
    [self startContinousPlayAtIndex:0];
}

- (void)startContinousPlayAtIndex:(NSInteger)index {
    const NSArray *bgmLists = @[
        [[NSBundle mainBundle] pathForResource:@"欢呼" ofType:@"m4a"],
        [[NSBundle mainBundle] pathForResource:@"giftSent" ofType:@"aac"],
        [[NSBundle mainBundle] pathForResource:@"on_mic" ofType:@"aac"],
    ];
    __typeof(self) wSelf = self;
    [self.manager playBgm:bgmLists[index] onProgress:nil onCompleted:^{
        [wSelf startContinousPlayAtIndex:(index + 1) % bgmLists.count];
    }];
}

@end
