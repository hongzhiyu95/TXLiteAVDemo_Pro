/*
* Module:   TRTCBgmSettingsCell
*
* Function: BGM Cell, 包含播放、暂停、继续、停止操作，以及播放进度的显示
*
*    1. playButton根据BGM的播放状态，来切换播放、暂停和继续操作。
*
*    2. slider用来显示和控制BGM的播放进度
*
*/

#import "TRTCBgmSettingsCell.h"
#import "UIButton+TRTC.h"
#import "UISlider+TRTC.h"
#import "UILabel+TRTC.h"
#import "Masonry.h"
#import "ColorMacro.h"

@interface TRTCBgmSettingsCell ()

@property (strong, nonatomic) UIButton *playButton;
@property (strong, nonatomic) UIButton *stopButton;
@property (strong, nonatomic) UISlider *slider;
@property (strong, nonatomic) UILabel *progressLabel;
@property (nonatomic) NSInteger duration;

@end

@implementation TRTCBgmSettingsCell

- (void)setupUI {
    [super setupUI];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapTitleLabel)];
    self.titleLabel.userInteractionEnabled = YES;
    [self.titleLabel addGestureRecognizer:tap];
    
    self.playButton = [UIButton trtc_iconButtonWithImage:[UIImage imageNamed:@"audio_play"]];
    [self.playButton setImage:[UIImage imageNamed:@"audio_pause"] forState:UIControlStateSelected];
    [self.playButton addTarget:self action:@selector(onClickPlayButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.playButton];

    self.stopButton = [UIButton trtc_iconButtonWithImage:[UIImage imageNamed:@"audio_stop"]];
    [self.stopButton addTarget:self action:@selector(onClickStopButton:) forControlEvents:UIControlEventTouchUpInside];
    [self.contentView addSubview:self.stopButton];

    self.slider = [UISlider trtc_slider];
    self.slider.minimumValue = 0;
    self.slider.maximumValue = 100;
    self.slider.value = 0;
    [self.slider addTarget:self action:@selector(onSliderValueChange:) forControlEvents:UIControlEventValueChanged];
    [self.contentView addSubview:self.slider];
    
    self.progressLabel = [UILabel trtc_contentLabel];
    self.progressLabel.textAlignment = NSTextAlignmentRight;
    self.progressLabel.text = @"0%";
    [self.contentView addSubview:self.progressLabel];

    [self.playButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.contentView);
        make.leading.equalTo(self.titleLabel.mas_trailing).offset(10);
        make.trailing.equalTo(self.stopButton.mas_leading).offset(-10);
        make.size.mas_equalTo(CGSizeMake(30, 30));
    }];
    [self.stopButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.contentView);
        make.trailing.equalTo(self.slider.mas_leading).offset(-4);
        make.size.mas_equalTo(CGSizeMake(30, 30));
    }];
    [self.slider mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.contentView);
        make.trailing.equalTo(self.progressLabel.mas_leading).offset(-10);
    }];
    [self.progressLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerY.equalTo(self.contentView);
        make.trailing.equalTo(self.contentView).offset(-18);
        make.width.mas_equalTo(40);
    }];
}

- (void)didUpdateItem:(TRTCSettingsBaseItem *)item {
    if ([item isKindOfClass:[TRTCBgmSettingsItem class]]) {
        self.playButton.selected = [self.manager isBgmPlaying];
        self.slider.value = [self.manager getProgress] * 100;
    }
}

- (TRTCCloudBgmManager *)manager {
    TRTCBgmSettingsItem *bgmItem = (TRTCBgmSettingsItem *)self.item;
    return bgmItem.bgmManager;
}

#pragma mark - Events

- (void)onClickPlayButton:(UIButton *)button {
    if ([self.manager isBgmOnPause]) {
        [self.manager resumeBgm];
    } else if ([self.manager isBgmPlaying]) {
        [self.manager pauseBgm];
    } else {
        [self playBgmAtPath:[[NSBundle mainBundle] pathForResource:@"bgm_demo" ofType:@"mp3"]];
    }
    button.selected = [self.manager isBgmPlaying] && ![self.manager isBgmOnPause];
}

- (void)onTapTitleLabel {
    [self playBgmAtPath:@"http://www.music.helsinki.fi/tmt/opetus/uusmedia/esim/a2002011001-e02.wav"];
    self.playButton.selected = YES;
}

- (void)onClickStopButton:(id)sender {
    if ([self.manager isBgmPlaying]) {
        [self.manager stopBgm];
        self.playButton.selected = NO;
        self.slider.value = 0;
    }
}

- (void)onSliderValueChange:(UISlider *)slider {
    [self.manager seekToTime:self.duration * slider.value / 100];
}

#pragma mark - Private

- (void)playBgmAtPath:(NSString *)path {
    self.duration = [self.manager getBgmDuration:path];
    
    __weak __typeof(self) wSelf = self;
    [self.manager playBgm:path onProgress:^(float progress) {
        __strong __typeof(self) self = wSelf;
        self.slider.value = progress * 100;
        self.progressLabel.text = [NSString stringWithFormat:@"%@%%", @([self.manager getProgressInMs] * 100 / self.duration)];
    } onCompleted:^{
        wSelf.playButton.selected = NO;
        wSelf.slider.value = 0;
        //bgm播放完毕后右边的进度百分比也应归0
        self.progressLabel.text = @"0%";
    }];
}

- (NSString *)createNoExtFileFrom:(NSString *)path {
    NSString *folder = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
    NSString *targetPath = [folder stringByAppendingPathComponent:@"temp_bgm"];
    
    NSError *error;
    if ([[NSFileManager defaultManager] fileExistsAtPath:targetPath]) {
        [[NSFileManager defaultManager] removeItemAtPath:targetPath error:&error];
        if (error) {
            NSLog(@"TRTCBgmSettingsCell - Failed to remove temp file");
            return nil;
        }
    }
    
    [[NSFileManager defaultManager] copyItemAtPath:path toPath:targetPath error:&error];
    if (error) {
        NSLog(@"TRTCBgmSettingsCell - Failed to copy file");
        return nil;
    }
    return [NSString stringWithFormat:@"File://%@", targetPath];
}

@end


@implementation TRTCBgmSettingsItem

- (instancetype)initWithTitle:(NSString *)title bgmManager:(TRTCCloudBgmManager *)bgmManager {
    if (self = [super init]) {
        self.title = title;
        self.bgmManager = bgmManager;
    }
    return self;
}

+ (Class)bindedCellClass {
    return [TRTCBgmSettingsCell class];
}

- (NSString *)bindedCellId {
    return [TRTCBgmSettingsItem bindedCellId];
}

@end

