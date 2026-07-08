//
//  PHYBLEManager.h
//  OTASDK
//
//  Created by 陈双超 on 2022/6/9.
//  Copyright © 2022 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import <OTASDK/PHYOTASDKLogger.h>

NS_ASSUME_NONNULL_BEGIN

@protocol PHYBLEManagerDelegate <NSObject>
@required
- (void)centerMessage:(NSString *)message code:(NSUInteger)code;
- (void)deviceFound:(NSArray *)devicesArray;
- (void)listenNotify:(CBPeripheral *)peripheral message:(NSString *)message code:(NSUInteger)code;
@end

@interface PHYBLEManager : NSObject
@property (nonatomic, weak, nullable) id<PHYBLEManagerDelegate> delegate;
@property (nonatomic, strong) NSMutableArray *deviceArray;
@property (nonatomic, strong) CBCentralManager *myCentralManager;

+ (instancetype)shareInstance;

- (void)selectFilePath:(NSString *)filePath;
- (void)stopOTA;

// 模式一： 扫描后选择设备进行OTA
- (void)startScan;
- (void)stopScan;
- (BOOL)addDevices:(NSArray *)otaDevices;

// 模式二: 为已连接的设备，不断连OTA升级，仅支持一个设备
- (void)connectedDeviceOTA:(CBPeripheral *)peripheral;

@end

NS_ASSUME_NONNULL_END
