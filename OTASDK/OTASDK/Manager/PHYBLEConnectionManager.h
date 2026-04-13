//
//  PHYBLEConnectionManager.h
//  OTASDK
//
//  Created by di lu on 2026/4/1.
//  Copyright © 2026 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "PHYBLEModel.h"
#import "PHYOTAType.h"



@protocol PHYBLEConnectionManagerDelegate;

@interface PHYBLEConnectionManager : NSObject
@property (nonatomic, weak) id<PHYBLEConnectionManagerDelegate> delegate;
@property (nonatomic, strong, readonly) NSMutableArray *connectedPeripherals;
- (void)connectModel:(PHYBLEModel *)model central:(CBCentralManager *)central;
- (void)cancelConnection:(CBPeripheral *)peripheral central:(CBCentralManager *)central;
- (void)disconnectAllWithCentral:(CBCentralManager *)central;

- (void)connectionManagerDidConnect:(CBPeripheral *)peripheral;
- (void)connectionManagerDidDisconnect:(CBPeripheral *)peripheral error:(NSError *)error;

@end

@protocol PHYBLEConnectionManagerDelegate <NSObject>
- (void)connectionManagerDidFailToConnect:(CBPeripheral *)peripheral error:(NSError *)error;
@end


