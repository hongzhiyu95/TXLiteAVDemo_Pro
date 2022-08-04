//
//  HeChangAdapter.h
//  TXLiteAVDemo_ILiveRoom_Smart
//
//  Created by hans on 2020/3/4.
//  Copyright © 2020 Tencent. All rights reserved.
//
#import <Foundation/Foundation.h>
#import "TXILiveRoomDefine.h"
#import "OneSecAdapter.h"

typedef NS_ENUM(NSInteger, HeChangMode) {
    HeChangDefaultMode = 0,
    HeChangAudioMode,
    HeChangVideoOnlyMixAudioMode
};

typedef NS_ENUM(NSInteger, HeChangRole) {
    HeChangMCRole = 0,
    HeChangMainSingerRole,
    HeChangSubSingerRole,
    HeChangAudienceRole
};

@interface HeChangRoleConfig : NSObject

@property (nonatomic, assign) UInt64 userId;
@property (nonatomic, assign) HeChangRole role;
@property (nonatomic, assign) int width;    // 如果该角色有视频，那么需要设定视频宽度
@property (nonatomic, assign) int height;   // 如果该角色有视频，那么需要设定视频高度
@property (nonatomic, weak) UIView *renderView;
@end

@protocol HeChangMusicDelegate <NSObject>
@optional


- (void)onMusicPlayBegin;

- (void)onMusicPlayProgress:(long) progress;

- (void)onMusicPlayFinish;

- (void)onMusicPlayError:(int) code;
@end

@interface HeChangAdapter : NSObject
@property (nonatomic, weak) id<TXILiveRoomDelegateAdapter> delegate;
@property (nonatomic, weak) id<HeChangMusicDelegate> musicDelegate;

- (void)joinRoom:(OneSecAdapterParams *)params config:(TXILiveRoomConfig *)config;

- (void)sendVideoSampleBuffer:(CMSampleBufferRef)sampleBuffer;

- (void)updateHCConfig:(HeChangMode) mode role:(HeChangRole)role roleConfig:(NSDictionary *)roleConfig targetVideoWidth:(int)width targetVideoHeight:(int) height;

- (void)destroy;

- (void)muteLocalAudio:(BOOL) mute;

- (void)playMusic:(NSString *)url loopback:(BOOL) loopback times:(int)times;

- (void)stopMusic;

- (void)setMusicVolume:(float) volume;
@end
