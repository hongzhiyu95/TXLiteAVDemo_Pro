//
//  TRTCCloudBGMManagerCpp.m
//  TXLiteAVDemo_TRTC
//
//  Created by zanhanding on 2020/11/13.
//  Copyright © 2020 Tencent. All rights reserved.
//

#import "TRTCCloudBgmManagerCpp.h"
#import "cpp_interface/ITRTCCloud.h"

class MyMusicPlayObserver : public trtc::ITXMusicPlayObserver{
public:
    __weak TRTCCloudBgmManagerCpp *bgmManager;
    void(^progressNotify)(float progress);
    void(^completeNotify)();
    void onStart(int id,int errCode);
    void onPlayProgress(int id,long curPtsMS,long durationMS);
    void onComplete(int id,int errCode);
};

@interface TRTCCloudBgmManagerCpp()
@property (nonatomic) MyMusicPlayObserver *trtcBgmObserver;
@end

@implementation TRTCCloudBgmManagerCpp
{
    trtc::ITRTCCloud *trtcCloud;
    MyMusicPlayObserver *musicObserver;
    BOOL isPlaying;
    BOOL isOnPause;
    float progress;
    NSInteger progressInMs;
    NSInteger bgmVolume;
    NSInteger bgmPlayoutVolume;
    NSInteger bgmPublishVolume;
    float bgmPitch;
    float bgmSpeed;
    NSInteger micVolume;
    trtc::TXVoiceReverbType reverbType;
    int32_t bgmId;
}

- (instancetype)initWithTrtc:(TRTCCloud *)trtc {
    if (self = [super initWithTrtc:trtc]) {
        trtcCloud = getTRTCShareInstance();
        _trtcBgmObserver = nullptr;
        bgmVolume = 100;
        bgmPlayoutVolume = 100;
        bgmPublishVolume = 100;
        micVolume = 100;
        bgmSpeed = 1;
    }
    return self;
}

-(void)dealloc {
    if (_trtcBgmObserver) {
        trtcCloud->getAudioEffectManager()->setMusicObserver(bgmId, nullptr);
        delete _trtcBgmObserver;
        _trtcBgmObserver = nullptr;
    }
}

- (void)playBgm:(NSString *)path onProgress:(void (^ _Nullable)(float))progressNotify onCompleted:(void (^)(void))completeNotify {
    isPlaying = YES;
    TXAudioMusicParam *params = [[TXAudioMusicParam alloc] init];
    params.ID = bgmId;
    params.path = path;
    trtcCloud->getAudioEffectManager()->startPlayMusic(*transMusicParamToCpp(params));
    if (!_trtcBgmObserver) {
        _trtcBgmObserver = new MyMusicPlayObserver();
        _trtcBgmObserver->bgmManager = self;
        trtcCloud->getAudioEffectManager()->setMusicObserver(bgmId, _trtcBgmObserver);
    }
    _trtcBgmObserver->progressNotify = progressNotify;
    _trtcBgmObserver->completeNotify = completeNotify;
}

- (void)stopBgm {
    isPlaying = NO;
    trtcCloud->getAudioEffectManager()->stopPlayMusic(bgmId);
}

- (void)resumeBgm {
    isOnPause = NO;
    trtcCloud->getAudioEffectManager()->resumePlayMusic(bgmId);
}

- (void)pauseBgm {
    isOnPause = YES;
    trtcCloud->getAudioEffectManager()->pausePlayMusic(bgmId);
}

- (void)seekToTime:(double)timestamp {
    trtcCloud->getAudioEffectManager()->seekMusicToPosInTime(bgmId, timestamp);
}

- (BOOL)isBgmPlaying {
    return isPlaying;
}

- (BOOL)isBgmOnPause {
    return isOnPause;
}

- (NSInteger)getProgressInMs {
    return progressInMs;
}


- (NSInteger)getBgmDuration:(NSString *)path {
    return trtcCloud->getAudioEffectManager()->getMusicDurationInMS((char*)[path UTF8String]);
}

- (float)getProgress {
    return progress;
}

- (NSInteger)getBgmVolume {
    return bgmVolume;
}

- (NSInteger)getBgmPlayoutVolume {
    return bgmPlayoutVolume;
}

- (NSInteger)getBgmPublishVolume {
    return bgmPublishVolume;
}

- (NSInteger)getMicVolume {
    return micVolume;
}

- (float)getBgmPitch {
    return bgmPitch;
}


- (float)getBgmSpeed {
    return bgmSpeed;
}

- (TXVoiceReverbType)getReverb {
    return (TXVoiceReverbType)reverbType;
}

- (void)setBgmVolume:(NSInteger)volume {
    bgmVolume = volume;
    bgmPlayoutVolume = volume;
    bgmPublishVolume = volume;
    trtcCloud->getAudioEffectManager()->setMusicPublishVolume(bgmId, (int)volume);
    trtcCloud->getAudioEffectManager()->setMusicPlayoutVolume(bgmId, (int)volume);
}

- (void)setBgmPlayoutVolume:(NSInteger)volume {
    bgmPlayoutVolume = volume;
    trtcCloud->getAudioEffectManager()->setMusicPlayoutVolume(bgmId, (int)volume);
}

- (void)setBgmPublishVolume:(NSInteger)volume {
    bgmPublishVolume = volume;
    trtcCloud->getAudioEffectManager()->setMusicPublishVolume(bgmId, (int)volume);
}

- (void)setBgmPitch:(float)bgmPitch {
    bgmPitch = bgmPitch;
    trtcCloud->getAudioEffectManager()->setMusicPitch(bgmId, bgmPitch);
}

- (void)setBgmSpeed:(float)speed {
    bgmSpeed = speed;
    trtcCloud->getAudioEffectManager()->setMusicSpeedRate(bgmId, speed);
}

- (void)setMicVolume:(NSInteger)volume {
    micVolume = volume;
    trtcCloud->getAudioEffectManager()->setVoiceCaptureVolume((int)volume);
}

- (void)setReverb:(TXVoiceReverbType)reverb {
    reverbType = (trtc::TXVoiceReverbType)reverb;
    trtcCloud->getAudioEffectManager()->setVoiceReverbType(reverbType);
}

#pragma mark - Type Translate Funtions

std::shared_ptr<trtc::AudioMusicParam> transMusicParamToCpp(TXAudioMusicParam *param) {
    std::shared_ptr<trtc::AudioMusicParam> musicParam(new trtc::AudioMusicParam(param.ID, (char*)[param.path UTF8String]));
    musicParam->endTimeMS = param.endTimeMS;
    musicParam->isShortFile = param.isShortFile;
    musicParam->loopCount = (int)param.loopCount;
    musicParam->publish = param.publish;
    musicParam->startTimeMS = param.startTimeMS;
    return musicParam;
}

#pragma mark - C++ Callback implements

void MyMusicPlayObserver::onStart(int id,int errCode) {
    if (errCode != 0) {
        bgmManager->isPlaying = NO;
        completeNotify();
    }
}

void MyMusicPlayObserver::onPlayProgress(int id,long curPtsMS,long durationMS) {
    if (progressNotify) {
        progressNotify((float)curPtsMS/(float)durationMS);
    }
    bgmManager->progressInMs = curPtsMS;
    bgmManager->progress = (float)curPtsMS / (float)durationMS;
}

void MyMusicPlayObserver::onComplete(int id,int errCode) {
    bgmManager->isPlaying = NO;
    if (completeNotify) {
        completeNotify();
    }
}

@end
