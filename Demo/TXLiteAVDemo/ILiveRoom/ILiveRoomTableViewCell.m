//
//  ILiveRoomTableViewCell.m
//  TXLiteAVDemo
//
//  Created by lijie on 2018/9/14.
//  Copyright © 2018年 Tencent. All rights reserved.
//

#import "ILiveRoomTableViewCell.h"
#import "ColorMacro.h"

@interface ILiveRoomTableViewCell() {
    UILabel   *_roomNameLeftLabel;
    UILabel   *_roomNameRightLabel;
    UILabel   *_roomIDLeftLabel;
    UILabel   *_roomIDRightLabel;
    UILabel   *_roomCreatorLeftLabel;
    UILabel   *_roomCreatorRightLabel;
}
@end

@implementation ILiveRoomTableViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        self.backgroundColor = UIColorFromRGB(0x262626);
        
        _roomNameLeftLabel = [UILabel new];
        _roomNameLeftLabel.text = @"直播间名称:";
        _roomNameLeftLabel.font = [UIFont systemFontOfSize:16];
        _roomNameLeftLabel.textAlignment = NSTextAlignmentLeft;
        _roomNameLeftLabel.textColor = UIColorFromRGB(0x999999);
        
        _roomIDLeftLabel = [UILabel new];
        _roomIDLeftLabel.text = @"直播间ID:";
        _roomIDLeftLabel.font = [UIFont systemFontOfSize:16];
        _roomIDLeftLabel.textAlignment = NSTextAlignmentLeft;
        _roomIDLeftLabel.textColor = UIColorFromRGB(0x999999);
        
        _roomCreatorLeftLabel = [UILabel new];
        _roomCreatorLeftLabel.text = @"房主ID:";
        _roomCreatorLeftLabel.font = [UIFont systemFontOfSize:16];
        _roomCreatorLeftLabel.textAlignment = NSTextAlignmentLeft;
        _roomCreatorLeftLabel.textColor = UIColorFromRGB(0x999999);
        
        _roomNameRightLabel = [UILabel new];
        _roomNameRightLabel.text = @"";
        _roomNameRightLabel.font = [UIFont systemFontOfSize:16];
        _roomNameRightLabel.textAlignment = NSTextAlignmentLeft;
        _roomNameRightLabel.textColor = UIColorFromRGB(0xffffff);
        
        _roomIDRightLabel = [UILabel new];
        _roomIDRightLabel.text = @"";
        _roomIDRightLabel.font = [UIFont systemFontOfSize:16];
        _roomIDRightLabel.textAlignment = NSTextAlignmentLeft;
        _roomIDRightLabel.textColor = UIColorFromRGB(0xffffff);
        
        _roomCreatorRightLabel = [UILabel new];
        _roomCreatorRightLabel.text = @"";
        _roomCreatorRightLabel.font = [UIFont systemFontOfSize:16];
        _roomCreatorRightLabel.textAlignment = NSTextAlignmentLeft;
        _roomCreatorRightLabel.textColor = UIColorFromRGB(0xffffff);
        
        [self.contentView addSubview:_roomNameLeftLabel];
        [self.contentView addSubview:_roomNameRightLabel];
        [self.contentView addSubview:_roomIDLeftLabel];
        [self.contentView addSubview:_roomIDRightLabel];
        [self.contentView addSubview:_roomCreatorLeftLabel];
        [self.contentView addSubview:_roomCreatorRightLabel];
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    _roomNameLeftLabel.frame = CGRectMake(20, 20, 200, 20);
    _roomNameRightLabel.frame = CGRectMake(120, 20, 200, 20);
    
    _roomIDLeftLabel.frame = CGRectMake(20, 50, 200, 20);
    _roomIDRightLabel.frame = CGRectMake(120, 50, 200, 20);
    
    _roomCreatorLeftLabel.frame = CGRectMake(20, 80, 200, 20);
    _roomCreatorRightLabel.frame = CGRectMake(120, 80, 200, 20);
    
    _roomNameRightLabel.text = _roomInfo.roomName;
    _roomIDRightLabel.text = [NSString stringWithFormat:@"%u", _roomInfo.roomId];
    _roomCreatorRightLabel.text = [NSString stringWithFormat:@"%llu", _roomInfo.roomCreator];
}

- (void)setFrame:(CGRect)frame {
    frame.size.height -= 10;
    [super setFrame:frame];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
    
    // Configure the view for the selected state
}

@end
