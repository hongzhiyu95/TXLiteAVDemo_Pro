//
//  TXCCameraCapture.m
//  BeautyDemo
//
//  Created by xiangzhang on 2017/5/16.
//

#import <UIKit/UIKit.h>
#import <CoreMotion/CoreMotion.h>
#import <CoreImage/CoreImage.h>
#import "iLiveVideoCapture.h"


static void *TXCCameraQueueKey;

@interface iLiveVideoCapture () <AVCaptureVideoDataOutputSampleBufferDelegate>
@property(atomic, strong) AVCaptureSession *captureSession;
@property(atomic, strong) AVCaptureDevice *inputCamera;
@property(atomic, strong) AVCaptureDeviceInput *videoInput;
@property(atomic, strong) AVCaptureVideoDataOutput *videoOutput;
@property(atomic, strong) AVCaptureMetadataOutput *metaOutput;
@property(atomic, strong) AVCaptureConnection *videoConnection;
@property(atomic, strong) CIDetector* faceDetector;
@property(nonatomic, strong) dispatch_queue_t cameraProcessingQueue;
@property(nonatomic, assign) AVCaptureDevicePosition position;
@property(atomic, strong) AVCaptureVideoPreviewLayer *prevLayer;

@end

@implementation iLiveVideoCapture

- (id)init {
    if (self = [super init]) {
        _position = AVCaptureDevicePositionFront;
        TXCCameraQueueKey = &TXCCameraQueueKey;
        _cameraProcessingQueue = dispatch_queue_create("com.txc.capturequeue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_cameraProcessingQueue, TXCCameraQueueKey, (__bridge void *)self, NULL);
    }
    return self;
}

- (void)initCameraCapture
{
    self.captureSession = [[AVCaptureSession alloc] init];
    self.inputCamera = [self cameraWithPosition:_position];
    [self.captureSession beginConfiguration];
    [self setSessionPreset:AVCaptureSessionPreset640x480];
    
    NSError *error = nil;
    self.videoInput = [AVCaptureDeviceInput deviceInputWithDevice:self.inputCamera error:&error];
    if ([self.captureSession canAddInput:self.videoInput]) {
        [self.captureSession addInput:self.videoInput];
    }
    self.videoOutput = [AVCaptureVideoDataOutput new];
    [self.videoOutput setSampleBufferDelegate:self queue:dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)];
    
    NSDictionary *captureSettings = @{(NSString *) kCVPixelBufferPixelFormatTypeKey: @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)};
    self.videoOutput.videoSettings = captureSettings;
    self.videoOutput.alwaysDiscardsLateVideoFrames = YES;
    
    if ([self.captureSession canAddOutput:self.videoOutput]) {
        [self.captureSession addOutput:self.videoOutput];
    }
    [self.captureSession commitConfiguration];
    self.videoConnection = [self.videoOutput connectionWithMediaType:AVMediaTypeVideo];
}

- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position {
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
        if (device.position == position) {
            return device;
        }
    return nil;
}

- (void)setFrameRate{
    int32_t frameRate = 15;
    if ([self supportsVideoFrameRate:frameRate]) {
        if ([self.inputCamera respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
            [self.inputCamera respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
            
            NSError *error;
            [self.inputCamera lockForConfiguration:&error];
            if (error == nil) {
#if defined(__IPHONE_7_0)
                [self.inputCamera setActiveVideoMinFrameDuration:CMTimeMake(1, frameRate)];
                [self.inputCamera setActiveVideoMaxFrameDuration:CMTimeMake(1, frameRate)];
#endif
            }
            [self.inputCamera unlockForConfiguration];
            
        } else {
            
            for (AVCaptureConnection *connection in self.videoOutput.connections) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
                    connection.videoMinFrameDuration = CMTimeMake(1, frameRate);
                
                if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)])
                    connection.videoMaxFrameDuration = CMTimeMake(1, frameRate);
#pragma clang diagnostic pop
            }
        }
        
    } else {
        if ([self.inputCamera respondsToSelector:@selector(setActiveVideoMinFrameDuration:)] &&
            [self.inputCamera respondsToSelector:@selector(setActiveVideoMaxFrameDuration:)]) {
            
            NSError *error;
            [self.inputCamera lockForConfiguration:&error];
            if (error == nil) {
#if defined(__IPHONE_7_0)
                [self.inputCamera setActiveVideoMinFrameDuration:kCMTimeInvalid];
                [self.inputCamera setActiveVideoMaxFrameDuration:kCMTimeInvalid];
#endif
            }
            [self.inputCamera unlockForConfiguration];
            
        } else {
            
            for (AVCaptureConnection *connection in self.videoOutput.connections) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
                if ([connection respondsToSelector:@selector(setVideoMinFrameDuration:)])
                    connection.videoMinFrameDuration = kCMTimeInvalid; // This sets videoMinFrameDuration back to default
                
                if ([connection respondsToSelector:@selector(setVideoMaxFrameDuration:)])
                    connection.videoMaxFrameDuration = kCMTimeInvalid; // This sets videoMaxFrameDuration back to default
#pragma clang diagnostic pop
            }
        }
        
    }
}

