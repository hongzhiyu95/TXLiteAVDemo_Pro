/*
* Module:   TRTCCloudBgmManager
*
* Function: TRTC SDK的BGM和声音处理功能调用
*
*    1. BGM包括播放、暂停、继续和停止。注意每次调用playBgm时，BGM都会重头开始播放。
*
*    2. 声音的处理包括混响和变声，支持的类型分别定义在 TXVoiceReverbType 和 TXVoiceChangeType 中。
*
*/

#import <Foundation/Foundation.h>
#import "TRTCCloud.h"
#import "TRTCCloudDef.h"
#import "TXAudioEffectManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface TRTCCloudBgmManager : NSObject

- (instancetype)initWithTrtc:(TRTCCloud *)trtc NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// 开始播放BGM
/// @param path Bgm文件位置，可以是本地文件地址，也可以是网络地址
/// @param progressNotify 播放进度回调，取值范围为0.0 - 1.0
- (void)playBgm:(NSString *)path onProgress:(void (^ _Nullable)(float))progressNotify onCompleted:(void (^)(void))completeNotify;

/// 停止播放
- (void)stopBgm;

/// 继续播放
- (void)resumeBgm;

/// 暂停播放
- (void)pauseBgm;

/// 设置播放位置
/// @param timestamp Bgm 的播放位置，时间单位为ms
- (void)seekToTime:(double)timestamp;

/// 当前Bgm是否在播放
- (BOOL)isBgmPlaying;

/// 当前Bgm是否为暂停状态
- (BOOL)isBgmOnPause;

/// 获取当前Bgm 进度（毫秒数）
- (NSInteger)getProgressInMs;

/// 获取 Bgm 总时长
- (NSInteger)getBgmDuration:(NSString *)path;

/// 获取当前Bgm进度（比例）
- (float)getProgress;

/// 获取 Bgm音量
- (NSInteger)getBgmVolume;

/// 获取 Bgm播放音量
- (NSInteger)getBgmPlayoutVolume;

/// 获取 Bgm推流音量
- (NSInteger)getBgmPublishVolume;

/// 获取 Mic音量
- (NSInteger)getMicVolume;

/// 获取当前Bgm音调
- (float)getBgmPitch;

/// 获取当前Bgm速率
- (float)getBgmSpeed;

/// 获取当前混响类型
- (TXVoiceReverbType)getReverb;

/// 获取当前变声类型
- (TXVoiceChangeType)getVoiceChanger;

/// 设置Bgm音量大小
/// @note 会将PlayoutVolume和PublishVolume统一设置为volume
/// @param volume Bgm音量，取值范围为0 - 100
- (void)setBgmVolume:(NSInteger)volume;

/// 设置Bgm本地播放的音量
/// @param volume Bgm本地播放音量，取值范围为0 - 100
- (void)setBgmPlayoutVolume:(NSInteger)volume;

/// 设置Bgm远端播放的音量
/// @param volume Bgm远端播放音量，取值范围为0 - 100
- (void)setBgmPublishVolume:(NSInteger)volume;

/// 设置Bgm的音调
/// @param bgmPitch Bgm音调，取值范围为-1.0 - 1.0，默认值为0
- (void)setBgmPitch:(float)bgmPitch;

/// 设置Bgm的速率
/// @param speed Bgm速率，取值范围为0.5 - 2.0，默认值为1.0
- (void)setBgmSpeed:(float)speed;

/// 设置混音时麦克风音量大小
/// @param volume 麦克风音量，取值范围为0 - 100
- (void)setMicVolume:(NSInteger)volume;

/// 设置混响类型
/// @param reverb 混响类型，详见 TXVoiceReverbType
- (void)setReverb:(TXVoiceReverbType)reverb;

/// 设置变声类型
/// @param voiceChanger 变声类型，详见 TRTCVoiceChangerType
- (void)setVoiceChanger:(TXVoiceChangeType)voiceChanger;

@end

NS_ASSUME_NONNULL_END
