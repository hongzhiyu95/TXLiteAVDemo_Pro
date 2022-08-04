//
//  HeChangAdapter.m
//  TXLiteAVDemo_ILiveRoom_Smart
//
//  Created by hans on 2020/3/4.
//  Copyright © 2020 Tencent. All rights reserved.
//

#import "HeChangAdapter.h"

#define HC_WEAKIFY(x) __weak __typeof(x) weak_##x = self
#define HC_STRONGIFY(x) __strong __typeof(weak_##x) x = weak_##x
#define HC_STRONGIFY_OR_RETURN(x) __strong __typeof(weak_##x) x = weak_##x; if (x == nil) {return;};

@implementation HeChangRoleConfig
@end

@interface HeChangAdapter() <TXILiveRoomDelegateAdapter, TXILiveRoomAudioDelegateAdapter>

@end

@implementation HeChangAdapter {
    HeChangMode                 _mode;
    HeChangRole                 _role;
    OneSecAdapter               *_liveRoom;
    NSMutableDictionary<NSNumber*, HeChangRoleConfig*> *_roleConfigMap;
    NSMutableSet<NSNumber*>     *_onRoomBroadcasterSet;
    NSString                    * _bgmStartStr;
    NSString                    * _bgmFinishStr;
    NSString                    * _bgmErorrStr;
    NSInteger                   _bgmDuration;
    
    // 定时发送 SEI 的定时器，用于同步歌曲进度
    dispatch_source_t           _seiTimer;
    dispatch_queue_t            _seiTimerQueue;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _mode = HeChangDefaultMode;
        _role = HeChangAudienceRole;
        _roleConfigMap = [[NSMutableDictionary alloc] init];
        _onRoomBroadcasterSet = [[NSMutableSet alloc] init];
        _bgmStartStr = @"HeChang: BGM start play.";
        _bgmFinishStr = @"HeChang: BGM play finish.";
        _bgmErorrStr = @"HeChang: BGM start play error.";
        _bgmDuration = 0;
        _seiTimerQueue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
    }
    return self;
}

- (void)sendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer {
    if (_mode == HeChangAudioMode) {
        return;
    }
    [_liveRoom sendVideoSampleBuffer:sampleBuffer];
}

- (void)joinRoom:(OneSecAdapterParams *)params config:(TXILiveRoomConfig *)config {
    if (_liveRoom == nil) {
        _liveRoom = [[OneSecAdapter alloc] initWithSdkAppId:params.sdkAppId userId:params.userId];
    }
    _liveRoom.audioDelegate = self;
    _liveRoom.delegate = self;
    [_liveRoom setVolumeType:TXILiveRoomAudioVolumeTypeMedia];
    [_liveRoom joinRoom:params config:config];
    
}

