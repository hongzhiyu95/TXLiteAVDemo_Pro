//
//  ILiveRoomLogView.h
//  TXLiteAVDemo
//
//  Created by rushanting on 2018/9/19.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol ILiveRoomLogViewDelegate <NSObject>

- (void)onShowPlayerView:(uint64_t)userID;

@end

@interface ILiveRoomLogView : NSObject
@property (nonatomic, weak) id<ILiveRoomLogViewDelegate> delegate;
@property (nonatomic, assign) BOOL hidden;


- (id)initWithParentController:(UIViewController*)parentController;
- (void)addEvent:(uint64_t)userID event:(NSString*)event;
- (void)addStatus:(uint64_t)userID status:(NSString*)status;
- (void)addAVStatistic:(uint64_t)userID status:(NSString*)statitic;
- (void)addEventStatusItem:(uint64_t)userID;
- (void)delEventStatusItem:(uint64_t)userID;
- (void)freshCurrentEvtStatusView;
@end
