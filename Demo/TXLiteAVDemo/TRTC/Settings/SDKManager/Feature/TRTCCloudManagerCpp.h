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

#import "TRTCCloudManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface TRTCCloudManagerCpp : TRTCCloudManager

@end

NS_ASSUME_NONNULL_END
