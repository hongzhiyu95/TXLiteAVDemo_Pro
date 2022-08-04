//
//  iLiveBGMControl.m
//  TXLiteAVDemo_ILiveRoom_Standard
//
//  Created by xiang zhang on 2018/10/29.
//  Copyright © 2018 Tencent. All rights reserved.
//

#import "iLiveBGMControl.h"
#import "UIView+Additions.h"

@interface iLiveBGMControl()<UITextFieldDelegate>

@end

@implementation iLiveBGMControl
{
    UISwitch *_uploadSwitch;
    UITextField *_bgmLoopField;
    UITextField *_pitchField;
}

-(instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        _bgmLoopField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 50, 30)];
        _bgmLoopField.placeholder = @"循环次数?";
        _bgmLoopField.delegate = self;
        
        UILabel *uploadLabel = [[UILabel alloc] initWithFrame:CGRectMake(_bgmLoopField.right, _bgmLoopField.top, 50 * 1.2, 30)];
        uploadLabel.text = @"本地?";
        _uploadSwitch = [[UISwitch alloc] initWithFrame:CGRectMake(uploadLabel.right, uploadLabel.top, 50, 30)];
        
        UIButton *startBtn = [[UIButton alloc] initWithFrame:CGRectMake(_uploadSwitch.right, _uploadSwitch.top, _uploadSwitch.width, _uploadSwitch.height)];
        [startBtn setTitle:@"播放" forState:UIControlStateNormal];
        [startBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        [startBtn addTarget:self action:@selector(start:) forControlEvents:UIControlEventTouchUpInside];
        
        UIButton *lrsBtn = [[UIButton alloc] initWithFrame:CGRectMake(startBtn.right, startBtn.top, startBtn.width, startBtn.height)];
        [lrsBtn setTitle:@"狼人" forState:UIControlStateNormal];
        [lrsBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        [lrsBtn addTarget:self action:@selector(onClickLRS:) forControlEvents:UIControlEventTouchUpInside];
        
        UIButton *onLineStartBtn = [[UIButton alloc] initWithFrame:CGRectMake(lrsBtn.right, lrsBtn.top, lrsBtn.width, lrsBtn.height)];
        [onLineStartBtn setTitle:@"在线" forState:UIControlStateNormal];
        [onLineStartBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        [onLineStartBtn addTarget:self action:@selector(onLineStart:) forControlEvents:UIControlEventTouchUpInside];
        
        UIButton *stopBtn = [[UIButton alloc] initWithFrame:CGRectMake(onLineStartBtn.right, onLineStartBtn.top, onLineStartBtn.width, onLineStartBtn.height)];
        [stopBtn setTitle:@"停止" forState:UIControlStateNormal];
        [stopBtn setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        [stopBtn addTarget:self action:@selector(stop:) forControlEvents:UIControlEventTouchUpInside];
        
        UILabel *micVolume = [[UILabel alloc] initWithFrame:CGRectMake(0, _bgmLoopField.bottom + 10, 50, 30)];
        micVolume.text = @"MIC";
        UISlider *micSlider = [[UISlider alloc] initWithFrame:CGRectMake(micVolume.right, micVolume.top, self.width - micVolume.right, micVolume.height)];
        micSlider.minimumValue = 0;
        micSlider.maximumValue = 1;
        micSlider.value = 1;
        [micSlider addTarget:self action:@selector(micVolume:) forControlEvents:UIControlEventTouchUpInside];
        
        UILabel *bgmVolume = [[UILabel alloc] initWithFrame:CGRectMake(0, micVolume.bottom + 10, micVolume.width, micVolume.height)];
        bgmVolume.text = @"BGM";
        UISlider *bgmSlider = [[UISlider alloc] initWithFrame:CGRectMake(bgmVolume.right, bgmVolume.top, micSlider.width, micSlider.height)];
        bgmSlider.minimumValue = 0;
        bgmSlider.maximumValue = 1;
        bgmSlider.value = 1;
        [bgmSlider addTarget:self action:@selector(bgmVolume:) forControlEvents:UIControlEventTouchUpInside];
        
        UILabel *seekLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, bgmVolume.bottom + 10, bgmVolume.width, bgmVolume.height)];
        seekLabel.text = @"Seek";
        UISlider *seekSlider = [[UISlider alloc] initWithFrame:CGRectMake(seekLabel.right, seekLabel.top, bgmSlider.width, bgmSlider.height)];
        seekSlider.minimumValue = 0;
        seekSlider.maximumValue = 1;
        seekSlider.value = 0;
        [seekSlider addTarget:self action:@selector(bgmSeek:) forControlEvents:UIControlEventTouchUpInside];
        
        
        _pitchField = [[UITextField alloc] initWithFrame:CGRectMake(10, seekSlider.bottom + 10, 50 * 2, 30)];
        _pitchField.placeholder = @"-12 ~ 12";
        _pitchField.delegate = self;

        UIButton *pitch = [[UIButton alloc] initWithFrame:CGRectMake(_pitchField.right + 10, seekSlider.bottom + 10, 100, _uploadSwitch.height)];
        [pitch setTitle:@"调整音调" forState:UIControlStateNormal];
        [pitch setTitleColor:[UIColor greenColor] forState:UIControlStateNormal];
        [pitch setTag:0];
        [pitch addTarget:self action:@selector(pitchClick:) forControlEvents:UIControlEventTouchUpInside];
        
        [self addSubview:_bgmLoopField];
        [self addSubview:uploadLabel];
        [self addSubview:_uploadSwitch];
        [self addSubview:startBtn];
        [self addSubview:lrsBtn];
        [self addSubview:onLineStartBtn];
        [self addSubview:stopBtn];
        [self addSubview:micVolume];
        [self addSubview:micSlider];
        [self addSubview:bgmVolume];
        [self addSubview:bgmSlider];
        [self addSubview:seekLabel];
        [self addSubview:seekSlider];
        [self addSubview:_pitchField];
        [self addSubview:pitch];
        self.backgroundColor = [UIColor grayColor];
    }
    return self;
}

