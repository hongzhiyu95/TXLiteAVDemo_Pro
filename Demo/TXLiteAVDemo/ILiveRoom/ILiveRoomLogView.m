//
//  ILiveRoomLogView.m
//  TXLiteAVDemo
//
//  Created by rushanting on 2018/9/19.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "ILiveRoomLogView.h"

@interface ILiveRoomEventStatus : NSObject
@property (nonatomic, assign) UInt64    userID;
@property (nonatomic, strong) NSString* event;
@property (nonatomic, strong) NSString* status;
@property (nonatomic, strong) NSString* avStatistic;
@end


@implementation ILiveRoomEventStatus
- (instancetype)init {
    if (self = [super init]) {
        self.event = @"";
        self.status = @"";
        self.avStatistic = @"";
    }
    return self;
}
@end


@interface ILiveRoomLogView()
{
    NSUInteger                _insertIndex;
    NSMutableArray*           _evtStatsDataArray;
    int                       _evtStatsDataIndex;
    
    UIView*                   _currEvtStatsView;
    UIView*                   _prevEvtStatsView;
}
@property(nonatomic, weak) UIViewController* parentController;
@end

@implementation ILiveRoomLogView
- (id)initWithParentController:(UIViewController *)parentController
{
    if (self = [super init]) {
        _parentController = parentController;
        _evtStatsDataArray = [[NSMutableArray alloc] init];
        _evtStatsDataIndex = 0;
        _currEvtStatsView = [self createEvtStatsView:0];
        _prevEvtStatsView = [self createEvtStatsView:1];
    }
    
    return self;
}

- (void)addEvent:(UInt64)userID event:(NSString *)event
{
    for (ILiveRoomEventStatus * item in _evtStatsDataArray) {
        if (userID == item.userID) {
            item.event = [NSString stringWithFormat:@"%@\n%@", item.event, event];
            break;
        }
    }
    
    [self updateEvtAndStats:_currEvtStatsView index:_evtStatsDataIndex];
}

- (void)addStatus:(uint64_t)userID status:(NSString *)status
{
    for (ILiveRoomEventStatus * item in _evtStatsDataArray) {
        if (userID == item.userID) {
            item.status = status;
            break;
        }
    }
    
    [self updateEvtAndStats:_currEvtStatsView index:_evtStatsDataIndex];
}

- (void)addAVStatistic:(uint64_t)userID status:(NSString *)statitic {
    for (ILiveRoomEventStatus * item in _evtStatsDataArray) {
           if (userID == item.userID) {
               item.avStatistic = statitic;
               break;
           }
       }
    [self updateEvtAndStats:_currEvtStatsView index:_evtStatsDataIndex];
}

- (void)addEventStatusItem:(UInt64)userID {
    for (ILiveRoomEventStatus* item in _evtStatsDataArray) {
        if (item.userID == userID) {
            return;
        }
    }
    
    ILiveRoomEventStatus* eventStatus = [[ILiveRoomEventStatus alloc] init];
    eventStatus.userID = userID;
    [_evtStatsDataArray addObject:eventStatus];
}

- (void)delEventStatusItem:(UInt64)userID {
    for (ILiveRoomEventStatus* item in _evtStatsDataArray) {
        if (item.userID == userID) {
            [_evtStatsDataArray removeObject:item];
            break;
        }
    }
}

- (void)handleSwipes:(UISwipeGestureRecognizer *)sender {
    if (sender.direction == UISwipeGestureRecognizerDirectionLeft) {
        [self slideEvtStatsView:YES];
    }
    
    if (sender.direction == UISwipeGestureRecognizerDirectionRight) {
        [self slideEvtStatsView:NO];
    }
}

- (void)slideEvtStatsView:(BOOL)direction {
    _currEvtStatsView.hidden = NO;
    [_currEvtStatsView removeFromSuperview];
    if (_insertIndex > self.parentController.view.subviews.count) {
        _insertIndex = self.parentController.view.subviews.count;
    }
    [self.parentController.view insertSubview:_currEvtStatsView atIndex:_insertIndex];
    _prevEvtStatsView.hidden = NO;
    [_prevEvtStatsView removeFromSuperview];
    [self.parentController.view insertSubview:_prevEvtStatsView atIndex:_insertIndex];
    
    CGRect currFrame = _currEvtStatsView.frame;
    CGRect leftFrame = currFrame;
    CGRect rightFrame = currFrame;
    leftFrame.origin.x = -CGRectGetMaxX(currFrame);
    rightFrame.origin.x = [[UIScreen mainScreen] bounds].size.width;
    
    int evtStatsCount = (int)_evtStatsDataArray.count;
    int evtStatsIndex = ((direction ? _evtStatsDataIndex + 1 : _evtStatsDataIndex - 1) + evtStatsCount) % evtStatsCount;
    
    printf("slide count = %d currentIndex = %d nextIndex = %d\n", evtStatsCount, _evtStatsDataIndex, evtStatsIndex);
    
    _prevEvtStatsView.frame = direction ? rightFrame : leftFrame;
    [self updateEvtAndStats:_prevEvtStatsView index:evtStatsIndex];
    
    [UIView animateWithDuration:0.5f animations:^{
        _prevEvtStatsView.frame = currFrame;
        _currEvtStatsView.frame = direction ? leftFrame : rightFrame;
    } completion:^(BOOL finished) {
        if (finished) {
            UIView* tempView = _currEvtStatsView;
            _currEvtStatsView = _prevEvtStatsView;
            _prevEvtStatsView = tempView;
            
            _evtStatsDataIndex = evtStatsIndex;
            [self updateEvtAndStats:_currEvtStatsView index:_evtStatsDataIndex];
            
            if (_evtStatsDataIndex < _evtStatsDataArray.count) {
                ILiveRoomEventStatus* item = [_evtStatsDataArray objectAtIndex:_evtStatsDataIndex];
                if ([_delegate respondsToSelector:@selector(onShowPlayerView:)]) {
                    [_delegate onShowPlayerView:item.userID];
                }
//                [_parentController setPlayerViewHighlight:item.userID];
            }
        }
    }];
}


