//
//  TXCCameraCapture.h
//  BeautyDemo
//
//  Created by xiangzhang on 2017/5/16.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol ILiveVideoCaptureDelegate <NSObject>
- (void)onCaptureFrame:(CMSampleBufferRef)sampleBuffer;
@end

@interface iLiveVideoCapture : NSObject
@property (nonatomic,weak) id<ILiveVideoCaptureDelegate> delegate;
- (void)start;
- (void)stop;
@end
