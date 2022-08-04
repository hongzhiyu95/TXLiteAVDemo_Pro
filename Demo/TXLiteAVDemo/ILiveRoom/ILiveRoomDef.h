//
//  ILiveRoomDef.h
//  TXLiteAVDemo
//
//  Created by lijie on 2018/9/14.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "OneSecAdapter.h"

// sdkappid
#define ILIVEROOM_SDKAPPID  1400044820

// 直播业务id和appid，可在控制台的 直播管理中查看
#define ILIVEROOM_BIZID  8525
#define ILIVEROOM_APPID  1253488539


@interface ILiveRoomInfo : NSObject

@property (nonatomic, copy) NSString* roomName;
@property (nonatomic, assign) UInt32 roomId;
@property (nonatomic, assign) UInt64 roomCreator;

@end

typedef enum : NSUInteger {
    ILiveRoom_IDLE,
    ILiveRoom_ENTERING,
    ILiveRoom_ENTERED,
    ILiveRoom_EXITING,
} ILiveRoomStatus;


@interface ILiveRoomService : NSObject

+ (instancetype)sharedInstance;

@property UInt32 roomId;
@property UInt64 userId;

- (void)getRoomList:(int)index cnt:(int)cnt success:(void (^)(NSInteger code, NSString* msg, NSArray<ILiveRoomInfo*>* roomInfos))success fail:(void (^)(NSError *  error))fail;

- (void)createRoom:(UInt64)userId roomName:(NSString*)roomName privateMap:(int)privateMap success:(void (^)(NSInteger code, NSString* msg, UInt32 roomId, NSData* privateMapKey, int privateMap, NSData* userSig))success fail:(void (^)(NSError *error))fail;

- (void)enterRoom:(UInt64)userId roomId:(UInt32)roomId privateMap:(int)privateMap success:(void (^)(NSInteger code, NSString* msg, UInt32 roomId, NSData* privateMapKey, int privateMap, NSData* userSig))success fail:(void (^)(NSError *error))fail;

- (void)deleteRoom:(UInt32)roomId success:(void (^)(NSInteger code, NSString* msg))success fail:(void (^)(NSError *error))fail;

- (void)hearBeat:(UInt32)roomId success:(void (^)(NSInteger code, NSString* msg))success fail:(void (^)(NSError *error))fail;

- (UInt64)getUserId;

+ (NSString *)getRoomRtmpUrl:(UInt32)roomId userId:(UInt64)userId;
+ (NSString *)getRoomFlvUrl:(UInt32)roomId userId:(UInt64)userId;
@end