- (UIView *)createEvtStatsView:(int)index {
    CGSize size = [[UIScreen mainScreen] bounds].size;
    int ICON_SIZE = size.width / 10;
    
    UIView * view = [[UIView alloc] init];
    view.frame = CGRectMake(index == 0 ? 10.0f : size.width, 55 + 2 * ICON_SIZE, size.width - 20, size.height - 75 - 3 * ICON_SIZE);
    view.backgroundColor = [UIColor whiteColor];
    view.alpha = 0.5;
    view.hidden = YES;
    NSUInteger idx = 0;
    for (idx = 0; idx < self.parentController.view.subviews.count; idx++) {
        if ([self.parentController.view.subviews[idx] isKindOfClass:[UIButton class]]) {
            _insertIndex = idx;
            break;
        }
    }
    [self.parentController.view insertSubview:view atIndex:_insertIndex];
    
    int logheadH = 150;
    UITextView * statusView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, size.width - 20, logheadH)];
    statusView.backgroundColor = [UIColor clearColor];
    statusView.alpha = 1;
    statusView.textColor = [UIColor blackColor];
    statusView.editable = NO;
    statusView.tag = 0;
    [view addSubview:statusView];
    
    int avStatisticHead = 60;
    UITextView * avStatisticView = [[UITextView alloc] initWithFrame:CGRectMake(0, logheadH, size.width - 20, avStatisticHead)];
    avStatisticView.backgroundColor = [UIColor blackColor];
    avStatisticView.alpha = 0.5;
    avStatisticView.textColor = [UIColor whiteColor];
    avStatisticView.editable = NO;
    avStatisticView.tag = 1;
    [view addSubview:avStatisticView];
    
    UITextView * eventView = [[UITextView alloc] initWithFrame:CGRectMake(0, logheadH + avStatisticHead, size.width - 20, size.height - 75 - 3 * ICON_SIZE - logheadH - avStatisticHead)];
    eventView.backgroundColor = [UIColor clearColor];
    eventView.alpha = 1;
    eventView.textColor = [UIColor blackColor];
    eventView.editable = NO;
    eventView.tag = 2;
    [view addSubview:eventView];
    
    UISwipeGestureRecognizer *recognizerLeft;
    recognizerLeft = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipes:)];
    [recognizerLeft setDirection:(UISwipeGestureRecognizerDirectionLeft)];
    [eventView addGestureRecognizer:recognizerLeft];
    
    UISwipeGestureRecognizer *recognizerRight;
    recognizerRight = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipes:)];
    [recognizerRight setDirection:(UISwipeGestureRecognizerDirectionRight)];
    [eventView addGestureRecognizer:recognizerRight];
    
    return view;
}

- (void)setHidden:(BOOL)hidden
{
    BOOL changed = _currEvtStatsView.hidden != hidden;
    _currEvtStatsView.hidden = hidden;
    if (!hidden) {
        if (changed) {
            [self updateEvtAndStats:_currEvtStatsView index:_evtStatsDataIndex];
        }
        if (_evtStatsDataIndex < _evtStatsDataArray.count) {
            ILiveRoomEventStatus* item = [_evtStatsDataArray objectAtIndex:_evtStatsDataIndex];
            if ([_delegate respondsToSelector:@selector(onShowPlayerView:)]) {
                [_delegate onShowPlayerView:item.userID];
            }
        }
    }
}


- (void)updateEvtAndStats:(UIView*)view index:(int)index {
    if (_evtStatsDataArray.count == 0) {
        return;
    }
    
    if (index >= _evtStatsDataArray.count) {
        index = 0;
    }
    
    ILiveRoomEventStatus * eventStatus = [_evtStatsDataArray objectAtIndex:index];
    
    if (!_currEvtStatsView.hidden) {
        for (UITextView * item in [view subviews]) {
            if (item.tag == 0) {
                [item setText:eventStatus.status];
            } else if (item.tag == 2) {
                [item setText:eventStatus.event];
            } else if (item.tag == 1) {
                if ([eventStatus.avStatistic length] > 0) {
                    item.hidden = NO;
                    [item setText:eventStatus.avStatistic];
                } else {
                    item.hidden = YES;
                }
            }
        }
    }
}

- (void)freshCurrentEvtStatusView {
    [self updateEvtAndStats:_currEvtStatsView index:_evtStatsDataIndex];
//    if (_currEvtStatsView.hidden == NO) {
//        [_currEvtStatsView removeFromSuperview];
//        [self.parentController.view addSubview:_currEvtStatsView];
//    }
}


@end
