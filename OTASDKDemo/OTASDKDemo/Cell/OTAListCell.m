//
//  OTAListCell.m
//  PHY
//
//  Created by Han on 2018/10/9.
//  Copyright © 2018年 phy. All rights reserved.
//

#import "OTAListCell.h"

@implementation OTAListCell

- (void)awakeFromNib {
    [super awakeFromNib];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier{
    if(self = [super initWithStyle:style
                   reuseIdentifier:reuseIdentifier]){
       
        UIView *bgView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, SCREEN_WIDTH, 60)];
        [self addSubview:bgView];
        _contentLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, 0, SCREEN_WIDTH-20, 60)];
        _contentLabel.font = [UIFont systemFontOfSize:16.0];
        _contentLabel.textColor = [UIColor blackColor];
        _contentLabel.numberOfLines = 0;
        _contentLabel.backgroundColor = [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1];
        [bgView addSubview:_contentLabel];
        
        UILabel *line = [[UILabel alloc] initWithFrame:CGRectMake(0, bgView.bounds.size.height-0.5, SCREEN_WIDTH, 0.5)];
        line.backgroundColor = [UIColor lightGrayColor];
        [bgView addSubview:line];
        
    }
    return self;
}
@end