- (void)updateHCConfig:(HeChangMode)mode role:(HeChangRole)role roleConfig:(NSDictionary<NSNumber*,HeChangRoleConfig*>*)roleConfig targetVideoWidth:(int)width targetVideoHeight:(int)height {
    NSLog(@"HeChange: update config, mode:%d, role:%d, config:%@, target width:%d, target heigth:%d", (int)mode, (int)role, roleConfig, width, height);
    
    _mode = mode;
    if (_mode == HeChangAudioMode) {
        // 纯音频模式下，需要启动该能力，才能够通过 sendMessageEx 发送歌词时间戳
        [_liveRoom enableAudioMessage:YES];
    } else {
        // 音视频模式下，需要关闭该能力。 否则无法通过 sendCustomVideoTexture 发送视频数据
        [_liveRoom enableAudioMessage:NO];
    }
    _role = role;
    if (_role == HeChangAudienceRole) {
        [_liveRoom switchRole:TXILiveRoomRoleAudience];
    } else {
        // 合唱角色除了观众，其他都是要切换到主播
        [_liveRoom switchRole:TXILiveRoomRoleBroadcaster];
    }
    // 移除原有配置
    [_roleConfigMap removeAllObjects];
    // 先清除一遍本地混流配置
    [_liveRoom clearLocalMixConfig];
    if (roleConfig != nil  && roleConfig.count > 0) {
        _roleConfigMap = [roleConfig mutableCopy];
        if (_role == HeChangSubSingerRole) {
            // 如果是副唱，需要组织混流配置
            NSMutableArray *roleConfigArr = [[_roleConfigMap allValues] mutableCopy];
            // 按照主持人、领唱、副唱的顺序排好队，方便本地混流
            [roleConfigArr sortUsingComparator:^NSComparisonResult(HeChangRoleConfig *obj1, HeChangRoleConfig *obj2) {
                return obj1.role - obj2.role;
            }];
            
            TXILiveRoomLocalMixConfig *config = [[TXILiveRoomLocalMixConfig alloc] init];
            config.videoWidth = width;
            config.videoHeight = height;
            config.onlyMixAudio = _mode == HeChangVideoOnlyMixAudioMode;
            NSMutableArray<TXILiveRoomLocalMixUser *> *userArr = [[NSMutableArray alloc] init];
            for (HeChangRoleConfig* roleConfig in roleConfigArr) {
                if (roleConfig.role == HeChangMainSingerRole) {
                    TXILiveRoomLocalMixUser *mixUser = [[TXILiveRoomLocalMixUser alloc] init];
                    mixUser.userId = roleConfig.userId;
                    mixUser.rect = CGRectMake(0, 0, roleConfig.width, roleConfig.height);
                    [userArr addObject:mixUser];
                } else if(roleConfig.role == HeChangSubSingerRole) {
                    if ([userArr count] != 1) {
                        // 说明没有找到主唱的 role config
                        break;
                    }
                    TXILiveRoomLocalMixUser *mixUser= [[TXILiveRoomLocalMixUser alloc] init];
                    mixUser.userId = roleConfig.userId;
                    mixUser.rect = CGRectMake([userArr objectAtIndex:0].rect.size.width, 0, roleConfig.width, roleConfig.height);
                    [userArr addObject:mixUser];
                }
            }
            config.mixUsers = userArr;
            if ([config.mixUsers count] == 2) {
                [_liveRoom setLocalMixConfig:config];
            }
        }
    }
    // 停止所有渲染
    [_liveRoom stopAllRemoteRender];
    // 如果已经有主播在房间里面了，可能 config 发生了变化，那么重新发起渲染。
    for (NSNumber *userId in _onRoomBroadcasterSet) {
        [self startSDKRender:[userId longLongValue]];
    }
}

- (void)dealloc {
    [self destroy];
}

- (void)destroy {
    [self stopSEITimer];
    if (_liveRoom != nil) {
        _liveRoom.audioDelegate = nil;
        _liveRoom.delegate = nil;
        [_liveRoom stopMusic];
        [_liveRoom quitRoom];
        _liveRoom = nil;
        _bgmDuration = 0;
    }
}

- (void)muteLocalAudio:(BOOL)mute {
    [_liveRoom muteLocalAudio:mute];
}

- (void)playMusic:(NSString *)url loopback:(BOOL)loopback times:(int)times {
    [_liveRoom playMusicWithUrl:url loopback:loopback repeat:times];
}

- (void)stopMusic {
    [_liveRoom stopMusic];
}

- (void)setMusicVolume:(float)volume {
    [_liveRoom setMusicVolume:volume];
}

