//
//  iLiveRenderView.m
//
//  Created by kennethmiao on 17/5/9.
//  Copyright © 2017年 kennethmiao. All rights reserved.
//

#import "iLiveRenderView.h"
#import <OpenGLES/ES2/gl.h>
#import <GLKit/GLKit.h>
#import "iLiveOpenGLContext.h"

typedef void (^snapshotCompletionBlock)(UIImage *);

GLfloat kiLiveRenderColorConversion601FullRangeDefault[] = {
    1.0,    1.0,    1.0,
    0.0,    -0.343, 1.765,
    1.4,    -0.711, 0.0,
};

typedef NS_ENUM(NSUInteger, TXERotationInner) {
    TXE_ROTATION_INNER_NO,
    TXE_ROTATION_INNER_LEFT,
    TXE_ROTATION_INNER_RIGHT,
    TXE_ROTATION_INNER_FLIP_V,
    TXE_ROTATION_INNER_FLIP_H,
    TXE_ROTATION_INNER_RIGHT_FLIP_V,
    TXE_ROTATION_INNER_RIGHT_FLIP_H,
    TXE_ROTATION_INNER_180,
};

@interface iLiveRenderView () {
    BOOL _isInBackground;
    BOOL _isInitOpenglParam;
    TXIliveRoomFrameFormat _format;
    CGSize _bufSize;
    CGRect _frameRect;
    GLfloat _imageVertices[8];
    const GLfloat *_preferredConversion;
    
    CGRect _frame;
    CALayer *_layer;
    
    UITapGestureRecognizer  *_tapGestureRecognizer;
    UIPinchGestureRecognizer  *_pinchGestureRecognizer;
}
#pragma mark - opengl param
@property(nonatomic, strong) CAEAGLLayer *eaglLayer;
@property(nonatomic, strong) EAGLContext *curContext;

@property(nonatomic, assign) GLuint renderBuffer;
@property(nonatomic, assign) GLuint frameBuffer;
@property(nonatomic, assign) GLuint yuvYTexture;
@property(nonatomic, assign) GLuint yuvUTexture;
@property(nonatomic, assign) GLuint yuvVTexture;
@property(nonatomic, assign) GLuint vertexShader;
@property(nonatomic, assign) GLuint fragmentShader;
@property(nonatomic, assign) GLuint programHandle;

@property(nonatomic, assign) GLuint positionSlot;
@property(nonatomic, assign) GLuint texCoordSlot;
@property(nonatomic, assign) GLuint yuvTypeUniform;
@property(nonatomic, assign) GLuint textureUniformY;
@property(nonatomic, assign) GLuint textureUniformU;
@property(nonatomic, assign) GLuint textureUniformV;
@property(nonatomic, assign) GLuint yuvConversionMatrixUniform;

@end

@implementation iLiveRenderView

- (instancetype)init {
    if (self = [super init]) {
        [self setup];
    }
    return self;
}

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        [self setup];
    }
    return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    if (self = [super initWithCoder:aDecoder]) {
        [self setup];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setup];
}

- (void)layoutSubviews{
    [super layoutSubviews];
    CGRect frame = self.frame;
    [[iLiveOpenGLContext shareInstance] runAsyncOnRenderQueue:^{
        if([EAGLContext currentContext] != _curContext){
            [EAGLContext setCurrentContext:_curContext];
        }
        glFinish();
        _frame = frame;
        if(_isInitOpenglParam){
            [self convertYUVToRGBOutput];
        }
    }];
}

- (void)removeFromSuperview {
    [super removeFromSuperview];
}

- (void)setup {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillResignActive:) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self setContentScaleFactor:[UIScreen mainScreen].scale];


    _isInitOpenglParam = NO;
    _isInBackground = NO;
    _frameRect = self.frame;
    _bufSize = CGSizeZero;
    _format = TXE_FRAME_FORMAT_NONE;
    _renderMode = TXE_RENDER_MODE_FILL_EDGE;
    _rotation = TXE_ROTATION_0;
    
    _layer = self.layer;
    _frame = self.frame;
    
    [self setContentScaleFactor:[UIScreen mainScreen].scale];
    _isInBackground = ([UIApplication sharedApplication].applicationState != UIApplicationStateActive);
    
}

