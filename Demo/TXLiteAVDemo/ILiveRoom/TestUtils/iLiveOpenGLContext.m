//
//  TXCOpenGLContext.m
//  TXLiteAVRenderer
//
//  Created by kennethmiao on 2017/7/4.
//  Copyright © 2017年 Tencent. All rights reserved.
//

#import "iLiveOpenGLContext.h"
#import <OpenGLES/ES2/gl.h>
#import <OpenGLES/ES2/glext.h>
#import <OpenGLES/EAGL.h>

static void *TXCRenderQueueKey;

@interface iLiveOpenGLContext()
@property (nonatomic, strong) EAGLContext *glContext;
@property (nonatomic, strong) dispatch_queue_t renderQueue;
@property (nonatomic, assign) BOOL isSync;
@property (nonatomic, assign) CVOpenGLESTextureCacheRef coreVideoTextureCache;
@end

@implementation iLiveOpenGLContext

+ (instancetype)shareInstance
{
    static iLiveOpenGLContext *share = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        share = [[iLiveOpenGLContext alloc] init];
    });
    return share;
}

- (id)init
{
    self = [super init];
    if(self){
        TXCRenderQueueKey = &TXCRenderQueueKey;
        self.renderQueue = dispatch_queue_create("com.LiteAV.renderQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_queue_set_specific(_renderQueue, TXCRenderQueueKey, (__bridge void *)self, NULL);
        
        EAGLRenderingAPI api = kEAGLRenderingAPIOpenGLES2;
        self.glContext = [[EAGLContext alloc] initWithAPI:api];
        if(!self.glContext){
            exit(-1);
        }
//        if(![EAGLContext setCurrentContext:self.glContext]){
//            LOGE("Failed to set current OpenGL context");
//            exit(-1);
//        }
    }
    return self;
}

- (EAGLContext *)openGLContext
{
    return self.glContext;
}

+ (BOOL)supportsFastTextureUpload
{
//#if TARGET_IPHONE_SIMULATOR
//    return NO;
//#else
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wtautological-pointer-compare"
    return (CVOpenGLESTextureCacheCreate != NULL);
#pragma clang diagnostic pop
    
//#endif
}

- (CVOpenGLESTextureCacheRef)coreVideoTextureCache;
{
    if (_coreVideoTextureCache == NULL)
    {
#if defined(__IPHONE_6_0)
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, _glContext, NULL, &_coreVideoTextureCache);
#else
        CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, (__bridge void *)_glContext, NULL, &_coreVideoTextureCache);
#endif
        
        if (err){
            NSAssert(NO, @"Error at CVOpenGLESTextureCacheCreate %d", err);
        }
    }
    return _coreVideoTextureCache;
}

#pragma mark - render queue
- (void)runSyncOnRenderQueue:(void (^)(void))block
{
    if(dispatch_get_specific(TXCRenderQueueKey) && _isSync){
        block();
    }
    else{
        _isSync = YES;
        dispatch_sync(self.renderQueue, ^{
            block();
        });
    }
}

- (void)runAsyncOnRenderQueue:(void (^)(void))block
{
    if(dispatch_get_specific(TXCRenderQueueKey) && !_isSync){
        block();
    }
    else{
        _isSync = NO;
        dispatch_async(self.renderQueue, ^{
            block();
        });
    }
}
@end
