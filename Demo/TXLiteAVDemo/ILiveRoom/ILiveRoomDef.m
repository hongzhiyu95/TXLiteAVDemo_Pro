//
//  ILiveRoomDef.m
//  TXLiteAVDemo
//
//  Created by lijie on 2018/9/14.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "ILiveRoomDef.h"
#import "AFNetworking.h"
#import <CommonCrypto/CommonDigest.h>

#define kILiveRoomAddr_CreateRoom  @"https://xzb.qcloud.com/roomlist/weapp/iliveroom/create_room"
#define kILiveRoomAddr_EnterRoom   @"https://xzb.qcloud.com/roomlist/weapp/iliveroom/enter_room"
#define kILiveRoomAddr_HeartBeat   @"https://xzb.qcloud.com/roomlist/weapp/iliveroom/heartbeat"
#define kILiveRoomAddr_DeleteRoom  @"https://xzb.qcloud.com/roomlist/weapp/iliveroom/delete_room"
#define kILiveRoomAddr_GetRoomList @"https://xzb.qcloud.com/roomlist/weapp/iliveroom/get_room_list"


// 直播的API鉴权Key，可在控制台的 直播管理 => 接入管理 => 直播码接入 => 接入配置 中查看
static NSString *MIX_API_KEY = @"45eeb9fc2e4e6f88b778e0bbd9de3737";
// 固定地址
static NSString *MIX_SERVER = @"http://fcgi.video.qcloud.com";



@implementation ILiveRoomInfo

- (instancetype)init {
    if (self = [super init]) {
        
    }
    return self;
}
@end


@interface ILiveRoomService()

@property (nonatomic, retain) AFHTTPSessionManager* httpSession;

@end

@implementation ILiveRoomService

+ (instancetype)sharedInstance
{
    static ILiveRoomService* s_sharedObject = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        s_sharedObject = [[ILiveRoomService alloc] init];
    });
    return s_sharedObject;
}

- (id)init
{
    if (self = [super init]) {
        _httpSession = [AFHTTPSessionManager manager];
        [_httpSession setRequestSerializer:[AFJSONRequestSerializer serializer]];
        [_httpSession setResponseSerializer:[AFJSONResponseSerializer serializer]];
        [_httpSession.requestSerializer willChangeValueForKey:@"timeoutInterval"];
        _httpSession.requestSerializer.timeoutInterval = 5.0;
        [_httpSession.requestSerializer didChangeValueForKey:@"timeoutInterval"];
        _httpSession.responseSerializer.acceptableContentTypes = [NSSet setWithObjects:@"application/json", @"text/json", @"text/javascript", @"text/html", @"text/xml", @"text/plain", nil];
        
    }
    
    return self;
}

- (void)getRoomList:(int)index cnt:(int)cnt success:(void (^)(NSInteger code, NSString *msg, NSArray<ILiveRoomInfo *> *))success fail:(void (^)(NSError * _Nonnull error))fail
{
    NSDictionary *param = @{@"index": @(index), @"cnt": @(cnt)};
    
    [_httpSession POST:kILiveRoomAddr_GetRoomList parameters:param progress:nil
               success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        int errCode = [responseObject[@"code"] intValue];
        NSString *errMsg = responseObject[@"message"];
        //                   [self toastTip:[NSString stringWithFormat:@"getroomlist: code[%d] msg[%@]", errCode, errMsg]];
        NSLog(@"%@", [NSString stringWithFormat:@"getroomlist: code[%d] msg[%@]", errCode, errMsg]);
        NSMutableArray *roomInfos = nil;
        
        do {
            if (errCode != 0) {
                break;
            }
            
            NSArray *rooms = responseObject[@"rooms"];
            roomInfos = [[NSMutableArray alloc] init];
            for (id room in rooms) {
                ILiveRoomInfo *roomInfo = [[ILiveRoomInfo alloc] init];
                roomInfo.roomId = [room[@"roomID"] unsignedIntValue];
                roomInfo.roomName = room[@"roomName"];
                roomInfo.roomCreator = [room[@"roomCreator"] unsignedLongLongValue];
                [roomInfos addObject:roomInfo];
            }
        } while (0);
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                success(errCode, errMsg, roomInfos);
            });
        }
    }
               failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"getRoomList net error:%@", error.debugDescription);
        if (fail) {
            dispatch_async(dispatch_get_main_queue(), ^{
                fail(error);
            });
        }
    }
     ];
}

