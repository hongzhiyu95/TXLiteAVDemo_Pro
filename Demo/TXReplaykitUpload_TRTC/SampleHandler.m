//
//  SampleHandler.m
//  TXReplaykitUpload_TRTC
//
//  Created by cui on 2020/5/12.
//  Copyright © 2020 Tencent. All rights reserved.
//


#import "SampleHandler.h"
#if TRTC_EXT
@import TXLiteAVSDK_ReplayKitExt;
#endif

#if DEBUG
#define APPGROUP @"group.com.tencent.liteav.RPLiveStreamShare"
#else
#define APPGROUP @"group.com.tencent.liteav.RPLiveStreamRelease"
#endif

@interface SampleHandler() <TXReplayKitExtDelegate>
@end

@implementation SampleHandler
#if TRTC_EXT
- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo {
    [[TXReplayKitExt sharedInstance] setupWithAppGroup:APPGROUP delegate:self];
}

- (void)broadcastPaused {
    // User has requested to pause the broadcast. Samples will stop being delivered.
}

- (void)broadcastResumed {
    // User has requested to resume the broadcast. Samples delivery will resume.
}

- (void)broadcastFinished {
    [[TXReplayKitExt sharedInstance] finishBroadcast];
    // User has requested to finish the broadcast.
}

#pragma mark - TXReplayKitExtDelegate
- (void)boradcastFinished:(TXReplayKitExt *)broadcast reason:(TXReplayKitExtReason)reason
{
    NSString *tip = @"";
    switch (reason) {
        case TXReplayKitExtReasonRequestedByMain:
            tip = @"屏幕共享已结束";
            break;
        case TXReplayKitExtReasonDisconnected:
            tip = @"应用断开";
            break;
        case TXReplayKitExtReasonVersionMismatch:
            tip = @"集成错误（SDK 版本号不相符合）";
            break;
    }

    NSError *error = [NSError errorWithDomain:NSStringFromClass(self.class)
                                         code:0
                                     userInfo:@{
                                         NSLocalizedFailureReasonErrorKey:tip
                                     }];
    [self finishBroadcastWithError:error];
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType {
    [[TXReplayKitExt sharedInstance] sendSampleBuffer:sampleBuffer withType:sampleBufferType];
}

- (void)broadcastFinished:(nonnull TXReplayKitExt *)broadcast reason:(TXReplayKitExtReason)reason {
    
}
#endif
@end
