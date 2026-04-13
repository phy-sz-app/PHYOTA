//
//  PHYBLEDataSender.m
//  OTASDK
//
//  Created by di lu on 2026/4/1.
//  Copyright © 2026 phy. All rights reserved.
//

#import "PHYBLEDataSender.h"
#import "JCDataConvert.h"

NS_ASSUME_NONNULL_BEGIN

@interface PHYBLEDataSender ()
@property (nonatomic, strong) NSMutableDictionary *cmdQueueMap;
@end

@implementation PHYBLEDataSender

- (instancetype)init {
    self = [super init];
    if (self) {
        _cmdQueueMap = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)sendHex:(NSString *)hex peripheral:(CBPeripheral *)peripheral charUUID:(NSString *)charUUID {
    NSData *data = [JCDataConvert stringToHexData:hex];
    [self sendData:data peripheral:peripheral charUUID:charUUID noResponse:NO];
}

- (void)sendData:(NSData *)data peripheral:(CBPeripheral *)peripheral charUUID:(NSString *)charUUID noResponse:(BOOL)noResponse {
    NSLog(@"发送指令：%@",data);
    NSString *uuid = peripheral.identifier.UUIDString;
    if (!noResponse) {
        @synchronized (self) {
            NSMutableArray *q = self.cmdQueueMap[uuid];
            if (!q) q = [NSMutableArray array];
            if (q.count >= MAX_CMD_QUEUE_SIZE) [q removeAllObjects];
            [q addObject:data];
            self.cmdQueueMap[uuid] = q;
            if (q.count > 1) {
                NSLog(@"要等一等");
                return; //有指令发送后还没确认成功，先等待
            }
        }
    }
    
    for (CBService *service in peripheral.services) {
        for (CBCharacteristic *c in service.characteristics) {
            if ([c.UUID.UUIDString isEqualToString:charUUID]) {
                [peripheral writeValue:data forCharacteristic:c type:noResponse ? CBCharacteristicWriteWithoutResponse : CBCharacteristicWriteWithResponse];
                return;
            }
        }
    }
}

- (void)didWriteValueForCharacteristic:(CBPeripheral *)peripheral characteristic:(CBCharacteristic *)characteristic {
    NSString *uuid = peripheral.identifier.UUIDString;
    @synchronized (self) {
        NSMutableArray *q = self.cmdQueueMap[uuid];
        if (q && q.count>0) {
            NSLog(@"指令发送成功：%@",q[0]);
            [q removeObjectAtIndex:0];//将发送成功的指令从队列中移除
            
            if (q.count>0) {    //如果还有指令在队列中等待发送
                NSLog(@"直接发送队列中指令：%@",q[0]);
                [peripheral writeValue:q[0] forCharacteristic:characteristic type:CBCharacteristicWriteWithResponse];
                
                NSString *sendStr = [JCDataConvert convertDataToHexStr:q[0]];
                if ([sendStr isEqualToString:@"0102"] || [sendStr isEqualToString:@"0103"]) {
                    [self.delegate dataSend:peripheral updateState:SBKAppModeOver message:NSLocalizedStringFromTable(@"SendOTAModeSwitch", @"PHYOTA", @"让设备重启进入升级模式！")];
                }
            }
        }
    }
}

- (void)clearQueueForUUID:(NSString *)uuid {
    @synchronized (self) {
        [self.cmdQueueMap removeObjectForKey:uuid];
    }
}

- (void)clearAllQueues {
    @synchronized (self) {
        [self.cmdQueueMap removeAllObjects];
    }
}


@end

NS_ASSUME_NONNULL_END
