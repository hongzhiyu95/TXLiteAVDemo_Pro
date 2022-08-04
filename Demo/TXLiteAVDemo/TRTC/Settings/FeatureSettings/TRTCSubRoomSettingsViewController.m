//
//  TRTCSubRoomSettingsViewController.m
//  TXReplaykitUpload_TRTC
//
//  Created by J J on 2020/7/15.
//  Copyright © 2020 Tencent. All rights reserved.
//

#import "TRTCSubRoomSettingsViewController.h"
#import "TRTCSettingsSubRoomTableViewCell.h"
#import "TRTCSettingsMainRoomTableViewCell.h"
#import "TRTCCloud.h"
#import "GenerateTestUserSig.h"
#import "TRTCVideoView.h"
#import "ColorMacro.h"
#import "TRTCMainViewController.h"

@interface TRTCSubRoomSettingsViewController ()
@property (copy, nonatomic) NSString *ownRoomId;
@property (copy, nonatomic) NSString *ownUserId;
@property (strong, nonatomic) NSMutableArray<NSString *> *arraySubRoomId;
@end

@implementation TRTCSubRoomSettingsViewController

- (NSString *)title {
    return @"子房间";
}

- (void) dealloc {
    @try {
        [_trtcCloudManager.audioConfig removeObserver:self forKeyPath:@"isMuted"];
        [_trtcCloudManager.videoConfig removeObserver:self forKeyPath:@"isMuted"];
        [_trtcCloudManager.params removeObserver:self forKeyPath:@"role"];
        [_trtcCloudManager.params removeObserver:self forKeyPath:@"roomId"];
        [_trtcCloudManager.params removeObserver:self forKeyPath:@"strRoomId"];
    } @catch (NSException *exception) {
        NSLog(@"TRTCSubRoomSettingsViewController dealloc observer 未注册");
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _arraySubRoomId = [[NSMutableArray alloc] init];
    
    _ownRoomId = _trtcCloudManager.params.roomId ? [@(_trtcCloudManager.params.roomId) stringValue] : _trtcCloudManager.params.strRoomId;
    _ownUserId = _trtcCloudManager.params.userId;
    __weak __typeof(self) wSelf = self;
    
    TRTCSettingsMessageItem *createRoomItem = [[TRTCSettingsMessageItem alloc] initWithTitle:@"新房间" placeHolder:@"仅支持数字房间号" content:nil actionTitle:@"进入" action:^(NSString *roomId) {
        if (![self->_arraySubRoomId containsObject:roomId] && ![roomId isEqual: @""] && ![roomId isEqual:self.ownRoomId]) {
            [wSelf createChildRoom:roomId];
            [self->_arraySubRoomId addObject:roomId];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"进房失败" message:@"请勿输入与主房间相同的房间号；仅支持数字房间号" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
            [alert show];
        }
    }];
    
    //主房间
    BOOL isPushing = !(_trtcCloudManager.audioConfig.isMuted && _trtcCloudManager.videoConfig.isMuted);
    TRTCSettingsMainRoomTableViewItem *mainRoomItem = [[TRTCSettingsMainRoomTableViewItem alloc] initWithRoomId:_ownRoomId isOn:isPushing actionA:^(BOOL isPush, id  _Nonnull cell) {
        //用户切换主房间推流开关后会触发这个Block
        __strong __typeof(self) self = wSelf;
        NSArray *cellIndPaths = [self.tableView indexPathsForVisibleRows];
        for (int index = 2; index < cellIndPaths.count; index ++) {
            TRTCSettingsSubRoomTableViewCell *subCell = [self.tableView cellForRowAtIndexPath:cellIndPaths[index]];
            if ([subCell.relatedItem.subRoomId isEqualToString:wSelf.trtcCloudManager.currentPublishingRoomId]) {
                //一、如果主房间开始推流，则关闭所有子房间的推流
                [subCell setCellSelected:NO];//切换按钮选择状态
                [wSelf.trtcCloudManager pushAudioStreamInSubRoom:subCell.relatedItem.subRoomId push:NO];
                [wSelf.trtcCloudManager pushVideoStreamInSubRoom:subCell.relatedItem.subRoomId push:NO];
                [wSelf.trtcCloudManager switchSubRoomRole:TRTCRoleAudience roomId:subCell.relatedItem.subRoomId];
            }
        }
        
        //二、根据isPush来开关主房间的推流
        [wSelf.trtcCloudManager switchRole:isPush ? TRTCRoleAnchor : TRTCRoleAudience];
        [wSelf.trtcCloudManager setAudioMuted:!isPush];
        [wSelf.trtcCloudManager setVideoMuted:!isPush];
        [cell setCellSelected:isPush];
    } actionTitle:@"" actionB:^(NSString * _Nullable content) {
        //
    }];
    
    self.items = [[NSMutableArray alloc] initWithArray:@[
        createRoomItem,
        mainRoomItem,
    ]];
    [_trtcCloudManager.audioConfig addObserver:self forKeyPath:@"isMuted" options:NSKeyValueObservingOptionNew context:nil];
    [_trtcCloudManager.videoConfig addObserver:self forKeyPath:@"isMuted" options:NSKeyValueObservingOptionNew context:nil];
    [_trtcCloudManager.params addObserver:self forKeyPath:@"roomId" options:NSKeyValueObservingOptionNew context:nil];
    [_trtcCloudManager.params addObserver:self forKeyPath:@"role" options:NSKeyValueObservingOptionNew context:nil];
    [_trtcCloudManager.params addObserver:self forKeyPath:@"strRoomId" options:NSKeyValueObservingOptionNew context:nil];
}

#pragma mark - Actions

- (void)createChildRoom:(NSString *)roomId {
    __weak __typeof(self) wSelf = self;
    //注意，这里将roomId转换成了整数，代表进入的子房间都是数值房间号
    UInt32 copyRoomId = [roomId intValue];
    _params = [[TRTCParams alloc] init];
    _params.roomId = copyRoomId;
    _params.sdkAppId = _SDKAppID;
    _params.userId = _ownUserId;
    _params.userSig = [GenerateTestUserSig genTestUserSig:_ownUserId sdkAppId:_SDKAppID secretKey:_SECRETKEY];
    _params.privateMapKey = @"";
    _params.role = TRTCRoleAudience;
    
    [_trtcCloudManager enterSubRoom:_params];
    //子房间
    __block TRTCSettingsSubRoomCellTableViewItem *subItem = [[TRTCSettingsSubRoomCellTableViewItem alloc] initWithRoomId:roomId isOn:NO actionA:^(BOOL isPush, id  _Nonnull cell) {
        //用户切换子房间推流开关后会触发这个Block
        NSArray *cellIndPaths = [self.tableView indexPathsForVisibleRows];
        for (int index = 1; index < cellIndPaths.count; index ++) {
            if (index == 1) {
                TRTCSettingsMainRoomTableViewCell *mainCell = [self.tableView cellForRowAtIndexPath:cellIndPaths[index]];
                if ([mainCell.relatedItem.title isEqualToString:wSelf.trtcCloudManager.currentPublishingRoomId]) {
                    [mainCell setCellSelected:NO];//切换按钮选择状态
                    //一、在subCloud推流前先停止主房间的推流
                    [wSelf.trtcCloudManager setAudioMuted:YES];
                    [wSelf.trtcCloudManager setVideoMuted:YES];
                    [wSelf.trtcCloudManager switchRole:TRTCRoleAudience];
                }
            } else if (cell != cellIndPaths[index]) {
                TRTCSettingsSubRoomTableViewCell *subCell = [self.tableView cellForRowAtIndexPath:cellIndPaths[index]];
                if ([subCell.relatedItem.subRoomId isEqualToString:wSelf.trtcCloudManager.currentPublishingRoomId]) {
                    //二、在目标subCloud推流前先停止其它子房间的推流
                    [subCell setCellSelected:NO];
                    [wSelf.trtcCloudManager pushAudioStreamInSubRoom:subCell.relatedItem.subRoomId push:NO];
                    [wSelf.trtcCloudManager pushVideoStreamInSubRoom:subCell.relatedItem.subRoomId push:NO];
                    [wSelf.trtcCloudManager switchSubRoomRole:TRTCRoleAudience roomId:subCell.relatedItem.subRoomId];
                }
            }
        }
        //三、最后开启目标子房间的推流
        [wSelf.trtcCloudManager switchSubRoomRole:TRTCRoleAnchor roomId:roomId];
        [wSelf.trtcCloudManager pushAudioStreamInSubRoom:subItem.subRoomId push:isPush];
        [wSelf.trtcCloudManager pushVideoStreamInSubRoom:subItem.subRoomId push:isPush];
    } actionTitle:@"退房" actionB:^(NSString * _Nullable content) {
        [wSelf.trtcCloudManager exitSubRoom:roomId];
        [wSelf.arraySubRoomId removeObject:subItem.title];
        [wSelf.items removeObject:subItem];
        [wSelf.tableView reloadData];
    }];
    [self.items addObject:subItem];
    [self.tableView reloadData];
}

- (void)onSelectItem:(TRTCSettingsBaseItem *)item {
    
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context {
    if ([keyPath isEqualToString:@"role"]||
        [keyPath isEqualToString:@"isMuted"]) {
        BOOL isPushing = !(_trtcCloudManager.audioConfig.isMuted && _trtcCloudManager.videoConfig.isMuted);
        NSArray *cellIndPaths = [self.tableView indexPathsForVisibleRows];
        if ([_trtcCloudManager.currentPublishingRoomId isEqualToString:_ownRoomId]) {
            //当前在主房间推流，更新主房间状态
            TRTCSettingsMainRoomTableViewCell *mainCell = (TRTCSettingsMainRoomTableViewCell *)[self.tableView cellForRowAtIndexPath:cellIndPaths[1]];
                [mainCell setCellSelected:isPushing&&[_trtcCloudManager.currentPublishingRoomId isEqualToString:mainCell.relatedItem.title]];
        } else {
            //若当前是在子房间推流
            for (int i = 2; i < cellIndPaths.count; i++) {
                TRTCSettingsSubRoomTableViewCell *subCell = (TRTCSettingsSubRoomTableViewCell *)[self.tableView cellForRowAtIndexPath:cellIndPaths[i]];
                if ([subCell.relatedItem.subRoomId isEqualToString:_trtcCloudManager.currentPublishingRoomId]) {
                    [subCell setCellSelected:isPushing&&[_trtcCloudManager.currentPublishingRoomId isEqualToString:subCell.relatedItem.subRoomId]];
                }
            }
        }
    }
    if ([keyPath isEqualToString:@"roomId"]||[keyPath isEqualToString:@"strRoomId"]) {
        //切换了房间
        _ownRoomId = _trtcCloudManager.params.roomId ? [@(_trtcCloudManager.params.roomId) stringValue] : _trtcCloudManager.params.strRoomId;
        //更新主房间cell的房间号
        TRTCSettingsMainRoomTableViewItem *mainItem = (TRTCSettingsMainRoomTableViewItem *)self.items[1];
        [mainItem setTitle:_ownRoomId];
    }
    [self.tableView reloadData];
}

@end

