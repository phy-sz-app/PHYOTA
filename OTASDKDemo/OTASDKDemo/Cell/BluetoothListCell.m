//
//  BluetoothListCellTableViewCell.m
//  PHY
//
//  Created by Han on 2018/9/28.
//  Copyright © 2018年 phy. All rights reserved.
//

#import "BluetoothListCell.h"

@implementation BluetoothListCell
- (void)awakeFromNib {
    [super awakeFromNib];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];
}

- (void)setMSelected:(BOOL)mSelected {
    _mSelected = mSelected;
    if (_mSelected) {
        self.accessoryType = UITableViewCellAccessoryCheckmark;
    }else {
        self.accessoryType = UITableViewCellAccessoryNone;
    }
}

- (void)setBlutoothInfo:(PHYBLEModel *)blutoothInfo isScan:(BOOL)isScan {
    _blutoothInfo = blutoothInfo;
    NSNumber *RSSI = blutoothInfo.RSSI;
    NSString *customNmae = [[NSUserDefaults standardUserDefaults] objectForKey:blutoothInfo.peripheral.identifier.UUIDString];
    BOOL isHaveName = customNmae.length > 0;
    
    if (isScan) {
        self.bluetoothName.text = isHaveName ? customNmae: blutoothInfo.realName;
        self.bluetoothMacName.text = blutoothInfo.adverMacAddr.length>0 ?  blutoothInfo.adverMacAddr : blutoothInfo.peripheral.identifier.UUIDString;
    }else {
        NSString *macStr = blutoothInfo.adverMacAddr.length>0 ?  blutoothInfo.adverMacAddr : @"";
        NSString *nameStr = isHaveName ? customNmae: blutoothInfo.realName;
        self.bluetoothName.text = [NSString stringWithFormat:@"%@ %@",nameStr,macStr];
        self.bluetoothMacName.text = [NSString stringWithFormat:@"%@", blutoothInfo.OTAMessage==nil ? @"空闲" : blutoothInfo.OTAMessage];
    }
    
    /*计算蓝牙距离*/
    int iRssi = abs([RSSI intValue]);
    self.signaiStrengthLabel.text = [NSString stringWithFormat:@"%@dBm",RSSI];
    //    float power = (iRssi-59)/(10*2.0);
    //    float distance = pow(10, power);
    //    self.distance.text = [NSString stringWithFormat:@"%.3f米",distance];
    if (iRssi < 40) {
        self.signalImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"信号3"]];//信号4
    }
    else if(iRssi > 100){
        self.signalImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"信号0"]];
    }
    else if(iRssi <= 100 || iRssi >= 40){
        self.signalImageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"信号%01d",4-((iRssi - 20)/20)]];//5-((iRssi - 25)/15)
    }
}
@end
