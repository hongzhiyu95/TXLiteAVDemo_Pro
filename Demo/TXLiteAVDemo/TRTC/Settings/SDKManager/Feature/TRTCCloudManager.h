/*
* Module:   TRTCCloudManager
*
* Function: TRTC SDK的视频、音频以及消息功能
*
*    1. 视频功能包括摄像头的设置，视频编码的设置和视频流的设置
*
*    2. 音频功能包括采集端的设置（采集开关、增益、降噪、耳返、采样率），以及播放端的设置（音频通道、音量类型、音量提示）
*
*    3. 消息发送有两种：自定义消息和SEI消息，具体适用场景和限制可参照TRTCCloud.h中sendCustomCmdMsg和sendSEIMsg的接口注释
*/

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

#import "TRTCVideoConfig.h"
#import "TRTCAudioConfig.h"
#import "TRTCStreamConfig.h"
#import "TRTCRemoteUserManager.h"

#import "TRTCCloud.h"
#import "TRTCCloudDef.h"

NS_ASSUME_NONNULL_BEGIN

@class TRTCCloudManager;

@protocol TRTCCloudManagerDelegate <NSObject>

@optional
- (void)roomSettingsManager:(TRTCCloudManager *)manager didSetVolumeEvaluation:(BOOL)isEnabled;
- (void)roomSettingsManager:(TRTCCloudManager *)manager enableVOD:(BOOL)isEnabled;
- (void)roomSettingsManager:(TRTCCloudManager *)manager enableVODAttachToTRTC:(BOOL)isEnabled;
- (void)onMuteLocalAudio:(BOOL)isMute;
- (void)onEnterSubRoom:(NSString *)roomId result:(NSInteger)result;
- (void)onExitSubRoom:(NSString *)roomId reason:(NSInteger)reason;
- (void)onSubRoomUserAudioAvailable:(NSString *)roomId userId:(NSString *)userId available:(BOOL)available;
- (void)onSubRoomUserVideoAvailable:(NSString *)roomId userId:(NSString *)userId available:(BOOL)available;
- (void)onSubRoomRemoteUserEnterRoom:(NSString *)roomId userId:(NSString *)userId;
- (void)onSubRoomRemoteUserLeaveRoom:(NSString *)roomId userId:(NSString *)userId reason:(NSInteger)reason;
@end


@interface TRTCCloudManager : NSObject

@property (weak, nonatomic) id<TRTCCloudManagerDelegate> managerDelegate;
@property (nonatomic) TRTCAppScene scene;
@property (strong, nonatomic) TRTCParams *params;
@property (strong, nonatomic, readonly) TRTCCloud *trtc;

@property (strong, nonatomic, readonly) TRTCVideoConfig *videoConfig;
@property (strong, nonatomic, readonly) TRTCAudioConfig *audioConfig;
@property (strong, nonatomic, readonly) TRTCStreamConfig *streamConfig;
@property (nonatomic) NSString* currentPublishingRoomId;
@property (strong, nonatomic) TRTCRemoteUserManager *remoteUserManager;
@property (strong, nonatomic, nullable) UIView *localVideoView;
@property (nonatomic) BOOL enableVOD;
@property (nonatomic) BOOL enableAttachVodToTRTC;
// 本地录制相关
@property (nonatomic) TRTCRecordType localRecordType;
@property (nonatomic) BOOL enableLocalRecord;

- (instancetype)initWithParams:(TRTCParams *)params
                       scene:(TRTCAppScene)scene
                       appId:(NSInteger)appId
                       bizId:(NSInteger)bizId NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

/// 用当前的配置项设置TRTC Engine
- (void)setupTrtc;

//销毁TRTC Engine
- (void)destroyTrtc;

#pragma mark - Room

/// 加入房间
- (void)enterRoom;

/// 加入子房间
- (void)enterSubRoom:(TRTCParams *)params;