- (void)dealloc {
    EAGLContext *context = [EAGLContext currentContext];

    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[iLiveOpenGLContext shareInstance] runSyncOnRenderQueue:^{
        if([EAGLContext currentContext] != self.curContext){
            [EAGLContext setCurrentContext:self.curContext];
        }
        glDeleteRenderbuffers(1, &_renderBuffer);
        glDeleteFramebuffers(1, &_frameBuffer);
        if(_format != TXE_FRAME_FORMAT_NV12 || ![iLiveOpenGLContext supportsFastTextureUpload]){
            //软解才需要删除纹理，硬解如果删除纹理会导致软硬解切换时，硬解闪屏
//            [self deleteTexture];
        }
        if (_vertexShader){
            glDeleteShader(_vertexShader);
        }
        if (_fragmentShader){
            glDeleteShader(_fragmentShader);
        }
        if (_programHandle){
            glDeleteProgram(_programHandle);
        }
        
    }];
    [self removeGestureRecognizer:_pinchGestureRecognizer];
    [EAGLContext setCurrentContext:context];
}

#pragma mark - opengl init
+ (Class)layerClass {
    return [CAEAGLLayer class];
}

- (void)setupLayer {
    self.eaglLayer = (CAEAGLLayer *)_layer;
    self.eaglLayer.opaque = YES;
    [CATransaction flush];
}

- (void)setupRenderBuffer {
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, self.renderBuffer);
    [_curContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:self.eaglLayer];
}

- (void)setupFrameBuffer {
    glGenFramebuffers(1, &_frameBuffer);
    glBindFramebuffer(GL_FRAMEBUFFER, self.frameBuffer);
    glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, self.renderBuffer);
}