- (void)createRoom:(UInt64)userId roomName:(NSString*)roomName privateMap:(int)privateMap success:(void (^)(NSInteger code, NSString* msg, UInt32 roomId, NSData* privateMapKey, int privateMap, NSData* userSig))success fail:(void (^)(NSError *error))fail
{
    NSDictionary* param = @{@"userID": @(userId), @"roomName": roomName, @"authBits": @(privateMap), @"version": @(1)};
    [_httpSession POST:kILiveRoomAddr_CreateRoom parameters:param progress:nil
               success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        int errCode = [responseObject[@"code"] intValue];
        NSString *errMsg = responseObject[@"message"];
        //                   [self toastTip:[NSString stringWithFormat:@"getroomlist: code[%d] msg[%@]", errCode, errMsg]];
        NSLog(@"%@", [NSString stringWithFormat:@"createRoom: code[%d] msg[%@]", errCode, errMsg]);
        UInt32 roomId = -1;
        NSData *privateMapKey = nil;
        NSData *userSig = nil;
        int privateMap = 0;
        do {
            if (errCode != 0)
                break;
            
            roomId = [responseObject[@"roomID"] unsignedIntValue];
            privateMapKey = [responseObject[@"privMapEncrypt"] dataUsingEncoding:NSUTF8StringEncoding];
            privateMap = [responseObject[@"authBits"] intValue];
            userSig = [responseObject[@"userSig"] dataUsingEncoding:NSUTF8StringEncoding];
            
            self.roomId = roomId;
            self.userId = userId;
        } while (0);
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                success(errCode, errMsg, roomId, privateMapKey, privateMap, userSig);
            });
        }
    }
               failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"createRoom net error:%@", error.debugDescription);
        if (fail) {
            dispatch_async(dispatch_get_main_queue(), ^{
                fail(error);
            });
        }
    }
     ];
}

- (void)enterRoom:(UInt64)userId roomId:(UInt32)roomId privateMap:(int)privateMap success:(void (^)(NSInteger code, NSString* msg, UInt32 roomId, NSData* privateMapKey, int privateMap, NSData* userSig))success fail:(void (^)(NSError *error))fail
{
    NSDictionary* param = @{@"userID": @(userId), @"roomID":@(roomId), @"authBits": @(privateMap), @"version": @(1)};
    [_httpSession POST:kILiveRoomAddr_EnterRoom parameters:param progress:nil
               success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        int errCode = [responseObject[@"code"] intValue];
        NSString *errMsg = responseObject[@"message"];
        //                   [self toastTip:[NSString stringWithFormat:@"getroomlist: code[%d] msg[%@]", errCode, errMsg]];
        NSLog(@"%@", [NSString stringWithFormat:@"enterRoom: code[%d] msg[%@]", errCode, errMsg]);
        UInt32 roomId = -1;
        NSData *privateMapKey = nil;
        NSData *userSig = nil;
        int privateMap = 0;
        
        do {
            if (errCode != 0)
                break;
            
            roomId = [responseObject[@"roomID"] unsignedIntValue];
            privateMapKey = [responseObject[@"privMapEncrypt"] dataUsingEncoding:NSUTF8StringEncoding];
            privateMap = [responseObject[@"authBits"] intValue];
            userSig = [responseObject[@"userSig"] dataUsingEncoding:NSUTF8StringEncoding];
            
        } while (0);
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                success(errCode, errMsg, roomId, privateMapKey, privateMap, userSig);
            });
        }
    }
               failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"enterRoom net error:%@", error.debugDescription);
        if (fail) {
            dispatch_async(dispatch_get_main_queue(), ^{
                fail(error);
            });
        }
    }
     ];
}

