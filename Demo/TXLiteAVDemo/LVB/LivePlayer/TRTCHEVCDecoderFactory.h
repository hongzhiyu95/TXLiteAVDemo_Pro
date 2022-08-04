//
//  TRTCHEVCDecoderFactory.h
//  TXLiteAVDemo
//
//  Created by abyyxwang on 2020/12/15.
//  Copyright © 2020 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

#ifndef TXLiteAVDecoderFactoryInterface_h
#define TXLiteAVDecoderFactoryInterface_h

@protocol TXLiteAVDecoderFactoryInterface <NSObject>

/// 创建软解器实例对象。指针必须为ITXLiteAVVideoDecoder类的派生类
- (void *)createHEVCDecoder;

/// 销毁指针
/// @param decoder 需要销毁的指针
- (void)destroyHEVCDecoder:(void *)decoder;

@end
#endif /* TXLiteAVDecoderFactoryInterface_h */

NS_ASSUME_NONNULL_BEGIN

@interface TRTCHEVCDecoderFactory : NSObject<TXLiteAVDecoderFactoryInterface>

- (void *)createHEVCDecoder;
- (void)destroyHEVCDecoder:(void *)decoder;

@end

NS_ASSUME_NONNULL_END
