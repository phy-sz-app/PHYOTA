//
//  PHYBLEScanManager.h
//  OTASDK
//
//  Created by di lu on 2026/4/1.
//  Copyright © 2026 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "PHYBLEModel.h"

NS_ASSUME_NONNULL_BEGIN

@protocol PHYBLEScanManagerDelegate;

@interface PHYBLEScanManager : NSObject
@property (nonatomic, weak) id<PHYBLEScanManagerDelegate> delegate;
@property (nonatomic, strong, readonly) NSMutableArray *mySearchArray;
- (void)startScanWithCentral:(CBCentralManager *)central OTAMode:(BOOL)isRescan;
- (void)stopScan;
- (void)handleDiscoveredPeripheral:(CBPeripheral *)peripheral
                          advData:(NSDictionary *)advData
                             RSSI:(NSNumber *)RSSI;
@end

@protocol PHYBLEScanManagerDelegate <NSObject>
- (void)scanManagerDidUpdateDeviceList:(NSArray *)deviceList;
- (void)scanManagerDidFindRescanDevice:(PHYBLEModel *)model;
@end

NS_ASSUME_NONNULL_END
