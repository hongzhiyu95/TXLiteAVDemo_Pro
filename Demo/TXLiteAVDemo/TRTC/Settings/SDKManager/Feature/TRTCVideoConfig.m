/*
* Module:   TRTCVideoConfig
*
* Function: 保存视频的设置项，并提供每个分辨率下对应的码率支持
*
*    1. 在init中，会检查UserDefauls是否有历史记录，如存在则用历史记录初始化对象
*
*    2. 在dealloc中，将对象当前的值保存进UserDefaults中
*
*    3. 分辨率对应的码率配置在TRTCBitrateRange对象中，包括最小、最大和推荐码率，以及码率调整的步长
*/

#import "TRTCVideoConfig.h"

@interface TRTCVideoConfig()

@property (nonatomic) TRTCAppScene scene;

@end

@implementation TRTCVideoConfig

- (instancetype)initWithScene:(TRTCAppScene)scene {
    if (self = [super init]) {
        self.scene = scene;
        self.source = TRTCVideoSourceCamera;
        self.subSource = TRTCVideoSourceNone;
        self.videoEncConfig = [[TRTCVideoEncParam alloc] init];
        self.videoEncConfig.videoResolution = TRTCVideoResolution_640_360;
        self.videoEncConfig.videoBitrate = scene == TRTCAppSceneLIVE ? 750 : 500;
        if (scene == TRTCAppSceneVideoCall) {
            self.videoEncConfig.enableAdjustRes = YES;
        }
        self.smallVideoEncConfig = [[TRTCVideoEncParam alloc] init];
        self.smallVideoEncConfig.videoResolution = TRTCVideoResolution_160_90;
        self.smallVideoEncConfig.videoBitrate = 100;
        
        self.subStreamVideoEncConfig = [[TRTCVideoEncParam alloc] init];
        self.subStreamVideoEncConfig.videoResolution = TRTCVideoResolution_640_360;
        self.subStreamVideoEncConfig.videoBitrate = scene == TRTCAppSceneLIVE ? 750 : 500;
        if (scene == TRTCAppSceneVideoCall) {
            self.subStreamVideoEncConfig.enableAdjustRes = YES;
        }
        
        self.qosConfig = [[TRTCNetworkQosParam alloc] init];
        
        self.isEnabled = YES;
        self.isFrontCamera = YES;
        self.isAutoFocusOn = YES;
        self.localRenderParams = [[TRTCRenderParams alloc] init];
        self.enableHEVCAbility = [self isSupportDecodeH265] && [self isSupportEncodeH265];
        [self loadFromLocal];
    }
    return self;
}

- (BOOL)isSupportEncodeH265
{
    if (@available(iOS 11.0, macOS 10.13, *)) {
        static BOOL isSupported = NO;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            isSupported = [[AVAssetExportSession allExportPresets] containsObject:AVAssetExportPresetHEVCHighestQuality];
        });
        return isSupported;
    }
    return NO;
}

- (BOOL)isSupportDecodeH265
{
#if defined(__MAC_10_13) || defined(__IPHONE_11_0)
    if (@available(iOS 11.0, macOS 10.13, *)) {
       return YES;
    }
#endif
    return NO;
}

- (void)dealloc {
    [self saveToLocal];
}

