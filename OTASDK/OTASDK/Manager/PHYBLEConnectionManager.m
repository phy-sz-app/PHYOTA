//
//  PHYBLEConnectionManager.m
//  OTASDK
//
//  Created by di lu on 2026/4/1.
//  Copyright © 2026 phy. All rights reserved.
//

#import "PHYBLEConnectionManager.h"



@implementation PHYBLEConnectionManager

- (instancetype)init {
    self = [super init];
    if (self) {
        _connectedPeripherals = [NSMutableArray array];
    }
    return self;
}

- (void)connectModel:(PHYBLEModel *)model central:(CBCentralManager *)central {
    if (!model || !model.peripheral) return;
    CBPeripheral *p = model.peripheral;

    // 取消之前的超时任务
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                 selector:@selector(onConnectTimeout:)
                                                   object:p];
    
    @synchronized (self) {
        if (![self.connectedPeripherals containsObject:p]) {
            [self.connectedPeripherals addObject:p];
        }
    }
    NSLog(@"CBCentralManager 连接设备 ====== :%@，%@",model.realName, model.peripheral.identifier.UUIDString );
    [central connectPeripheral:p options:nil];

    [self performSelector:@selector(onConnectTimeout:) withObject:p afterDelay:10.0];
}

- (void)onConnectTimeout:(CBPeripheral *)peripheral {
    [self.delegate connectionManagerDidFailToConnect:peripheral error:nil];
}

- (void)cancelConnection:(CBPeripheral *)peripheral central:(CBCentralManager *)central {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onConnectTimeout:) object:peripheral];
    [central cancelPeripheralConnection:peripheral];
}

- (void)disconnectAllWithCentral:(CBCentralManager *)central {
    @synchronized (self) {
        NSArray *arr = self.connectedPeripherals.copy;
        for (CBPeripheral *p in arr) {
            [central cancelPeripheralConnection:p];
        }
        [self.connectedPeripherals removeAllObjects];
    }
}

- (void)connectionManagerDidConnect:(CBPeripheral *)peripheral {
    NSLog(@" 连接设备成功 ====== :%@，%@",peripheral.name, peripheral.identifier.UUIDString );
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(onConnectTimeout:) object:peripheral];
}

- (void)connectionManagerDidDisconnect:(CBPeripheral *)peripheral error:(NSError *)error {
    @synchronized (self) {
        if ([self.connectedPeripherals containsObject:peripheral]) {
            [self.connectedPeripherals removeObject:peripheral];
        }
    }
}

@end


