//
//  PHYOTASLBProtocol.h
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

@protocol PHYOTASLBProtocolDelegate;

@interface PHYOTASLBProtocol : NSObject
@property (nonatomic, weak) PHYBLEDataSender *dataSender;
@property (nonatomic, strong) PHYFileHandle *fileDetail;
@property (nonatomic, weak) id<PHYOTASLBProtocolDelegate> delegate;

- (void)startOTAWithModel:(PHYBLEModel *)model;
- (void)parseNotifyData:(NSData *)data model:(PHYBLEModel *)model;
@end

@protocol PHYOTASLBProtocolDelegate <NSObject>
- (void)slbOTA:(CBPeripheral *)peripheral updateState:(NSInteger)state message:(NSString *)msg;
- (void)slbOTA:(CBPeripheral *)peripheral didComplete:(BOOL)success;
@end
NS_ASSUME_NONNULL_END
