/*
* Module:   TRTCCloudManager
*
* Function: TRTC SDK的视频、音频以及消息功能
*
*    1. 视频功能包括摄像头的设置，视频编码的设置和视频流的设置
*
*    2. 音频功能包括采集端的设置（采集开关、增益、降噪、耳返、采样率），以及播放端的设置（音频通道、音量类型、音量提示）
*
*    3. 消息发送有两种：自定义消息和SEI消息，具体适用场景和限制可参照TRTCCloud.h中sendCustomCmdMsg和sendSEIMsg的描述
*/

#import "TRTCCloudManager.h"
#import "TRTCCloudDef.h"
#import "NSString+Common.h"
#import "CustomAudioFileReader.h"
#import "TestSendCustomVideoData.h"
#import "TestRenderVideoFrame.h"
#import "TRTCCustomerCrypt.h"
#import "TRTCCloudDelegate.h"
#import "TRTCVideoCustomPreprocessor.h"
#import "CoreImageFilter.h"

#define PLACE_HOLDER_LOCAL_MAIN   @"$PLACE_HOLDER_LOCAL_MAIN$"
#define PLACE_HOLDER_LOCAL_SUB   @"$PLACE_HOLDER_LOCAL_SUB$"
#define PLACE_HOLDER_REMOTE     @"$PLACE_HOLDER_REMOTE$"

#if DEBUG
#define APPGROUP @"group.com.tencent.liteav.RPLiveStreamShare"
#else
#define APPGROUP @"group.com.tencent.liteav.RPLiveStreamRelease" // App Store Group
#endif

@interface TRTCSubRoomDelegate : NSObject <TRTCCloudDelegate>
//用来从TRTCSubCloud实例中获取回调并转发
@property (nonatomic) NSString *subRoomId;
@property (weak, nonatomic) TRTCCloudManager *weakManager;
- (instancetype)initWithRoomId:(NSString *)roomId manager:(TRTCCloudManager*) manager;
- (void)onEnterRoom:(NSInteger)result;
- (void)onExitRoom:(NSInteger)reason;
- (void)onUserAudioAvailable:(NSString *)userId available:(BOOL)available;
- (void)onUserVideoAvailable:(NSString *)userId available:(BOOL)available;
- (void)onRemoteUserEnterRoom:(NSString *)userId;
- (void)onRemoteUserLeaveRoom:(NSString *)userId reason:(NSInteger)reason;
@end

@interface TRTCCloudManager()<CustomAudioFileReaderDelegate, TRTCVideoFrameDelegate,TXLiveAudioSessionDelegate>

@property (strong, nonatomic) TRTCCloud *trtc;
@property (nonatomic) BOOL isCrossingRoom;
@property (nonatomic) NSInteger appId;
@property (nonatomic) NSInteger bizId;
@property (strong, nonatomic) TXDeviceManager *deviceManager;
@property (strong, nonatomic) TXAudioEffectManager *audioEffectManager;

// 视频文件播放
@property (strong, nonatomic) TestSendCustomVideoData *videoCaptureTester;
@property (strong, nonatomic) TestSendCustomVideoData *subVideoCaptureTester;
@property (strong, nonatomic) TestRenderVideoFrame *renderTester;

@property (strong, nonatomic) TRTCVideoCustomPreprocessor *customPreprocessor;
@property (strong, nonatomic) CoreImageFilter *yuvPreprocessor;

//子房间
@property (strong, atomic)NSMutableDictionary<NSString *, TRTCCloud *> *subClouds;
@property (strong, atomic)NSMutableDictionary<NSString *, TRTCSubRoomDelegate *> *subDelegates;

@end

@implementation TRTCCloudManager

- (instancetype)initWithParams:(TRTCParams *)params
                       scene:(TRTCAppScene)scene
                       appId:(NSInteger)appId
                       bizId:(NSInteger)bizId {
    if (self = [super init]) {
        _trtc = [TRTCCloud sharedInstance];
        _params = params;
        _scene = scene;
        _appId = appId;
        _bizId = bizId;
        _videoConfig = [[TRTCVideoConfig alloc] initWithScene:scene];
        _audioConfig = [[TRTCAudioConfig alloc] init];
#pragma mark - 接管AVAudioSession用 记得测试完注释掉
        [TXLiveBase setAudioSessionDelegate:self];
        _streamConfig = [[TRTCStreamConfig alloc] init];
        _renderTester = [[TestRenderVideoFrame alloc] init];
        _subClouds = [[NSMutableDictionary alloc] init];
        _subDelegates = [[NSMutableDictionary alloc] init];
        _deviceManager = [_trtc getDeviceManager];
        _audioEffectManager = [_trtc getAudioEffectManager];
        _customPreprocessor = [[TRTCVideoCustomPreprocessor alloc] init];
        _yuvPreprocessor = [[CoreImageFilter alloc] init];
        [self setupTorchObservation];
    }
    return self;
}
#pragma mark -接管AVAudioSession 使用前需要[TXLiveBase setAudioSessionDelegate:self];
-(BOOL)overrideOutputAudioPort:(AVAudioSessionPortOverride)portOverride error:(NSError *__autoreleasing  _Nullable *)outError{
    return YES;
}
- (BOOL)setCategory:(NSString *)category withOptions:(AVAudioSessionCategoryOptions)options error:(NSError *__autoreleasing  _Nullable *)outError{
    return YES;
}
-(BOOL)setCategory:(NSString *)category mode:(NSString *)mode options:(AVAudioSessionCategoryOptions)options error:(NSError *__autoreleasing  _Nullable *)outError{
    return YES;
}
-(BOOL)setCategory:(NSString *)category error:(NSError *__autoreleasing  _Nullable *)outError{
    return YES;
}
-(BOOL)setMode:(NSString *)mode error:(NSError *__autoreleasing  _Nullable *)outError{
    return YES;
}
- (void)setupTrtc {
    [self setupTrtcVideo];
    [self setupTrtcAudio];
}

- (void)destroyTrtc {
    [TRTCCloud destroySharedIntance];
    _trtc = nil;
}

#pragma mark - Room