- (void)setupTexture {
    glGenTextures(1, &_yuvYTexture);
    glBindTexture(GL_TEXTURE_2D, self.yuvYTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glGenTextures(1, &_yuvUTexture);
    glBindTexture(GL_TEXTURE_2D, self.yuvUTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    
    glGenTextures(1, &_yuvVTexture);
    glBindTexture(GL_TEXTURE_2D, self.yuvVTexture);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
}

- (void)deleteTexture{
    glDeleteTextures(1, &_yuvYTexture);
    glDeleteTextures(1, &_yuvUTexture);
    glDeleteTextures(1, &_yuvVTexture);
}

- (GLuint)compileShader:(NSString *)shaderString withType:(GLenum)shaderType {
    
    GLuint shaderHandle = glCreateShader(shaderType);
    
    const char *shaderStringUTF8 = [shaderString UTF8String];
    int shaderStringLength = (int) [shaderString length];
    glShaderSource(shaderHandle, 1, &shaderStringUTF8, &shaderStringLength);
    
    glCompileShader(shaderHandle);
    
    GLint compileSuccess;
    glGetShaderiv(shaderHandle, GL_COMPILE_STATUS, &compileSuccess);
    if (compileSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetShaderInfoLog(shaderHandle, sizeof(messages), 0, &messages[0]);
        exit(1);
    }
    
    return shaderHandle;
}

- (void)compileShaders {
    NSString *vString = @"attribute vec4 Position;\n"
    "attribute vec2 TexCoordIn;\n"
    "varying vec2 TexCoordOut;\n"
    "void main(void){\n"
    "   gl_Position =  Position;\n"
    "   TexCoordOut = TexCoordIn;\n"
    "}\n";
    
    NSString *fString = @"varying highp vec2 TexCoordOut;\n"
    "uniform sampler2D TextureY;\n"
    "uniform sampler2D TextureU;\n"
    "uniform sampler2D TextureV;\n"
    "uniform highp mat3 YuvConversionMatrix;\n"
    "uniform int YuvType; //0=>i420,1=>nv12,2=>rgba\n"
    "void main(void){\n"
    "   highp vec3 yuv;\n"
    "   highp vec3 rgb;\n"
    "   if(YuvType == 0){\n"
    "       yuv.x = texture2D(TextureY, TexCoordOut).r;\n"
    "       yuv.y = texture2D(TextureU, TexCoordOut).r - 0.5;\n"
    "       yuv.z = texture2D(TextureV, TexCoordOut).r - 0.5;\n"
    "       rgb = YuvConversionMatrix * yuv;\n"
    "   }\n"
    "   else if(YuvType == 1){\n"
    "       yuv.x = texture2D(TextureY, TexCoordOut).r;\n"
    "       yuv.y = texture2D(TextureU, TexCoordOut).r - 0.5;\n"
    "       yuv.z = texture2D(TextureU, TexCoordOut).a - 0.5;\n"
    "       rgb = YuvConversionMatrix * yuv;\n"
    "   }\n"
    "   else{\n"
    "       rgb = texture2D(TextureY, TexCoordOut).rgb;\n"
    "   }\n"
    "   gl_FragColor = vec4(rgb,1);\n"
    "}";
    
    _vertexShader = [self compileShader:vString
                               withType:GL_VERTEX_SHADER];
    _fragmentShader = [self compileShader:fString
                                 withType:GL_FRAGMENT_SHADER];
    
    _programHandle = glCreateProgram();
    glAttachShader(_programHandle, _vertexShader);
    glAttachShader(_programHandle, _fragmentShader);
    glLinkProgram(_programHandle);
    if (_vertexShader)
    {
        glDeleteShader(_vertexShader);
        _vertexShader = 0;
    }
    if (_fragmentShader)
    {
        glDeleteShader(_fragmentShader);
        _fragmentShader = 0;
    }
    
    GLint linkSuccess;
    glGetProgramiv(_programHandle, GL_LINK_STATUS, &linkSuccess);
    if (linkSuccess == GL_FALSE) {
        GLchar messages[256];
        glGetProgramInfoLog(_programHandle, sizeof(messages), 0, &messages[0]);
        exit(1);
    }
    
    glUseProgram(_programHandle);
    
    _positionSlot = (GLuint) glGetAttribLocation(_programHandle, "Position");
    glEnableVertexAttribArray(_positionSlot);
    _texCoordSlot = (GLuint) glGetAttribLocation(_programHandle, "TexCoordIn");
    glEnableVertexAttribArray(_texCoordSlot);
    
    
    _textureUniformY = (GLuint) glGetUniformLocation(_programHandle, "TextureY");
    _textureUniformU = (GLuint) glGetUniformLocation(_programHandle, "TextureU");
    _textureUniformV = (GLuint) glGetUniformLocation(_programHandle, "TextureV");
    _yuvTypeUniform = (GLuint) glGetUniformLocation(_programHandle, "YuvType");
    _yuvConversionMatrixUniform = (GLuint) glGetUniformLocation(_programHandle, "YuvConversionMatrix");
}

#pragma mark - render byte
- (void)innerRenderFrame:(Byte *)data format:(TXIliveRoomFrameFormat)format width:(NSInteger)width height:(NSInteger)height {
    Byte *y = data;
    Byte *u = data + width * height;
    Byte *v = NULL;
    if(format == TXE_FRAME_FORMAT_I420){
        v = data + width * height * 5 / 4;
    }
    [self innerRenderFrame:y u:u v:v format:format width:(uint32_t)width height:(uint32_t)height];
}

#pragma mark - render samplebuffer
- (void)renderFrame:(CMSampleBufferRef)sampleBuffer {
    EAGLContext *context = [EAGLContext currentContext];
    CFRetain(sampleBuffer);
    [[iLiveOpenGLContext shareInstance] runSyncOnRenderQueue:^{
        if (sampleBuffer == nil || _isInBackground) {
            return;
        }
    
        _curContext = [iLiveOpenGLContext shareInstance].openGLContext;
        if([EAGLContext currentContext] != _curContext){
            [EAGLContext setCurrentContext:_curContext];
        }
        
        if(!_isInitOpenglParam){
            _isInitOpenglParam = YES;
            [self setupLayer];
            [self setupRenderBuffer];
            [self setupFrameBuffer];
            [self setupTexture];
            [self compileShaders];
        }
        [self innerRenderFrame:sampleBuffer];
        CFRelease(sampleBuffer);
    }];
    [EAGLContext setCurrentContext:context];
}

- (void)innerRenderFrame:(CMSampleBufferRef)sampleBuffer{
    CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
    int bufferWidth = (int) CVPixelBufferGetWidth(cameraFrame);
    int bufferHeight = (int) CVPixelBufferGetHeight(cameraFrame);
    OSType pixelFormat = CVPixelBufferGetPixelFormatType(cameraFrame);
    
    CGSize newSize = CGSizeMake(bufferWidth, bufferHeight);
    if(!CGSizeEqualToSize(_bufSize, newSize)){
        _bufSize = newSize;
    }
    switch (pixelFormat) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            _format = TXE_FRAME_FORMAT_NV12;
            break;
        case kCVPixelFormatType_420YpCbCr8Planar:
        case kCVPixelFormatType_420YpCbCr8PlanarFullRange:
            if(_format != TXE_FRAME_FORMAT_I420){
                _format = TXE_FRAME_FORMAT_I420;
                //硬解切软解的时候，需要重新创建纹理，使用硬解的纹理会导致绿屏
                [self setupTexture];
            }
            break;
        default:
            //TODO 不支持的格式类型
            return;
    }

    //    CMTime currentTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer);
    if ([iLiveOpenGLContext supportsFastTextureUpload])
    {
        if (CVPixelBufferGetPlaneCount(cameraFrame) > 0){
            CVOpenGLESTextureRef yTextureRef = NULL;
            CVOpenGLESTextureRef uTextureRef = NULL;
            CVPixelBufferLockBaseAddress(cameraFrame, 0);
            if(_format == TXE_FRAME_FORMAT_NV12){
                //硬编、软解、硬解
                CVReturn err;
                // Y-plane
                glActiveTexture(GL_TEXTURE0);
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[iLiveOpenGLContext shareInstance] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE, bufferWidth, bufferHeight, GL_LUMINANCE, GL_UNSIGNED_BYTE, 0, &yTextureRef);
                _yuvYTexture = CVOpenGLESTextureGetName(yTextureRef);
                glBindTexture(GL_TEXTURE_2D, _yuvYTexture);
                glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            
                // UV-plane
                glActiveTexture(GL_TEXTURE1);
                err = CVOpenGLESTextureCacheCreateTextureFromImage(kCFAllocatorDefault, [[iLiveOpenGLContext shareInstance] coreVideoTextureCache], cameraFrame, NULL, GL_TEXTURE_2D, GL_LUMINANCE_ALPHA, bufferWidth/2, bufferHeight/2, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, 1, &uTextureRef);
                _yuvUTexture = CVOpenGLESTextureGetName(uTextureRef);
                glBindTexture(GL_TEXTURE_2D, _yuvUTexture);
                glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
                glTexParameterf(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
                
                [self convertYUVToRGBOutput];
                
                if(yTextureRef != NULL){
                    CFRelease(yTextureRef);
                }
                if(uTextureRef != NULL){
                    CFRelease(uTextureRef);
                }
            }
            else if(_format == TXE_FRAME_FORMAT_I420){
                //软编
                Byte *y = CVPixelBufferGetBaseAddressOfPlane(cameraFrame, 0);
                Byte *u = CVPixelBufferGetBaseAddressOfPlane(cameraFrame, 1);
                Byte *v = CVPixelBufferGetBaseAddressOfPlane(cameraFrame, 2);
                [self innerRenderFrame:y u:u v:v format:_format width:bufferWidth height:bufferHeight];
            }
            else{
                //TODO:不支持的格式
            }
            
            CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
        }
        else{
            //TODO:samplebuffer格式出错
        }
    }
    else{
        //TODO:不支持快速纹理上传
        if (CVPixelBufferGetPlaneCount(cameraFrame) > 0){
            CVPixelBufferLockBaseAddress(cameraFrame, 0);
            Byte *y = NULL;
            Byte *u = NULL;
            Byte *v = NULL;
            if(_format == TXE_FRAME_FORMAT_NV12){
                y = CVPixelBufferGetBaseAddressOfPlane(cameraFrame, 0);
                u = CVPixelBufferGetBaseAddressOfPlane(cameraFrame, 1);
            }
            else if(_format == TXE_FRAME_FORMAT_I420){
                y = CVPixelBufferGetBaseAddressOfPlane(cameraFrame, 0);
                u = CVPixelBufferGetBaseAddressOfPlane(cameraFrame, 1);
                v = CVPixelBufferGetBaseAddressOfPlane(cameraFrame, 2);
            }
            else{
                //TODO:不支持的格式
            }
            [self innerRenderFrame:y u:u v:v format:_format width:bufferWidth height:bufferHeight];
            CVPixelBufferUnlockBaseAddress(cameraFrame, 0);
        }
        else{
            //TODO:samplebuffer格式出错
        }
    }
}

- (void)innerRenderFrame:(Byte *)y u:(Byte *)u v:(Byte *)v format:(TXIliveRoomFrameFormat)format width:(int)width height:(int)height{
    _format = format;
    if (_format == TXE_FRAME_FORMAT_I420) {
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, _yuvYTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width, height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, y);
        
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, _yuvUTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width / 2, height / 2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, u);
        
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, _yuvVTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width / 2, height / 2, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, v);
    } else if (_format == TXE_FRAME_FORMAT_NV12) {
        glActiveTexture(GL_TEXTURE0);
        glBindTexture(GL_TEXTURE_2D, _yuvYTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE, width, height, 0, GL_LUMINANCE, GL_UNSIGNED_BYTE, y);
        
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, _yuvUTexture);
        glTexImage2D(GL_TEXTURE_2D, 0, GL_LUMINANCE_ALPHA, width / 2, height / 2, 0, GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, u);
    } else {
        //TODO:不支持的格式
    }
    
    [self convertYUVToRGBOutput];
}