/// 离开子房间
- (void)exitSubRoom:(NSString *)roomId;

///离开所有子房间
- (void)exitAllSubRoom;

/// 切换到房间
- (void)switchRoom:(TRTCSwitchRoomConfig *)switchRoomConfig;

/// 退出房间
- (void)exitRoom;

/// 切换身份，调用此方法时，TRTCCloudManager会自动开关本地音视频
/// @param role 用户在房间的身份：主播或观众
- (void)setRole:(TRTCRoleType)role;

/// 切换主房间身份
/// @param role 用户在房间的身份：主播或观众
- (void)switchRole:(TRTCRoleType)role;

/// 切换子房间身份
/// @param role 用户在房间的身份：主播或观众
/// @param roomId 房间号
- (void)switchSubRoomRole:(TRTCRoleType)role roomId:(NSString *)roomId;

#pragma mark - Set Delegate

/// 设置回调
/// @param delegate trtc回调
- (void)setTRTCDelegate:(id<TRTCCloudDelegate>)delegate;

/// 设置音频数据回调
/// @param delegate trtc的音频数据回调
- (void)setAudioFrameDelegate:(id<TRTCAudioFrameDelegate>)delegate;

/// 设置本地视频数据回调
/// @param delegate trtc的本地视频数据回调
- (int)setLocalVideoRenderDelegate:(id<TRTCVideoRenderDelegate>)delegate pixelFormat:(TRTCVideoPixelFormat)pixelFormat bufferType:(TRTCVideoBufferType)bufferType;

/// 设置远端视频数据回调
/// @param delegate trtc的远端视频数据回调
- (int)setRemoteVideoRenderDelegate:(NSString*)userId delegate:(id<TRTCVideoRenderDelegate>)delegate pixelFormat:(TRTCVideoPixelFormat)pixelFormat bufferType:(TRTCVideoBufferType)bufferType;

/// 设置日志信息回调
/// @param logDelegate trtc的日志信息回调
+ (void)setLogDelegate:(id<TRTCLogDelegate>)logDelegate;

#pragma mark - Video Functions

/// 设置视频采集源
/// @param source 视频采集源
- (void)setVideoSource:(TRTCVideoSource)source;

/// 设置视频采集源
/// @param source 视频采集源
- (void)setSubVideoSource:(TRTCVideoSource)source;

/// 设置主路、辅路视频采集
/// @param isEnabled 开启视频采集
- (void)setVideoEnabled:(BOOL)isEnabled;

/// 设置对应 streamType 视频采集
/// @param isEnabled 开启视频采集
/// @param streamType 视频流类型
- (void)setVideoEnabled:(BOOL)isEnabled streamType:(TRTCVideoStreamType)streamType;

/// 设置视频推送
/// @param isMuted 推送关闭
- (void)setVideoMuted:(BOOL)isMuted;

/// 设置推送纯黑视频帧
/// @param enable 开启或关闭
/// @param size 黑帧size，默认CGSizeZero
- (void)enableBlackStream:(BOOL)enable size:(CGSize)size;

/// 暂停屏幕采集
/// @param isPaused 暂时采集
- (void)pauseScreenCapture:(BOOL)isPaused;

/// 设置垫片推流
/// @param isEnabled 开启垫片推流
- (void)enableVideoMuteImage:(BOOL)isEnabled;

/// 设置HEVC编码
/// @param enableHEVC 开启HEVC编码
- (void)enableHEVCEncode:(BOOL)enableHEVC;

/// 设置HEVC编解码能力
/// （测试使用，iOS设备如无意外均支持H265）
/// 该接口以设备实际支持情况为准
/// @param enableHEVCAbility 是否支持HEVC编解码
- (void)enableHEVCAbility:(BOOL)enableHEVCAbility;

/// 设置分辨率
/// @param resolution 分辨率
- (void)setResolution:(TRTCVideoResolution)resolution;

