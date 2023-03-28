/*
* Module:   TRTCStreamSettingsViewController
*
* Function: 混流设置页
*
*    1. 通过TRTCCloudManager来开启关闭云端混流。
*
*    2. 显示房间的直播地址二维码。
*
*/

#import "TRTCStreamSettingsViewController.h"
#import "NSString+Common.h"
#import "QRCode.h"
#import "Masonry.h"

@interface TRTCStreamSettingsViewController ()

@property (strong, nonatomic) IBOutlet UIImageView *qrCodeView;
@property (strong, nonatomic) IBOutlet UILabel *qrCodeTitle;

@end

@implementation TRTCStreamSettingsViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    TRTCStreamConfig *config = self.trtcCloudManager.streamConfig;
    
    __weak __typeof(self) wSelf = self;
    self.items = @[
        [[TRTCSettingsSegmentItem alloc] initWithTitle:@"云端混流"
                                                 items:@[@"关闭", @"手动", @"纯音频", @"预设"]
                                         selectedIndex:config.mixMode
                                                action:^(NSInteger index) {
            [wSelf onSelectMixModeIndex:index];
        }],
        [[TRTCSettingsSegmentItem alloc] initWithTitle:@"背景图"
                                                 items:@[@"无", @"图1", @"图2"]
                                         selectedIndex:0
                                                action:^(NSInteger index) {
            [wSelf onSelectBackgroundImage:index];
        }],
       
        [[TRTCSettingsMessageItem alloc] initWithTitle:@"混流ID"
                                           placeHolder:@"自定义混流ID"
                                               content:nil
                                           actionTitle:@"设置"
                                                action:^(NSString *content) {
            [wSelf setMixStreamId:content];
        }],
        [[TRTCSettingsMessageItem alloc] initWithTitle:@"发布媒体流"
                                           placeHolder:@"目标房间号"
                                               content:nil
                                           actionTitle:@"发布"
                                                action:^(NSString *content) {
            [wSelf setPublishMeidaStreamWithRoomID:content];
        }],
    
    ];
    
    [self setupSubviews];
    [self.qrCodeView layoutIfNeeded];
    [self updateStreamInfo];
}

- (void)setupSubviews {
    [self.tableView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.leading.trailing.equalTo(self.view);
        make.height.mas_equalTo(self.items.count * 50);
        make.bottom.lessThanOrEqualTo(self.qrCodeTitle.mas_top).offset(-20);
    }];
}

#pragma mark - Actions

- (void)onSelectMixModeIndex:(NSInteger)index {
    [self.trtcCloudManager setMixMode:index];
    [self updateStreamInfo];
}

- (void)onSelectBackgroundImage:(NSInteger)index {
    if (index == 0) {
        [self.trtcCloudManager setMixBackgroundImage:nil];
    } else {
        NSString *imageName = @[@"51", @"52"][index - 1];
        [self.trtcCloudManager setMixBackgroundImage:imageName];
    }
}

- (void)setMixStreamId:(NSString *)streamId {
    [self.trtcCloudManager setMixStreamId:streamId];
}

-(void)setPublishMeidaStreamWithRoomID:(NSString *) roomid{
    [self.trtcCloudManager setPublishMediaStreamWithRoomId:roomid];
}
- (IBAction)onClickShareButton:(UIButton *)button{
    NSString *shareUrl = [self.trtcCloudManager getCdnUrlOfUser:self.trtcCloudManager.params.userId];
    UIActivityViewController *activityView = [[UIActivityViewController alloc]
                                              initWithActivityItems:@[shareUrl]
                                              applicationActivities:nil];
    [self presentViewController:activityView animated:YES completion:nil];
}

- (void)updateStreamInfo {
    NSString *shareUrl = [self.trtcCloudManager getCdnUrlOfUser:self.trtcCloudManager.params.userId];
    self.qrCodeView.image = [QRCode qrCodeWithString:shareUrl size:self.qrCodeView.frame.size];
}

@end
