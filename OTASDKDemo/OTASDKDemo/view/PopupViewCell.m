//
//  PopupViewCell.m
//  OTASDKDemo
//
//  Created by di lu on 2024/8/2.
//  Copyright © 2024 phy. All rights reserved.
//

#import "PopupViewCell.h"

@implementation PopupViewCell

- (void)awakeFromNib {
    [super awakeFromNib];
    // Initialization code
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    if(self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]){
        _mTitleLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, SCREEN_WIDTH-20, 44)];
        _mTitleLabel.font = [UIFont systemFontOfSize:16.0];
        _mTitleLabel.textColor = [UIColor blackColor];
        _mTitleLabel.numberOfLines = 0;
        [self.contentView addSubview:_mTitleLabel];
    }
    return self;
}

@end
