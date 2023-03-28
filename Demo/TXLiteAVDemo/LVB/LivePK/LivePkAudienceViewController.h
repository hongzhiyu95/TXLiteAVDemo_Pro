//
//  LivePkAudienceViewController.h
//  MLVB-API-Example-OC
//
//  Created by bluedang on 2021/7/1.
//  Copyright © 2021 Tencent. All rights reserved.
//


#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN

@interface LivePkAudienceViewController : UIViewController
- (instancetype)initWithStreamId:(NSString *)streamId userId:(NSString *)userId;
@end

NS_ASSUME_NONNULL_END
