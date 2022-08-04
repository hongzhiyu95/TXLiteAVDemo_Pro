//
//  SampleHandlerDelegate.h
//  TXLiteAVDemo
//
//  Created by gamhonghu(胡锦康) on 2021/4/20.
//  Copyright © 2021 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RPBroadcastSampleHandler;

@protocol SampleHandlerProtocol <NSObject>

@property (nonatomic,weak) RPBroadcastSampleHandler *superHandler;//父handler

@end
