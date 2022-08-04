//
//  HCViewController.h
//  TXLiteAVDemo_ILiveRoom_Smart
//
//  Created by hans on 2020/3/4.
//  Copyright © 2020 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "HeChangAdapter.h"
@interface HCViewController : UIViewController
@property (nonatomic, copy) NSString *roomName;
@property (nonatomic, copy) NSData * userSign;
@property (nonatomic, assign) UInt32   sdkAppId;
@property (nonatomic, assign) UInt64   userId;
@property (nonatomic, assign) HeChangRole role;
@property (nonatomic, assign) HeChangMode mode;
@property (nonatomic, copy) NSDictionary<NSNumber*, NSNumber*> *rolePair;
@end