- (void)enterRoom {
    [self setupTrtc];
    [self startLocalVideo];
#ifndef TRTC_INTERNATIONAL
    [self.trtc callExperimentalAPI:[self dictionaryToJson:@{
        @"api" : @"setEncodedDataProcessingListener",
        @"params" : @{
                @"listener" : @((uint64_t)[[TRTCCustomerCrypt sharedInstance] getEncodedDataProcessingListener])
        }
    }]];
#endif
    [self.trtc enterRoom:self.params appScene:self.scene];
    if (self.params.role == TRTCRoleAnchor) {
        self.currentPublishingRoomId = self.params.roomId ? [@(self.params.roomId) stringValue] : self.params.strRoomId;
    }
    [self startLocalAudio];
    [self.trtc startPublishing:@"hzhi" type:TRTCVideoStreamTypeBig];
}

- (void)enterSubRoom:(TRTCParams *)params {
    TRTCCloud *subCloud = [[TRTCCloud sharedInstance] createSubCloud];
    //不论是字符串房间号还是数字房间号，在这里都用字符串做主键；因此同时进入数值与字符串相同的两个房间会出问题
    NSString *stringRoomId = params.roomId ? [@(params.roomId) stringValue] : params.strRoomId;
    [_subClouds setValue:subCloud forKey:stringRoomId];
    TRTCSubRoomDelegate *subDelegate = [[TRTCSubRoomDelegate alloc] initWithRoomId:stringRoomId manager:self];
    [subCloud setDelegate:subDelegate];
    [_subDelegates setValue:subDelegate forKey:stringRoomId];
    //进入子房间
    [subCloud enterRoom:params appScene:_scene];
}

- (void)exitSubRoom:(NSString *)roomId {
    //不论是字符串房间号还是数字房间号，在这里都用字符串做主键；因此同时进入数值与字符串相同的两个房间会出问题
    TRTCCloud *subCloud = [_subClouds objectForKey:roomId];
    [subCloud exitRoom];
    [[TRTCCloud sharedInstance] destroySubCloud:subCloud];
    [_subClouds removeObjectForKey:roomId];
}

- (void)exitAllSubRoom {
    for (TRTCCloud *cloud in [_subClouds allValues]) {
        [cloud exitRoom];
    }
}

- (void)switchRoom:(TRTCSwitchRoomConfig *)switchRoomConfig {
    if ([self.currentPublishingRoomId isEqualToString:self.params.roomId ? [@(self.params.roomId) stringValue] : self.params.strRoomId]) {
        //若之前正在主房间中推流，则更新推流房间为新的房间号
        self.currentPublishingRoomId = switchRoomConfig.roomId ? [@(switchRoomConfig.roomId) stringValue] : switchRoomConfig.strRoomId;
    }
    self.params.roomId = switchRoomConfig.roomId;
    self.params.strRoomId = switchRoomConfig.strRoomId;
    if(switchRoomConfig.userSig) {
        self.params.userSig = switchRoomConfig.userSig;
    }
    if(switchRoomConfig.privateMapKey) {
        self.params.privateMapKey = switchRoomConfig.privateMapKey;
    }
    [self.trtc switchRoom:switchRoomConfig];
}

- (NSString*)dictionaryToJson:(NSDictionary *)dic

{
    NSError *parseError = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dic options:NSJSONWritingPrettyPrinted error:&parseError];
    
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

- (void)exitRoom {
    [self stopLocalAudio];
    [self stopLocalVideo];
    
    [self.trtc exitRoom];
}

- (void)setRole:(TRTCRoleType)role {
    if (role==TRTCRoleAnchor) {
        self.currentPublishingRoomId = self.params.roomId ? [@(self.params.roomId) stringValue] : self.params.strRoomId;
    }
    self.params.role = role;
    [self.trtc switchRole:role];
    
    if (role == TRTCRoleAnchor) {
        [self startLocalAudio];
        [self startLocalVideo];
    } else {
        [self stopLocalAudio];
        [self stopLocalVideo];
    }
}

- (void)switchRole:(TRTCRoleType)role {
    if (role==TRTCRoleAnchor) {
        self.currentPublishingRoomId = self.params.roomId ? [@(self.params.roomId) stringValue] : self.params.strRoomId;
    }
    self.params.role = role;
    [self.trtc switchRole:role];
}

- (void)switchSubRoomRole:(TRTCRoleType)role roomId:(NSString *)roomId {
    if (role==TRTCRoleAnchor) {
        self.currentPublishingRoomId = roomId;
    }
    [self.subClouds[roomId] switchRole:role];
}

- (void)setupTrtcVideo {
    [self.trtc setVideoEncoderParam:self.videoConfig.videoEncConfig];
    [self.trtc setSubStreamEncoderParam:self.videoConfig.videoEncConfig];
    
    [self.trtc enableEncSmallVideoStream:self.videoConfig.isSmallVideoEnabled
                             withQuality:self.videoConfig.smallVideoEncConfig];
    [self.trtc setNetworkQosParam:self.videoConfig.qosConfig];
    
    [self.trtc setLocalRenderParams:self.videoConfig.localRenderParams];
    [self.trtc setGSensorMode:self.videoConfig.isGSensorEnabled ?
        TRTCGSensorMode_UIAutoLayout :
        TRTCGSensorMode_Disable];
    [self.trtc setPriorRemoteVideoStreamType:self.videoConfig.prefersLowQuality ?
        TRTCVideoStreamTypeSmall :
        TRTCVideoStreamTypeBig];
    [self.trtc setWatermark:nil streamType:TRTCVideoStreamTypeBig rect:CGRectZero];
}

- (void)setupTrtcAudio {
    [self.deviceManager setAudioRoute:self.audioConfig.route];
    [self.audioEffectManager enableVoiceEarMonitor:self.audioConfig.isEarMonitoringEnabled];
}

#pragma mark - Set Delegate

- (void)setTRTCDelegate:(id<TRTCCloudDelegate>)delegate{
    [self.trtc setDelegate:delegate];
}

- (void)setAudioFrameDelegate:(id<TRTCAudioFrameDelegate>)delegate{
    [self.trtc setAudioFrameDelegate:delegate];
}

- (int)setLocalVideoRenderDelegate:(id<TRTCVideoRenderDelegate>)delegate pixelFormat:(TRTCVideoPixelFormat)pixelFormat bufferType:(TRTCVideoBufferType)bufferType{
    return [self.trtc setLocalVideoRenderDelegate:delegate pixelFormat:pixelFormat bufferType:bufferType];
}