-(void)pitchClick:(UIButton *)btn
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(onBgmPitchClick:)]) {
        [self.delegate onBgmPitchClick:[_pitchField.text  isEqual: @""] ? 12 : [_pitchField.text intValue]];
    }
}

-(void)start:(UIButton *)btn
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(onBgmStart:loopTimes:type:)]) {
        [self.delegate onBgmStart:_uploadSwitch.isOn loopTimes:([_bgmLoopField.text  isEqual: @""] ? 1 : [_bgmLoopField.text intValue]) type:0];
    }
}

-(void)onLineStart:(UIButton*)btn {
    if (self.delegate && [self.delegate respondsToSelector:@selector(onBgmStart:loopTimes:type:)]) {
        [self.delegate onBgmStart:_uploadSwitch.isOn loopTimes:([_bgmLoopField.text  isEqual: @""] ? 1 : [_bgmLoopField.text intValue]) type:2];
    }
}

-(void)onClickLRS:(UIButton*) btn{
    if (self.delegate && [self.delegate respondsToSelector:@selector(onBgmStart:loopTimes:type:)]) {
        [self.delegate onBgmStart:_uploadSwitch.isOn loopTimes:([_bgmLoopField.text  isEqual: @""] ? 1 : [_bgmLoopField.text intValue]) type:1];
    }
}

-(void)stop:(UIButton *)btn
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(onBgmStop)]) {
        [self.delegate onBgmStop];
    }
}

-(void)micVolume:(UISlider *)slider
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(onMicVolume:)]) {
        [self.delegate onMicVolume:slider.value];
    }
}

-(void)bgmVolume:(UISlider *)slider
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(onBgmVolume:)]) {
        [self.delegate onBgmVolume:slider.value];
    }
}

-(void)bgmSeek:(UISlider *)slider
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(onBgmSeek:)]) {
        [self.delegate onBgmSeek:slider.value];
    }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    if (textField == _bgmLoopField) {
        [_bgmLoopField resignFirstResponder];
    } else {
        [_pitchField resignFirstResponder];
    }
    return YES;
}

@end
