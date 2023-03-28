// Copyright (c) 2020 Tencent. All rights reserved.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LiveLinkOrPkSwitchRoleViewController : UIViewController

@property(nonatomic, copy)void (^didClickNextBlock)(NSString *userId, BOOL isAnchor);
- (instancetype)initWithUserId:(NSString *)userId title:(NSString *)title;
@end
NS_ASSUME_NONNULL_END
