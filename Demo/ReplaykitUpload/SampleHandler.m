//
//  ReplyKitExtSampleHandler.h
//  TXLiteAVDemo_Enterprise
//
//  Created by gamhonghu(胡锦康) on 2021/4/20.
//  Copyright © 2021 Tencent. All rights reserved.
//

#import "SampleHandler.h"
#if TRTC_EXT
#import "ReplyKitExtSampleHandler.h"
#else
#import "LivePushSampleHandler.h"
#endif



@interface SampleHandler()

@property (nonatomic, strong) RPBroadcastSampleHandler<SampleHandlerProtocol> *sampleHandler;

@end

@implementation SampleHandler
- (instancetype)init
{
    self = [super init];
    if (self) {
#if TRTC_EXT
        _sampleHandler = [ReplyKitExtSampleHandler new];
#else
        _sampleHandler = [LivePushSampleHandler new];
#endif
        _sampleHandler.superHandler = self;
    }
    return self;
}

- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo {
    [_sampleHandler broadcastStartedWithSetupInfo:setupInfo];
}

- (void)broadcastPaused {
    // User has requested to pause the broadcast. Samples will stop being delivered.
    [_sampleHandler broadcastPaused];
}

- (void)broadcastResumed {
    // User has requested to resume the broadcast. Samples delivery will resume.
    [_sampleHandler broadcastResumed];
}

- (void)broadcastFinished {
    // User has requested to finish the broadcast.
    [_sampleHandler broadcastFinished];
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType {
    [_sampleHandler processSampleBuffer:sampleBuffer withType:sampleBufferType];
}

@end
