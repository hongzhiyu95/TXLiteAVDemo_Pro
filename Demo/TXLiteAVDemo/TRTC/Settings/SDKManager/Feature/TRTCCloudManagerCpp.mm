/*
* Module:   TRTCCloudManagerCpp
*
* Function: TRTC SDK的视频、音频以及消息功能（调用C++接口），TRTCCloudManagerCpp是TRTCCloudManager的子类，
* 主要是用于测试C++全平台接口，Demo层对TRTCCloud实例的引用应当全部收敛到TRTCCloudManager中，这样可以通过
* TRTCCloudManagerCpp统一替换Demo对TRTCCloud的调用
*
*    1. 视频功能包括摄像头的设置，视频编码的设置和视频流的设置
*
*    2. 音频功能包括采集端的设置（采集开关、增益、降噪、耳返、采样率），以及播放端的设置（音频通道、音量类型、音量提示）
*
*    3. 消息发送有两种：自定义消息和SEI消息，具体适用场景和限制可参照TRTCCloud.h中sendCustomCmdMsg和sendSEIMsg的接口注释
*/

#import "cpp_interface/ITRTCCloud.h"
#import "TRTCCloudManagerCpp.h"
#import "TRTCCloudDef.h"
#import "TRTCStatistics.h"
#import "NSString+Common.h"
#import "CustomAudioFileReader.h"
#import "TestSendCustomVideoData.h"
#import "TestRenderVideoFrame.h"
#import "TRTCCustomerCrypt.h"
#include <map>
#include <string>

#define PLACE_HOLDER_LOCAL_MAIN   @"$PLACE_HOLDER_LOCAL_MAIN$"
#define PLACE_HOLDER_LOCAL_SUB   @"$PLACE_HOLDER_LOCAL_SUB$"
#define PLACE_HOLDER_REMOTE     @"$PLACE_HOLDER_REMOTE$"
#define SUBCLOUD_GUARD     if (!subCloud) {\
NSLog(@"subCloud实例已销毁");\
return;\
}
#if DEBUG
#define APPGROUP @"group.com.tencent.liteav.RPLiveStreamShare"
#else
#define APPGROUP @"group.com.tencent.liteav.RPLiveStreamRelease" // App Store Group
#endif

class MyTRTCCoudCallBack : public trtc::ITRTCCloudCallback{
    void onError(TXLiteAVError errCode, const char *errMsg, void *extraInfo);
    void onWarning(TXLiteAVWarning warningCode, const char *warningMsg, void *extraInfo);
    void onEnterRoom(int result);
    void onExitRoom(int reason);
    void onSwitchRole(TXLiteAVError errCode, const char* errMsg);
    void onConnectOtherRoom(const char* userId, TXLiteAVError errCode, const char* errMsg);
    void onSwitchRoom(TXLiteAVError errCode, const char* errMsg);
    void onRemoteUserEnterRoom(const char* userId);
    void onRemoteUserLeaveRoom(const char* userId, int reason);
    void onUserVideoAvailable(const char* userId, bool available);
    void onUserSubStreamAvailable(const char* userId, bool available);
    void onUserAudioAvailable(const char* userId, bool available);
    void onFirstVideoFrame(const char* userId, const trtc::TRTCVideoStreamType streamType, const int width, const int height);
    void onNetworkQuality(trtc::TRTCQualityInfo localQuality, trtc::TRTCQualityInfo* remoteQuality, uint32_t remoteQualityCount);
    void onStatistics(const trtc::TRTCStatistics& statis);
    void onUserVoiceVolume(trtc::TRTCVolumeInfo* userVolumes, uint32_t userVolumesCount, uint32_t totalVolume);
    void onRecvCustomCmdMsg(const char* userId, int32_t cmdID, uint32_t seq, const uint8_t* message, uint32_t messageSize);
    void onMissCustomCmdMsg(const char* userId, int32_t cmdID, int32_t errCode, int32_t missed);
    void onRecvSEIMsg(const char* userId, const uint8_t* message, uint32_t messageSize);
};

class MyTRTCSubCoudCallBack : public trtc::ITRTCCloudCallback{
    std::string subRoomId;
    __weak TRTCCloudManagerCpp *weakManager;
public:
    MyTRTCSubCoudCallBack(std::string roomId, TRTCCloudManagerCpp* manager);
    void onError(TXLiteAVError errCode, const char *errMsg, void *extraInfo);
    void onWarning(TXLiteAVWarning warningCode, const char *warningMsg, void *extraInfo);
    void onEnterRoom(int result);
    void onExitRoom(int reason);
    void onUserAudioAvailable(const char* userId, bool available);
    void onUserVideoAvailable(const char* userId, bool available);
    void onRemoteUserEnterRoom(const char* userId);
    void onRemoteUserLeaveRoom(const char* userId, int reason);
};

class MyAudioCallBack : public trtc::ITRTCAudioFrameCallback {
    void onCapturedAudioFrame(trtc::TRTCAudioFrame *frame);
    void onMixedPlayAudioFrame(trtc::TRTCAudioFrame *frame);
};

class MyLocalVideoCallBack : public trtc::ITRTCVideoRenderCallback {
    void onRenderVideoFrame(const char* userId, trtc::TRTCVideoStreamType streamType, trtc::TRTCVideoFrame* frame);
};

class MyRemoteVideoCallBack : public trtc::ITRTCVideoRenderCallback {
    void onRenderVideoFrame(const char* userId, trtc::TRTCVideoStreamType streamType, trtc::TRTCVideoFrame* frame);
};

@interface TRTCCloudManagerCpp()<CustomAudioFileReaderDelegate>
@property (nonatomic) BOOL isCrossingRoom;

@property (nonatomic) NSInteger appId;
@property (nonatomic) NSInteger bizId;

// 视频文件播放
@property (strong, nonatomic) TestSendCustomVideoData *videoCaptureTester;

@property (nonatomic) trtc::TRTCRenderParams localRenderParams;
@property (nonatomic) trtc::TRTCRenderParams remoteRenderParams;
@property (nonatomic) trtc::TRTCRenderParams remoteSubRenderParams;
@property (nonatomic) TRTCAudioQuality localAudioQuality;
@property (nonatomic) MyTRTCCoudCallBack *trtcCloudCallBack;
@property (nonatomic) MyAudioCallBack *trtcAudioCallBack;
@property (nonatomic) MyLocalVideoCallBack *trtcLocalVideoCallBack;
@property (atomic) std::map<std::string, MyRemoteVideoCallBack *> trtcRemoteVideoCallBackMap;
@property (atomic) std::map<std::string, trtc::ITRTCCloud *> subClouds;
@property (atomic) std::map<std::string, trtc::ITRTCCloudCallback *> subCallbacks;
@end

@implementation TRTCCloudManagerCpp {
    UIView *localVideoView;
    TestRenderVideoFrame *renderTester;
}

@synthesize isCrossingRoom = _isCrossingRoom;
trtc::ITRTCCloud* trtcCloud = nullptr;
id<TRTCCloudDelegate> trtcDelegate;
id<TRTCAudioFrameDelegate> trtcAudioDelegate;
id<TRTCVideoRenderDelegate> trtcLocalVideoDelegate;
NSMutableDictionary<NSString *, id<TRTCVideoRenderDelegate>> *remoteVideoDelegateDic;