- (void)deleteRoom:(UInt32)roomId success:(void (^)(NSInteger code, NSString *msg))success fail:(void (^)(NSError * _Nonnull))fail
{
    NSDictionary* param = @{@"roomID": @(roomId)};
    [_httpSession POST:kILiveRoomAddr_DeleteRoom parameters:param progress:nil
               success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        int errCode = [responseObject[@"code"] intValue];
        NSString *errMsg = responseObject[@"message"];
        //                   [self toastTip:[NSString stringWithFormat:@"getroomlist: code[%d] msg[%@]", errCode, errMsg]];
        NSLog(@"%@", [NSString stringWithFormat:@"deleteRoom: code[%d] msg[%@]", errCode, errMsg]);
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                success(errCode, errMsg);
            });
        }
    }
               failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"deleteRoom net error:%@", error.debugDescription);
        if (fail) {
            dispatch_async(dispatch_get_main_queue(), ^{
                fail(error);
            });
        }
    }
     ];
}

- (void)hearBeat:(UInt32)roomId success:(void (^)(NSInteger, NSString *))success fail:(void (^)(NSError * _Nonnull))fail
{
    NSDictionary* param = @{@"roomID": @(roomId)};
    [_httpSession POST:kILiveRoomAddr_HeartBeat parameters:param progress:nil
               success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        int errCode = [responseObject[@"code"] intValue];
        NSString *errMsg = responseObject[@"message"];
        //                   [self toastTip:[NSString stringWithFormat:@"getroomlist: code[%d] msg[%@]", errCode, errMsg]];
        if (success) {
            dispatch_async(dispatch_get_main_queue(), ^{
                success(errCode, errMsg);
            });
        }
    }
               failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        NSLog(@"hearBeat net error:%@", error.debugDescription);
        if (fail) {
            dispatch_async(dispatch_get_main_queue(), ^{
                fail(error);
            });
        }
    }
     ];
}

#pragma mark - Util
// 为了方便调试，将userId保持到文件中，这样每次打开app都是同一个userId
- (UInt64)getUserId {
    UInt64 userId = 0;
    NSNumber *d = [[NSUserDefaults standardUserDefaults] objectForKey:@"__iliveroom_current_userid__"];
    if (d) {
        userId = [d unsignedLongLongValue];
    } else {
        double tt = [[NSDate date] timeIntervalSince1970];
        userId = ((uint64_t)(tt * 1000.0)) % 100000000;
        [[NSUserDefaults standardUserDefaults] setObject:@(userId) forKey:@"__iliveroom_current_userid__"];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    NSLog(@"getUserId:%llu", userId);
    return userId;
}

- (NSInteger) getCurrentSec
{
    return [[NSDate date] timeIntervalSince1970];
}
+ (NSString *)getMD5:(NSString *)string
{
    const char *cStr = [string UTF8String];
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    
    CC_MD5(cStr, (CC_LONG)strlen(cStr), digest);
    
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i++) {
        [result appendFormat:@"%02x", digest[i]];
    }
    
    return result;
}
+ (NSString *)getStreamId:(UInt32)roomId userId:(UInt64)userId
{
    NSString *str = [NSString stringWithFormat:@"%d_%lld_main", roomId, userId];
    return [NSString stringWithFormat:@"%d_%@", ILIVEROOM_BIZID, [self getMD5:str]];
}
+ (NSString *)getRoomRtmpUrl:(UInt32)roomId userId:(UInt64)userId
{
    return [NSString stringWithFormat:@"rtmp://%d.liveplay.myqcloud.com/live/%@",
            ILIVEROOM_BIZID, [self getStreamId:roomId userId:userId]];
}
@end