- (int)setRemoteVideoRenderDelegate:(NSString*)userId delegate:(id<TRTCVideoRenderDelegate>)delegate pixelFormat:(TRTCVideoPixelFormat)pixelFormat bufferType:(TRTCVideoBufferType)bufferType{
    return [self.trtc setRemoteVideoRenderDelegate:userId delegate:delegate pixelFormat:pixelFormat bufferType:bufferType];
}

+ (void)setLogDelegate:(id<TRTCLogDelegate>)logDelegate{
    [TRTCCloud setLogDelegate:logDelegate];
}

#pragma mark - Video Functions

- (void)setVideoSource:(TRTCVideoSource)source {
    self.videoConfig.source = source;
}

- (void)setSubVideoSource:(TRTCVideoSource)source {
    self.videoConfig.subSource = source;
}

- (void)setVideoEnabled:(BOOL)isEnabled {
    [self setVideoEnabled:isEnabled streamType:TRTCVideoStreamTypeBig];
    [self setVideoEnabled:isEnabled streamType:TRTCVideoStreamTypeSub];
}

- (void)setVideoEnabled:(BOOL)isEnabled streamType:(TRTCVideoStreamType)streamType {
    if (streamType == TRTCVideoStreamTypeBig) {
        self.videoConfig.isEnabled = isEnabled;
    }
    
    if (isEnabled) {
        [self startLocalVideo:streamType];
    } else {
        [self stopLocalVideo:streamType];
    }
}

- (void)enableBlackStream:(BOOL)enable size:(CGSize)size {
    NSDictionary *json = @{
        @"api": @"enableBlackStream",
        @"params": @{
            @"enable": @(enable),
            @"width": @(size.width),
            @"height": @(size.height)
        }
    };
    NSString *jsonString = [self jsonStringFrom:json];
    [self.trtc callExperimentalAPI:jsonString];
}

- (void)setVideoMuted:(BOOL)isMuted {
    self.videoConfig.isMuted = isMuted;
    [self.trtc muteLocalVideo:isMuted];
}

- (void)pauseScreenCapture:(BOOL)isPaused {
    self.videoConfig.isScreenCapturePaused = isPaused;
    if (@available(iOS 11.0, *)) {
        if (isPaused) {
            [self.trtc pauseScreenCapture];
        } else {
            [self.trtc resumeScreenCapture];
        }
    }
}

- (void)enableVideoMuteImage:(BOOL)isEnabled {
    [self.trtc setVideoMuteImage:isEnabled ? [UIImage imageNamed:@"background"] : nil fps:3];
}

- (void)enableHEVCEncode:(BOOL)enableHEVC {
    NSDictionary *json = @{
        @"api": @"enableHevcEncode",
        @"params": @{
            @"enable": @(enableHEVC)
        }
    };
    NSString *jsonString = [self jsonStringFrom:json];
    [self.trtc callExperimentalAPI:jsonString];
}

- (void)enableHEVCAbility:(BOOL)enableHEVCAbility {
    // change Ability 测试入口，需要的话临时添加测试代码
}

- (void)setResolution:(TRTCVideoResolution)resolution {
    self.videoConfig.videoEncConfig.videoResolution = resolution;
    [self.trtc setVideoEncoderParam:self.videoConfig.videoEncConfig];
}

- (void)setSubStreamResolution:(TRTCVideoResolution)resolution {
    self.videoConfig.subStreamVideoEncConfig.videoResolution = resolution;
    [self.trtc setSubStreamEncoderParam:self.videoConfig.subStreamVideoEncConfig];
}

- (void)setVideoFps:(int)fps {
    self.videoConfig.videoEncConfig.videoFps = fps;
    [self.trtc setVideoEncoderParam:self.videoConfig.videoEncConfig];
    
    self.videoConfig.smallVideoEncConfig.videoFps = fps;
    [self.trtc enableEncSmallVideoStream:self.videoConfig.isSmallVideoEnabled
                             withQuality:self.videoConfig.smallVideoEncConfig];
}

- (void)setSubStreamVideoFps:(int)fps {
    self.videoConfig.subStreamVideoEncConfig.videoFps = fps;
    [self.trtc setSubStreamEncoderParam:self.videoConfig.subStreamVideoEncConfig];
}

- (void)setVideoBitrate:(int)bitrate {
    self.videoConfig.videoEncConfig.videoBitrate = bitrate;
    [self.trtc setVideoEncoderParam:self.videoConfig.videoEncConfig];
}

- (void)setSubStreamVideoBitrate:(int)bitrate {
    self.videoConfig.subStreamVideoEncConfig.videoBitrate = bitrate;
    [self.trtc setSubStreamEncoderParam:self.videoConfig.subStreamVideoEncConfig];
}

- (void)setQosPreference:(TRTCVideoQosPreference)preference {
    self.videoConfig.qosConfig.preference = preference;
    [self.trtc setNetworkQosParam:self.videoConfig.qosConfig];
}

- (void)setResolutionMode:(TRTCVideoResolutionMode)mode {
    self.videoConfig.videoEncConfig.resMode = mode;
    if (self.videoConfig.streamType == 0) {
        [self.trtc setVideoEncoderParam:self.videoConfig.videoEncConfig];
    } else if (self.videoConfig.streamType == 1) {
        [self.trtc setSubStreamEncoderParam:self.videoConfig.videoEncConfig];
    }
    
    self.videoConfig.smallVideoEncConfig.resMode = mode;
    [self.trtc enableEncSmallVideoStream:self.videoConfig.isSmallVideoEnabled
                             withQuality:self.videoConfig.smallVideoEncConfig];
}

- (void)setVideoFillMode:(TRTCVideoFillMode)mode {
    self.videoConfig.localRenderParams.fillMode = mode;
    [self.trtc setLocalRenderParams:self.videoConfig.localRenderParams];
}

- (void)setLocalMirrorType:(TRTCVideoMirrorType)type {
    self.videoConfig.localRenderParams.mirrorType = type;
    [self.trtc setLocalRenderParams:self.videoConfig.localRenderParams];
}

- (void)setRemoteMirrorEnabled:(BOOL)isEnabled {
    self.videoConfig.isRemoteMirrorEnabled = isEnabled;
    [self.trtc setVideoEncoderMirror:isEnabled];
}

