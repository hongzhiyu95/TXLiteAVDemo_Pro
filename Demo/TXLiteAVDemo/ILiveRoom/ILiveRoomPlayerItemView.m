//
//  ILiveRoomPlayerItemView.m
//  TXLiteAVDemo
//
//  Created by rushanting on 2018/9/17.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "ILiveRoomPlayerItemView.h"

@implementation ILiveRoomPlayerItemView
{
    UIImageView  *_loadingImageView;
}

- (id)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        //loading imageview
        NSMutableArray *array = [[NSMutableArray alloc] initWithObjects:[UIImage imageNamed:@"loading_1.png"],[UIImage imageNamed:@"loading_2.png"],[UIImage imageNamed:@"loading_3.png"],[UIImage imageNamed:@"loading_4.png"],[UIImage imageNamed:@"loading_5.png"],[UIImage imageNamed:@"loading_6.png"],[UIImage imageNamed:@"loading_7.png"],[UIImage imageNamed:@"loading_8.png"],[UIImage imageNamed:@"loading_9.png"],[UIImage imageNamed:@"loading_10.png"],[UIImage imageNamed:@"loading_11.png"],[UIImage imageNamed:@"loading_12.png"],[UIImage imageNamed:@"loading_13.png"],[UIImage imageNamed:@"loading_14.png"], nil];
        _loadingImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        _loadingImageView.animationImages = array;
        _loadingImageView.animationDuration = 1;
        _loadingImageView.hidden = YES;
        [self addSubview:_loadingImageView];
        
        _volumeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 50, 30)];
        _volumeLabel.textColor = [UIColor greenColor];
        [self addSubview:_volumeLabel];
    }
    return self;
}

- (void)layoutSubviews {
    float width = 45;
    float height = 45;
    float offsetX = (self.frame.size.width - width) / 2;
    float offsetY = (self.frame.size.height - height) / 2;
    _loadingImageView.frame = CGRectMake(offsetX, offsetY, width, height);
}

- (void)startLoadingAnimation {
    if (_loadingImageView != nil) {
        _loadingImageView.hidden = NO;
        [_loadingImageView startAnimating];
    }
}

- (void)stopLoadingAnimation {
    if (_loadingImageView != nil) {
        _loadingImageView.hidden = YES;
        [_loadingImageView stopAnimating];
    }
}

- (void)setHighlight:(BOOL)enable {
    self.layer.borderWidth = enable ? 1 : 0;
    self.layer.borderColor = enable ? UIColor.redColor.CGColor : UIColor.clearColor.CGColor;
}

@end