- (void)startSDKRender:(UInt64) userId {
    HeChangRoleConfig *roleConfig = [_roleConfigMap objectForKey:@(userId)];
    if (roleConfig == nil) {
        NSLog(@"HeChang: start sdk render, role config is null, may be something error!!!");
        return;
    }
    NSLog(@"HeChang: start sdk render,role config:%@", roleConfig);
    if (roleConfig.role == HeChangMCRole) {
        // 主持人进房：主持人在业务逻辑上不会开视频位，直接停止渲染。、
        [_liveRoom stopRemoteRender:userId];
        NSLog(@"HeChang: ignore render");
    } else if (roleConfig.role == HeChangMainSingerRole) {
        if (_role == HeChangSubSingerRole) {
            // 领唱进房：只有副唱会去拉领唱
            [_liveRoom startRemoteRender:userId view:(_mode == HeChangDefaultMode || _mode == HeChangVideoOnlyMixAudioMode) ? roleConfig.renderView : nil];
            NSLog(@"HeChang: do render");
        } else {
            // 其他人全部不拉领唱，直接停止拉流
            if (_mode == HeChangDefaultMode) {
                [_liveRoom muteRemoteAudio:userId mute:YES];
                [_liveRoom muteRemoteVideo:userId mute:YES];
                [_liveRoom stopRemoteRender:userId];
            } else if(_mode == HeChangVideoOnlyMixAudioMode) {
                [_liveRoom muteRemoteAudio:userId mute:YES];
                [_liveRoom startRemoteRender:userId view:roleConfig.renderView];
            }
            NSLog(@"HeChang: ignore render");
        }
    } else if (roleConfig.role == HeChangSubSingerRole) {
        if (_role == HeChangMainSingerRole) {
            // 副唱进房：领唱不拉副唱
            [_liveRoom muteRemoteAudio:userId mute:YES];
            [_liveRoom muteRemoteVideo:userId mute:YES];
            [_liveRoom stopRemoteRender:userId];
            NSLog(@"HeChang: ignore render");
        } else {
            // 其他人都要拉副唱（副唱画面和声音是 副唱本地合成领唱和自己的）
            [_liveRoom startRemoteRender:userId view:(_mode == HeChangDefaultMode || _mode == HeChangVideoOnlyMixAudioMode) ? roleConfig.renderView : nil];
            NSLog(@"HeChang: do render");
        }
    } else {
        // 进来的人一定是主持人、领唱、副唱之一，因为只有他们才能是主播，所以走到里是有异常情况
        NSLog(@"HeChang: invalid broadcaster enter room, userId:%llu",userId);
    }
}

- (void)onRoomBroadcasterIn:(NSString *)roomName userId:(UInt64)userId {
    NSLog(@"HeChang: broadcater in, my role:%d, enter user id:%llu", (int)_role, userId);
    [_onRoomBroadcasterSet addObject:@(userId)];
    [self startSDKRender:userId];
}

- (void)onRoomBroadcasterOut:(NSString *)roomName userId:(UInt64)userId reason:(TXILiveRoomOfflineReason)reason {
    NSLog(@"HeChang: brocaster out, my role:%d, exit user id:%llu", (int)_role, userId);
    [_onRoomBroadcasterSet removeObject:@(userId)];
    [_liveRoom stopRemoteRender:userId];
}

- (void)onRecvMessage:(NSString *)roomName userId:(UInt64)userId msg:(NSData *)msg {
    HeChangRoleConfig *roleConfig = [_roleConfigMap objectForKey:@(userId)];
    if (roleConfig == nil) {
        NSLog(@"HeChang: on recv sei, but role config is null, maybe something error!!!");
        return;
    }
    NSString *strMsg = [[NSString alloc] initWithData:msg encoding:NSUTF8StringEncoding];
    // 情况1： 消息来自领唱，我的角色是副唱，那么需要处理
    // 情况2： 消息来自副唱，我的角色是观众或者主持人，那么需要处理
    if ((roleConfig.role == HeChangMainSingerRole && _role == HeChangSubSingerRole)
            || (roleConfig.role == HeChangSubSingerRole && (_role == HeChangAudienceRole || _role == HeChangMCRole))) {
        
        if ([strMsg containsString:_bgmStartStr]) {
            [self callbackMusicStart];
        } else if ([strMsg containsString:_bgmFinishStr]) {
            [self callbackMusicFinsih];
        } else if ([strMsg containsString:_bgmErorrStr]) {
            NSArray<NSString*> *arr = [strMsg componentsSeparatedByString:@":"];//分隔字符串
            if (arr != nil && [arr count] == 2) {
                [self callbackMusicError:[arr[1] intValue]];
            }
        } else {
            [self callbackMusicProgress:[strMsg longLongValue]];
        }
    }
    // 副唱需要转发里领唱的消息
    if (roleConfig.role == HeChangMainSingerRole && _role == HeChangSubSingerRole) {
        [_liveRoom sendMessageEx:msg];
    }
}