- (instancetype)initWithParams:(TRTCParams *)params
                       scene:(TRTCAppScene)scene
                       appId:(NSInteger)appId
                       bizId:(NSInteger)bizId {
    if (self = [super initWithParams:params
                             scene:scene
                             appId:appId
                             bizId:bizId]) {
        if (trtcCloud) {
            trtc::ITRTCCloud::destroyTRTCShareInstance();
        }
        trtcCloud = trtc::ITRTCCloud::getTRTCShareInstance();
        self.bizId = bizId;
        self.appId = appId;
        self.params = params;
        self.scene = scene;
        renderTester = [[TestRenderVideoFrame alloc] init];
        remoteVideoDelegateDic = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (void)setupTrtc {
    [self setupTrtcVideo];
    [self setupTrtcAudio];
}

-(void)dealloc
{
    if (_trtcCloudCallBack) {
        trtcCloud->removeCallback(_trtcCloudCallBack);
        delete _trtcCloudCallBack;
        _trtcCloudCallBack = nullptr;
    }
    if (_trtcAudioCallBack) {
        trtcCloud->setAudioFrameCallback(nullptr);
        delete _trtcAudioCallBack;
        _trtcAudioCallBack = nullptr;
    }
    //这里不能置为nil，因为它是个全局变量，其它TRTCCloudManagerCpp实例的释放会影响它
    [remoteVideoDelegateDic removeAllObjects];
    
    //在销毁TRTCCloudManager的时候才销毁subClouds
    for (auto iter = _subClouds.begin();iter != _subClouds.end(); iter++){
        trtcCloud->destroySubCloud(iter->second);
    }
}

#pragma mark - Room

- (void)enterRoom {
    [self setupTrtc];
    [self startLocalVideo];
    trtcCloud->enterRoom(*transTrtcParamToCpp(self.params), (trtc::TRTCAppScene)self.scene);
    if (self.params.role == TRTCRoleAnchor) {
        self.currentPublishingRoomId = self.params.roomId ? [@(self.params.roomId) stringValue] : self.params.strRoomId;
    }
    [self startLocalAudio];
}

- (void)enterSubRoom:(TRTCParams *)params {
    trtc::ITRTCCloud *subCloud = trtcCloud->createSubCloud();
    //不论是字符串房间号还是数字房间号，在这里都用字符串做主键；因此同时进入数值与字符串相同的两个房间会出问题
    NSString *stringRoomId = params.roomId ? [@(params.roomId) stringValue] : params.strRoomId;
    _subClouds[[stringRoomId UTF8String]] = subCloud;
    MyTRTCSubCoudCallBack *subCallback = new MyTRTCSubCoudCallBack([stringRoomId UTF8String], self);
    subCloud->addCallback(subCallback);
    _subCallbacks[[stringRoomId UTF8String]] = subCallback;
    //进入子房间
    subCloud->enterRoom(*transTrtcParamToCpp(params), (trtc::TRTCAppScene)self.scene);
}

- (void)exitSubRoom:(NSString *)roomId {
    //不论是字符串房间号还是数字房间号，在这里都用字符串做主键；因此同时进入数值与字符串相同的两个房间会出问题
    trtc::ITRTCCloud *subCloud = _subClouds[[roomId UTF8String]];
    SUBCLOUD_GUARD
    subCloud->exitRoom();
    //这里不调用destroySubCloud，否则会导致UI层收不到onExitRoom
}

- (void)exitAllSubRoom {
    for (auto iter = _subClouds.begin();iter != _subClouds.end(); iter++){
        if (iter->second) {
            iter->second->exitRoom();
        }
    }
}

- (void)switchRoom:(TRTCSwitchRoomConfig *)switchRoomConfig {
    if ([self.currentPublishingRoomId isEqualToString:self.params.roomId ? [@(self.params.roomId) stringValue] : self.params.strRoomId]) {
        //若之前正在主房间中推流，则更新推流房间为新的房间号
        self.currentPublishingRoomId = switchRoomConfig.roomId ? [@(switchRoomConfig.roomId) stringValue] : switchRoomConfig.strRoomId;
    }
    self.params.roomId = switchRoomConfig.roomId;
    self.params.strRoomId = switchRoomConfig.strRoomId;
    if (switchRoomConfig.userSig) {
        self.params.userSig = switchRoomConfig.userSig;
    }
    if (switchRoomConfig.privateMapKey) {
        self.params.privateMapKey = switchRoomConfig.privateMapKey;
    }
    trtcCloud->switchRoom(*transSwitchRoomConfigToCpp(switchRoomConfig));
}

- (void)exitRoom {
    [self stopLocalAudio];
    [self stopLocalVideo];
    trtcCloud->exitRoom();
}

- (void)setRole:(TRTCRoleType)role {
    if (role==TRTCRoleAnchor) {
        self.currentPublishingRoomId = self.params.roomId ? [@(self.params.roomId) stringValue] : self.params.strRoomId;
    }
    self.params.role = role;
    trtcCloud->switchRole((trtc::TRTCRoleType)role);
    
    if (role == TRTCRoleAnchor) {
        [self startLocalAudio];
        [self startLocalVideo];
    } else {
        [self stopLocalAudio];
        [self stopLocalVideo];
    }
}

- (void)switchRole:(TRTCRoleType)role {
    self.params.role = role;
    if (role==TRTCRoleAnchor) {
        self.currentPublishingRoomId = self.params.roomId ? [@(self.params.roomId) stringValue] : self.params.strRoomId;
    }
    trtcCloud->switchRole((trtc::TRTCRoleType)role);
}

- (void)switchSubRoomRole:(TRTCRoleType)role roomId:(NSString *)roomId {
    if (role==TRTCRoleAnchor) {
        self.currentPublishingRoomId = roomId;
    }
    trtc::ITRTCCloud *subCloud = _subClouds[[roomId UTF8String]];
    SUBCLOUD_GUARD
    subCloud->switchRole((trtc::TRTCRoleType)role);
}

- (void)setupTrtcVideo {
    trtcCloud->setVideoEncoderParam(*transVideoEncParamToCpp(self.videoConfig.videoEncConfig));
    trtcCloud->enableSmallVideoStream(self.videoConfig.isSmallVideoEnabled, *transVideoEncParamToCpp(self.videoConfig.smallVideoEncConfig));
    trtcCloud->setNetworkQosParam(*transQosParamToCpp(self.videoConfig.qosConfig));
    trtc::TRTCRenderParams renderParams = trtc::TRTCRenderParams();
    renderParams.fillMode = (trtc::TRTCVideoFillMode)self.videoConfig.localRenderParams.fillMode;
    renderParams.mirrorType = (trtc::TRTCVideoMirrorType)self.videoConfig.localRenderParams.mirrorType;
    trtcCloud->setLocalRenderParams(renderParams);
    trtcCloud->setVideoEncoderMirror(self.videoConfig.isRemoteMirrorEnabled);
    // TODO TRTCCloud C++ 全平台接口暂不支持 setGSensorMode
//    [self.trtc setGSensorMode:self.videoConfig.isGSensorEnabled ?
//        TRTCGSensorMode_UIAutoLayout :
//        TRTCGSensorMode_Disable];
}

- (void)setupTrtcAudio {
    trtcCloud->getDeviceManager()->setAudioRoute((trtc::TXAudioRoute)self.audioConfig.route);
    // TODO TRTCCloud C++ 全平台接口暂不支持 enableAudioEarMonitoring
//    [self.trtc enableAudioEarMonitoring:self.audioConfig.isEarMonitoringEnabled];
    trtcCloud->enableAudioVolumeEvaluation(self.audioConfig.isVolumeEvaluationEnabled ? 300 : 0);
}

#pragma mark - Set Delegate

- (void)setTRTCDelegate:(id<TRTCCloudDelegate>)delegate {
    trtcDelegate = delegate;
    if (delegate) {
        if (!_trtcCloudCallBack) {
            _trtcCloudCallBack = new MyTRTCCoudCallBack();
            trtcCloud->addCallback(_trtcCloudCallBack);
        }
    } else if (_trtcCloudCallBack) {
        //确保在demo层释放之前，先removeCallback
        trtcCloud->removeCallback(_trtcCloudCallBack);
        delete _trtcCloudCallBack;
        _trtcCloudCallBack = nullptr;
    }
}

- (void)setAudioFrameDelegate:(id<TRTCAudioFrameDelegate>)delegate {
    trtcAudioDelegate = delegate;
    if (delegate) {
        if (!_trtcAudioCallBack) {
            _trtcAudioCallBack = new MyAudioCallBack();
            trtcCloud->setAudioFrameCallback(_trtcAudioCallBack);
        }
    } else if (_trtcAudioCallBack) {
        //确保在demo层释放之前，先setAudioFrameCallback(nullptr)
        trtcCloud->setAudioFrameCallback(nullptr);
        delete _trtcAudioCallBack;
        _trtcAudioCallBack = nullptr;
    }
}

- (int)setLocalVideoRenderDelegate:(id<TRTCVideoRenderDelegate>)delegate pixelFormat:(TRTCVideoPixelFormat)pixelFormat bufferType:(TRTCVideoBufferType)bufferType {
    trtcLocalVideoDelegate = delegate;
    int result = 0;
    if (delegate) {
        if (!_trtcLocalVideoCallBack) {
            _trtcLocalVideoCallBack = new MyLocalVideoCallBack();
            result = trtcCloud->setLocalVideoRenderCallback(trtc::TRTCVideoPixelFormat_BGRA32, (trtc::TRTCVideoBufferType)bufferType, self.trtcLocalVideoCallBack);
        }
    } else if (_trtcLocalVideoCallBack) {
        //确保在demo层释放之前，先setLocalVideoRenderCallback(nullptr)
        result = trtcCloud->setLocalVideoRenderCallback(trtc::TRTCVideoPixelFormat_BGRA32, (trtc::TRTCVideoBufferType)bufferType, nullptr);
        delete _trtcLocalVideoCallBack;
        _trtcLocalVideoCallBack = nullptr;
    }
    return result;
}

- (int)setRemoteVideoRenderDelegate:(NSString*)userId delegate:(id<TRTCVideoRenderDelegate>)delegate pixelFormat:(TRTCVideoPixelFormat)pixelFormat bufferType:(TRTCVideoBufferType)bufferType{
    int result = 0;
    [remoteVideoDelegateDic setValue:delegate forKey:userId];
    std::string key = [userId UTF8String];
    auto it = _trtcRemoteVideoCallBackMap.find(key);
    if (delegate) {
        if (it != _trtcRemoteVideoCallBackMap.end() && it->second) {
            //若之前存在旧的监听类，现在需要释放
            free(it->second);
            it->second = nullptr;
        }
            _trtcRemoteVideoCallBackMap[key] = new MyRemoteVideoCallBack();
            result = trtcCloud->setRemoteVideoRenderCallback(key.c_str(), trtc::TRTCVideoPixelFormat_BGRA32, (trtc::TRTCVideoBufferType)bufferType, _trtcRemoteVideoCallBackMap[key]);
    } else if (it != _trtcRemoteVideoCallBackMap.end()&&it->second) {
        //确保在demo层释放之前，先setRemoteVideoRenderCallback(nullptr)
        result = trtcCloud->setRemoteVideoRenderCallback(key.c_str(), trtc::TRTCVideoPixelFormat_BGRA32, (trtc::TRTCVideoBufferType)bufferType, nullptr);
        delete _trtcRemoteVideoCallBackMap[key];
            _trtcRemoteVideoCallBackMap.erase(key);
    }
    return result;
}

+ (void)setLogDelegate:(id<TRTCLogDelegate>)logDelegate {
    // 这里依然设置原生回调，因为外层传入的是原生的TRTCLogDelegate
    [TRTCCloud setLogDelegate:logDelegate];
}

#pragma mark - Video Functions

- (void)setVideoSource:(TRTCVideoSource)source {
    self.videoConfig.source = source;
}

- (void)setVideoEnabled:(BOOL)isEnabled {
    self.videoConfig.isEnabled = isEnabled;

    if (isEnabled) {
        [self startLocalVideo];
    } else {
        [self stopLocalVideo];
    }
}

- (void)setVideoMuted:(BOOL)isMuted {
    self.videoConfig.isMuted = isMuted;
    trtcCloud->muteLocalVideo(isMuted);
}

- (void)setResolution:(TRTCVideoResolution)resolution {
    self.videoConfig.videoEncConfig.videoResolution = resolution;
    trtcCloud->setVideoEncoderParam(*transVideoEncParamToCpp(self.videoConfig.videoEncConfig));
}

- (void)setVideoFps:(int)fps {
    self.videoConfig.videoEncConfig.videoFps = fps;
    trtcCloud->setVideoEncoderParam(*transVideoEncParamToCpp(self.videoConfig.videoEncConfig));
    
    self.videoConfig.smallVideoEncConfig.videoFps = fps;
    trtcCloud->enableSmallVideoStream(self.videoConfig.isSmallVideoEnabled, *transVideoEncParamToCpp(self.videoConfig.smallVideoEncConfig));
}

- (void)setVideoBitrate:(int)bitrate {
    self.videoConfig.videoEncConfig.videoBitrate = bitrate;
    trtcCloud->setVideoEncoderParam(*transVideoEncParamToCpp(self.videoConfig.videoEncConfig));
}

- (void)setQosPreference:(TRTCVideoQosPreference)preference {
    self.videoConfig.qosConfig.preference = preference;
    trtcCloud->setNetworkQosParam(*transQosParamToCpp(self.videoConfig.qosConfig));
}

- (void)setResolutionMode:(TRTCVideoResolutionMode)mode {
    self.videoConfig.videoEncConfig.resMode = mode;
    trtcCloud->setVideoEncoderParam(*transVideoEncParamToCpp(self.videoConfig.videoEncConfig));
    
    self.videoConfig.smallVideoEncConfig.resMode = mode;
    trtcCloud->enableSmallVideoStream(self.videoConfig.isSmallVideoEnabled, *transVideoEncParamToCpp(self.videoConfig.smallVideoEncConfig));
}

- (void)setVideoFillMode:(TRTCVideoFillMode)mode {
    self.videoConfig.localRenderParams.fillMode = mode;
    trtc::TRTCRenderParams params = trtc::TRTCRenderParams();
    params.fillMode = (trtc::TRTCVideoFillMode)self.videoConfig.localRenderParams.fillMode;
    params.mirrorType = (trtc::TRTCVideoMirrorType)self.videoConfig.localRenderParams.mirrorType;
    trtcCloud->setLocalRenderParams(params);
}

- (void)setLocalMirrorType:(TRTCLocalVideoMirrorType)type {
    self.videoConfig.localRenderParams.mirrorType = (TRTCVideoMirrorType)type;
    trtc::TRTCRenderParams params = trtc::TRTCRenderParams();
    params.fillMode = (trtc::TRTCVideoFillMode)self.videoConfig.localRenderParams.fillMode;
    params.mirrorType = (trtc::TRTCVideoMirrorType)self.videoConfig.localRenderParams.mirrorType;
    trtcCloud->setLocalRenderParams(params);
}

- (void)setRemoteMirrorEnabled:(BOOL)isEnabled {
    self.videoConfig.isRemoteMirrorEnabled = isEnabled;
    trtcCloud->setVideoEncoderMirror(isEnabled);
}

- (void)setWaterMark:(UIImage *)image inRect:(CGRect)rect {
    NSData *imageData =  UIImagePNGRepresentation(image);
    const char *data = (const char *)imageData.bytes;
    trtcCloud->setWaterMark(trtc::TRTCVideoStreamTypeBig, data, trtc::TRTCWaterMarkSrcTypeRGBA32, image.size.width, image.size.height, rect.origin.x, rect.origin.y, rect.size.width);
    trtcCloud->setWaterMark(trtc::TRTCVideoStreamTypeSub, data, trtc::TRTCWaterMarkSrcTypeRGBA32, image.size.width, image.size.height, rect.origin.x, rect.origin.y, rect.size.width);
}

- (void)switchCamera {
    self.videoConfig.isFrontCamera = !self.videoConfig.isFrontCamera;
    self.videoConfig.isTorchOn = NO;
    trtcCloud->getDeviceManager()->switchCamera(self.videoConfig.isFrontCamera);
}

- (void)switchTorch {
    self.videoConfig.isTorchOn = !self.videoConfig.isTorchOn;
    trtcCloud->getDeviceManager()->enableCameraTorch(self.videoConfig.isTorchOn);
}

- (void)setAutoFocusEnabled:(BOOL)isEnabled {
    self.videoConfig.isAutoFocusOn = isEnabled;
    trtcCloud->getDeviceManager()->enableCameraAutoFocus(isEnabled);
}

- (void)setQosControlMode:(TRTCQosControlMode)mode {
    self.videoConfig.qosConfig.controlMode = mode;
    trtcCloud->setNetworkQosParam(*transQosParamToCpp(self.videoConfig.qosConfig));
}

- (void)setSmallVideoEnabled:(BOOL)isEnabled {
    self.videoConfig.isSmallVideoEnabled = isEnabled;
    transVideoEncParamToCpp(self.videoConfig.smallVideoEncConfig);
    trtcCloud->enableSmallVideoStream(isEnabled, *transVideoEncParamToCpp(self.videoConfig.smallVideoEncConfig));
}

- (void)startRemoteView:(NSString *)userId streamType:(TRTCVideoStreamType)type view:(TXView *)view {
    trtcCloud->startRemoteView([userId UTF8String], (trtc::TRTCVideoStreamType)type, (__bridge void*)view);
}

- (void)startSubRoomRemoteView:(NSString *)userId roomId:(NSString *)roomId streamType:(TRTCVideoStreamType)type view:(TXView *)view {
    trtc::ITRTCCloud *subCloud = _subClouds[[roomId UTF8String]];
    SUBCLOUD_GUARD
    subCloud->startRemoteView([userId UTF8String], (trtc::TRTCVideoStreamType)type, (__bridge void*)view);
}

- (void)updateRemoteView:(TXView *)view streamType:(TRTCVideoStreamType)type forUser:(NSString *)userId {
    trtcCloud->updateRemoteView([userId UTF8String], (trtc::TRTCVideoStreamType)type, (__bridge void*)view);
}
- (void)updateSubRoomRemoteView:(TXView *)view roomId:(NSString *)roomId streamType:(TRTCVideoStreamType)type forUser:(NSString *)userId {
    trtc::ITRTCCloud *subCloud = _subClouds[[roomId UTF8String]];
    SUBCLOUD_GUARD
    subCloud->updateRemoteView([userId UTF8String], (trtc::TRTCVideoStreamType)type, (__bridge void*)view);
}

- (void)stopSubRoomRemoteView:(NSString *)userId roomId:(NSString *)roomId streamType:(TRTCVideoStreamType)type {
    trtc::ITRTCCloud *subCloud = _subClouds[[roomId UTF8String]];
    SUBCLOUD_GUARD
    subCloud->stopRemoteView([userId UTF8String], (trtc::TRTCVideoStreamType)type);
}

- (void)stopRemoteView:(NSString *)userId streamType:(TRTCVideoStreamType)type {
    trtcCloud->stopRemoteView([userId UTF8String], (trtc::TRTCVideoStreamType)type);
}

- (void)stopAllRemoteView {
    trtcCloud->stopAllRemoteView();
}

- (void)setRemoteViewFillMode:(NSString*)userId mode:(TRTCVideoFillMode)mode {
    _remoteRenderParams.fillMode = (trtc::TRTCVideoFillMode)mode;
    trtcCloud->setRemoteRenderParams([userId UTF8String], trtc::TRTCVideoStreamTypeBig, _remoteRenderParams);
}

- (void)setRemoteViewRotation:(NSString*)userId rotation:(TRTCVideoRotation)rotation {
    _remoteRenderParams.rotation = (trtc::TRTCVideoRotation)rotation;
    trtcCloud->setRemoteRenderParams([userId UTF8String], trtc::TRTCVideoStreamTypeBig, _remoteRenderParams);
}

- (void)startRemoteSubStreamView:(NSString *)userId view:(TXView *)view {
    trtcCloud->startRemoteView([userId UTF8String], trtc::TRTCVideoStreamTypeSub, (__bridge void*)view);
}

- (void)stopRemoteSubStreamView:(NSString *)userId {
    trtcCloud->stopRemoteView([userId UTF8String], trtc::TRTCVideoStreamTypeSub);
}

- (void)setLocalViewFillMode:(TRTCVideoFillMode)mode {
    _localRenderParams.fillMode = (trtc::TRTCVideoFillMode)mode;
    trtcCloud->setLocalRenderParams(_localRenderParams);
}

- (void)setLocalViewRotation:(TRTCVideoRotation)rotation {
    _localRenderParams.rotation = (trtc::TRTCVideoRotation)rotation;
    trtcCloud->setLocalRenderParams(_localRenderParams);
}

#if TARGET_OS_IPHONE
- (void)setLocalViewMirror:(TRTCLocalVideoMirrorType)mirror {
    _localRenderParams.mirrorType = (trtc::TRTCVideoMirrorType)mirror;
    trtcCloud->setLocalRenderParams(_localRenderParams);
}
#elif TARGET_OS_MAC
- (void)setLocalViewMirror:(BOOL)mirror {
    _localRenderParams.mirrorType = mirror ? trtc::TRTCVideoMirrorType_Enable : trtc::TRTCVideoMirrorType_Disable;
    trtcCloud->setLocalRenderParams(_localRenderParams);
}
#endif

- (void)setRemoteSubStreamViewFillMode:(NSString *)userId mode:(TRTCVideoFillMode)mode {
    _remoteSubRenderParams.fillMode = (trtc::TRTCVideoFillMode)mode;
    trtcCloud->setRemoteRenderParams([userId UTF8String], trtc::TRTCVideoStreamTypeSub, _remoteSubRenderParams);
}

- (void)setLocalVideoView:(UIView *)videoView {
    localVideoView = videoView;
    if (renderTester) {
        [renderTester addUser:nil videoView:localVideoView];
    }
}

- (void)updateCustomRenderView:(UIImageView *)videoView forUser:(NSString *)userId
{
    if (renderTester) {
        [renderTester addUser:userId videoView:videoView];
    }
}

- (void)updateLocalView:(UIView *)videoView {
    trtcCloud->updateLocalView((__bridge void*)videoView);
}

- (void)setCustomVideo:(AVAsset *)videoAsset {
    self.videoConfig.videoAsset = videoAsset;
}

- (void)pushVideoStreamInSubRoom:(NSString *)roomId push:(BOOL)isPush
{
    self.videoConfig.isMuted = !isPush;
    trtc::ITRTCCloud *subCloud = _subClouds[[roomId UTF8String]];
    SUBCLOUD_GUARD
    subCloud->muteLocalVideo(!isPush);
}

#pragma mark - Audio Functions

- (void)setAudioEnabled:(BOOL)isEnabled {
    self.audioConfig.isEnabled = isEnabled;
    if (isEnabled) {
        [self startLocalAudio];
    } else {
        [self stopLocalAudio];
    }
}

- (void)setAudioQuality:(TRTCAudioQuality)quality {
    _localAudioQuality = quality;
}

- (void)setAudioCustomCaptureEnabled:(BOOL)isEnabled {
    self.audioConfig.isCustomCapture = isEnabled;
}

- (void)setAudioRoute:(TRTCAudioRoute)route {
    self.audioConfig.route = route;
    trtcCloud->getDeviceManager()->setAudioRoute((trtc::TXAudioRoute)route);
}

- (void)setVolumeType:(TRTCSystemVolumeType)type {
    trtcCloud->getDeviceManager()->setSystemVolumeType((trtc::TXSystemVolumeType)type);
}

- (void)setAecEnabled:(BOOL)isEnabled {
    self.audioConfig.isAecEnabled = isEnabled;
    if (isEnabled) {
        trtcCloud->callExperimentalAPI("{\
                                       \"api\":\"enableAudioAEC\",\
                                       \"params\":{\
                                            \"enable\":1\
                                            }\
                                       }");
    } else {
        trtcCloud->callExperimentalAPI("{\
                                       \"api\":\"enableAudioAEC\",\
                                       \"params\":{\
                                            \"enable\":0\
                                            }\
                                       }");
    }
}

- (void)setAgcEnabled:(BOOL)isEnabled {
    self.audioConfig.isAgcEnabled = isEnabled;
    if (isEnabled) {
        trtcCloud->callExperimentalAPI("{\
                                       \"api\":\"enableAudioAGC\",\
                                       \"params\":{\
                                            \"enable\":1\
                                            }\
                                       }");
    } else {
        trtcCloud->callExperimentalAPI("{\
                                       \"api\":\"enableAudioAGC\",\
                                       \"params\":{\
                                            \"enable\":0\
                                            }\
                                       }");
    }
}

- (void)setAnsEnabled:(BOOL)isEnabled {
    self.audioConfig.isAnsEnabled = isEnabled;
    if (isEnabled) {
        trtcCloud->callExperimentalAPI("{\
                                       \"api\":\"enableAudioANS\",\
                                       \"params\":{\
                                            \"enable\":1\
                                            }\
                                       }");
    } else {
        trtcCloud->callExperimentalAPI("{\
                                       \"api\":\"enableAudioANS\",\
                                       \"params\":{\
                                            \"enable\":0\
                                            }\
                                       }");
    }
}

- (void)setVolumeEvaluationEnabled:(BOOL)isEnabled {
    self.audioConfig.isVolumeEvaluationEnabled = isEnabled;
    trtcCloud->enableAudioVolumeEvaluation(isEnabled ? 300 : 0);
    if ([self.managerDelegate respondsToSelector:@selector(roomSettingsManager:didSetVolumeEvaluation:)]) {
        [self.managerDelegate roomSettingsManager:self didSetVolumeEvaluation:isEnabled];
    }
}

- (void)setAudioMuted:(BOOL)isMuted {
    self.audioConfig.isMuted = isMuted;
    trtcCloud->muteLocalAudio(isMuted);
    if ([self.managerDelegate respondsToSelector:@selector(onMuteLocalAudio:)]) {
        [self.managerDelegate onMuteLocalAudio:isMuted];
    }
}

- (void)muteRemoteAudio:(NSString *)userId mute:(BOOL)mute {
    trtcCloud->muteRemoteAudio([userId UTF8String], mute);
}

- (void)muteAllRemoteAudio:(BOOL)mute {
    trtcCloud->muteAllRemoteAudio(mute);
}

- (void)setRemoteAudioVolume:(NSString *)userId volume:(int)volume {
    trtcCloud->setRemoteAudioVolume([userId UTF8String], volume);
}

- (void)setCaptureVolume:(NSInteger)volume {
    trtcCloud->setAudioCaptureVolume((int)volume);
}

- (void)setPlayoutVolume:(NSInteger)volume {
    trtcCloud->setAudioPlayoutVolume((int)volume);
}

- (NSInteger)captureVolume {
    return trtcCloud->getAudioCaptureVolume();
}

- (NSInteger)playoutVolume {
    return trtcCloud->getAudioPlayoutVolume();
}

- (void)pushAudioStreamInSubRoom:(NSString *)roomId push:(BOOL)isPush
{
    self.audioConfig.isMuted = !isPush;
    trtc::ITRTCCloud *subCloud = _subClouds[[roomId UTF8String]];
    SUBCLOUD_GUARD
    subCloud->muteLocalAudio(!isPush);
    if ([self.managerDelegate respondsToSelector:@selector(onMuteLocalAudio:)]) {
        [self.managerDelegate onMuteLocalAudio:!isPush];
    }
}

#pragma mark - Stream

- (void)setMixMode:(TRTCTranscodingConfigMode)mixMode {
    self.streamConfig.mixMode = mixMode;
    [self updateCloudMixtureParams];
}

- (void)updateCloudMixtureParams {
    if (self.streamConfig.mixMode == TRTCTranscodingConfigMode_Unknown) {
        trtcCloud->setMixTranscodingConfig(nullptr);
        return;
    } else if (self.streamConfig.mixMode == TRTCTranscodingConfigMode_Template_PureAudio ||
               self.streamConfig.mixMode == TRTCTranscodingConfigMode_Template_ScreenSharing) {
        TRTCTranscodingConfig *config = [TRTCTranscodingConfig new];
        config.appId = (int) self.appId;
        config.bizId = (int) self.bizId;
        config.mode = self.streamConfig.mixMode;
        config.streamId = self.streamConfig.streamId;
        //将OC层的TRTCTranscodingConfig转换为C++层
        trtcCloud->setMixTranscodingConfig(transTranscodingConfigToCpp(config).get());
        return;
    }
    
    int videoWidth  = 720;
    int videoHeight = 1280;
    
    // 小画面宽高
    int subWidth  = 180;
    int subHeight = 320;
    
    int offsetX = 5;
    int offsetY = 50;
    
    int bitrate = 200;
    
    switch (self.videoConfig.videoEncConfig.videoResolution) {
            
        case TRTCVideoResolution_160_160:
        {
            videoWidth  = 160;
            videoHeight = 160;
            subWidth    = 32;
            subHeight   = 48;
            offsetY     = 10;
            bitrate     = 200;
            break;
        }
        case TRTCVideoResolution_320_180:
        {
            videoWidth  = 192;
            videoHeight = 336;
            subWidth    = 54;
            subHeight   = 96;
            offsetY     = 30;
            bitrate     = 400;
            break;
        }
        case TRTCVideoResolution_320_240:
        {
            videoWidth  = 240;
            videoHeight = 320;
            subWidth    = 54;
            subHeight   = 96;
            offsetY     = 30;
            bitrate     = 400;
            break;
        }
        case TRTCVideoResolution_480_480:
        {
            videoWidth  = 480;
            videoHeight = 480;
            subWidth    = 72;
            subHeight   = 128;
            bitrate     = 600;
            break;
        }
        case TRTCVideoResolution_640_360:
        {
            videoWidth  = 368;
            videoHeight = 640;
            subWidth    = 90;
            subHeight   = 160;
            bitrate     = 800;
            break;
        }
        case TRTCVideoResolution_640_480:
        {
            videoWidth  = 480;
            videoHeight = 640;
            subWidth    = 90;
            subHeight   = 160;
            bitrate     = 800;
            break;
        }
        case TRTCVideoResolution_960_540:
        {
            videoWidth  = 544;
            videoHeight = 960;
            subWidth    = 160;
            subHeight   = 288;
            bitrate     = 1000;
            break;
        }
        case TRTCVideoResolution_1280_720:
        {
            videoWidth  = 720;
            videoHeight = 1280;
            subWidth    = 192;
            subHeight   = 336;
            bitrate     = 1500;
            break;
        }
        case TRTCVideoResolution_1920_1080:
        {
            videoWidth  = 1088;
            videoHeight = 1920;
            subWidth    = 272;
            subHeight   = 480;
            bitrate     = 1900;
            break;
        }
        default:
            assert(false);
            break;
    }
    TRTCTranscodingConfig* config = [TRTCTranscodingConfig new];
    config.appId = (int) self.appId;
    config.bizId = (int) self.bizId;
    config.videoWidth = videoWidth;
    config.videoHeight = videoHeight;
    config.videoGOP = 1;
    config.videoFramerate = 15;
    config.videoBitrate = bitrate;
    config.audioSampleRate = 48000;
    config.audioBitrate = 64;
    config.audioChannels = 1;
    config.backgroundImage = self.streamConfig.backgroundImage;
    config.streamId = self.streamConfig.streamId;
    // 设置混流后主播的画面位置
    TRTCMixUser* broadCaster = [TRTCMixUser new];
    broadCaster.userId = self.streamConfig.mixMode == TRTCTranscodingConfigMode_Template_PresetLayout ? PLACE_HOLDER_LOCAL_MAIN : self.params.userId;
    
    // 设置背景图后，本地画面缩小到左上角，防止背景图被遮挡无法测试
    if (self.streamConfig.backgroundImage.length > 0) {
        broadCaster.rect = CGRectMake(0, 0, videoWidth / 2, videoHeight / 2);
    } else {
        broadCaster.rect = CGRectMake(0, 0, videoWidth, videoHeight);
    }
    
    NSMutableArray* mixUsers = [NSMutableArray new];
    [mixUsers addObject:broadCaster];
    
    // 设置混流后各个小画面的位置
    __block int index = 0;
    [self.remoteUserManager.remoteUsers enumerateKeysAndObjectsUsingBlock:^(NSString *userId, TRTCRemoteUserConfig *settings, BOOL *stop) {
        TRTCMixUser* audience = [TRTCMixUser new];
        audience.userId = self.streamConfig.mixMode == TRTCTranscodingConfigMode_Template_PresetLayout ? PLACE_HOLDER_REMOTE : userId;
        audience.zOrder = 2 + index;
        audience.roomID = settings.roomId;
        //辅流判断：辅流的Id为原userId + "-sub"
        if ([userId hasSuffix:@"-sub"]) {
            NSArray* spritStrs = [userId componentsSeparatedByString:@"-"];
            if (spritStrs.count < 2) {
                return;
            }
            NSString* realUserId = self.streamConfig.mixMode == TRTCTranscodingConfigMode_Template_PresetLayout ? PLACE_HOLDER_REMOTE : spritStrs[0];
            audience.userId = realUserId;
            audience.streamType = TRTCVideoStreamTypeSub;
        }
        if (index < 3) {
            // 前三个小画面靠右从下往上铺
            audience.rect = CGRectMake(videoWidth - offsetX - subWidth, videoHeight - offsetY - index * subHeight - subHeight, subWidth, subHeight);
        } else if (index < 6) {
            // 后三个小画面靠左从下往上铺
            audience.rect = CGRectMake(offsetX, videoHeight - offsetY - (index - 3) * subHeight - subHeight, subWidth, subHeight);
        } else {
            // 最多只叠加六个小画面
        }
        
        [mixUsers addObject:audience];
        ++index;
    }];
    config.mixUsers = mixUsers;
    config.mode = self.streamConfig.mixMode;
    
    //将OC层的TRTCTranscodingConfig转换为C++层
    std::shared_ptr<trtc::TRTCTranscodingConfig> configCpp = transTranscodingConfigToCpp(config);
    trtcCloud->setMixTranscodingConfig(configCpp.get());
}

- (void)setMixBackgroundImage:(NSString *)imageId {
    self.streamConfig.backgroundImage = imageId;
    [self updateCloudMixtureParams];
}

- (void)setMixStreamId:(NSString *)streamId {
    self.streamConfig.streamId = streamId;
    [self updateCloudMixtureParams];
}

#pragma mark - Message

- (BOOL)sendCustomMessage:(NSString *)message {
    NSData * _Nullable data = [message dataUsingEncoding:NSUTF8StringEncoding];
    if (data != nil) {
        return trtcCloud->sendCustomCmdMsg(0, (const unsigned char *)data.bytes, (uint32_t)data.length, true, false);
    }
    return NO;
}

- (BOOL)sendSEIMessage:(NSString *)message repeatCount:(NSInteger)repeatCount {
    NSData * _Nullable data = [message dataUsingEncoding:NSUTF8StringEncoding];
    if (data != nil) {
        return trtcCloud->sendSEIMsg((const unsigned char *)data.bytes, (uint32_t)data.length, repeatCount == 0 ? 1 : (int)repeatCount);
    }
    return NO;
}

#pragma mark - Cross Rooom

- (void)startCrossRoom:(NSString *)roomId userId:(NSString *)userId {
    self.isCrossingRoom = YES;
    
    NSDictionary* pkParams = @{
        @"strRoomId" : roomId,
        @"userId" : userId,
    };
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:pkParams options:0 error:nil];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    trtcCloud->connectOtherRoom([jsonString UTF8String]);
    [self.remoteUserManager addUser:userId roomId:roomId];
}

- (void)stopCrossRomm {
    self.isCrossingRoom = NO;
    trtcCloud->disconnectOtherRoom();
}

#pragma mark - Others

- (void)playCustomVideoOfUser:(NSString *)userId inView:(UIImageView *)view {
    trtcCloud->startRemoteView([userId UTF8String], trtc::TRTCVideoStreamTypeBig, nullptr);
    [renderTester addUser:userId videoView:view];
    [self setRemoteVideoRenderDelegate:userId
                              delegate:renderTester
                           pixelFormat:TRTCVideoPixelFormat_NV12
                            bufferType:TRTCVideoBufferType_PixelBuffer];
}

#pragma mark - Private

- (void)startLocalAudio {
    if (!self.audioConfig.isEnabled || self.isLiveAudience) {
        return;
    }
    if (self.audioConfig.isCustomCapture) {
        trtcCloud->enableCustomAudioCapture(true);
        [CustomAudioFileReader sharedInstance].delegate = self;
        [[CustomAudioFileReader sharedInstance] start:48000 channels:1 framLenInSample:960];
    } else {
        trtcCloud->startLocalAudio((trtc::TRTCAudioQuality)_localAudioQuality);
    }
}

- (void)stopLocalAudio {
    if (self.audioConfig.isCustomCapture) {
        trtcCloud->enableCustomAudioCapture(false);
        [[CustomAudioFileReader sharedInstance] stop];
        [CustomAudioFileReader sharedInstance].delegate = nil;
    } else {
        trtcCloud->stopLocalAudio();
    }
}

- (void)startLocalVideo {
    if (!self.videoConfig.isEnabled || self.isLiveAudience) {
        return;
    }
    switch (self.videoConfig.source) {
        case TRTCVideoSourceCamera:
            trtcCloud->startLocalPreview(self.videoConfig.isFrontCamera, (__bridge void*)localVideoView);
            break;
        case TRTCVideoSourceCustom:
            if (self.videoConfig.videoAsset) {
                // 使用视频文件
                [self setupVideoCapture];
                trtcCloud->enableCustomVideoCapture(true);
                [self setLocalVideoRenderDelegate:renderTester
                                           pixelFormat:TRTCVideoPixelFormat_NV12
                                            bufferType:TRTCVideoBufferType_PixelBuffer];
                [renderTester addUser:nil videoView:localVideoView];
                [self.videoCaptureTester start];
            }
            break;
        case TRTCVideoSourceAppScreen:
            if (@available(iOS 11.0, *)) {
                self.videoConfig.videoEncConfig.videoResolution = TRTCVideoResolution_1280_720;
                self.videoConfig.videoEncConfig.videoFps = 10;
                self.videoConfig.videoEncConfig.videoBitrate = 1600;
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"测试须知" message:@"全平台C++接口暂时不支持startScreenCaptureInApp" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
                [alert show];
//                [self.trtc startScreenCaptureInApp:self.videoConfig.videoEncConfig];
            }
            break;
        case TRTCVideoSourceDeviceScreen:
            if (@available(iOS 11.0, *)) {
                self.videoConfig.videoEncConfig.videoResolution = TRTCVideoResolution_1280_720;
                self.videoConfig.videoEncConfig.videoFps = 10;
                self.videoConfig.videoEncConfig.videoBitrate = 1600;
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"测试须知" message:@"全平台C++接口暂时不支持startScreenCaptureByReplaykit" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
                [alert show];
//                [self.trtc startScreenCaptureByReplaykit:self.videoConfig.videoEncConfig
//                                                appGroup:APPGROUP];
            }
            break;
    }
}

- (void)stopLocalVideo {
    switch (self.videoConfig.source) {
        case TRTCVideoSourceCamera:
            trtcCloud->stopLocalPreview();
            break;
        case TRTCVideoSourceCustom:
            trtcCloud->enableCustomVideoCapture(false);
            if (self.videoCaptureTester) {
                [self.videoCaptureTester stop];
                self.videoCaptureTester = nil;
            }
            break;
        case TRTCVideoSourceAppScreen: case TRTCVideoSourceDeviceScreen:
            if (@available(iOS 11.0, *)) {
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"测试须知" message:@"全平台C++接口暂时不支持stopScreenCapture" delegate:self cancelButtonTitle:@"确定" otherButtonTitles:nil];
                [alert show];
//                [self.trtc stopScreenCapture];
            }
            break;
    }
}

