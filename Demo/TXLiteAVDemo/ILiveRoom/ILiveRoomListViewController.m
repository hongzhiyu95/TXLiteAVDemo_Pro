//
//  ILiveRoomListViewController.m
//  TXLiteAVDemo
//
//  Created by lijie on 2018/9/14.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "ILiveRoomListViewController.h"
#import "ILiveRoomDef.h"
#import "UIView+Additions.h"
#import "ColorMacro.h"
#import "ILiveRoomTableViewCell.h"
#import "ILiveRoomNewViewController.h"
#import "ILiveRoomTableViewCell.h"
#import "AppDelegate.h"
//#import "PlayViewController.h"
#import "TRTCCloud.h"
#import "ILiveRoomPusherViewController.h"
#import "HCNewViewController.h"

@interface TRTCCloud (Private)
+ (void)setNetEnv:(BOOL)enabled;
@end


@interface ILiveRoomListViewController () <UITableViewDelegate, UITableViewDataSource> {
    NSArray<ILiveRoomInfo *>    *_roomInfoArray;
    
    UILabel                  *_tipLabel;
    UITableView              *_roomlistView;
    UISwitch                 *_trtcDebugEnvSwitch;
    UISwitch                 *_trtcEnterRoomWithCDN; // 是否进房就发起转推
    UILabel                  *_trtcDebugEnvLabel;
    UILabel                  *_trtcEnterRoomWithCDNLabel;
    UISwitch                 *_enableSmallStreamSwitch;
    UILabel                  *_streamLabel;

    UIButton                 *_createBtn;
    UIButton                 *_hcBtn;

    UIButton    *_room1;
    UIButton    *_room2;
    NSIndexPath *_selectIndexPath;
}
@end

@implementation ILiveRoomListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSLog(@"iliveroom version: %@", [OneSecAdapter getSDKVersionStr]);
    _roomInfoArray = [[NSArray alloc] init];
    [self initUI];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.navigationController.navigationBar.hidden = NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    // 请求房间列表
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self requestRoomList];
    });
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.navigationController.navigationBar.hidden = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}

