//
//  ILiveRoomPusherViewController.h
//  TXLiteAVDemo
//
//  Created by lijie on 2018/9/14.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>

#define PA_UNLIKELY(x) (x)
#define PA_CLAMP_UNLIKELY(x, low, high) (PA_UNLIKELY((x) > (high)) ? (high) : (PA_UNLIKELY((x) < (low)) ? (low) : (x)))

typedef NS_ENUM(NSInteger,PushType){
    PushType_Camera,
    PushType_MV,
};

@interface ILiveRoomPusherViewController : UIViewController

@property (nonatomic, strong) NSString *roomName;
@property (nonatomic, assign) UInt64   hostUserId;
@property (nonatomic, assign) UInt64   userId;
@property (nonatomic, assign) UInt32   roomId;
@property (nonatomic, assign) UInt32   privateMap;
@property (nonatomic, strong) NSData   *privateMapKey;
@property (nonatomic, strong) NSData   *userSig;
@property (nonatomic, assign) UInt32   appId;
@property (nonatomic, assign) UInt32   sdkAppId;
@property (nonatomic, assign) UInt32   bizId;
@property (nonatomic, assign) NSInteger audioEncQualityIndex;
@property (nonatomic, assign) PushType pushType;
@property (nonatomic, assign) BOOL     isEnterRoomWithCDN;
@property (nonatomic, strong) NSString *cdnURL;
@property (nonatomic, strong) NSString *playURL;
@property (nonatomic, assign) BOOL     enableSmallStream;
@property (nonatomic, assign) BOOL     enableSendMsgLoop;
@property (nonatomic, assign) BOOL     isBroadcaster; // 区分观众进房还是主播进房
@end
