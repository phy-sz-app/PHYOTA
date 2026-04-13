//
//  PHYBLEDataSender.h
//  OTASDK
//
//  Created by di lu on 2026/4/1.
//  Copyright © 2026 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "PHYOTAType.h"

NS_ASSUME_NONNULL_BEGIN

@protocol PHYBLEDataSenderDelegate;

@interface PHYBLEDataSender : NSObject

@property (nonatomic, weak) id<PHYBLEDataSenderDelegate> delegate;

- (void)sendHex:(NSString *)hex
     peripheral:(CBPeripheral *)peripheral
          charUUID:(NSString *)charUUID;

- (void)sendData:(NSData *)data
     peripheral:(CBPeripheral *)peripheral
          charUUID:(NSString *)charUUID
        noResponse:(BOOL)noResponse;

- (void)didWriteValueForCharacteristic:(CBPeripheral *)peripheral characteristic:(CBCharacteristic *)characteristic;
- (void)clearQueueForUUID:(NSString *)uuid;
- (void)clearAllQueues;

@end

@protocol PHYBLEDataSenderDelegate <NSObject>
- (void)dataSend:(CBPeripheral *)peripheral updateState:(NSInteger)state message:(NSString *)msg;
@end
NS_ASSUME_NONNULL_END