#pragma mark - render samplebuffer and byte
- (void)convertYUVToRGBOutput
{
    if(!CGRectEqualToRect(_frameRect, _frame)){
        _frameRect = _frame;
        glDeleteFramebuffers(1, &_frameBuffer);
        glDeleteRenderbuffers(1, &_renderBuffer);
        glGenRenderbuffers(1, &_renderBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
        [_curContext renderbufferStorage:GL_RENDERBUFFER fromDrawable:_eaglLayer];
        glGenFramebuffers(1, &_frameBuffer);
        glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
        glFramebufferRenderbuffer(GL_FRAMEBUFFER, GL_COLOR_ATTACHMENT0, GL_RENDERBUFFER, _renderBuffer);
    }
    else{
        glBindFramebuffer(GL_FRAMEBUFFER, _frameBuffer);
        glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    }
    glUseProgram(_programHandle);
    glViewport(0, 0, _frameRect.size.width * [UIScreen mainScreen].scale, _frameRect.size.height * [UIScreen mainScreen].scale);
    
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT);
    
    glActiveTexture(GL_TEXTURE0);
    glBindTexture(GL_TEXTURE_2D, _yuvYTexture);
    glUniform1i(_textureUniformY, 0);
    
    _preferredConversion = kiLiveRenderColorConversion601FullRangeDefault;
    if(_format == TXE_FRAME_FORMAT_NV12){
        glUniform1i(_yuvTypeUniform, 1);
        
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, _yuvUTexture);
        glUniform1i(_textureUniformU, 1);
    }
    else if(_format == TXE_FRAME_FORMAT_I420){
        glUniform1i(_yuvTypeUniform, 0);
        
        glActiveTexture(GL_TEXTURE1);
        glBindTexture(GL_TEXTURE_2D, _yuvUTexture);
        glUniform1i(_textureUniformU, 1);
        
        glActiveTexture(GL_TEXTURE2);
        glBindTexture(GL_TEXTURE_2D, _yuvVTexture);
        glUniform1i(_textureUniformV, 2);
    }
    else if(_format == TXE_FRAME_FORMAT_RGBA){
        glUniform1i(_yuvTypeUniform, 2);
    }
    else{
        //TODO:不支持的格式
    }
    
    [self calculateVertices];
    glUniformMatrix3fv(_yuvConversionMatrixUniform, 1, GL_FALSE, _preferredConversion);
    glVertexAttribPointer(_positionSlot, 2, GL_FLOAT, 0, 0, _imageVertices);
    glVertexAttribPointer(_texCoordSlot, 2, GL_FLOAT, 0, 0, [iLiveRenderView textureCoordinatesForRotation:[self calculateRotation]]);
    
    glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);
    [_curContext presentRenderbuffer:GL_RENDERBUFFER];
    glBindRenderbuffer(GL_RENDERBUFFER, 0);
    glBindFramebuffer(GL_FRAMEBUFFER, 0);
}