- (BOOL)isLiveAudience {
    return self.scene == TRTCAppSceneLIVE && self.params.role == TRTCRoleAudience;
}

- (void)setupVideoCapture {
    self.videoCaptureTester = [[TestSendCustomVideoData alloc]
                               initWithTRTCCloud:[TRTCCloud sharedInstance]
                               mediaAsset:self.videoConfig.videoAsset];
    [self setVideoFps:self.videoCaptureTester.mediaReader.fps];
}

- (void)setExperimentConfig:(NSString *)key params:(NSDictionary *)params {
    NSDictionary *json = @{
        @"api": key,
        @"params": params
    };
    trtcCloud->callExperimentalAPI([[self jsonStringFrom:json] UTF8String]);
}

- (NSString *)jsonStringFrom:(NSDictionary *)dict {
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:NULL];
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

#pragma mark - Live Player

- (NSString *)getCdnUrlOfUser:(NSString *)userId {
    NSString *filePath;
    if (self.params.strRoomId) {
        //字符串房间号
        filePath = [NSString stringWithFormat:@"%@_%@_%@_main", @(self.params.sdkAppId), self.params.strRoomId, userId];
    } else {
        //数字房间号
        filePath = [NSString stringWithFormat:@"%@_%@_%@_main", @(self.params.sdkAppId), @(self.params.roomId), userId];
    }
    return [NSString stringWithFormat:@"http://%@.liveplay.myqcloud.com/live/%@.flv", @(self.bizId), filePath];
}