- (BOOL)supportsVideoFrameRate:(NSInteger)videoFrameRate
{
    if (!self.inputCamera) {
        return NO;
    }
    
    AVCaptureDeviceFormat* format = [self.inputCamera activeFormat];
    NSArray *videoSupportedFrameRateRanges = [format videoSupportedFrameRateRanges];
    for (AVFrameRateRange *frameRateRange in videoSupportedFrameRateRanges) {
        if ( (frameRateRange.minFrameRate <= videoFrameRate) && (videoFrameRate <= frameRateRange.maxFrameRate) ) {
            return YES;
        }
    }
    
    return NO;
}

- (void)start {
    AVAuthorizationStatus AVstatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];//相机权限
    switch (AVstatus) {
        case AVAuthorizationStatusAuthorized:
        {
            NSLog(@"AVMediaTypeVideo Authorized");
            break;
        }
        case AVAuthorizationStatusDenied:
        {
            NSLog(@"AVMediaTypeVideo Denied");
            return;
            break;
        }
        case AVAuthorizationStatusNotDetermined:
        {
            NSLog(@"AVMediaTypeVideo not Determined");
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {//相机权限
                if (granted) {
                    NSLog(@"requestAccessForMediaType:AVMediaTypeVideo Authorized");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self startCapture];
                    });
                }else{
                    NSLog(@"requestAccessForMediaType:AVMediaTypeVideo Denied or Restricted");
                }
            }];
            return;
            break;
        }
        case AVAuthorizationStatusRestricted:
        {
            NSLog(@"AVMediaTypeVideo Restricted");
            return;
            break;
        }
        default:
            break;
    }
    [self startCapture];
}


- (void)startCapture
{
    if (!self.captureSession) {
        [self initCameraCapture];
    }
    AVAuthorizationStatus status = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (status == AVAuthorizationStatusAuthorized) { // authorized
        if (![self.captureSession isRunning]) {
            [self setFrameRate];
            [self.captureSession startRunning];
        }
    } else if (status == AVAuthorizationStatusDenied) { // denied
        NSLog(@"AVAuthorizationStatusDenied");
    } else if (status == AVAuthorizationStatusRestricted) { // restricted
        NSLog(@"AVAuthorizationStatusRestricted");
    } else if (status == AVAuthorizationStatusNotDetermined) { // not determined
        dispatch_semaphore_t sig = dispatch_semaphore_create(0);
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self start];
            });
            
            dispatch_semaphore_signal(sig);
        }];
        dispatch_semaphore_wait(sig, DISPATCH_TIME_FOREVER);
    }
}

- (void)stop {
    if (self.captureSession && [self.captureSession isRunning]) {
        [self.captureSession stopRunning];
    }
}

- (BOOL)setSessionPreset:(NSString*)preset
{
    if (!self.inputCamera)
        return YES;
    
    BOOL ret = [self.inputCamera supportsAVCaptureSessionPreset:preset];
    if (!ret) {
        NSLog(@"preset:%@ not support!", preset);
        return NO;
    }
    
    [self.captureSession setSessionPreset:preset];
    return YES;
}


#pragma mark AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    dispatch_sync(_cameraProcessingQueue, ^{
        if (connection == self.videoConnection) {
            if ([self.delegate respondsToSelector:@selector(onCaptureFrame:)]) {
                [self.delegate onCaptureFrame:sampleBuffer];
            }
        }
    });
    
}


- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
