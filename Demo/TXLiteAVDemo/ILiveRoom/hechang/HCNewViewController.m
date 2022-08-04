//
//  HCNewViewController.m
//  TXLiteAVDemo_ILiveRoom_Smart
//
//  Created by hans on 2020/3/4.
//  Copyright © 2020 Tencent. All rights reserved.
//

#import "HCNewViewController.h"
#import "UIView+Additions.h"
#import "HCViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "GenerateTestUserSig.h"
@interface HCNewViewController()

@end

@implementation HCNewViewController {
    UISegmentedControl *_roleControl;
    UISegmentedControl *_modeControl;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    [self.view setBackgroundColor:UIColor.darkGrayColor];
    
    self.title = @"合唱房间";

    CGSize size = [[UIScreen mainScreen] bounds].size;
    
    NSArray *roleArray = [[NSArray alloc]initWithObjects:@"主持人",@"领唱",@"副唱",@"观众", nil];
    _roleControl = [[UISegmentedControl alloc] initWithItems:roleArray];
    _roleControl.frame = CGRectMake((size.width - 250) / 2, 100, 250.0, 50.0);
    _roleControl.segmentedControlStyle = UISegmentedControlStylePlain;
    _roleControl.selectedSegmentIndex = 0;//设置默认选择项索引
    [self.view addSubview:_roleControl];
    
    NSArray *modeArray = [[NSArray alloc]initWithObjects:@"音视频模式", @"纯音频模式", @"音视频模式(只混音频)", nil];
    _modeControl = [[UISegmentedControl alloc] initWithItems:modeArray];
    _modeControl.frame = CGRectMake((size.width - 250) / 2, 200, 250.0, 50.0);
    _modeControl.segmentedControlStyle = UISegmentedControlStylePlain;
    _modeControl.selectedSegmentIndex = 0;//设置默认选择项索引
    [self.view addSubview:_modeControl];
    
    UIButton *btnStart = [UIButton buttonWithType:UIButtonTypeCustom];
    btnStart.frame = CGRectMake(40, self.view.height - 70, self.view.width - 80, 50);
    btnStart.layer.cornerRadius = 8;
    btnStart.layer.masksToBounds = YES;
    btnStart.layer.shadowOffset = CGSizeMake(1, 1);
    btnStart.layer.shadowOpacity = 0.8;
    [btnStart setTitle:@"进合唱房" forState:UIControlStateNormal];
    [btnStart addTarget:self action:@selector(onClickStart:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btnStart];
    
    [self applyPermission];
}

- (BOOL)checkPermission {
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    //读取设备授权状态
    if(authStatus != AVAuthorizationStatusAuthorized) {
        return NO;
    }
     authStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    //读取设备授权状态
    if(authStatus != AVAuthorizationStatusAuthorized) {
        return NO;
    }
    return YES;
}

- (void)applyPermission {
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                   
        }];
    }
    
    status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeAudio];
    if (status == AVAuthorizationStatusNotDetermined) {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeAudio completionHandler:^(BOOL granted) {
                   
        }];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    self.navigationController.navigationBar.hidden = NO;
}

- (void)onClickStart:(UIButton *)sender {
    if(![self checkPermission]) {
        [self alertTips:@"权限" msg:@"没有摄像头或者麦克风权限" completion:nil];
        return;
    }
    long roleIndex = _roleControl.selectedSegmentIndex;
    UInt64 userId = 0;
    HeChangRole role = HeChangAudienceRole;
    switch (roleIndex) {
        case 0:
            userId = 100000;
            role = HeChangMCRole;
            break;
        case 1:
            userId = 100001;
            role = HeChangMainSingerRole;
            break;
        case 2:
            role = HeChangSubSingerRole;
            userId = 100002;
            break;
        case 3:
            role = HeChangAudienceRole;
            // 观众的 id 生成 100w - 110w之间的随机数
            userId = [self getRandomNumber:1000000 to:1100000];
            break;
        default:
            break;
    }
    long modeIndex = _modeControl.selectedSegmentIndex;
    HeChangMode mode = HeChangDefaultMode;
    switch (modeIndex) {
        case 0:
            mode = HeChangDefaultMode;
            break;
        case 1:
            mode = HeChangAudioMode;
            break;
        case 2:
            mode = HeChangVideoOnlyMixAudioMode;
            break;
        default:
            break;
    }
    
    NSMutableDictionary<NSNumber*, NSNumber*> *rolePair = [[NSMutableDictionary alloc] init];
    [rolePair setObject:@((int)HeChangMCRole) forKey:@(100000)];
    [rolePair setObject:@((int)HeChangMainSingerRole) forKey:@(100001)];
    [rolePair setObject:@((int)HeChangSubSingerRole) forKey:@(100002)];

    HCViewController *hcController = [[HCViewController alloc] init];
    hcController.roomName = @"hc_100000";
    hcController.role = role;
    hcController.userId = userId;
    hcController.mode = mode;
    hcController.rolePair = rolePair;
    hcController.sdkAppId = 1400188366;
    NSString *strSign = [GenerateTestUserSig genTestUserSig:[NSString stringWithFormat:@"%llu", userId] sdkAppId:1400188366 secretKey:_SECRETKEY];
    hcController.userSign = [strSign dataUsingEncoding:NSUTF8StringEncoding];
    [self.navigationController pushViewController:hcController animated:YES];
}

- (int)getRandomNumber:(int)from to:(int)to {
    return (int)(from + (arc4random() % (to - from + 1)));
}

- (void)alertTips:(NSString *)title msg:(NSString *)msg completion:(void(^)())completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
            if (completion) {
                completion();
            }
        }]];
        
        [self.navigationController presentViewController:alertController animated:YES completion:nil];
    });
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