- (void)loadFromLocal {
    NSDictionary *dict = [[NSUserDefaults standardUserDefaults] dictionaryForKey:@"TRTCVideoConfig"];
    if (!dict) {
        return;
    }
    self.videoEncConfig.videoResolution = [dict[@"resolution"] integerValue];
    self.videoEncConfig.videoBitrate = [dict[@"videoBitrate"] intValue];
    self.videoEncConfig.videoFps = [dict[@"videoFps"] intValue];
    self.videoEncConfig.resMode = [dict[@"resMode"] integerValue];
    self.smallVideoEncConfig.videoFps = [dict[@"videoFps"] intValue];
    self.smallVideoEncConfig.resMode = [dict[@"resMode"] integerValue];
    self.qosConfig.preference = [dict[@"preference"] integerValue];
    self.qosConfig.controlMode = [dict[@"controlMode"] integerValue];
    self.isRemoteMirrorEnabled = [dict[@"isRemoteMirrorEnabled"] boolValue];
    self.localRenderParams.mirrorType = [dict[@"localMirrorType"] integerValue];
    self.localRenderParams.fillMode = [dict[@"fillMode"] integerValue];
    self.isSmallVideoEnabled = [dict[@"isSmallVideoEnabled"] boolValue];
    self.prefersLowQuality = [dict[@"prefersLowQuality"] boolValue];
    self.isGSensorEnabled = [dict[@"isGSensorEnabled"] boolValue];
    self.isH265Enabled= [dict[@"isH265Enabled"] boolValue];
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"resolution" : @(self.videoEncConfig.videoResolution),
        @"videoFps" : @(self.videoEncConfig.videoFps),
        @"videoBitrate" : @(self.videoEncConfig.videoBitrate),
        @"resMode" : @(self.videoEncConfig.resMode),
        @"preference" : @(self.qosConfig.preference),
        @"controlMode" : @(self.qosConfig.controlMode),
        @"isRemoteMirrorEnabled" : @(self.isRemoteMirrorEnabled),
        @"localMirrorType" : @(self.localRenderParams.mirrorType),
        @"fillMode" : @(self.localRenderParams.fillMode),
        @"isSmallVideoEnabled" : @(self.isSmallVideoEnabled),
        @"prefersLowQuality" : @(self.prefersLowQuality),
        @"isGSensorEnabled" : @(self.isGSensorEnabled),
        @"isH265Enabled" : @(self.isH265Enabled),
    };
}

- (void)saveToLocal {
    NSDictionary *dict = [self dictionaryRepresentation];
    [[NSUserDefaults standardUserDefaults] setValue:dict forKey:@"TRTCVideoConfig"];
}

+ (NSArray<NSNumber *> *)formats {
    return @[
        @(TRTCVideoPixelFormat_Unknown),
        @(TRTCVideoPixelFormat_Texture_2D),
        @(TRTCVideoPixelFormat_NV12),
        @(TRTCVideoPixelFormat_I420),
        @(TRTCVideoPixelFormat_32BGRA),
    ];
}

+ (NSArray<NSString *> *)formatNames {
    return @[ @"关闭", @"纹理", @"NV12", @"I420", @"RGB" ];
}

- (NSInteger)formatIndex {
    return [[[self class] formats] indexOfObject:@(self.format)];
}

+ (NSArray<NSNumber *> *)resolutions {
    return @[
        @(TRTCVideoResolution_160_160),
        @(TRTCVideoResolution_320_180),
        @(TRTCVideoResolution_320_240),
        @(TRTCVideoResolution_640_360),
        @(TRTCVideoResolution_480_480),
        @(TRTCVideoResolution_640_480),
        @(TRTCVideoResolution_960_540),
        @(TRTCVideoResolution_1280_720),
        @(TRTCVideoResolution_1920_1080),
    ];
}
+ (NSArray<NSString *> *)resolutionNames {
    return @[
        @"160x160",
        @"180x320",
        @"240x320",
        @"360x640",
        @"480x480",
        @"480x640",
        @"540x960",
        @"720x1280",
        @"1080X1920",
    ];
}

+ (NSArray<NSString *> *)fpsList {
    return @[@"15", @"20", @"24"];
}

+ (NSArray<NSString *> *)localMirrorTypeNames {
    return @[@"自动", @"开启", @"关闭"];
}