- (void)setWaterMark:(UIImage *)image inRect:(CGRect)rect {
    [self.trtc setWatermark:image streamType:TRTCVideoStreamTypeBig rect:rect];
    [self.trtc setWatermark:image streamType:TRTCVideoStreamTypeSub rect:rect];
}

- (void)switchCamera {
    self.videoConfig.isFrontCamera = !self.videoConfig.isFrontCamera;
    self.videoConfig.isTorchOn = NO;
    [self.deviceManager switchCamera:self.videoConfig.isFrontCamera];
}

- (void)switchTorch {
    self.videoConfig.isTorchOn = !self.videoConfig.isTorchOn;
    [self.deviceManager enableCameraTorch:self.videoConfig.isTorchOn];
}

- (void)setAutoFocusEnabled:(BOOL)isEnabled {
    self.videoConfig.isAutoFocusOn = isEnabled;
    [self.deviceManager enableCameraAutoFocus:isEnabled];
}

- (void)setGSensorEnabled:(BOOL)isEnable {
    self.videoConfig.isGSensorEnabled = isEnable;
    [self.trtc setGSensorMode:isEnable ? TRTCGSensorMode_UIAutoLayout : TRTCGSensorMode_Disable];
}

- (void)setQosControlMode:(TRTCQosControlMode)mode {
    self.videoConfig.qosConfig.controlMode = mode;
    [self.trtc setNetworkQosParam:self.videoConfig.qosConfig];
}

- (void)setSmallVideoEnabled:(BOOL)isEnabled {
    self.videoConfig.isSmallVideoEnabled = isEnabled;
    [self.trtc enableEncSmallVideoStream:isEnabled
                             withQuality:self.videoConfig.smallVideoEncConfig];
}

- (void)setPrefersLowQuality:(BOOL)prefersLowQuality {
    self.videoConfig.prefersLowQuality = prefersLowQuality;
    TRTCVideoStreamType type = prefersLowQuality ?
        TRTCVideoStreamTypeSmall :
        TRTCVideoStreamTypeBig;
    [self.trtc setPriorRemoteVideoStreamType:type];
}

- (void)enableSharpnessEnhancement:(BOOL)enable {
    [[self.trtc getBeautyManager] enableSharpnessEnhancement:enable];
}

- (void)setDebugViewMargin:(NSString *)userId margin:(TXEdgeInsets)margin{
    [self.trtc setDebugViewMargin:userId margin:margin];
}

- (void)setCustomProcessFormat:(TRTCVideoPixelFormat)format {
    self.videoConfig.format = format;
    TRTCVideoBufferType type = format == TRTCVideoPixelFormat_Texture_2D
        ? TRTCVideoBufferType_Texture
        : TRTCVideoBufferType_PixelBuffer;
    
    [self.customPreprocessor invalidateBindedTexture];
    if (format == TRTCVideoPixelFormat_Unknown) {
        [self.trtc setLocalVideoProcessDelegete:nil pixelFormat:format bufferType:TRTCVideoBufferType_Unknown];
    } else {
        [self.trtc setLocalVideoProcessDelegete:self pixelFormat:format bufferType:type];
    }
}

- (void)setCustomBrightness:(CGFloat)brightness {
    self.videoConfig.brightness = brightness;
    self.customPreprocessor.brightness = brightness;
}

- (void)showDebugView:(NSInteger)showType{
    [self.trtc showDebugView:showType];
}

- (void)startRemoteView:(NSString *)userId streamType:(TRTCVideoStreamType)type view:(TXView *)view {
    [self.trtc startRemoteView:userId streamType:type view:view];
}

- (void)startSubRoomRemoteView:(NSString *)userId roomId:(NSString *)roomId streamType:(TRTCVideoStreamType)type view:(TXView *)view {
    [self.subClouds[roomId] startRemoteView:userId streamType:type view:view];
}

- (void)updateRemoteView:(TXView *)view streamType:(TRTCVideoStreamType)type forUser:(NSString *)userId {
    [self.trtc updateRemoteView:view streamType:type forUser:userId];
}

- (void)updateSubRoomRemoteView:(TXView *)view roomId:(NSString *)roomId streamType:(TRTCVideoStreamType)type forUser:(NSString *)userId {
    [self.subClouds[roomId] updateRemoteView:view streamType:type forUser:userId];
}

- (void)stopSubRoomRemoteView:(NSString *)userId roomId:(NSString *)roomId streamType:(TRTCVideoStreamType)type {
    [self.subClouds[roomId] stopRemoteView:userId streamType:type];
}

- (void)stopRemoteView:(NSString *)userId streamType:(TRTCVideoStreamType)type {
    [self.trtc stopRemoteView:userId streamType:type];
}

- (void)stopAllRemoteView {
    [self.trtc stopAllRemoteView];
}

- (void)setRemoteViewFillMode:(NSString*)userId mode:(TRTCVideoFillMode)mode {
    [self.trtc setRemoteViewFillMode:userId mode:mode];
}

- (void)setRemoteViewRotation:(NSString*)userId rotation:(TRTCVideoRotation)rotation {
    [self.trtc setRemoteViewRotation:userId rotation:rotation];
}

- (void)startRemoteSubStreamView:(NSString *)userId view:(TXView *)view {
    [self.trtc startRemoteSubStreamView:userId view:view];
}

- (void)stopRemoteSubStreamView:(NSString *)userId {
    [self.trtc stopRemoteSubStreamView:userId];
}

- (void)setLocalViewFillMode:(TRTCVideoFillMode)mode {
    [self.trtc setLocalViewFillMode:mode];
}

- (void)setLocalViewRotation:(TRTCVideoRotation)rotation {
    [self.trtc setLocalViewRotation:rotation];
}

#if TARGET_OS_IPHONE
- (void)setLocalViewMirror:(TRTCLocalVideoMirrorType)mirror {
    [self.trtc setLocalViewMirror:mirror];
}
#elif TARGET_OS_MAC
- (void)setLocalViewMirror:(BOOL)mirror {
    [self.trtc setLocalViewMirror:mirror];
}
#endif

- (void)setRemoteSubStreamViewFillMode:(NSString *)userId mode:(TRTCVideoFillMode)mode {
    [self.trtc setRemoteSubStreamViewFillMode:userId mode:mode];
}

- (void)setLocalVideoView:(UIView *)videoView {
    _localVideoView = videoView;
    if (_renderTester) {
        [_renderTester addUser:nil videoView:_localVideoView];
    }
}