#pragma SDK回调
- (void)onMusicPlayBegin {
    if (_role == HeChangMainSingerRole) {
        //timer start
        [self startSEITimer];
        
        _bgmDuration = [_liveRoom getMusicDuration];
        
        [_liveRoom sendMessageEx:[_bgmStartStr dataUsingEncoding:NSUTF8StringEncoding]];
        
        [self callbackMusicStart];
    }
}

- (void)onMusicPlayFinish {
    if (_role == HeChangMainSingerRole) {
        // timer stop
        [self stopSEITimer];
        
        // 发送一个歌曲播放到结尾的 SEI
        [_liveRoom sendMessageEx:[[NSString stringWithFormat:@"%ld", _bgmDuration] dataUsingEncoding:NSUTF8StringEncoding]];
        
        // 发送 BGM 播放完成的信息
        [_liveRoom sendMessageEx:[_bgmFinishStr dataUsingEncoding:NSUTF8StringEncoding]];
        
        [self callbackMusicFinsih];
    }
}

- (void)onMusicPlayError:(TXILiveRoomErrorCode)error {
    if (_role == HeChangMainSingerRole) {
        // timer stop
        [self stopSEITimer];
        
        [_liveRoom sendMessageEx:[[NSString stringWithFormat:@"%@:%d", _bgmErorrStr, (int)error] dataUsingEncoding:NSUTF8StringEncoding]];
        
        [self callbackMusicError:(int) error];
    }
}

#pragma 回调到外部
- (void)callbackMusicStart{
    if (_musicDelegate && [_musicDelegate respondsToSelector:@selector(onMusicPlayBegin)]) {
      [_musicDelegate onMusicPlayBegin];
    }
}

- (void)callbackMusicFinsih{
    if (_musicDelegate && [_musicDelegate respondsToSelector:@selector(onMusicPlayFinish)]) {
       [_musicDelegate onMusicPlayFinish];
    }
}

- (void)callbackMusicError:(int) error{
    if (_musicDelegate && [_musicDelegate respondsToSelector:@selector(onMusicPlayError:)]) {
       [_musicDelegate onMusicPlayError:error];
    }
}
- (void)callbackMusicProgress:(long) progress {
    if (_musicDelegate && [_musicDelegate respondsToSelector:@selector(onMusicPlayProgress:)]) {
       [_musicDelegate onMusicPlayProgress:progress];
    }
}

#pragma SEI looper

- (void)startSEITimer {
    NSLog(@"HeChang: start sei looper");

    if (_seiTimer != nil) {
        return;
    }
    HC_WEAKIFY(self);
    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _seiTimerQueue);
    dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 1 / 15.0 * NSEC_PER_SEC, 0.1 * NSEC_PER_SEC);
    dispatch_source_set_event_handler(timer, ^{
        HC_STRONGIFY_OR_RETURN(self);
        [self onSEITimer];
    });
    dispatch_resume(timer);
    _seiTimer = timer;
}

- (void)onSEITimer {
    NSInteger progess = [_liveRoom getMusicCurrentPosition];
    NSLog(@"music progress:%ld", progess);
    [_liveRoom sendMessageEx:[[NSString stringWithFormat:@"%ld", progess] dataUsingEncoding:NSUTF8StringEncoding]];
    [self callbackMusicProgress:progess];
}

- (void)stopSEITimer {
    if (_seiTimer != nil) {
        dispatch_cancel(_seiTimer);
        _seiTimer = nil;
    }
}

@end