/// 设置辅路分辨率
/// @param resolution 分辨率
- (void)setSubStreamResolution:(TRTCVideoResolution)resolution;

/// 设置帧率
/// @param fps 帧率
- (void)setVideoFps:(int)fps;

/// 设置帧率
/// @param fps 帧率
- (void)setSubStreamVideoFps:(int)fps;

/// 设置码率
/// @param bitrate 码率
- (void)setVideoBitrate:(int)bitrate;

/// 设置辅路码率
/// @param bitrate 码率
- (void)setSubStreamVideoBitrate:(int)bitrate;

/// 设置画质偏好
/// @param preference 画质偏好
- (void)setQosPreference:(TRTCVideoQosPreference)preference;

/// 设置画面方向
/// @param mode 画面方向
- (void)setResolutionMode:(TRTCVideoResolutionMode)mode;

/// 设置填充模式
/// @param mode 填充模式
- (void)setVideoFillMode:(TRTCVideoFillMode)mode;

/// 设置本地镜像
/// @param type 本地镜像模式
- (void)setLocalMirrorType:(TRTCVideoMirrorType)type;

/// 设置远程镜像
/// @param isEnabled 开启远程镜像
- (void)setRemoteMirrorEnabled:(BOOL)isEnabled;

/// 设置视频水印
/// @param image 水印图片，必须使用透明底的png格式图片
/// @param rect 水印位置，x, y, width, height取值范围都是0 - 1
/// @note 如果当前分辨率为540 x 960, 设置rect为(0.1, 0.1, 0.2, 0)，
///       那水印图片的出现位置在(540 * 0.1, 960 * 0.1) = (54, 96),
///       宽度为540 * 0.2 = 108, 高度自动计算
- (void)setWaterMark:(UIImage * _Nullable)image inRect:(CGRect)rect;

/// 切换前后摄像头
- (void)switchCamera;

/// 切换闪光灯
- (void)switchTorch;

/// 设置自动对焦
/// @param isEnabled 开启自动对焦
- (void)setAutoFocusEnabled:(BOOL)isEnabled;

/// 设置重力感应
/// @param isEnable 开启重力感应
- (void)setGSensorEnabled:(BOOL)isEnable;

/// 设置流控方案
/// @param mode 流控方案
- (void)setQosControlMode:(TRTCQosControlMode)mode;

/// 设置双路编码
/// @param isEnabled 开启双路编码
- (void)setSmallVideoEnabled:(BOOL)isEnabled;

/// 设置是否默认观看低清
/// @param prefersLowQuality 默认观看低清
- (void)setPrefersLowQuality:(BOOL)prefersLowQuality;

/// 设置是否开启清晰度增强
/// @param enable 是否开启
- (void)enableSharpnessEnhancement:(BOOL)enable;

/// 设置仪表盘的边距
/// 必须在 showDebugView 调用前设置才会生效
/// @param userId 用户 ID
/// @param margin 仪表盘内边距，注意这里是基于 parentView 的百分比，margin 的取值范围是0 - 1
- (void)setDebugViewMargin:(NSString *)userId margin:(TXEdgeInsets)margin;

/// 显示仪表盘
/// 仪表盘是状态统计和事件消息浮层 view，方便调试。
/// @param showType 0：不显示；1：显示精简版；2：显示全量版
- (void)showDebugView:(NSInteger)showType;

/// 开始显示远端视频画面
/// @param userId 对方的用户标识
/// @param type 视频线路，可以设置为主路（TRTCVideoStreamTypeBig）或者辅路（TRTCVideoStreamTypeSub）
/// @param view 承载视频画面的控件
- (void)startRemoteView:(NSString *)userId streamType:(TRTCVideoStreamType)type view:(TXView *)view;