- (void)updateCustomRenderView:(UIImageView *)videoView forUser:(NSString *)userId
{
    if (_renderTester) {
        [_renderTester addUser:userId videoView:videoView];
    }
}
- (void)updateLocalView:(UIView *)videoView {
    [self.trtc updateLocalView:videoView];
}

- (void)setCustomVideo:(AVAsset *)videoAsset {
    self.videoConfig.videoAsset = videoAsset;
}

- (void)pushVideoStreamInSubRoom:(NSString *)roomId push:(BOOL)isPush
{
    self.videoConfig.isMuted = !isPush;
    [[_subClouds objectForKey:roomId] muteLocalVideo:!isPush];
}

#pragma mark - Audio Functions

- (void)setAudioEnabled:(BOOL)isEnabled {
    self.audioConfig.isEnabled = isEnabled;
    if (isEnabled) {
        [self setupTrtcAudio];
        [self startLocalAudio];
    } else {
        [self stopLocalAudio];
    }
}

- (void)setAudioQuality:(TRTCAudioQuality)quality {
    [self.trtc setAudioQuality:quality];
}

- (void)setAudioCustomCaptureEnabled:(BOOL)isEnabled {
    self.audioConfig.isCustomCapture = isEnabled;
}

- (void)setSubStreamCaptureEnabled:(BOOL)isEnabled {
    self.videoConfig.isCustomSubStreamCapture = isEnabled;
}

- (void)setAudioRoute:(TRTCAudioRoute)route {
    self.audioConfig.route = route;
    [self.deviceManager setAudioRoute:route];
}

- (void)setVolumeType:(TRTCSystemVolumeType)type {
    [self.deviceManager setSystemVolumeType:type];
}

- (void)setEarMonitoringEnabled:(BOOL)isEnabled {
    self.audioConfig.isEarMonitoringEnabled = isEnabled;
    [self.audioEffectManager enableVoiceEarMonitor:isEnabled];
}

- (void)setAecEnabled:(BOOL)isEnabled {
    self.audioConfig.isAecEnabled = isEnabled;
    [self setExperimentConfig:@"enableAudioAEC" params:@{ @"enable": @(isEnabled) }];
}

- (void)setAgcEnabled:(BOOL)isEnabled {
    self.audioConfig.isAgcEnabled = isEnabled;
    [self setExperimentConfig:@"enableAudioAGC" params:@{ @"enable": @(isEnabled) }];
}

- (void)setAnsEnabled:(BOOL)isEnabled {
    self.audioConfig.isAnsEnabled = isEnabled;
    [self setExperimentConfig:@"enableAudioANS" params:@{ @"enable": @(isEnabled) }];
}

- (void)setVolumeEvaluationEnabled:(BOOL)isEnabled {
    self.audioConfig.isVolumeEvaluationEnabled = isEnabled;
    [self.trtc enableAudioVolumeEvaluation:isEnabled ? 300 : 0];
    if ([self.managerDelegate respondsToSelector:@selector(roomSettingsManager:didSetVolumeEvaluation:)]) {
        [self.managerDelegate roomSettingsManager:self didSetVolumeEvaluation:isEnabled];
    }
}

- (void)setAudioMuted:(BOOL)isMuted {
    self.audioConfig.isMuted = isMuted;
    [self.trtc muteLocalAudio:isMuted];
    if ([self.managerDelegate respondsToSelector:@selector(onMuteLocalAudio:)]) {
        [self.managerDelegate onMuteLocalAudio:isMuted];
    }
}

- (void)muteRemoteAudio:(NSString *)userId mute:(BOOL)mute {
    [self.trtc muteRemoteAudio:userId mute:mute];
}

- (void)muteAllRemoteAudio:(BOOL)mute {
    [self.trtc muteAllRemoteAudio:mute];
}

- (void)setRemoteAudioVolume:(NSString *)userId volume:(int)volume {
    [self.trtc setRemoteAudioVolume:userId volume:volume];
}

- (void)setCaptureVolume:(NSInteger)volume {
    [self.trtc setAudioCaptureVolume:volume];
}

- (void)setPlayoutVolume:(NSInteger)volume {
    [self.trtc setAudioPlayoutVolume:volume];
}

- (NSInteger)captureVolume {
    return [self.trtc getAudioCaptureVolume];
}

- (NSInteger)playoutVolume {
    return [self.trtc getAudioPlayoutVolume];
}

- (void)setEarMonitoringVolume:(NSInteger)volume {
    [[self.trtc getAudioEffectManager] setVoiceEarMonitorVolume:volume];
}

- (void)pushAudioStreamInSubRoom:(NSString *)roomId push:(BOOL)isPush
{
    self.audioConfig.isMuted = !isPush;
    [[_subClouds objectForKey:roomId] muteLocalAudio:!isPush];
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
        [self.trtc setMixTranscodingConfig:nil];
        return;
    } else if (self.streamConfig.mixMode == TRTCTranscodingConfigMode_Template_PureAudio ||
               self.streamConfig.mixMode == TRTCTranscodingConfigMode_Template_ScreenSharing) {
        TRTCTranscodingConfig *config = [TRTCTranscodingConfig new];
        config.appId = (int) self.appId;
        config.bizId = (int) self.bizId;
        config.mode = self.streamConfig.mixMode;
        config.streamId = self.streamConfig.streamId;
        [self.trtc setMixTranscodingConfig:config];
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
    
    // 辅路
    TRTCMixUser* broadCasterSub = [TRTCMixUser new];
    broadCasterSub.zOrder = 2 + index;
    broadCasterSub.userId = PLACE_HOLDER_LOCAL_SUB;
    broadCasterSub.streamType = TRTCVideoStreamTypeSub;
    if (index < 3) {
        // 前三个小画面靠右从下往上铺
        broadCasterSub.rect = CGRectMake(videoWidth - offsetX - subWidth, videoHeight - offsetY - index * subHeight - subHeight, subWidth, subHeight);
    } else if (index < 6) {
        // 后三个小画面靠左从下往上铺
        broadCasterSub.rect = CGRectMake(offsetX, videoHeight - offsetY - (index - 3) * subHeight - subHeight, subWidth, subHeight);
    } else {
        // 最多只叠加六个小画面
    }
    [mixUsers addObject:broadCasterSub];
    
    config.mixUsers = mixUsers;
    config.mode = self.streamConfig.mixMode;
    if (!_trtc) {
        _trtc = [TRTCCloud sharedInstance];
    }
    [_trtc setMixTranscodingConfig:config];
}

