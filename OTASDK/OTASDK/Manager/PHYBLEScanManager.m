//
//  PHYBLEScanManager.m
//  OTASDK
//
//  Created by di lu on 2026/4/1.
//  Copyright © 2026 phy. All rights reserved.
//

#import "PHYBLEScanManager.h"
#import "JCDataConvert.h"

NS_ASSUME_NONNULL_BEGIN

@interface PHYBLEScanManager ()
@property (nonatomic, assign) BOOL isRescan;
@property (nonatomic, strong) CBCentralManager *central;
@property (nonatomic, strong) NSDate *lastUpdateDate;
@end

@implementation PHYBLEScanManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _mySearchArray = [NSMutableArray array];
        _lastUpdateDate = [NSDate date];
    }
    return self;
}

- (void)startScanWithCentral:(CBCentralManager *)central  OTAMode:(BOOL)isRescan{
    if (central.isScanning) {
        NSLog(@"已经在扫描中了");
        return;
    }
    self.isRescan = isRescan;
    _central = central;
    [central scanForPeripheralsWithServices:nil options:@{
        CBCentralManagerScanOptionAllowDuplicatesKey: @YES
    }];
}

- (void)stopScan {
    [self.central stopScan];
}

- (void)handleDiscoveredPeripheral:(CBPeripheral *)peripheral
                         advData:(NSDictionary *)advertisementData
                                  RSSI:(NSNumber *)RSSI {
    if (!peripheral.name || peripheral.name.length == 0) return;

    NSDate *now = [NSDate date];
    PHYBLEModel *model = [PHYBLEModel new];
    model.peripheral = peripheral;
    model.RSSI = RSSI;
    model.lastUpdateDate = now;

    NSString *localName = advertisementData[CBAdvertisementDataLocalNameKey];
    model.realName = localName ?: peripheral.name;

    NSData *manuData = advertisementData[CBAdvertisementDataManufacturerDataKey];
    model.adverMacAddr = [JCDataConvert getPeripheralMac:manuData];
    
    if (self.isRescan) {
        NSLog(@"二次扫描：%@",model.adverMacAddr);
        [self.delegate scanManagerDidFindRescanDevice:model];
        return;
    }
    
    __block BOOL found = NO;
    @synchronized (self) {
        for (NSInteger i=0; i<self.mySearchArray.count; i++) {
            PHYBLEModel *m = self.mySearchArray[i];
            if ([m.peripheral.identifier isEqual:peripheral.identifier]) {
                self.mySearchArray[i] = model;
                found = YES;
                break;
            }
        }
        if (!found) [self.mySearchArray addObject:model];
    }

    if (_lastUpdateDate && [now timeIntervalSinceDate:_lastUpdateDate] < 1.0) return;
    _lastUpdateDate = now;

    @synchronized (self) {
        for (NSInteger i = self.mySearchArray.count-1; i>=0; i--) {
            PHYBLEModel *m = self.mySearchArray[i];
            if ([m.lastUpdateDate timeIntervalSinceDate:now] <= -5) {
                [self.mySearchArray removeObjectAtIndex:i];
            }
        }

        [self.mySearchArray sortUsingComparator:^NSComparisonResult(PHYBLEModel *p1, PHYBLEModel *p2) {
            return [p2.RSSI compare:p1.RSSI];
        }];
    }

    [self.delegate scanManagerDidUpdateDeviceList:self.mySearchArray.copy];
}

@end

NS_ASSUME_NONNULL_END