/// 开始显示子房间的远端视频画面
/// @param userId 对方的用户标识
/// @param roomId  子房间号
/// @param type 视频线路，可以设置为主路（TRTCVideoStreamTypeBig）或者辅路（TRTCVideoStreamTypeSub）
/// @param view 承载视频画面的控件
- (void)startSubRoomRemoteView:(NSString *)userId roomId:(NSString *)roomId streamType:(TRTCVideoStreamType)type view:(TXView *)view;

/// 开始显示子房间远端视频画面
/// @param userId 对方的用户标识
/// @param roomId  子房间号
/// @param type 视频线路，可以设置为主路（TRTCVideoStreamTypeBig）或者辅路（TRTCVideoStreamTypeSub）
/// @param view 承载视频画面的控件
- (void)updateSubRoomRemoteView:(TXView *)view roomId:(NSString *)roomId streamType:(TRTCVideoStreamType)type forUser:(NSString *)userId;

/// 更新远端视频画面的窗口
/// @param view 承载视频画面的控件
/// @param type 要设置预览窗口的流类型(TRTCVideoStreamTypeBig、TRTCVideoStreamTypeSub)
/// @param userId 对方的用户标识
- (void)updateRemoteView:(TXView *)view streamType:(TRTCVideoStreamType)type forUser:(NSString *)userId;

/// 更新自定义渲染时视频画面的窗口
/// @param videoView 承载视频画面的控件
/// @param userId 用户id，为nil时更新本地预览窗口，否则更新远端画面
- (void)updateCustomRenderView:(UIImageView *)videoView forUser:(NSString *)userId;

/// 停止显示远端视频画面，同时不再拉取该远端用户的视频数据流
/// @param userId 对方的用户标识
/// @param type 视频线路，可以设置为主路（TRTCVideoStreamTypeBig）或者辅路（TRTCVideoStreamTypeSub）
- (void)stopRemoteView:(NSString *)userId streamType:(TRTCVideoStreamType)type;

/// 停止显示远端视频画面，同时不再拉取该远端用户的视频数据流
/// @param userId 对方的用户标识
/// @param roomId  子房间号
/// @param type 视频线路，可以设置为主路（TRTCVideoStreamTypeBig）或者辅路（TRTCVideoStreamTypeSub）
- (void)stopSubRoomRemoteView:(NSString *)userId roomId:(NSString *)roomId streamType:(TRTCVideoStreamType)type;

/// 停止显示所有远端视频画面，同时不再拉取远端用户的视频数据流
/// @note 如果有屏幕分享的画面在显示，则屏幕分享的画面也会一并被关闭。
- (void)stopAllRemoteView;

/// 设置远端图像的渲染模式
/// @param userId 用户 ID
/// @param mode 填充（画面可能会被拉伸裁剪）或适应（画面可能会有黑边），默认值：TRTCVideoFillMode_Fill
- (void)setRemoteViewFillMode:(NSString*)userId mode:(TRTCVideoFillMode)mode;

/// 设置远端图像的顺时针旋转角度
/// @param userId 用户 ID
/// @param rotation 支持90、180以及270旋转角度，默认值：TRTCVideoRotation_0
- (void)setRemoteViewRotation:(NSString*)userId rotation:(TRTCVideoRotation)rotation;

/// 开始显示远端用户的辅路画面（TRTCVideoStreamTypeSub，一般用于屏幕分享）
/// @param userId 对方的用户标识
/// @param view 渲染控件
/// @note 请在 onUserSubStreamAvailable 回调后再调用这个接口。
- (void)startRemoteSubStreamView:(NSString *)userId view:(TXView *)view;

/// 停止显示远端用户的辅路画面（TRTCVideoStreamTypeSub，一般用于屏幕分享）。
/// @param userId 对方的用户标识
- (void)stopRemoteSubStreamView:(NSString *)userId;

/// 设置本地图像的渲染模式
/// @param mode 填充（画面可能会被拉伸裁剪）或适应（画面可能会有黑边），默认值：TRTCVideoFillMode_Fill
- (void)setLocalViewFillMode:(TRTCVideoFillMode)mode;