- (void)setMixBackgroundImage:(NSString *)imageId {
    self.streamConfig.backgroundImage = imageId;
    [self updateCloudMixtureParams];
}

- (void)setMixStreamId:(NSString *)streamId {
    self.streamConfig.streamId = streamId;
    [self updateCloudMixtureParams];
}
- (void)update3DAudioEffect{
    [self.trtc enable3DSpatialAudioEffect:YES];
    int position[3] = {0,0,0};
    float axisForward [3] = {1,0,0};
    float axisRight [3] = {0,1,0};
    float axisUp[3] = {0,0,1};
    [self.trtc updateSelf3DSpatialPosition:position axisForward:axisForward axisRight:axisRight axisUp:axisUp];
    [self.trtc set3DSpatialReceivingRange:@"123" range:100];
 
    [self.trtc updateRemote3DSpatialPosition:@"123" position:position];
}
-(void)setPublishMediaStreamWithRoomId:(NSString *)roomid{
    TRTCPublishTarget *target = [[TRTCPublishTarget alloc]init];
    target.mode = TRTCPublishMixStreamToRoom;
   // [self.trtc setGSensorMode:TRTCGSensorMode_UIFixLayout];
    target.mixStreamIdentity.userId = [NSString stringWithFormat:@"%@_mix",_params.userId];
    target.mixStreamIdentity.intRoomId = roomid.integerValue;
    
    TRTCStreamEncoderParam *params = [TRTCStreamEncoderParam new];
   // params
    params.videoEncodedFPS = 15;
    params.videoEncodedWidth = 720;
    params.videoEncodedHeight = 1280;
    params.videoEncodedGOP = 1;
    TRTCStreamMixingConfig *config = [TRTCStreamMixingConfig new];

    NSMutableArray *videoLayerList = [NSMutableArray array];
    __block int index = 0;
    TRTCUser *anchor  = [TRTCUser new];
    anchor.userId = _params.userId;
    TRTCVideoLayout *layer = [TRTCVideoLayout new];
    layer.rect = CGRectMake(0, 0, 720, 1280);
    layer.zOrder = 1;
    [videoLayerList addObject:layer];
    [self.remoteUserManager.remoteUsers enumerateKeysAndObjectsUsingBlock:^(NSString * _Nonnull userID, TRTCRemoteUserConfig * _Nonnull obj, BOOL * _Nonnull stop) {
        
        int videoWidth  = 720;
        int videoHeight = 1280;
        
        // 小画面宽高
        int subWidth  = 180;
        int subHeight = 320;
        
        int offsetX = 5;
        int offsetY = 50;
        
        TRTCUser *audience = [TRTCUser new];
        TRTCVideoLayout *layer = [TRTCVideoLayout new];
        audience.userId = userID;
        layer.fixedVideoUser = audience;
        layer.zOrder = 2 + index;
        if (index < 3) {
            // 前三个小画面靠右从下往上铺
            layer.rect = CGRectMake(videoWidth - offsetX - subWidth, videoHeight - offsetY - index * subHeight - subHeight, subWidth, subHeight);
        } else if (index < 6) {
            // 后三个小画面靠左从下往上铺
            layer.rect = CGRectMake(offsetX, videoHeight - offsetY - (index - 3) * subHeight - subHeight, subWidth, subHeight);
        } else {
            // 最多只叠加六个小画面
        }
        [videoLayerList addObject:layer];
        ++index;
     
    }];
    config.videoLayoutList = videoLayerList;
    [self.trtc startPublishMediaStream:target encoderParam:params  mixingConfig:config];
}

#pragma mark - Message

- (BOOL)sendCustomMessage:(NSString *)message {
    NSData * _Nullable data = [message dataUsingEncoding:NSUTF8StringEncoding];
    if (data != nil) {
        return [self.trtc sendCustomCmdMsg:0 data:data reliable:YES ordered:NO];
    }
    return NO;
}

- (BOOL)sendSEIMessage:(NSString *)message repeatCount:(NSInteger)repeatCount {
    NSData * _Nullable data = [message dataUsingEncoding:NSUTF8StringEncoding];
    if (data != nil) {
        return [self.trtc sendSEIMsg:data repeatCount:repeatCount == 0 ? 1 : (int)repeatCount];
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
    
    [self.trtc connectOtherRoom:jsonString];
    [self.remoteUserManager addUser:userId roomId:roomId];
}

- (void)stopCrossRomm {
    self.isCrossingRoom = NO;
    
    [self.trtc disconnectOtherRoom];
}

#pragma mark - Speed Test

- (void)startSpeedTest:(uint32_t)sdkAppId userId:(NSString *)userId userSig:(NSString *)userSig completion:(void(^)(TRTCSpeedTestResult* result, NSInteger completedCount, NSInteger totalCount))completion{
    [self.trtc startSpeedTest:sdkAppId userId:userId userSig:userSig completion:completion];
}

- (void)stopSpeedTest{
    [self.trtc stopSpeedTest];
}

#pragma mark - Local Record
- (void)startLocalRecording {
    self.enableLocalRecord = YES;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSDateFormatter * formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"yyyyMMddHHmmss"];
    NSDate *NowDate = [NSDate dateWithTimeIntervalSince1970:now];
    NSString *timeStr = [formatter stringFromDate:NowDate];
    NSString *fileName = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"mediaRecord%@.mp4", timeStr]];
    TRTCLocalRecordingParams *params = [[TRTCLocalRecordingParams alloc] init];
    params.filePath = fileName;
    params.interval = 1000;
    params.recordType = self.localRecordType;
    [self.trtc startLocalRecording:params];
}

- (void)stopLocalRecording {
    self.enableLocalRecord = NO;
    [self.trtc stopLocalRecording];
}

#pragma mark - Others

- (void)playCustomVideoOfUser:(NSString *)userId inView:(UIImageView *)view {
    [self.trtc startRemoteView:userId streamType:TRTCVideoStreamTypeBig view:view];
    [self.renderTester addUser:userId videoView:view];
    [self.trtc setRemoteVideoRenderDelegate:userId
                                   delegate:self.renderTester
                                pixelFormat:TRTCVideoPixelFormat_NV12
                                 bufferType:TRTCVideoBufferType_PixelBuffer];
}

