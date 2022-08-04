//
//  TRTCBroadcastExtensionLauncher.m
//  TXLiteAVDemo
//
//  Created by cui on 2020/5/29.
//  Copyright © 2020 Tencent. All rights reserved.
//

#import "TRTCBroadcastExtensionLauncher.h"
#import <ReplayKit/ReplayKit.h>

@implementation TRTCBroadcastExtensionLauncher
{
    RPSystemBroadcastPickerView *_systemBroacastExtensionPicker;
}

+ (instancetype)sharedInstance {
    static TRTCBroadcastExtensionLauncher *launcher = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        launcher = [[TRTCBroadcastExtensionLauncher alloc] init];
    });
    return launcher;
}

+ (void)launch {
    return [[TRTCBroadcastExtensionLauncher sharedInstance] show];
}

- (instancetype)init {
    if (self = [super init]) {
        if (@available(iOS 12.0, *)) {
            RPSystemBroadcastPickerView *picker = [[RPSystemBroadcastPickerView alloc] initWithFrame:CGRectMake(0, 0, 44, 44)];
            picker.showsMicrophoneButton = NO;
            NSString *extension = nil;
            NSString *pluginPath = [[NSBundle mainBundle] builtInPlugInsPath];
            NSArray *contents = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:pluginPath
                                                                                    error:nil];
            for (NSString *content in contents) {
                if ([content hasSuffix:@".appex"]) {
                    NSBundle *bundle = [NSBundle bundleWithPath:[pluginPath stringByAppendingPathComponent:content]];
                    if (bundle && [[bundle.infoDictionary valueForKeyPath:@"NSExtension.NSExtensionPointIdentifier"] isEqualToString:@"com.apple.broadcast-services-upload"]) {
                        extension = bundle.bundleIdentifier;
                        break;
                    }
                }
            }
            picker.preferredExtension = extension;
            picker.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin;
            _systemBroacastExtensionPicker = picker;
        }
    }
    return self;
}

- (void)show {
    for (UIView *view in _systemBroacastExtensionPicker.subviews) {
        if ([view isKindOfClass:[UIButton class]]) {
            if (@available(iOS 13.0, *)) {
                [(UIButton*)view sendActionsForControlEvents:UIControlEventTouchUpInside];
            } else {
                [(UIButton*)view sendActionsForControlEvents:UIControlEventTouchDown];
            }
            break;
        }
    }
}
@end
