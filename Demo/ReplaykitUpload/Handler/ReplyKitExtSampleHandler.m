//
//  ReplyKitExtSampleHandler.h
//  TXLiteAVDemo_Enterprise
//
//  Created by gamhonghu(胡锦康) on 2021/4/20.
//  Copyright © 2021 Tencent. All rights reserved.
//
#if TRTC_EXT
#import "ReplyKitExtSampleHandler.h"
@import TXLiteAVSDK_ReplayKitExt;

#if DEBUG
#define APPGROUP @"group.com.tencent.liteav.RPLiveStreamShare"
#else
#define APPGROUP @"group.com.tencent.liteav.RPLiveStreamRelease"
#endif

@interface ReplyKitExtSampleHandler() <TXReplayKitExtDelegate>
@end

@implementation ReplyKitExtSampleHandler

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
    [[TXReplayKitExt sharedInstance] broadcastFinished];
    // User has requested to finish the broadcast.
}

- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType {
    [[TXReplayKitExt sharedInstance] sendSampleBuffer:sampleBuffer withType:sampleBufferType];
}

#pragma mark - TXReplayKitExtDelegate
- (void)broadcastFinished:(nonnull TXReplayKitExt *)broadcast reason:(TXReplayKitExtReason)reason {
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
    [self.superHandler finishBroadcastWithError:error];
}

@end
#endif