#pragma mark - Private

- (void)startLocalAudio {
    if (!self.audioConfig.isEnabled || self.isLiveAudience) {
        return;
    }
    if (self.audioConfig.isCustomCapture) {
        [self.trtc enableCustomAudioCapture:YES];
        [CustomAudioFileReader sharedInstance].delegate = self;
        [[CustomAudioFileReader sharedInstance] start:48000 channels:1 framLenInSample:960];
    } else {
        [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayAndRecord mode:AVAudioSessionModeDefault options:109 error:nil];

        [[AVAudioSession sharedInstance]setActive:YES error:nil];
        [self.trtc startLocalAudio];
    }
}

- (void)stopLocalAudio {
    if (self.audioConfig.isCustomCapture) {
        [self.trtc enableCustomAudioCapture:NO];
        [[CustomAudioFileReader sharedInstance] stop];
        [CustomAudioFileReader sharedInstance].delegate = nil;
    } else {
        [self.trtc stopLocalAudio];
    }
}

- (void)startSubStreamVideo {
    if (self.videoConfig.subSource == TRTCVideoSourceCustom && (self.videoConfig.source == TRTCVideoSourceCamera ||
                                                                self.videoConfig.source == TRTCVideoSourceCustom ||
                                                                self.videoConfig.source == TRTCVideoSourceAppScreen ||
                                                                self.videoConfig.source == TRTCVideoSourceDeviceScreen)) {
        [self setupVideoCapture];
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            self.subVideoCaptureTester.streamType = 1;
            [self.trtc enableCustomVideoCapture:TRTCVideoStreamTypeSub enable:YES];
            [self.subVideoCaptureTester start];
        });
    } else if (self.videoConfig.subSource == TRTCVideoSourceAppScreen && (self.videoConfig.source == TRTCVideoSourceCamera ||
                                                                          self.videoConfig.source == TRTCVideoSourceCustom)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (@available(iOS 13.0, *)) {
                [self.trtc startScreenCaptureInApp:TRTCVideoStreamTypeSub encParam:self.videoConfig.subStreamVideoEncConfig];
            }
        });
    } else if (self.videoConfig.subSource == TRTCVideoSourceDeviceScreen && (self.videoConfig.source == TRTCVideoSourceCamera ||
                                                                             self.videoConfig.source == TRTCVideoSourceCustom)) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            if (@available(iOS 11.0, *)) {
                [self.trtc startScreenCaptureByReplaykit:TRTCVideoStreamTypeSub encParam:self.videoConfig.subStreamVideoEncConfig appGroup:APPGROUP];
            }
        });
    }
}

- (void)startLocalVideo {
    [self startLocalVideo:TRTCVideoStreamTypeBig];
    
    if (self.videoConfig.subSource != 0) {
        [self startLocalVideo:TRTCVideoStreamTypeSub];
    }
}

- (void)startLocalVideo:(TRTCVideoStreamType)streamType {
    if (!self.videoConfig.isEnabled || self.isLiveAudience) {
        return;
    }
    
    if (streamType == TRTCVideoStreamTypeBig) {
        self.videoConfig.isH265Enabled = YES;
        switch (self.videoConfig.source) {
            case TRTCVideoSourceCamera:
                [self.trtc startLocalPreview:self.videoConfig.isFrontCamera
                                        view:self.localVideoView];
                break;
            case TRTCVideoSourceCustom:
                if (self.videoConfig.videoAsset) {
                    // 使用视频文件
                    [self setupVideoCapture];
                    [self.trtc enableCustomVideoCapture:YES];
                    [self.trtc setLocalVideoRenderDelegate:self.renderTester
                                               pixelFormat:TRTCVideoPixelFormat_NV12
                                                bufferType:TRTCVideoBufferType_PixelBuffer];
                    [self.renderTester addUser:nil videoView:self.localVideoView];
                    [self.videoCaptureTester start];
                }
                break;
            case TRTCVideoSourceAppScreen:
                if (@available(iOS 11.0, *)) {
                    self.videoConfig.videoEncConfig.videoResolution = TRTCVideoResolution_1280_720;
                    self.videoConfig.videoEncConfig.videoFps = 10;
                    self.videoConfig.videoEncConfig.videoBitrate = 1600;
                    [self.trtc startScreenCaptureInApp:self.videoConfig.videoEncConfig];
                }
                break;
            case TRTCVideoSourceDeviceScreen:
                if (@available(iOS 11.0, *)) {
                    self.videoConfig.videoEncConfig.videoResolution = TRTCVideoResolution_1280_720;
                    self.videoConfig.videoEncConfig.videoFps = 10;
                    self.videoConfig.videoEncConfig.videoBitrate = 1600;
                    [self.trtc startScreenCaptureByReplaykit:self.videoConfig.videoEncConfig appGroup:APPGROUP];
                }
                break;
        }
    } else if (streamType == TRTCVideoStreamTypeSub) {
        [self startSubStreamVideo];
    }
}

- (void)stopLocalVideo {
    [self stopLocalVideo:TRTCVideoStreamTypeBig];
    [self stopLocalVideo:TRTCVideoStreamTypeSub];
}

- (void)stopLocalVideo:(TRTCVideoStreamType)streamType {
    if (streamType == TRTCVideoStreamTypeBig) {
        switch (self.videoConfig.source) {
            case TRTCVideoSourceCamera:
                [self.trtc stopLocalPreview];
                break;
            case TRTCVideoSourceCustom:
                [self.trtc enableCustomVideoCapture:NO];
                if (self.videoCaptureTester) {
                    [self.videoCaptureTester stop];
                    self.videoCaptureTester = nil;
                }
                break;
            case TRTCVideoSourceAppScreen: case TRTCVideoSourceDeviceScreen:
                if (@available(iOS 11.0, *)) {
                    [self.trtc stopScreenCapture];
                }
                break;
        }
    } else if (streamType == TRTCVideoStreamTypeSub) {
        switch (self.videoConfig.subSource) {
            case TRTCVideoSourceCamera:
                break;
            case TRTCVideoSourceCustom:
                [self.trtc enableCustomVideoCapture:TRTCVideoStreamTypeSub enable:NO];
                if (self.subVideoCaptureTester) {
                    [self.subVideoCaptureTester stop];
                    self.subVideoCaptureTester = nil;
                }
                break;
            case TRTCVideoSourceAppScreen: case TRTCVideoSourceDeviceScreen:
                if (@available(iOS 11.0, *)) {
                    [self.trtc stopScreenCapture];
                }
                break;
        }
    }
}