+ (TRTCBitrateRange *)bitrateRangeOf:(TRTCVideoResolution)resolution scene:(TRTCAppScene)scene {
    BOOL isLive = scene == TRTCAppSceneLIVE;
    switch (resolution) {
        case TRTCVideoResolution_160_160:
            return isLive
            ? [[TRTCBitrateRange alloc] initWithMin:40 max:300 defaultBitrate:220 step:10]
            : [[TRTCBitrateRange alloc] initWithMin:40 max:150 defaultBitrate:150 step:10];
        case TRTCVideoResolution_320_180:
            return isLive
            ? [[TRTCBitrateRange alloc] initWithMin:80 max:350 defaultBitrate:350 step:10]
            : [[TRTCBitrateRange alloc] initWithMin:80 max:350 defaultBitrate:250 step:10];
        case TRTCVideoResolution_320_240:
            return isLive
            ? [[TRTCBitrateRange alloc] initWithMin:100 max:400 defaultBitrate:400 step:10]
            : [[TRTCBitrateRange alloc] initWithMin:100 max:400 defaultBitrate:300 step:10];
        case TRTCVideoResolution_640_360:
            return isLive
            ? [[TRTCBitrateRange alloc] initWithMin:200 max:1000 defaultBitrate:750 step:10]
            : [[TRTCBitrateRange alloc] initWithMin:200 max:1000 defaultBitrate:500 step:10];
        case TRTCVideoResolution_480_480:
            return isLive
            ? [[TRTCBitrateRange alloc] initWithMin:200 max:1000 defaultBitrate:600 step:10]
            : [[TRTCBitrateRange alloc] initWithMin:200 max:1000 defaultBitrate:400 step:10];
        case TRTCVideoResolution_640_480:
            return isLive
            ? [[TRTCBitrateRange alloc] initWithMin:250 max:1000 defaultBitrate:900 step:50]
            : [[TRTCBitrateRange alloc] initWithMin:250 max:1000 defaultBitrate:600 step:50];
        case TRTCVideoResolution_960_540:
            return isLive
            ? [[TRTCBitrateRange alloc] initWithMin:400 max:1600 defaultBitrate:1200 step:50]
            : [[TRTCBitrateRange alloc] initWithMin:400 max:1600 defaultBitrate:800 step:50];
        case TRTCVideoResolution_1280_720:
            return isLive
            ? [[TRTCBitrateRange alloc] initWithMin:500 max:2000 defaultBitrate:1750 step:10]
            : [[TRTCBitrateRange alloc] initWithMin:500 max:2000 defaultBitrate:1150 step:10];
        case TRTCVideoResolution_1920_1080:
            return isLive
            ? [[TRTCBitrateRange alloc] initWithMin:800 max:3000 defaultBitrate:1900 step:50]
            : [[TRTCBitrateRange alloc] initWithMin:800 max:3000 defaultBitrate:1900 step:50];
        default:
            assert(false);
            return [[TRTCBitrateRange alloc] init];
    }
}

- (NSInteger)resolutionIndex {
    for (NSInteger i = 0; i < TRTCVideoConfig.resolutions.count; i++) {
        if ([TRTCVideoConfig.resolutions[i] integerValue] == self.videoEncConfig.videoResolution) {
            return i;
        }
    }
    return NSNotFound;
}

- (NSInteger)fpsIndex {
    for (NSInteger i = 0; i < TRTCVideoConfig.fpsList.count; i++) {
        if ([TRTCVideoConfig.fpsList[i] intValue] == self.videoEncConfig.videoFps) {
            return i;
        }
    }
    return NSNotFound;
}

- (NSInteger)qosPreferenceIndex {
    return self.qosConfig.preference == TRTCVideoQosPreferenceSmooth ? 0 : 1;
}

@end


@implementation TRTCBitrateRange

- (instancetype)initWithMin:(NSInteger)min max:(NSInteger)max defaultBitrate:(NSInteger)defaultBitrate step:(NSInteger)step {
    if (self = [super init]) {
        self.minBitrate = min;
        self.maxBitrate = max;
        self.defaultBitrate = defaultBitrate;
        self.step = step;
    }
    return self;
}

@end