/// 设置本地图像的顺时针旋转角度
/// @param rotation 支持90、180以及270旋转角度，默认值：TRTCVideoRotation_0
- (void)setLocalViewRotation:(TRTCVideoRotation)rotation;

#if TARGET_OS_IPHONE
/// 设置本地摄像头预览画面的镜像模式（iOS）
/// @param mirror 镜像模式，默认值：TRTCLocalVideoMirrorType_Auto
- (void)setLocalViewMirror:(TRTCLocalVideoMirrorType)mirror;
#elif TARGET_OS_MAC

/// 设置本地摄像头预览画面的镜像模式（Mac）
/// @param mirror 镜像模式，默认值：YES
- (void)setLocalViewMirror:(BOOL)mirror;
#endif

/// 设置辅路画面（TRTCVideoStreamTypeSub，一般用于屏幕分享）的显示模式
/// @param userId 用户的 ID
/// @param mode 填充（画面可能会被拉伸裁剪）或适应（画面可能会有黑边），默认值：TRTCVideoFillMode_Fit
- (void)setRemoteSubStreamViewFillMode:(NSString *)userId mode:(TRTCVideoFillMode)mode;

/// 更新本地视频画面的窗口
/// @param videoView 承载视频画面的控件
- (void)updateLocalView:(UIView *)videoView;

/// 设置是否在某个子房间内推送视频流
/// @param roomId 子房间 ID
/// @param push 是否推流
- (void)pushVideoStreamInSubRoom:(NSString *)roomId push:(BOOL)isPush;

/// 设置第三方美颜回调format
/// @param format 回调视频帧 format
- (void)setCustomProcessFormat:(TRTCVideoPixelFormat)format;

/// 调整画面亮度，用于测试 texture 回调
/// @param brightness 画面亮度，取值范围 -1.0 ~ 1.0
- (void)setCustomBrightness:(CGFloat)brightness;

#pragma mark - Audio Functions

/// 设置音频采集
/// @param isEnabled 开启音频采集
- (void)setAudioEnabled:(BOOL)isEnabled;

/// 设置声音质量（要在进房或开启音频前调用）
/// @param quality 声音质量
- (void)setAudioQuality:(TRTCAudioQuality)quality;

/// 设置自定义音频采信
/// @param isEnabled 开启自定义音频采集
- (void)setAudioCustomCaptureEnabled:(BOOL)isEnabled;

/// 设置自定义辅路
/// @param isEnabled 开启自定义辅路
- (void)setSubStreamCaptureEnabled:(BOOL)isEnabled;

/// 采集音量
@property (nonatomic) NSInteger captureVolume;

/// 播放音量
@property (nonatomic) NSInteger playoutVolume;

/// 设置音频通道
/// @param route 音频通道
- (void)setAudioRoute:(TRTCAudioRoute)route;

/// 设置音量类型
/// @param type 音量类型
- (void)setVolumeType:(TRTCSystemVolumeType)type;

/// 设置耳返
/// @param isEnabled 开启耳返
- (void)setEarMonitoringEnabled:(BOOL)isEnabled;

/// 设置耳返音量
/// @param volume 耳返音量
- (void)setEarMonitoringVolume:(NSInteger)volume;

/// 设置回声消除
/// @param isEnabled 开启回声消除
- (void)setAecEnabled:(BOOL)isEnabled;

/// 设置自动增益
/// @param isEnabled 开启自动增益
- (void)setAgcEnabled:(BOOL)isEnabled;

/// 设置噪声消除
/// @param isEnabled 开启噪声消除
- (void)setAnsEnabled:(BOOL)isEnabled;

/// 设置音量提示
/// @param isEnabled 开启音量提示
/// @note 在音频启动前设置
- (void)setVolumeEvaluationEnabled:(BOOL)isEnabled;