- (BOOL)isLiveAudience {
    return self.scene == TRTCAppSceneLIVE && self.params.role == TRTCRoleAudience;
}

- (void)setupVideoCapture {
    if (!self.videoCaptureTester){
        self.videoCaptureTester = [[TestSendCustomVideoData alloc]
                                   initWithTRTCCloud:[TRTCCloud sharedInstance]
                                   mediaAsset:self.videoConfig.videoAsset];
        [self setVideoFps:self.videoCaptureTester.mediaReader.fps];
    }
    
    if (!self.subVideoCaptureTester){
        self.subVideoCaptureTester = [[TestSendCustomVideoData alloc]
                                   initWithTRTCCloud:[TRTCCloud sharedInstance]
                                   mediaAsset:self.videoConfig.videoAsset];
        [self setSubStreamVideoFps:self.subVideoCaptureTester.mediaReader.fps];
    }
}

- (void)setExperimentConfig:(NSString *)key params:(NSDictionary *)params {
    NSDictionary *json = @{
        @"api": key,
        @"params": params
    };
    [self.trtc callExperimentalAPI:[self jsonStringFrom:json]];
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
    frame.sampleRate = sampleRate;
    frame.channels = channels;
    frame.timestamp = timestampMs;
    
    [self.trtc sendCustomAudioData:frame];
}

#pragma mark - enable vod

- (void)setEnableVOD:(BOOL)enableVOD {
    _enableVOD = enableVOD;
    if (self.managerDelegate && [self.managerDelegate respondsToSelector:@selector(roomSettingsManager:enableVOD:)]) {
        [self.managerDelegate roomSettingsManager:self enableVOD:enableVOD];
    }
}

- (void)setEnableAttachVodToTRTC:(BOOL)enableAttachVodToTRTC {
    if (_videoConfig.subSource == TRTCVideoSourceNone) {
        _enableAttachVodToTRTC = enableAttachVodToTRTC;
        if (self.managerDelegate && [self.managerDelegate respondsToSelector:@selector(roomSettingsManager:enableVODAttachToTRTC:)]){
            [self.managerDelegate roomSettingsManager:self enableVODAttachToTRTC:enableAttachVodToTRTC];
        }
    }
}

#pragma mark - TRTCVideoFrameDelegate

- (uint32_t)onProcessVideoFrame:(TRTCVideoFrame * _Nonnull)srcFrame dstFrame:(TRTCVideoFrame * _Nonnull)dstFrame {
    if (srcFrame.pixelFormat == TRTCVideoPixelFormat_Texture_2D) {
//        Solution 1: Use texture generated in app
        dstFrame.textureId = [self.customPreprocessor processTexture:srcFrame.textureId
                                                               width:srcFrame.width
                                                              height:srcFrame.height];
        
//        Solution 2: Use texture generated in sdk
//        [self.customPreprocessor processFrame:srcFrame dstFrame:dstFrame];
    } else if (srcFrame.data) {
        memcpy(dstFrame.data.bytes, srcFrame.data.bytes, srcFrame.data.length);
    } else if (srcFrame.pixelFormat == TRTCVideoPixelFormat_NV12 || srcFrame.pixelFormat == TRTCVideoPixelFormat_32BGRA) {
        CIImage *image = [self.yuvPreprocessor filterPixelBuffer:srcFrame];
        [self.yuvPreprocessor.fContex render:image toCVPixelBuffer:dstFrame.pixelBuffer];
    } else if (srcFrame.pixelFormat == TRTCVideoPixelFormat_I420) {
        dstFrame.pixelBuffer = srcFrame.pixelBuffer;
    }
    return 0;
}

@end


@implementation TRTCSubRoomDelegate
- (instancetype)initWithRoomId:(NSString *)roomId manager:(TRTCCloudManager*) manager {
    if (self = [super init]) {
        _subRoomId = roomId;
        _weakManager = manager;
    }
    return self;
}

//从TRTCSubClouds接收到回调后，转发给TRTCCloudManager的监听者（目前是TRTCMainViewController）

- (void)onEnterRoom:(NSInteger)result {
    if ([_weakManager.managerDelegate respondsToSelector:@selector(onEnterSubRoom:result:)]) {
        [_weakManager.managerDelegate onEnterSubRoom:_subRoomId result:result];
    }
}

- (void)onExitRoom:(NSInteger)reason {
    if ([_weakManager.managerDelegate respondsToSelector:@selector(onExitSubRoom:reason:)]) {
        [_weakManager.managerDelegate onExitSubRoom:_subRoomId reason:reason];
    }
}

- (void)onUserAudioAvailable:(NSString *)userId available:(BOOL)available {
    if ([_weakManager.managerDelegate respondsToSelector:@selector(onSubRoomUserAudioAvailable:userId:available:)]) {
        [_weakManager.managerDelegate onSubRoomUserAudioAvailable:_subRoomId userId:userId available:available];
    }
}

- (void)onUserVideoAvailable:(NSString *)userId available:(BOOL)available {
    if ([_weakManager.managerDelegate respondsToSelector:@selector(onSubRoomUserVideoAvailable:userId:available:)]) {
        [_weakManager.managerDelegate onSubRoomUserVideoAvailable:_subRoomId userId:userId available:available];
    }
}

- (void)onRemoteUserEnterRoom:(NSString *)userId {
    if ([_weakManager.managerDelegate respondsToSelector:@selector(onSubRoomRemoteUserEnterRoom:userId:)]) {
        [_weakManager.managerDelegate onSubRoomRemoteUserEnterRoom:_subRoomId userId:userId];
    }
}

- (void)onRemoteUserLeaveRoom:(NSString *)userId reason:(NSInteger)reason {
    if ([_weakManager.managerDelegate respondsToSelector:@selector(onSubRoomRemoteUserLeaveRoom:userId:reason:)]) {
        [_weakManager.managerDelegate onSubRoomRemoteUserLeaveRoom:_subRoomId userId:userId reason:reason];
    }
}
@end