#pragma mark - Torch Observe

- (void)setupTorchObservation {
    __weak __typeof(self) wSelf = self;
    [[NSNotificationCenter defaultCenter]
     addObserverForName:UIApplicationDidEnterBackgroundNotification
     object:self
     queue:NSOperationQueue.mainQueue
     usingBlock:^(NSNotification * _Nonnull note) {
        wSelf.videoConfig.isTorchOn = NO;
    }];
}

#pragma mark - custom audio send

- (void)onAudioCapturePcm:(NSData *)pcmData sampleRate:(int)sampleRate channels:(int)channels ts:(uint32_t)timestampMs {
    TRTCAudioFrame * frame = [[TRTCAudioFrame alloc] init];
    frame.data = pcmData;
    frame.sampleRate = (TRTCAudioSampleRate)sampleRate;
    frame.channels = channels;
    frame.timestamp = timestampMs;
    //将OC层的TRTCAudioFrame转换为C++层
    trtcCloud->sendCustomAudioData(transAudioFrameToCpp(frame).get());
}

#pragma mark - Type Translate Funtions

std::shared_ptr<trtc::TRTCVideoEncParam> transVideoEncParamToCpp(TRTCVideoEncParam *param) {
    std::shared_ptr<trtc::TRTCVideoEncParam> videoEncParam(new trtc::TRTCVideoEncParam());
    videoEncParam->enableAdjustRes = param.enableAdjustRes;
    videoEncParam->minVideoBitrate = param.minVideoBitrate;
    videoEncParam->resMode = (trtc::TRTCVideoResolutionMode)param.resMode;
    videoEncParam->videoBitrate = param.videoBitrate;
    videoEncParam->videoFps = param.videoFps;
    videoEncParam->videoResolution = (trtc::TRTCVideoResolution)param.videoResolution;
    return videoEncParam;
}

