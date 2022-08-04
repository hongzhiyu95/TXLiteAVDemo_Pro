//
//  ILiveRoomNewViewController.m
//  TXLiteAVDemo
//
//  Created by lijie on 2018/9/14.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "ILiveRoomNewViewController.h"
#import "UIView+Additions.h"
#import "ColorMacro.h"
#import "ILiveRoomPusherViewController.h"
#import "ILiveRoomDef.h"
#import "TCHttpUtil.h"
#import "HCNewViewController.h"

@interface ILiveRoomNewViewController () <UITextFieldDelegate> {
    UILabel           *_tipLabel;
    UITextField       *_roomNameTextField;
    UIButton          *_createBtn;
    
    UILabel           *_audioEncQualityLabel;
    UIButton          *_audioEncQuality1Button;
    UIButton          *_audioEncQuality2Button;
    UIButton          *_audioEncQuality3Button;
    
    NSInteger         audioEncQualityTag;
}

@end

@implementation ILiveRoomNewViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    audioEncQualityTag = 2;
    
    self.title = @"创建直播间";
    [self.view setBackgroundColor:UIColorFromRGB(0x333333)];
    
    _tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 100, 200, 30)];
    _tipLabel.textColor = UIColorFromRGB(0x999999);
    _tipLabel.text = @"直播间名称";
    _tipLabel.textAlignment = NSTextAlignmentLeft;
    _tipLabel.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:_tipLabel];
    
    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 18, 40)];
    _roomNameTextField = [[UITextField alloc] initWithFrame:CGRectMake(0, 136, self.view.width, 40)];
    _roomNameTextField.text = @((long)CFAbsoluteTimeGetCurrent()).stringValue;
    _roomNameTextField.delegate = self;
    _roomNameTextField.leftView = paddingView;
    _roomNameTextField.leftViewMode = UITextFieldViewModeAlways;
    _roomNameTextField.placeholder = @"请输入直播间名称";
    _roomNameTextField.backgroundColor = UIColorFromRGB(0x4a4a4a);
    _roomNameTextField.textColor = UIColorFromRGB(0x939393);
    [self.view addSubview:_roomNameTextField];
    
    _audioEncQualityLabel = [[UILabel alloc] initWithFrame:CGRectMake(18, 200, 100, 30)];
    _audioEncQualityLabel.textColor = UIColorFromRGB(0x999999);
    _audioEncQualityLabel.text = @"音质";
    _audioEncQualityLabel.textAlignment = NSTextAlignmentLeft;
    _audioEncQualityLabel.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:_audioEncQualityLabel];
    
    int btnSpace = 60;
    _audioEncQuality1Button = [UIButton buttonWithType:UIButtonTypeCustom];
    _audioEncQuality1Button.frame = CGRectMake(18 + btnSpace, 200, 30, 30);
    _audioEncQuality1Button.tag = 1;
    _audioEncQuality1Button.layer.shadowOffset = CGSizeMake(1, 1);
    _audioEncQuality1Button.layer.shadowColor = UIColorFromRGB(0x999999).CGColor;
    _audioEncQuality1Button.layer.shadowOpacity = 0.8;
    _audioEncQuality1Button.backgroundColor = UIColorFromRGB(0x05a764);
    [_audioEncQuality1Button setTitle:@"1" forState:UIControlStateNormal];
    [_audioEncQuality1Button setTitleColor:[UIColor blackColor]forState:UIControlStateSelected];
    [_audioEncQuality1Button setTitleColor:[UIColor whiteColor]forState:UIControlStateNormal];
    [_audioEncQuality1Button addTarget:self action:@selector(onAudioEncQualityBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_audioEncQuality1Button];
    
    _audioEncQuality2Button = [UIButton buttonWithType:UIButtonTypeCustom];
    _audioEncQuality2Button.frame = CGRectMake(18 + btnSpace*2, 200, 30, 30);
    _audioEncQuality2Button.tag = 2;
    _audioEncQuality2Button.layer.shadowOffset = CGSizeMake(1, 1);
    _audioEncQuality2Button.layer.shadowColor = UIColorFromRGB(0x999999).CGColor;
    _audioEncQuality2Button.layer.shadowOpacity = 0.8;
    _audioEncQuality2Button.backgroundColor = UIColorFromRGB(0x05a764);
    [_audioEncQuality2Button setTitle:@"2" forState:UIControlStateNormal];
    [_audioEncQuality2Button setTitleColor:[UIColor blackColor]forState:UIControlStateSelected];
    [_audioEncQuality2Button setTitleColor:[UIColor whiteColor]forState:UIControlStateNormal];
    [_audioEncQuality2Button addTarget:self action:@selector(onAudioEncQualityBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_audioEncQuality2Button];
    
    _audioEncQuality3Button = [UIButton buttonWithType:UIButtonTypeCustom];
    _audioEncQuality3Button.frame = CGRectMake(18 + btnSpace*3, 200, 30, 30);
    _audioEncQuality3Button.tag = 3;
    _audioEncQuality3Button.layer.shadowOffset = CGSizeMake(1, 1);
    _audioEncQuality3Button.layer.shadowColor = UIColorFromRGB(0x999999).CGColor;
    _audioEncQuality3Button.layer.shadowOpacity = 0.8;
    _audioEncQuality3Button.backgroundColor = UIColorFromRGB(0x05a764);
    [_audioEncQuality3Button setTitle:@"3" forState:UIControlStateNormal];
    [_audioEncQuality3Button setTitleColor:[UIColor blackColor]forState:UIControlStateSelected];
    [_audioEncQuality3Button setTitleColor:[UIColor whiteColor]forState:UIControlStateNormal];
    [_audioEncQuality3Button addTarget:self action:@selector(onAudioEncQualityBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_audioEncQuality3Button];
    
    _createBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _createBtn.frame = CGRectMake(40, self.view.height - 70, self.view.width - 80, 50);
    _createBtn.layer.cornerRadius = 8;
    _createBtn.layer.masksToBounds = YES;
    _createBtn.layer.shadowOffset = CGSizeMake(1, 1);
    _createBtn.layer.shadowColor = UIColorFromRGB(0x019b5c).CGColor;
    _createBtn.layer.shadowOpacity = 0.8;
    _createBtn.backgroundColor = UIColorFromRGB(0x05a764);
    [_createBtn setTitle:@"开始直播" forState:UIControlStateNormal];
    [_createBtn addTarget:self action:@selector(onCreateBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_createBtn];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = YES;
}

- (void)onCreateBtnClicked:(UIButton *)sender {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"选择模式" message:@"自采集模式：用于和声网对比性能数据  MV模式：用于模仿MOMO的使用场景" delegate:self cancelButtonTitle:@"自采集模式" otherButtonTitles:@"MV模式", nil];
    [alert show];
}

- (void)onAudioEncQualityBtnClicked:(UIButton *)btn {
    audioEncQualityTag = btn.tag;
    
    _audioEncQuality1Button.selected = NO;
    _audioEncQuality2Button.selected = NO;
    _audioEncQuality3Button.selected = NO;
    
    btn.selected = YES;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *roomName = _roomNameTextField.text;
    if (roomName.length == 0) {
        [self alertTips:@"提示" msg:@"直播间名称不能为空"];
        return;
    }
    if (roomName.length > 30) {
        [self alertTips:@"提示" msg:@"直播间名称长度超过限制"];
        return;
    }
    
    if (![self checkRoomName:roomName]) {
        [self alertTips:@"提示" msg:@"直播间名称只能为[a-zA-Z0-9]"];
        return;
    }
    
  
    [TCHttpUtil asyncSendHttpRequest:@"get_test_pushurl" httpServerAddr:kHttpServerAddr HTTPMethod:@"GET" param:nil handler:^(int result, NSDictionary *resultDict) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = @"获取转推播放地址中...";

        NSString *rtmpPushURL = @"";
        NSString *flvPlayURL = @"";
        if (result != 0) {
            NSLog(@"%@", @"获取转推地址失败！");
            pasteboard.string = @"获取转推地址失败...";
        } else {
            NSString* rtmpPlayUrl = nil;
            NSString* flvPlayUrl = nil;
            NSString* hlsPlayUrl = nil;
            NSString* accPlayUrl = nil;
            if (resultDict){
                rtmpPushURL = resultDict[@"url_push"];
                rtmpPlayUrl = resultDict[@"url_play_rtmp"];
                flvPlayURL = resultDict[@"url_play_flv"];
                hlsPlayUrl = resultDict[@"url_play_hls"];
                accPlayUrl = resultDict[@"url_play_acc"];
                NSString* playUrls = [NSString stringWithFormat:@"rtmp播放地址:%@\n\nflv播放地址:%@\n\nhls播放地址:%@\n\n低延时播放地址:%@", rtmpPlayUrl, flvPlayUrl, hlsPlayUrl, accPlayUrl];
                NSLog(@"%@ %@", rtmpPlayUrl, playUrls);
                
                pasteboard.string = playUrls;
            }
        }
  
        dispatch_async(dispatch_get_main_queue(), ^{
            uint64_t userId = [[ILiveRoomService sharedInstance] getUserId];
            __weak __typeof(self) weakSelf = self;
            [[ILiveRoomService sharedInstance] createRoom:userId roomName:roomName privateMap:TXIliveRoomAuthBitsDefaul success:^(NSInteger code, NSString *msg, UInt32 roomId, NSData *privateMapKey, int privateMap, NSData* userSig) {
                if (code != 0) {
                    [weakSelf alertTips:@"创建房间失败" msg:msg];
                    return;
                }
                ILiveRoomPusherViewController *vc = [[UIStoryboard storyboardWithName:@"ILivePusher" bundle:nil] instantiateViewControllerWithIdentifier:@"ILiveRoomPusherViewController"];
                vc.roomName = roomName;
                vc.userId   = userId;
                vc.hostUserId = userId;
                vc.privateMap = privateMap;
                vc.privateMapKey = privateMapKey;
                vc.userSig = userSig;
                vc.roomId = roomId;
                vc.sdkAppId = ILIVEROOM_SDKAPPID;
                vc.appId = ILIVEROOM_APPID;
                vc.bizId = ILIVEROOM_BIZID;
                vc.audioEncQualityIndex = audioEncQualityTag;
                vc.isBroadcaster = YES;
                if (buttonIndex == 0) {
                    vc.pushType = PushType_Camera;
                }else{
                    vc.pushType = PushType_MV;
                }
                vc.isEnterRoomWithCDN = self.isEnterRoomWithCDN;
                vc.cdnURL = rtmpPushURL;
                vc.playURL = flvPlayURL;
                vc.enableSmallStream = self.enableSmallStream;
                vc.enableSendMsgLoop = self.enableSendMsgLoop;
                [weakSelf.navigationController pushViewController:vc animated:YES];
            } fail:^(NSError * _Nonnull error) {
                [weakSelf alertTips:@"创建房间失败" msg:@"请求超时，请检查网络"];
                NSLog(@"createRoom:%@", error.debugDescription);
            }];
        });
    }];
}

- (void)alertTips:(NSString *)title msg:(NSString *)msg {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alertController = [UIAlertController alertControllerWithTitle:title message:msg preferredStyle:UIAlertControllerStyleAlert];
        [alertController addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        }]];
        
        [self.navigationController presentViewController:alertController animated:YES completion:nil];
    });
}

// 检查房间名是否合法
- (BOOL)checkRoomName:(NSString *)roomName {
    NSString *regex = @"[a-zA-Z0-9]+";
    NSPredicate *pred = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", regex];
    return [pred evaluateWithObject:roomName];
}

#pragma mark - UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return YES;
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [_roomNameTextField resignFirstResponder];
}

@end
