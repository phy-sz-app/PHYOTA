//
//  PHYOTASBKProtocol.h
//  OTASDK
//
//  Created by di lu on 2026/4/1.
//  Copyright © 2026 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "PHYBLEModel.h"
#import "PHYBLEDataSender.h"
#import "PHYFileHandle.h"
#import "PHYOTAType.h"

NS_ASSUME_NONNULL_BEGIN

@protocol PHYOTASBKProtocolDelegate;

@interface PHYOTASBKProtocol : NSObject
@property (nonatomic, weak) PHYBLEDataSender *dataSender;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
@property (nonatomic, strong) PHYFileHandle *fileDetail;
@property (nonatomic, weak) id<PHYOTASBKProtocolDelegate> delegate;

- (void)startAppOTAWithModel:(PHYBLEModel *)model;
- (void)startOTAWithModel:(PHYBLEModel *)model;
- (void)parseNotifyData:(NSData *)data model:(PHYBLEModel *)model;
@end

@protocol PHYOTASBKProtocolDelegate <NSObject>
- (void)sbkOTA:(CBPeripheral *)peripheral updateState:(NSInteger)state message:(NSString *)msg;
- (void)sbkOTA:(CBPeripheral *)peripheral didComplete:(BOOL)success;
@end

NS_ASSUME_NONNULL_END
