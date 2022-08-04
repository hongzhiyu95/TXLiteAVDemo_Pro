//
//  TXCOpenGLContext.h
//  TXLiteAVRenderer
//
//  Created by kennethmiao on 2017/7/4.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreVideo/CoreVideo.h>

@class EAGLContext;
@interface iLiveOpenGLContext : NSObject
+ (instancetype)shareInstance;
- (EAGLContext *)openGLContext;
- (CVOpenGLESTextureCacheRef)coreVideoTextureCache;
+ (BOOL)supportsFastTextureUpload;
- (void)runSyncOnRenderQueue:(void (^)(void))block;
- (void)runAsyncOnRenderQueue:(void (^)(void))block;
@end