/// 设置音频推送
/// @param isMuted YES：静音；NO：取消静音
- (void)setAudioMuted:(BOOL)isMuted;

/// 静音/取消静音指定的远端用户的声音
/// @param userId 对方的用户 ID
/// @param mute YES：静音；NO：取消静音
- (void)muteRemoteAudio:(NSString *)userId mute:(BOOL)mute;

/// 静音/取消静音所有用户的声音
/// @param mute YES：静音；NO：取消静音
- (void)muteAllRemoteAudio:(BOOL)mute;

/// 设置某个远程用户的播放音量
/// @param userId 远程用户 ID
/// @param volume 音量大小，取值0 - 100
- (void)setRemoteAudioVolume:(NSString *)userId volume:(int)volume;

/// 设置是否在某个子房间内推送音频流
/// @param roomId 子房间 ID
/// @param push 是否推流
- (void)pushAudioStreamInSubRoom:(NSString *)roomId push:(BOOL)isPush;

#pragma mark - Stream

/// 设置云端混流
/// @param mixMode 云端混流模式
- (void)setMixMode:(TRTCTranscodingConfigMode)mixMode;

/// 设置云端混流参数
- (void)updateCloudMixtureParams;

/// 设置混流背景图
/// @param imageId 背景图ID
- (void)setMixBackgroundImage:(NSString * _Nullable)imageId;

/// 设置混流自定义流ID
/// @param streamId 混流流ID
- (void)setMixStreamId:(NSString * _Nullable)streamId;
/// 设置发布媒体流roomid
/// @param roomid roomid
-(void)setPublishMediaStreamWithRoomId:(NSString *)roomid;


#pragma mark - Message

/// 发送自定义消息
/// @param message 消息内容，最大支持1kb
/// @result 发送是否成功
- (BOOL)sendCustomMessage:(NSString *)message;

/// 发送SEI消息
/// @param message 消息内容，最大支持1kb，推荐只传几个字节
/// @param repeatCount 发送数据次数
/// @result 消息是否检验成功，检验成功的消息将等待发送
- (BOOL)sendSEIMessage:(NSString *)message repeatCount:(NSInteger)repeatCount;

#pragma mark - Cross Room

/// 当前是否在跨房连接中
@property (nonatomic, readonly) BOOL isCrossingRoom;

/// 开始跨房通话
/// @param roomId 对方的房间ID
/// @param userId 对方的用户ID
- (void)startCrossRoom:(NSString *)roomId userId:(NSString *)userId;

/// 结束跨房通话
- (void)stopCrossRomm;

#pragma mark - Live Player

/// 旁路直播开启后，获取旁路直播的播放地址
- (NSString *)getCdnUrlOfUser:(NSString *)userId;

#pragma mark - Custom Video Capture and Render

/// 设置视频文件
/// @param videoAsset 视频文件资源
/// @note 这个接口需要要在enterRoom之前调用
- (void)setCustomVideo:(AVAsset *)videoAsset;

/// 开启远程用户视频的自定义渲染
/// @param userId 远程用户ID
/// @param view 视频页面
- (void)playCustomVideoOfUser:(NSString *)userId inView:(UIImageView *)view;

#pragma mark - Speed Test
/// 开始进行网络测速（视频通话期间请勿测试，以免影响通话质量）
/// @param sdkAppId 应用标识
/// @param userId 用户标识
/// @param userSig 用户签名
/// @param completion 测试回调，会分多次回调
- (void)startSpeedTest:(uint32_t)sdkAppId userId:(NSString *)userId userSig:(NSString *)userSig completion:(void(^)(TRTCSpeedTestResult* result, NSInteger completedCount, NSInteger totalCount))completion;

/// 停止服务器测速
- (void)stopSpeedTest;

#pragma mark - Media Record
/// 开启本地媒体录制
- (void)startLocalRecording;

/// 停止本地媒体录制
- (void)stopLocalRecording;

@end

NS_ASSUME_NONNULL_END