#pragma mark - helper

- (void)calculateVertices
{
    CGFloat heightScaling = 0, widthScaling = 0;
    CGSize currentViewSize = _frameRect.size;
    CGSize currentBufSize = _bufSize;
    if(_rotation == TXE_ROTATION_90 || _rotation == TXE_ROTATION_270){
        currentBufSize = CGSizeMake(_bufSize.height, _bufSize.width);
    }
    
    CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(currentBufSize, CGRectMake(0, 0, currentViewSize.width, currentViewSize.height));
    
    switch(_renderMode)
    {
        case TXE_RENDER_MODE_FILL_EDGE:
        {
            widthScaling = insetRect.size.width / currentViewSize.width;
            heightScaling = insetRect.size.height / currentViewSize.height;
        }; break;
        case TXE_RENDER_MODE_FILL_SCREEN:
        {
            //            CGFloat widthHolder = insetRect.size.width / currentViewSize.width;
            widthScaling = currentViewSize.height / insetRect.size.height;
            heightScaling = currentViewSize.width / insetRect.size.width;
        }; break;
    }
    
    _imageVertices[0] = -widthScaling;
    _imageVertices[1] = -heightScaling;
    _imageVertices[2] = widthScaling;
    _imageVertices[3] = -heightScaling;
    _imageVertices[4] = -widthScaling;
    _imageVertices[5] = heightScaling;
    _imageVertices[6] = widthScaling;
    _imageVertices[7] = heightScaling;
}