- (void)initUI {
    self.title = @"壹秒房";
    [self.view setBackgroundColor:UIColorFromRGB(0x333333)];
    
    _room1 = [UIButton buttonWithType:UIButtonTypeCustom];
    [_room1 setImage:[UIImage imageNamed:@"checked"] forState:UIControlStateSelected];
    [_room1 setImage:[UIImage imageNamed:@"unchecked"] forState:UIControlStateNormal];
    [_room1 setTitle:@"近端观众" forState:UIControlStateNormal];
    [_room1 addTarget:self action:@selector(roomChanged:) forControlEvents:UIControlEventTouchUpInside];
    _room1.selected = YES;
    _room1.frame = CGRectMake(70*kScaleX, 80*kScaleY, 100*kScaleX, 30*kScaleY);
    [self.view addSubview:_room1];

    _room2 = [UIButton buttonWithType:UIButtonTypeCustom];
    [_room2 setImage:[UIImage imageNamed:@"checked"] forState:UIControlStateSelected];
    [_room2 setImage:[UIImage imageNamed:@"unchecked"] forState:UIControlStateNormal];
    [_room2 setTitle:@"远端观众" forState:UIControlStateNormal];
    [_room2 addTarget:self action:@selector(roomChanged:) forControlEvents:UIControlEventTouchUpInside];
    _room2.frame = CGRectMake(200*kScaleX, 80*kScaleY, 100*kScaleX, 30*kScaleY);
    _room2.hidden = YES;
    [self.view addSubview:_room2];
    
    _tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(70*kScaleX, 200*kScaleY, self.view.width - 140*kScaleX, 60*kScaleY)];
    _tipLabel.textColor = UIColorFromRGB(0x999999);
    _tipLabel.text = @"当前没有进行中的直播\r\n请点击新建直播间";
    _tipLabel.textAlignment = NSTextAlignmentCenter;
    _tipLabel.numberOfLines = 2;
    _tipLabel.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:_tipLabel];
    
    _roomlistView = [[UITableView alloc] initWithFrame:CGRectMake(12*kScaleX, 160*kScaleY, self.view.width - 24*kScaleX, 400*kScaleY)];
    _roomlistView.delegate = self;
    _roomlistView.dataSource = self;
    _roomlistView.backgroundColor = [UIColor clearColor];
    _roomlistView.allowsMultipleSelection = NO;
    _roomlistView.separatorStyle = UITableViewCellSeparatorStyleNone;
    [_roomlistView registerClass:[ILiveRoomTableViewCell class] forCellReuseIdentifier:@"ILiveRoomTableViewCell"];
    [self.view addSubview:_roomlistView];
    
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refreshClick:) forControlEvents:UIControlEventValueChanged];
    [_roomlistView addSubview:refreshControl];
    //[refreshControl beginRefreshing];
    //[self refreshClick:refreshControl];
    
    _trtcDebugEnvSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(40*kScaleX, self.view.height - 150*kScaleY, 40*kScaleX, 30*kScaleY)];
    [self.view addSubview:_trtcDebugEnvSwitch];
    
    _trtcDebugEnvLabel = [[UILabel alloc] initWithFrame:CGRectMake(100*kScaleX, self.view.height - 150*kScaleY, 200*kScaleX, 30*kScaleY)];
    _trtcDebugEnvLabel.textColor = [UIColor whiteColor];
    _trtcDebugEnvLabel.text = @"TRTC测试环境";
    _trtcDebugEnvLabel.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:_trtcDebugEnvLabel];
    
    _trtcEnterRoomWithCDN = [[UISwitch alloc] initWithFrame:CGRectMake(40*kScaleX, self.view.height - 200*kScaleY, 40*kScaleX, 30*kScaleY)];
    [_trtcEnterRoomWithCDN setOn:YES];
    [self.view addSubview:_trtcEnterRoomWithCDN];
    
    _trtcEnterRoomWithCDNLabel = [[UILabel alloc] initWithFrame:CGRectMake(100*kScaleX, self.view.height - 200*kScaleY, 200*kScaleX, 30*kScaleY)];
    _trtcEnterRoomWithCDNLabel.textColor = [UIColor whiteColor];
    _trtcEnterRoomWithCDNLabel.text = @"进房且转推";
    _trtcEnterRoomWithCDNLabel.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:_trtcEnterRoomWithCDNLabel];
    
    _enableSmallStreamSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(40*kScaleX, self.view.height - 250*kScaleY, 40*kScaleX, 30*kScaleY)];
    [self.view addSubview:_enableSmallStreamSwitch];
    
    _streamLabel = [[UILabel alloc] initWithFrame:CGRectMake(100*kScaleX, self.view.height - 250*kScaleY, 200*kScaleX, 30*kScaleY)];
    _streamLabel.textColor = [UIColor whiteColor];
    _streamLabel.text = @"大小流模式";
    _streamLabel.font = [UIFont systemFontOfSize:16];
    [self.view addSubview:_streamLabel];
    
    _createBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _createBtn.frame = CGRectMake(0, self.view.height - 60*kScaleY, (self.view.width - 20)/2,  50*kScaleY);
    _createBtn.layer.cornerRadius = 8;
    _createBtn.layer.masksToBounds = YES;
    _createBtn.layer.shadowOffset = CGSizeMake(1, 1);
    _createBtn.layer.shadowColor = UIColorFromRGB(0x019b5c).CGColor;
    _createBtn.layer.shadowOpacity = 0.8;
    _createBtn.backgroundColor = UIColorFromRGB(0x05a764);
    [_createBtn setTitle:@"新建直播间" forState:UIControlStateNormal];
    [_createBtn addTarget:self action:@selector(onCreateBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_createBtn];
    
    _hcBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    _hcBtn.frame = CGRectMake((self.view.width - 20)/2 + 20, self.view.height - 60*kScaleY, (self.view.width - 20)/2,  50*kScaleY);
    _hcBtn.layer.cornerRadius = 8;
    _hcBtn.layer.masksToBounds = YES;
    _hcBtn.layer.shadowOffset = CGSizeMake(1, 1);
    _hcBtn.layer.shadowColor = UIColorFromRGB(0x019b5c).CGColor;
    _hcBtn.layer.shadowOpacity = 0.8;
    _hcBtn.backgroundColor = UIColorFromRGB(0x05a764);
    [_hcBtn setTitle:@"合唱" forState:UIControlStateNormal];
    [_hcBtn addTarget:self action:@selector(onHCBtnClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_hcBtn];
}

- (void)requestRoomList {
    [[ILiveRoomService sharedInstance] getRoomList:0 cnt:100 success:^(NSInteger code, NSString *msg, NSArray<ILiveRoomInfo *> *roomInfos) {
        if (code != 0) {
            [self toastTip:msg];
            return;
        }
        _roomInfoArray = roomInfos;
        // 刷新列表
        [_roomlistView reloadData];
        if (_roomInfoArray.count) {
            _tipLabel.text = @"选择直播间点击进入";
            _tipLabel.frame = CGRectMake(14*kScaleX, 120*kScaleY, self.view.width, 30*kScaleY);
            _tipLabel.textAlignment = NSTextAlignmentLeft;
        } else {
            _tipLabel.text = @"当前没有进行中的直播\r\n请点击新建直播间";
            _tipLabel.frame = CGRectMake(70*kScaleX, 200*kScaleY, self.view.width - 140*kScaleX, 60*kScaleY);
            _tipLabel.textAlignment = NSTextAlignmentCenter;
        }
    } fail:^(NSError * _Nonnull error) {
        [self toastTip:@"请求超时，请检查网络"];
        NSLog(@"getRoomList:%@", error.debugDescription);
    }];
}

- (void)refreshClick:(UIRefreshControl *)refreshControl {
    [refreshControl endRefreshing];
    
    [self requestRoomList];
}

- (void)onCreateBtnClicked:(UIButton *)sender {
    ILiveRoomNewViewController *newRoomController = [[ILiveRoomNewViewController alloc] init];
    newRoomController.isEnterRoomWithCDN = [_trtcEnterRoomWithCDN isOn];
    newRoomController.enableSmallStream = _enableSmallStreamSwitch.isOn;
    [TRTCCloud setNetEnv: _trtcDebugEnvSwitch.isOn];
    [self.navigationController pushViewController:newRoomController animated:YES];
}

- (void)onHCBtnClicked:(UIButton *)sender {
    HCNewViewController *newRoomController = [[HCNewViewController alloc] init];
    [self.navigationController pushViewController:newRoomController animated:YES];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _roomInfoArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *identify = @"ILiveRoomTableViewCell";
    ILiveRoomTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identify];
    if (cell == nil) {
        cell = [[ILiveRoomTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identify];
    }
    if (indexPath.row >= _roomInfoArray.count) {
        return cell;
    }
    cell.roomInfo = _roomInfoArray[indexPath.row];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= _roomInfoArray.count) {
        return;
    }
    if (_room1.selected) {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"选择模式" message:@"自采集模式：用于和声网对比性能数据  MV模式：用于模仿MOMO的使用场景" delegate:self cancelButtonTitle:@"自采集模式" otherButtonTitles:@"MV模式", nil];
        [alert show];
        _selectIndexPath = indexPath;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 130;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // 视图跳转
    if (_selectIndexPath.row < _roomInfoArray.count) {
        ILiveRoomPusherViewController *vc = [[UIStoryboard storyboardWithName:@"ILivePusher" bundle:nil] instantiateViewControllerWithIdentifier:@"ILiveRoomPusherViewController"];
        ILiveRoomInfo * info = _roomInfoArray[_selectIndexPath.row];
        
        uint64_t userId = [[ILiveRoomService sharedInstance] getUserId];
        [[ILiveRoomService sharedInstance] enterRoom:userId roomId:info.roomId privateMap:255
                                             success:^(NSInteger code, NSString *msg, UInt32 roomId, NSData *privateMapKey, int privateMap, NSData* userSig) {
            vc.roomName = info.roomName;
            vc.userId   = userId;
            vc.hostUserId = info.roomCreator;
            vc.privateMap = privateMap;
            vc.privateMapKey = privateMapKey;
            vc.userSig = userSig;
            vc.roomId = roomId;
            vc.sdkAppId = ILIVEROOM_SDKAPPID;
            vc.appId = ILIVEROOM_APPID;
            vc.bizId = ILIVEROOM_BIZID;
            vc.audioEncQualityIndex = 2;
            if (buttonIndex == 0) {
                vc.pushType = PushType_Camera;
            }else{
                vc.pushType = PushType_MV;
            }
            vc.isEnterRoomWithCDN = NO;
            vc.cdnURL = @"";
            vc.enableSmallStream = self->_enableSmallStreamSwitch.on;
            vc.isBroadcaster = NO;
            [self.navigationController pushViewController:vc animated:YES];
        }
                                                fail:^(NSError * _Nonnull error) {
            [self alertTips:@"进房失败" msg:@"业务服务器异常，获取userSign失败" completion:^{
                
            }];
        }];
    }
}