std::shared_ptr<trtc::TRTCNetworkQosParam> transQosParamToCpp(TRTCNetworkQosParam *param) {
    std::shared_ptr<trtc::TRTCNetworkQosParam> qosParam(new trtc::TRTCNetworkQosParam());
    qosParam->controlMode = (trtc::TRTCQosControlMode)param.controlMode;
    qosParam->preference = (trtc::TRTCVideoQosPreference)param.preference;
    return qosParam;
}

std::shared_ptr<trtc::TRTCParams> transTrtcParamToCpp(TRTCParams *param) {
    std::shared_ptr<trtc::TRTCParams> trtcParam(new trtc::TRTCParams());
    trtcParam->businessInfo = [param.bussInfo UTF8String];
    trtcParam->privateMapKey = [param.privateMapKey UTF8String];
    trtcParam->role = (trtc::TRTCRoleType)param.role;
    trtcParam->roomId = param.roomId;
    trtcParam->sdkAppId = param.sdkAppId;
    trtcParam->strRoomId = [param.strRoomId UTF8String];
    trtcParam->streamId = [param.streamId UTF8String];
    trtcParam->userDefineRecordId = [param.userDefineRecordId UTF8String];
    trtcParam->userId = [param.userId UTF8String];
    trtcParam->userSig = [param.userSig UTF8String];
    return trtcParam;
}


