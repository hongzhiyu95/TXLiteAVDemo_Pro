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

#import "TRTCCloudBgmManager.h"
#import "TXAudioEffectManager.h"

@interface TRTCCloudBgmManager()

@property (strong, nonatomic) TRTCCloud *trtc;
@property (strong, nonatomic) TXAudioEffectManager *audioEffectManager;

@property (nonatomic) BOOL isPlaying;
@property (nonatomic) BOOL isOnPause;
@property (nonatomic) float progress;
@property (nonatomic) NSInteger progressInMs;

@property (nonatomic) NSInteger bgmVolume;
@property (nonatomic) NSInteger bgmPlayoutVolume;
@property (nonatomic) NSInteger bgmPublishVolume;
@property (nonatomic) float bgmPitch;
@property (nonatomic) float bgmSpeed;
@property (nonatomic) NSInteger micVolume;
@property (nonatomic) TXVoiceReverbType reverb;
@property (nonatomic) TXVoiceChangeType voiceChanger;
@property (nonatomic) int32_t bgmId;

@end


@implementation TRTCCloudBgmManager

- (instancetype)initWithTrtc:(TRTCCloud *)trtc {
    if (self = [super init]) {
        _trtc = trtc;
        _audioEffectManager = [trtc getAudioEffectManager];
        _bgmVolume = 100;
        _bgmPlayoutVolume = 100;
        _bgmPublishVolume = 100;
        _micVolume = 100;
        _bgmSpeed = 1;
    }
    return self;
}

- (void)playBgm:(NSString *)path onProgress:(void (^ _Nullable)(float))progressNotify onCompleted:(void (^)(void))completeNotify {
    self.isPlaying = YES;
    
    __weak __typeof(self) wSelf = self;
    TXAudioMusicParam *params = [[TXAudioMusicParam alloc] init];
    params.ID = self.bgmId;
    params.path = path;
    [self.audioEffectManager startPlayMusic:params onStart:^(NSInteger errCode) {
        if (errCode != 0) {
            wSelf.isPlaying = NO;
            completeNotify();
        }
    } onProgress:^(NSInteger progressMS, NSInteger durationMS) {
        [wSelf handleProgressChange:progressMS duration:durationMS progressHandler:progressNotify];
    } onComplete:^(NSInteger errCode) {
        wSelf.isPlaying = NO;
        completeNotify();
    }];
}

- (void)stopBgm {
    self.isPlaying = NO;
    [self.audioEffectManager stopPlayMusic:self.bgmId];
}

- (void)resumeBgm {
    self.isOnPause = NO;
    [self.audioEffectManager resumePlayMusic:self.bgmId];
}

- (void)pauseBgm {
    self.isOnPause = YES;
    [self.audioEffectManager pausePlayMusic:self.bgmId];
}

- (void)seekToTime:(double)timestamp {
    [self.audioEffectManager seekMusicToPosInMS:self.bgmId pts:timestamp];
}

- (BOOL)isBgmPlaying {
    return _isPlaying;
}

- (BOOL)isBgmOnPause {
    return _isOnPause;
}

- (NSInteger)getProgressInMs {
    return _progressInMs;
}

- (NSInteger)getBgmDuration:(NSString *)path {
    return [self.audioEffectManager getMusicDurationInMS:path];
}

- (float)getProgress {
    return _progress;
}

- (NSInteger)getBgmVolume {
    return _bgmVolume;
}

- (NSInteger)getBgmPlayoutVolume {
    return _bgmPlayoutVolume;
}

- (NSInteger)getBgmPublishVolume {
    return _bgmPublishVolume;
}

- (NSInteger)getMicVolume {
    return _micVolume;
}

- (float)getBgmPitch {
    return _bgmPitch;
}


- (float)getBgmSpeed {
    return _bgmSpeed;
}

- (TXVoiceReverbType)getReverb {
    return _reverb;
}

- (TXVoiceChangeType)getVoiceChanger {
    return _voiceChanger;
}

- (void)setBgmVolume:(NSInteger)volume {
    _bgmVolume = volume;
    _bgmPlayoutVolume = volume;
    _bgmPublishVolume = volume;
    [self.audioEffectManager setMusicPublishVolume:self.bgmId volume:volume];
    [self.audioEffectManager setMusicPlayoutVolume:self.bgmId volume:volume];
}

- (void)setBgmPlayoutVolume:(NSInteger)volume {
    _bgmPlayoutVolume = volume;
    [self.audioEffectManager setMusicPlayoutVolume:self.bgmId volume:volume];
}

- (void)setBgmPublishVolume:(NSInteger)volume {
    _bgmPublishVolume = volume;
    [self.audioEffectManager setMusicPublishVolume:self.bgmId volume:volume];
}

- (void)setBgmPitch:(float)bgmPitch {
    _bgmPitch = bgmPitch;
    [self.audioEffectManager setMusicPitch:self.bgmId pitch:bgmPitch];
}

- (void)setBgmSpeed:(float)speed {
    _bgmSpeed = speed;
    [self.audioEffectManager setMusicSpeedRate:self.bgmId speedRate:speed];
}

- (void)setMicVolume:(NSInteger)volume {
    _micVolume = volume;
    [self.audioEffectManager setVoiceVolume:volume];
}

- (void)setReverb:(TXVoiceReverbType)reverb {
    _reverb = reverb;
    [self.audioEffectManager setVoiceReverbType:reverb];
}

- (void)setVoiceChanger:(TXVoiceChangeType)voiceChanger {
    _voiceChanger = voiceChanger;
    [self.audioEffectManager setVoiceChangerType:voiceChanger];
}

#pragma mark - Private

- (void)handleProgressChange:(NSInteger)progressMS
                    duration:(NSInteger)durationMS
             progressHandler:(void (^ _Nullable)(float))handler {
    self.progressInMs = [self.audioEffectManager getMusicCurrentPosInMS:self.bgmId];
    self.progress = (float)progressMS / durationMS;
    if (handler) { handler(self.progress); }
}

@end