+ (const GLfloat *)textureCoordinatesForRotation:(TXERotationInner)rotationMode;
{
    //    static const GLfloat noRotationTextureCoordinates[] = {
    //        0.0f, 0.0f,
    //        1.0f, 0.0f,
    //        0.0f, 1.0f,
    //        1.0f, 1.0f,
    //    };
    
    static const GLfloat noRotation[] = {
        0.0f, 1.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 0.0f,
    };
    
    static const GLfloat rotateRight[] = {
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotateLeft[] = {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat verticalFlip[] = {
        0.0f, 0.0f,
        1.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
    };
    
    static const GLfloat horizontalFlip[] = {
        1.0f, 1.0f,
        0.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
    };
    
    static const GLfloat rotateRightVerticalFlip[] = {
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
    };
    
    static const GLfloat rotateRightHorizontalFlip[] = {
        0.0f, 1.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
    };
    
    static const GLfloat rotate180[] = {
        1.0f, 0.0f,
        0.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 1.0f,
    };
    
    switch(rotationMode)
    {
        case TXE_ROTATION_INNER_NO: return noRotation;
        case TXE_ROTATION_INNER_LEFT: return rotateLeft;
        case TXE_ROTATION_INNER_RIGHT: return rotateRight;
        case TXE_ROTATION_INNER_FLIP_V: return verticalFlip;
        case TXE_ROTATION_INNER_FLIP_H: return horizontalFlip;
        case TXE_ROTATION_INNER_RIGHT_FLIP_V: return rotateRightVerticalFlip;
        case TXE_ROTATION_INNER_RIGHT_FLIP_H: return rotateRightHorizontalFlip;
        case TXE_ROTATION_INNER_180: return rotate180;
        default:
            return noRotation;
    }
}

- (TXERotationInner)calculateRotation
{
    switch (_rotation) {
        case TXE_ROTATION_0:
            return TXE_ROTATION_INNER_NO;
        case TXE_ROTATION_90:
            return TXE_ROTATION_INNER_RIGHT;
        case TXE_ROTATION_180:
            return TXE_ROTATION_INNER_180;
        case TXE_ROTATION_270:
            return TXE_ROTATION_INNER_LEFT;
        default:
            return TXE_ROTATION_INNER_NO;
    }
}

- (void)setRotation:(TXIliveRoomRotation)rotation
{
    [[iLiveOpenGLContext shareInstance] runAsyncOnRenderQueue:^{
        _rotation = rotation;
    }];
}

- (void)setRenderMode:(TXIliveRoomRenderMode)renderMode
{
    [[iLiveOpenGLContext shareInstance] runAsyncOnRenderQueue:^{
        _renderMode = renderMode;
    }];
}

#pragma mark - background
- (void)applicationWillResignActive:(NSNotification*)notification
{
    EAGLContext* context = [EAGLContext currentContext];
    [[iLiveOpenGLContext shareInstance] runSyncOnRenderQueue:^{
        _isInBackground = YES;
        [EAGLContext setCurrentContext:_curContext];
        glFinish();
    }];
    [EAGLContext setCurrentContext:context];
}

- (void)applicationDidBecomeActive:(NSNotification*)notification
{
    EAGLContext* context = [EAGLContext currentContext];
    [[iLiveOpenGLContext shareInstance] runSyncOnRenderQueue:^{
        _isInBackground = NO;
    }];
    [EAGLContext setCurrentContext:context];
}

- (void)applicationDidEnterBackground:(NSNotification*)notification
{
    EAGLContext* context = [EAGLContext currentContext];
    [[iLiveOpenGLContext shareInstance] runSyncOnRenderQueue:^{
        if (!_isInBackground) {
            _isInBackground = YES;
            [EAGLContext setCurrentContext:_curContext];
            glFinish();
        }
    }];
    [EAGLContext setCurrentContext:context];
}

- (void)applicationWillEnterForeground:(NSNotification*)notification
{
    [[iLiveOpenGLContext shareInstance] runSyncOnRenderQueue:^{
    }];
}
@end