/**
 @method 获取指定宽度width的字符串在UITextView上的高度
 @param textView 待计算的UITextView
 @param width 限制字符串显示区域的宽度
 @result float 返回的高度
 */
- (float)heightForString:(UITextView *)textView andWidth:(float)width {
    CGSize sizeToFit = [textView sizeThatFits:CGSizeMake(width, MAXFLOAT)];
    return sizeToFit.height;
}

- (void)toastTip:(NSString *)toastInfo {
    CGRect frameRC = [[UIScreen mainScreen] bounds];
    frameRC.origin.y = frameRC.size.height - 50;
    frameRC.size.height -= 110;
    __block UITextView *toastView = [[UITextView alloc] init];
    
    toastView.editable = NO;
    toastView.selectable = NO;
    
    frameRC.size.height = [self heightForString:toastView andWidth:frameRC.size.width];
    
    toastView.frame = frameRC;
    
    toastView.text = toastInfo;
    toastView.backgroundColor = [UIColor whiteColor];
    toastView.alpha = 0.5;
    
    [self.view addSubview:toastView];
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC);
    
    dispatch_after(popTime, dispatch_get_main_queue(), ^() {
        [toastView removeFromSuperview];
        toastView = nil;
    });
}

- (void)roomChanged:(UIButton *)btn
{
    if (btn == _room1) {
        _room1.selected = YES;
        _room2.selected = NO;
    } else {
        _room1.selected = NO;
        _room2.selected = YES;
    }
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
@end