void transcodingConfigDeleter (trtc::TRTCTranscodingConfig* ptr) {
    if (!ptr) return;
    if (ptr->mixUsersArray) {
        free(ptr->mixUsersArray);
        ptr->mixUsersArray = nullptr;
    }
    delete ptr;
    ptr = nullptr;
}

std::shared_ptr<trtc::TRTCTranscodingConfig> transTranscodingConfigToCpp(TRTCTranscodingConfig *config) {
    std::shared_ptr<trtc::TRTCTranscodingConfig> transCodingConfig(new trtc::TRTCTranscodingConfig(), transcodingConfigDeleter);
    transCodingConfig->appId = config.appId;
    transCodingConfig->audioBitrate = config.audioBitrate;
    transCodingConfig->audioChannels = config.audioChannels;
    transCodingConfig->audioSampleRate = config.audioSampleRate;
    transCodingConfig->backgroundColor = config.backgroundColor;
    transCodingConfig->backgroundImage = [config.backgroundImage UTF8String];
    transCodingConfig->bizId = config.bizId;
    transCodingConfig->streamId = [config.streamId UTF8String];
    trtc::TRTCMixUser *userArray = (trtc::TRTCMixUser *)malloc(sizeof(trtc::TRTCMixUser) * config.mixUsers.count);
    for (int i=0; i<config.mixUsers.count; i++) {
        userArray[i].pureAudio = config.mixUsers[i].pureAudio;
        userArray[i].rect.left = config.mixUsers[i].rect.origin.x;
        userArray[i].rect.top = config.mixUsers[i].rect.origin.y;
        userArray[i].rect.right = config.mixUsers[i].rect.origin.x+config.mixUsers[i].rect.size.width;
        userArray[i].rect.bottom = config.mixUsers[i].rect.origin.y+config.mixUsers[i].rect.size.height;
        userArray[i].roomId = [config.mixUsers[i].roomID UTF8String];
        userArray[i].streamType = (trtc::TRTCVideoStreamType)config.mixUsers[i].streamType;
        userArray[i].userId = [config.mixUsers[i].userId UTF8String];
        userArray[i].zOrder = config.mixUsers[i].zOrder;
        userArray[i].inputType = (trtc::TRTCMixInputType)config.mixUsers[i].inputType;
    }
    transCodingConfig->mixUsersArray = userArray;
    transCodingConfig->mixUsersArraySize = (int)config.mixUsers.count;
    transCodingConfig->mode = (trtc::TRTCTranscodingConfigMode)config.mode;
    transCodingConfig->streamId = [config.streamId UTF8String];
    transCodingConfig->videoBitrate = config.videoBitrate;
    transCodingConfig->videoFramerate = config.videoFramerate;
    transCodingConfig->videoGOP = config.videoGOP;
    transCodingConfig->videoHeight = config.videoHeight;
    transCodingConfig->videoWidth = config.videoWidth;
    return transCodingConfig;
}

std::shared_ptr<trtc::TRTCAudioFrame> transAudioFrameToCpp(TRTCAudioFrame *audioFrame) {
    std::shared_ptr<trtc::TRTCAudioFrame> audioFrameCpp(new trtc::TRTCAudioFrame());
    audioFrameCpp->audioFormat = trtc::TRTCAudioFrameFormatPCM;
    audioFrameCpp->channel = audioFrame.channels;
    audioFrameCpp->data = (char *)audioFrame.data.bytes;
    audioFrameCpp->length = (uint32_t)audioFrame.data.length;
    audioFrameCpp->sampleRate = (uint32_t)audioFrame.sampleRate;
    audioFrameCpp->timestamp = audioFrame.timestamp;
    return audioFrameCpp;
}

