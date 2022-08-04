//
//  RenderView.h
//  BeautyDemo
//
//  Created by kennethmiao on 17/5/9.
//  Copyright © 2017年 kennethmiao. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMedia/CoreMedia.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSInteger, TXIliveRoomRenderMode) {
    TXE_RENDER_MODE_FILL_SCREEN = 0,    // 图像铺满屏幕
    TXE_RENDER_MODE_FILL_EDGE            // 图像长边填满屏幕
};

typedef NS_ENUM(NSInteger, TXIliveRoomRotation) {
    TXE_ROTATION_0 = 0,         //旋转0
    TXE_ROTATION_90 = 1,        //旋转90
    TXE_ROTATION_180 = 2,       //旋转180
    TXE_ROTATION_270 = 3,       //旋转270
};

typedef NS_ENUM(NSInteger, TXIliveRoomFrameFormat) {
    TXE_FRAME_FORMAT_NONE = 0,
    TXE_FRAME_FORMAT_NV12 = 1,        //NV12格式
    TXE_FRAME_FORMAT_I420 = 2,        //I420格式
    TXE_FRAME_FORMAT_RGBA = 3,        //RGBA格式
};

@interface iLiveRenderView : UIView
@property(nonatomic, assign) TXIliveRoomRenderMode renderMode;
@property(nonatomic, assign) TXIliveRoomRotation rotation;

- (void)renderFrame:(CMSampleBufferRef)sampleBuffer;
@end
