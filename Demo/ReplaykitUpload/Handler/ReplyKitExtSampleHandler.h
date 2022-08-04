//
//  ReplyKitExtSampleHandler.h
//  TXLiteAVDemo_Enterprise
//
//  Created by gamhonghu(胡锦康) on 2021/4/20.
//  Copyright © 2021 Tencent. All rights reserved.
//
#if TRTC_EXT
#import <ReplayKit/ReplayKit.h>
#import "SampleHandlerProtocol.h"

@interface ReplyKitExtSampleHandler : RPBroadcastSampleHandler<SampleHandlerProtocol>

@property (nonatomic,weak) RPBroadcastSampleHandler *superHandler;//父handler

@end

#endif