TRTCQualityInfo *transQualityInfoFromCpp(trtc::TRTCQualityInfo *info) {
    TRTCQualityInfo *qualityInfo = [[TRTCQualityInfo alloc] init];
    qualityInfo.quality = (TRTCQuality)info->quality;
    qualityInfo.userId = [NSString stringWithUTF8String:info->userId];
    return qualityInfo;
}

TRTCStatistics *transStatisticsFromCpp(const trtc::TRTCStatistics& statistics) {
    TRTCStatistics *trtcStatistics = [[TRTCStatistics alloc] init];
    trtcStatistics.appCpu = statistics.appCpu;
    trtcStatistics.downLoss = statistics.downLoss;
    NSArray<TRTCLocalStatistics*>* localStatisticsArray = [[NSArray alloc] init];
    for (int i=0; i<statistics.localStatisticsArraySize; i++) {
        TRTCLocalStatistics *localStat = [[TRTCLocalStatistics alloc] init];
        localStat.audioBitrate = statistics.localStatisticsArray[i].audioBitrate;
        localStat.audioSampleRate = statistics.localStatisticsArray[i].audioSampleRate;
        localStat.frameRate = statistics.localStatisticsArray[i].frameRate;
        localStat.height = statistics.localStatisticsArray[i].height;
        localStat.streamType = (TRTCVideoStreamType)statistics.localStatisticsArray[i].streamType;
        localStat.videoBitrate = statistics.localStatisticsArray[i].videoBitrate;
        localStat.width = statistics.localStatisticsArray[i].width;
        localStatisticsArray = [localStatisticsArray arrayByAddingObject:localStat];
    }
    trtcStatistics.localStatistics = localStatisticsArray;
    trtcStatistics.receivedBytes = statistics.receivedBytes;
    NSArray<TRTCRemoteStatistics*>* remoteStatisticsArray = [[NSArray alloc] init];
    for (int i=0; i<statistics.remoteStatisticsArraySize; i++) {
        TRTCRemoteStatistics *remoteStat = [[TRTCRemoteStatistics alloc] init];
        remoteStat.audioBitrate = statistics.remoteStatisticsArray[i].audioBitrate;
        remoteStat.audioBlockRate = statistics.remoteStatisticsArray[i].audioBlockRate;
        remoteStat.audioSampleRate = statistics.remoteStatisticsArray[i].audioSampleRate;
        remoteStat.audioTotalBlockTime = statistics.remoteStatisticsArray[i].audioTotalBlockTime;
        remoteStat.finalLoss = statistics.remoteStatisticsArray[i].finalLoss;
        remoteStat.frameRate = statistics.remoteStatisticsArray[i].frameRate;
        remoteStat.height = statistics.remoteStatisticsArray[i].height;
        remoteStat.jitterBufferDelay = statistics.remoteStatisticsArray[i].jitterBufferDelay;
        remoteStat.point2PointDelay = statistics.remoteStatisticsArray[i].point2PointDelay;
        remoteStat.streamType = (TRTCVideoStreamType)statistics.remoteStatisticsArray[i].streamType;
        remoteStat.userId = [NSString stringWithUTF8String: statistics.remoteStatisticsArray[i].userId];
        remoteStat.videoBitrate = statistics.remoteStatisticsArray[i].videoBitrate;
        remoteStat.width = statistics.remoteStatisticsArray[i].width;
        remoteStatisticsArray = [remoteStatisticsArray arrayByAddingObject:remoteStat];
    }
    trtcStatistics.remoteStatistics = remoteStatisticsArray;
    trtcStatistics.rtt = statistics.rtt;
    trtcStatistics.sentBytes = statistics.sentBytes;
    trtcStatistics.systemCpu = statistics.systemCpu;
    trtcStatistics.upLoss = statistics.upLoss;
    return trtcStatistics;
}

TRTCVolumeInfo *transVolumeInfoFromCpp(trtc::TRTCVolumeInfo *info) {
    TRTCVolumeInfo *volumeInfo = [[TRTCVolumeInfo alloc] init];
    volumeInfo.userId = [NSString stringWithUTF8String:info->userId];
    volumeInfo.volume = info->volume;
    return volumeInfo;
}

TRTCAudioFrame *transAudioFrameFromCpp(trtc::TRTCAudioFrame *frame) {
    TRTCAudioFrame *audioFrame = [[TRTCAudioFrame alloc] init];
    audioFrame.channels = frame->channel;
    audioFrame.data = [[NSData alloc] initWithBytes:frame->data length:frame->length];
    audioFrame.sampleRate = (TRTCAudioSampleRate)frame->sampleRate;
    audioFrame.timestamp = frame->timestamp;
    return audioFrame;
}

std::shared_ptr<trtc::TRTCSwitchRoomConfig> transSwitchRoomConfigToCpp(TRTCSwitchRoomConfig *cfg) {
    std::shared_ptr<trtc::TRTCSwitchRoomConfig> switchRoomConfigCpp(new trtc::TRTCSwitchRoomConfig());
    if (cfg.privateMapKey) {
        switchRoomConfigCpp->privateMapKey = [cfg.privateMapKey UTF8String];
    }
    switchRoomConfigCpp->roomId = cfg.roomId;
    if (cfg.strRoomId) {
        switchRoomConfigCpp->strRoomId = [cfg.strRoomId UTF8String];
    }
    if (cfg.userSig) {
        switchRoomConfigCpp->userSig = [cfg.userSig UTF8String];
    }
    return switchRoomConfigCpp;
}

TRTCVideoFrame *transVideoFrameFromCpp(trtc::TRTCVideoFrame *frame) {
    TRTCVideoFrame *videoFrame = [[TRTCVideoFrame alloc] init];
    videoFrame.bufferType = TRTCVideoBufferType_NSData;
    videoFrame.data = [[NSData alloc] initWithBytes:frame->data length:frame->length];
    videoFrame.pixelBuffer = nil;
    videoFrame.pixelFormat = (TRTCVideoPixelFormat)frame->videoFormat;
    if (frame->videoFormat == trtc::TRTCVideoPixelFormat_BGRA32) {
        videoFrame.pixelFormat = TRTCVideoPixelFormat_32BGRA;
    }
    videoFrame.rotation = (TRTCVideoRotation)frame->rotation;
    videoFrame.timestamp = frame->timestamp;
    videoFrame.width = frame->width;
    videoFrame.height = frame->height;
    return videoFrame;
}

void MyTRTCCoudCallBack::onError(TXLiteAVError errCode, const char *errMsg, void *extraInfo) {
    if ([trtcDelegate respondsToSelector:@selector(onError:errMsg:extInfo:)]) {
        [trtcDelegate onError:errCode errMsg:[NSString stringWithUTF8String:errMsg] extInfo:nil];
    }
}

void MyTRTCCoudCallBack::onWarning(TXLiteAVWarning warningCode, const char *warningMsg, void *extraInfo) {
    if ([trtcDelegate respondsToSelector:@selector(onWarning:warningMsg:extInfo:)]) {
        [trtcDelegate onWarning:warningCode warningMsg:[NSString stringWithUTF8String:warningMsg] extInfo:nil];
    }
}

void MyTRTCCoudCallBack::onEnterRoom(int result) {
    if ([trtcDelegate respondsToSelector:@selector(onEnterRoom:)]) {
        [trtcDelegate onEnterRoom:result];
    }
}

void MyTRTCCoudCallBack::onExitRoom(int reason) {
    if ([trtcDelegate respondsToSelector:@selector(onExitRoom:)]) {
        [trtcDelegate onExitRoom:reason];
    }
}

void MyTRTCCoudCallBack::onSwitchRole(TXLiteAVError errCode, const char* errMsg) {
    if ([trtcDelegate respondsToSelector:@selector(onSwitchRole:errMsg:)]) {
        [trtcDelegate onSwitchRole:errCode errMsg:[NSString stringWithUTF8String:errMsg]];
    }
}

void MyTRTCCoudCallBack::onConnectOtherRoom(const char* userId, TXLiteAVError errCode, const char* errMsg) {
    if ([trtcDelegate respondsToSelector:@selector(onConnectOtherRoom:errCode:errMsg:)]) {
        [trtcDelegate onConnectOtherRoom:[NSString stringWithUTF8String:userId] errCode:errCode errMsg:[NSString stringWithUTF8String:errMsg]];
    }
}

void MyTRTCCoudCallBack::onSwitchRoom(TXLiteAVError errCode, const char* errMsg) {
    if ([trtcDelegate respondsToSelector:@selector(onSwitchRoom:errMsg:)]) {
        [trtcDelegate onSwitchRoom:errCode errMsg:errMsg ? [NSString stringWithUTF8String:errMsg] : @""];
    }
}

void MyTRTCCoudCallBack::onRemoteUserEnterRoom(const char* userId) {
    if ([trtcDelegate respondsToSelector:@selector(onRemoteUserEnterRoom:)]) {
        [trtcDelegate onRemoteUserEnterRoom:[NSString stringWithUTF8String:userId]];
    }
}

void MyTRTCCoudCallBack::onRemoteUserLeaveRoom(const char* userId, int reason) {
    if ([trtcDelegate respondsToSelector:@selector(onRemoteUserLeaveRoom:reason:)]) {
        [trtcDelegate onRemoteUserLeaveRoom:[NSString stringWithUTF8String:userId] reason:reason];
    }
}

void MyTRTCCoudCallBack::onUserVideoAvailable(const char* userId, bool available) {
    if ([trtcDelegate respondsToSelector:@selector(onUserVideoAvailable:available:)]) {
        [trtcDelegate onUserVideoAvailable:[NSString stringWithUTF8String:userId] available:available];
    }
}

