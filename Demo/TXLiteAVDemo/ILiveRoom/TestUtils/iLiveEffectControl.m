//
//  iLiveEffectControl.m
//  TXLiteAVDemo_ILiveRoom_Standard
//
//  Created by xiang zhang on 2018/11/6.
//  Copyright © 2018 Tencent. All rights reserved.
//

#import "iLiveEffectControl.h"
#import "UIView+Additions.h"

@implementation iLiveEffectControl
{
    NSMutableDictionary *_loopParam;
    NSMutableArray *_sliderList;
}

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _sliderList = [NSMutableArray array];
        for (int i = 0; i < 3; i++) {
            UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 50 * i, 50, 30)];
            if (i == 0) {
                label.text = [NSString stringWithFormat:@"上行?"];
            }else{
                label.text = [NSString stringWithFormat:@"音效%d",i];
            }
            UISwitch *loopSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(label.right, label.top, label.width, label.height)];
            [loopSwitch addTarget:self action:@selector(loop:) forControlEvents:UIControlEventTouchUpInside];
            UIButton *startBtn = [[UIButton alloc] initWithFrame:CGRectMake(loopSwitch.right, loopSwitch.top, loopSwitch.width, loopSwitch.height)];
            loopSwitch.tag = i;
            [startBtn setTitle:@"播放" forState:UIControlStateNormal];
            [startBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
            [startBtn addTarget:self action:@selector(start:) forControlEvents:UIControlEventTouchUpInside];
            UIButton *stopBtn = [[UIButton alloc] initWithFrame:CGRectMake(startBtn.right, startBtn.top, startBtn.width, startBtn.height)];
            startBtn.tag = i;
            startBtn.hidden = (i == 0);
            [stopBtn setTitle:@"停止" forState:UIControlStateNormal];
            [stopBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
            [stopBtn addTarget:self action:@selector(stop:) forControlEvents:UIControlEventTouchUpInside];
            stopBtn.tag = i;
            stopBtn.hidden = (i == 0);
            UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(stopBtn.right,stopBtn.top, self.width - stopBtn.right, stopBtn.height)];
            slider.minimumValue = 0;
            slider.maximumValue = 1;
            slider.value = 1;
            [slider setThumbImage:[UIImage imageNamed:@"slider"] forState:UIControlStateNormal];
            [slider setMinimumTrackImage:[UIImage imageNamed:@"green"] forState:UIControlStateNormal];
            [slider setMaximumTrackImage:[UIImage imageNamed:@"gray"] forState:UIControlStateNormal];
            [slider addTarget:self action:@selector(volume:) forControlEvents:UIControlEventValueChanged];
            slider.tag = i;
            [_sliderList addObject:slider];
            [self addSubview:label];
            [self addSubview:loopSwitch];
            [self addSubview:startBtn];
            [self addSubview:stopBtn];
            [self addSubview:slider];
        }
        _loopParam = [NSMutableDictionary dictionary];
        self.backgroundColor = [UIColor grayColor];
    }
    return self;
}

- (void)loop:(UISwitch *)sw
{
    [_loopParam setObject:@(sw.isOn) forKey:@(sw.tag)];
}

- (void)start:(UIButton *)btn
{
    if (btn.tag>0 && self.delegate && [self.delegate respondsToSelector:@selector(onEffectStart:isLoop:publish:)]) {
        [self.delegate onEffectStart:(int)btn.tag isLoop:[_loopParam[@(btn.tag)] boolValue] publish:[_loopParam[@(0)] boolValue]];
    }
}

- (void)stop:(UIButton *)btn
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(onEffectStop:)]) {
        [self.delegate onEffectStop:(int)btn.tag];
    }
}

- (void)volume:(UISlider *)slider
{
    if (slider.tag == 0) {
        for (UISlider *sliderl in _sliderList) {
            sliderl.value = slider.value;
        }
    }
    if (self.delegate && [self.delegate respondsToSelector:@selector(onEffectVolume:volume:)]) {
        [self.delegate onEffectVolume:(int)slider.tag volume:slider.value];
    }
}

-(void)reset:(int)effectId;
{
    UISlider *slider = _sliderList[effectId];
    slider.value = [(UISlider *)_sliderList[0] value];
    if (self.delegate && [self.delegate respondsToSelector:@selector(onEffectVolume:volume:)]) {
        [self.delegate onEffectVolume:effectId volume:slider.value];
    }
}

@end
