//
//  TRTCHEVCDecoderFactory.m
//  TXLiteAVDemo
//
//  Created by abyyxwang on 2020/12/15.
//  Copyright © 2020 Tencent. All rights reserved.
//

#import "TRTCHEVCDecoderFactory.h"
#import "FFHevcDecoder.h"

@interface TRTCHEVCDecoderFactory ()

@end

@implementation TRTCHEVCDecoderFactory

- (void)destroyHEVCDecoder:(void *)decoder {
    liteav::FFHevcDecoderFactory::ReleaseFFHevcDecoder();
}

- (void *)createHEVCDecoder {
    return liteav::FFHevcDecoderFactory::CreateFFHevcDecoder();
}


@end