void MyTRTCCoudCallBack::onUserSubStreamAvailable(const char* userId, bool available) {
    if ([trtcDelegate respondsToSelector:@selector(onUserSubStreamAvailable:available:)]) {
        [trtcDelegate onUserSubStreamAvailable:[NSString stringWithUTF8String:userId] available:available];
    }
}

void MyTRTCCoudCallBack::onUserAudioAvailable(const char* userId, bool available) {
    if ([trtcDelegate respondsToSelector:@selector(onUserAudioAvailable:available:)]) {
        [trtcDelegate onUserAudioAvailable:[NSString stringWithUTF8String:userId] available:available];
    }
}

void MyTRTCCoudCallBack::onFirstVideoFrame(const char* userId, const trtc::TRTCVideoStreamType streamType, const int width, const int height) {
    if ([trtcDelegate respondsToSelector:@selector(onFirstVideoFrame:streamType:width:height:)]) {
        [trtcDelegate onFirstVideoFrame:[NSString stringWithUTF8String:userId] streamType:(TRTCVideoStreamType)streamType width:width height:height];
    }
}

void MyTRTCCoudCallBack::onNetworkQuality(trtc::TRTCQualityInfo localQuality, trtc::TRTCQualityInfo* remoteQuality, uint32_t remoteQualityCount) {
    
    TRTCQualityInfo *qualityInfo = transQualityInfoFromCpp(&localQuality);
    NSArray<TRTCQualityInfo *> *qualityInfoArray = [[NSArray alloc] init];
    for (int i=0; i<remoteQualityCount; i++) {
        qualityInfoArray  = [qualityInfoArray arrayByAddingObject:transQualityInfoFromCpp(&remoteQuality[i])];
    }
    if ([trtcDelegate respondsToSelector:@selector(onNetworkQuality:remoteQuality:)]) {
        [trtcDelegate onNetworkQuality:qualityInfo remoteQuality:qualityInfoArray];
    }
}

void MyTRTCCoudCallBack::onStatistics(const trtc::TRTCStatistics& statics) {
    TRTCStatistics *trtcStatistics = transStatisticsFromCpp(statics);
    if ([trtcDelegate respondsToSelector:@selector(onStatistics:)]) {
        [trtcDelegate onStatistics:trtcStatistics];
    }
}

void MyTRTCCoudCallBack::onUserVoiceVolume(trtc::TRTCVolumeInfo* userVolumes, uint32_t userVolumesCount, uint32_t totalVolume) {
    NSArray<TRTCVolumeInfo *> *volumeInfos = [[NSArray alloc] init];
    for (int i=0; i<userVolumesCount; i++) {
        volumeInfos = [volumeInfos arrayByAddingObject:transVolumeInfoFromCpp(&userVolumes[i])];
    }
    if ([trtcDelegate respondsToSelector:@selector(onUserVoiceVolume:totalVolume:)]) {
        [trtcDelegate onUserVoiceVolume:volumeInfos totalVolume:totalVolume];
    }
}

void MyTRTCCoudCallBack::onRecvCustomCmdMsg(const char* userId, int32_t cmdID, uint32_t seq, const uint8_t* message, uint32_t messageSize) {
    NSData *msgData = [[NSData alloc] initWithBytes:message length:messageSize];
    if ([trtcDelegate respondsToSelector:@selector(onRecvCustomCmdMsgUserId:cmdID:seq:message:)]) {
        [trtcDelegate onRecvCustomCmdMsgUserId:[NSString stringWithUTF8String:userId] cmdID:cmdID seq:seq message:msgData];
    }
}

void MyTRTCCoudCallBack::onMissCustomCmdMsg(const char* userId, int32_t cmdID, int32_t errCode, int32_t missed) {
    if ([trtcDelegate respondsToSelector:@selector(onMissCustomCmdMsgUserId:cmdID:errCode:missed:)]) {
        [trtcDelegate onMissCustomCmdMsgUserId:[NSString stringWithUTF8String:userId] cmdID:cmdID errCode:errCode missed:missed];
    }
}

void MyTRTCCoudCallBack::onRecvSEIMsg(const char* userId, const uint8_t* message, uint32_t messageSize) {
    NSData *msgData = [[NSData alloc] initWithBytes:message length:messageSize];
    if ([trtcDelegate respondsToSelector:@selector(onRecvSEIMsg:message:)]) {
        [trtcDelegate onRecvSEIMsg:[NSString stringWithUTF8String:userId] message:msgData];
    }
}

//从TRTCSubClouds接收到回调后，转发给TRTCCloudManager的监听者（目前是TRTCMainViewController）

MyTRTCSubCoudCallBack::MyTRTCSubCoudCallBack(std::string roomId, TRTCCloudManagerCpp *manager) {
    subRoomId = roomId;
    MyTRTCSubCoudCallBack::weakManager = manager;
}

void MyTRTCSubCoudCallBack::onError(TXLiteAVError errCode, const char *errMsg, void *extraInfo) {
    //do nothing
}

void MyTRTCSubCoudCallBack::onWarning(TXLiteAVWarning warningCode, const char *warningMsg, void *extraInfo) {
    //do nothing
}

void MyTRTCSubCoudCallBack::onEnterRoom(int result) {
    if ([weakManager.managerDelegate respondsToSelector:@selector(onEnterSubRoom:result:)]) {
        [weakManager.managerDelegate onEnterSubRoom:[NSString stringWithUTF8String:subRoomId.c_str()] result:result];
    }
}

void MyTRTCSubCoudCallBack::onExitRoom(int reason) {
    if ([weakManager.managerDelegate respondsToSelector:@selector(onExitSubRoom:reason:)]) {
        [weakManager.managerDelegate onExitSubRoom:[NSString stringWithUTF8String:subRoomId.c_str()] reason:reason];
    }
}

void MyTRTCSubCoudCallBack::onUserAudioAvailable(const char* userId, bool available) {
    if ([weakManager.managerDelegate respondsToSelector:@selector(onSubRoomUserAudioAvailable:userId:available:)]) {
        [weakManager.managerDelegate onSubRoomUserAudioAvailable:[NSString stringWithUTF8String:subRoomId.c_str()]
                                                          userId:[NSString stringWithUTF8String:userId]
                                                       available:available];
    }
}

void MyTRTCSubCoudCallBack::onUserVideoAvailable(const char* userId, bool available) {
    if ([weakManager.managerDelegate respondsToSelector:@selector(onSubRoomUserVideoAvailable:userId:available:)]) {
        [weakManager.managerDelegate onSubRoomUserVideoAvailable:[NSString stringWithUTF8String:subRoomId.c_str()]
                                                          userId:[NSString stringWithUTF8String:userId]
                                                       available:available];
    }
}

void MyTRTCSubCoudCallBack::onRemoteUserEnterRoom(const char* userId) {
    if ([weakManager.managerDelegate respondsToSelector:@selector(onSubRoomRemoteUserEnterRoom:userId:)]) {
        [weakManager.managerDelegate onSubRoomRemoteUserEnterRoom:[NSString stringWithUTF8String:subRoomId.c_str()]
                                                           userId:[NSString stringWithUTF8String:userId]];
    }
}

void MyTRTCSubCoudCallBack::onRemoteUserLeaveRoom(const char* userId, int reason) {
    if ([weakManager.managerDelegate respondsToSelector:@selector(onSubRoomRemoteUserLeaveRoom:userId:reason:)]) {
        [weakManager.managerDelegate onSubRoomRemoteUserLeaveRoom:[NSString stringWithUTF8String:subRoomId.c_str()]
                                                           userId:[NSString stringWithUTF8String:userId]
                                                           reason:reason];
    }
}


void MyAudioCallBack::onCapturedAudioFrame(trtc::TRTCAudioFrame *frame) {
    if ([trtcDelegate respondsToSelector:@selector(onCapturedRawAudioFrame:)]) {
        [trtcAudioDelegate onCapturedRawAudioFrame:transAudioFrameFromCpp(frame)];
    }
}

void MyAudioCallBack::onMixedPlayAudioFrame(trtc::TRTCAudioFrame *frame) {
    if ([trtcDelegate respondsToSelector:@selector(onMixedPlayAudioFrame:)]) {
        [trtcAudioDelegate onMixedPlayAudioFrame:transAudioFrameFromCpp(frame)];
    }
}

void MyLocalVideoCallBack::onRenderVideoFrame(const char* userId, trtc::TRTCVideoStreamType streamType, trtc::TRTCVideoFrame* frame) {
    [trtcLocalVideoDelegate onRenderVideoFrame:transVideoFrameFromCpp(frame) userId:[NSString stringWithUTF8String:userId] streamType:(TRTCVideoStreamType)streamType];
}

void MyRemoteVideoCallBack::onRenderVideoFrame(const char* userId, trtc::TRTCVideoStreamType streamType, trtc::TRTCVideoFrame* frame) {
    id<TRTCVideoRenderDelegate> delegate = [remoteVideoDelegateDic objectForKey:[NSString stringWithUTF8String:userId]];
    if (delegate) {
        [delegate onRenderVideoFrame:transVideoFrameFromCpp(frame) userId:[NSString stringWithUTF8String:userId] streamType:(TRTCVideoStreamType)streamType];
    }
}



@end
