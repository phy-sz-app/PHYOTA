//
//  PHYBLEManager.m
//  OTASDK
//
//  Created by 陈双超 on 2022/6/9.
//  Copyright © 2022 phy. All rights reserved.
//

#import "PHYBLEManager.h"
#import "PHYBLEScanManager.h"
#import "PHYBLEConnectionManager.h"
#import "PHYBLEDataSender.h"
#import "PHYOTASLBProtocol.h"
#import "PHYOTASBKProtocol.h"
#import "PHYFileHandle.h"
#import "PHYBLEModel.h"
#import "JCDataConvert.h"
#import "PHYOTAType.h"

@interface PHYBLEManager ()
<CBCentralManagerDelegate,
CBPeripheralDelegate,
PHYBLEScanManagerDelegate,
PHYBLEConnectionManagerDelegate,
PHYBLEDataSenderDelegate,
PHYOTASLBProtocolDelegate,
PHYOTASBKProtocolDelegate>

@property (nonatomic, strong) dispatch_queue_t bleQueue;

@property (nonatomic, strong) PHYBLEScanManager *scanManager;
@property (nonatomic, strong) PHYBLEConnectionManager *connManager;
@property (nonatomic, strong) PHYBLEDataSender *dataSender;
@property (nonatomic, strong) PHYOTASLBProtocol *slbProtocol;
@property (nonatomic, strong) PHYOTASBKProtocol *sbkProtocol;

@property (nonatomic, strong) PHYFileHandle *fileDetail;

@end

@implementation PHYBLEManager

+ (instancetype)shareInstance {
    static PHYBLEManager *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[super alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _bleQueue = dispatch_queue_create("com.phy.bleQueue", DISPATCH_QUEUE_SERIAL);

        _scanManager = [PHYBLEScanManager new];
        _connManager = [PHYBLEConnectionManager new];
        _dataSender = [PHYBLEDataSender new];
        _slbProtocol = [PHYOTASLBProtocol new];
        _sbkProtocol = [PHYOTASBKProtocol new];

        _scanManager.delegate = self;
        _connManager.delegate = self;
        _dataSender.delegate = self;
        _slbProtocol.delegate = self;
        _sbkProtocol.delegate = self;

        _slbProtocol.dataSender = _dataSender;
        _sbkProtocol.dataSender = _dataSender;

        _deviceArray = [NSMutableArray array];

        dispatch_sync(_bleQueue, ^{
            self.myCentralManager = [[CBCentralManager alloc] initWithDelegate:self queue:self.bleQueue];
        });
    }
    return self;
}

- (void)selectFilePath:(NSString *)filePath {
    self.fileDetail = [[PHYFileHandle alloc] initWithPath:filePath];
    
    if (!self.fileDetail || self.fileDetail.fileResult.count == 0) {
        [self centerMessage:@"Error:File data is empty!" code:OTAFailed];
        return;
    }
    
    if (self.fileDetail.booterVerson.length > 0) {
        [self centerMessage:[NSString stringWithFormat:@"%@%@", self.fileDetail.productID, self.fileDetail.booterVerson] code:FileVersion];
    }
    
    if (self.fileDetail.mFileType == SLBFile ) {
        self.slbProtocol.fileDetail = self.fileDetail;
    }else if (self.fileDetail.mFileType == SBKFile) {
        self.sbkProtocol.fileDetail = self.fileDetail;
    }
}

- (void)startScan {
    [self stopOTA];
    [self.scanManager startScanWithCentral:self.myCentralManager OTAMode:NO];
}

- (void)stopScan {
    [self.scanManager stopScan];
}

- (void)startSBKOTAReScan {
    NSLog(@"开始二次扫描");
    [self.scanManager startScanWithCentral:self.myCentralManager OTAMode:YES];
}

- (BOOL)addDevices:(NSArray *)otaDevices {
    [self stopOTA];
    __block BOOL added = NO;
    dispatch_sync(self.bleQueue, ^{
        @synchronized (self) {
            for (NSString *uuid in otaDevices) {
                for (PHYBLEModel *m in self.scanManager.mySearchArray) {
                    if ([m.peripheral.identifier.UUIDString isEqualToString:uuid]) {
                        [self.deviceArray addObject:m];
                        added = YES;
                        break;
                    }
                }
            }
        }
    });

    if (added) {
        [self tryStartOTA];
        return YES;
    } else {
        [self centerMessage:@"Device data type Error！" code:DeviceError];
        return NO;
    }
}

- (void)stopOTA {
    dispatch_async(self.bleQueue, ^{
        @synchronized (self) {
            for (PHYBLEModel *model in self.deviceArray) {
                if (model.myTimer) {
                    dispatch_source_cancel(model.myTimer);
                    model.myTimer = nil;
                }
                if (model.disconnectTimer) {
                    dispatch_source_cancel(model.disconnectTimer);
                    model.disconnectTimer = nil;
                }
            }
            [self.deviceArray removeAllObjects];
        }
        
        [self.connManager disconnectAllWithCentral:self.myCentralManager];
        [self.dataSender clearAllQueues];
    });
}

- (void)tryStartOTA {
    if (!self.fileDetail || !self.fileDetail.isDataOK) {
        [self centerMessage:@"Error:File data is empty!" code:OTAFailed];
        return;
    }

    dispatch_async(self.bleQueue, ^{
        @synchronized (self) {
            for (PHYBLEModel *model in self.deviceArray) {
                if (self.connManager.connectedPeripherals.count >= MAXConnection) {
                    return;
                }
                if (model.OTAType == None) {
                    [self.connManager connectModel:model central:self.myCentralManager];
                    [self updateDevice:model.peripheral type:DeviceConnecting message:@"开始连接设备"];
                }
            }
        }
    });
}

- (PHYBLEModel *)findModelByPeripheral:(CBPeripheral *)p {
    @synchronized (self) {
        for (PHYBLEModel *m in self.deviceArray) {
            if ([m.peripheral.identifier isEqual:p.identifier]) {
                return m;
            }
        }
    }
    return nil;
}

- (void)updateDevice:(CBPeripheral *)p type:(OTAType)t message:(NSString *)m {
    dispatch_async(self.bleQueue, ^{
        PHYBLEModel *model = [self findModelByPeripheral:p];
        if (model) {
            model.OTAType = t;
            model.OTAMessage = m;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate listenNotify:p message:m code:t];
        });
    });
}

- (void)centerMessage:(NSString *)message code:(NSUInteger)code {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate centerMessage:message code:code];
    });
}

// 模式二: 为已连接的设备，不断连OTA升级，仅支持一个设备
- (void)connectedDeviceOTA:(CBPeripheral *)peripheral {

    if (self.fileDetail.mFileType == NoneFile) {
        [self centerMessage:@"请选择升级文件"  code:FileError];
        return;
    }
    if (peripheral.state == CBPeripheralStateConnected) {
        PHYBLEModel *model = [[PHYBLEModel alloc] init];
        model.peripheral = peripheral;
        [self.deviceArray addObject:model];
        
        [self updateDevice:peripheral type:ServicesDiscovering message:NSLocalizedStringFromTable(@"BluetoothConnectionSuccessful", @"PHYOTA", @"蓝牙连接成功,确定升级方式")];
        peripheral.delegate = self;
        [peripheral discoverServices:nil];
    }
}

- (void)setMyCentralManager:(CBCentralManager *)myCentralManager {
    _myCentralManager = myCentralManager;
    _myCentralManager.delegate = self;
}

#pragma mark - Scan Delegate
- (void)scanManagerDidUpdateDeviceList:(NSArray *)deviceList {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.delegate deviceFound:deviceList];
    });
}

- (void)scanManagerDidFindRescanDevice:(PHYBLEModel *)model {
    dispatch_async(self.bleQueue, ^{
        __block BOOL needRescan = NO;
        @synchronized (self) {
            for (PHYBLEModel *m in self.deviceArray) {
                if ([JCDataConvert compareAppMAc:m.adverMacAddr OTAMAC:model.adverMacAddr rescanByte:m.mSBKContext.checkByte]) {
                    m.mSBKContext.isFamewareCheck = YES;
                    m.peripheral = model.peripheral;
                    m.OTAType = None;
                    m.adverMacAddr = model.adverMacAddr;
                    m.realName = model.realName ?: m.realName;
                }
                if (m.OTAType == SBKAppModeOver) {
                    needRescan = YES;
                }
            }
        }
        
        if (!needRescan) {
            [self stopScan];
            [self tryStartOTA];
        }
    });
}

#pragma mark - Connection Delegate
- (void)connectionManagerDidFailToConnect:(CBPeripheral *)peripheral error:(NSError *)error {
    dispatch_async(self.bleQueue, ^{
        if (peripheral.state == CBPeripheralStateConnecting) {
            [self updateDevice:peripheral type:DeviceConnectFail message:@"连接超时"];
            [self.connManager cancelConnection:peripheral central:self.myCentralManager];
        }
    });
}

#pragma mark - CBCentralManagerDelegate
- (void)centralManagerDidUpdateState:(CBCentralManager *)central {
    if (central.state == CBManagerStatePoweredOn) {
        [self centerMessage:@"蓝牙已开启" code:BLEActive];
    } else {
        [self stopOTA];
        [self centerMessage:@"蓝牙不可用" code:BLENOTActive];
    }
}

- (void)centralManager:(CBCentralManager *)central didDiscoverPeripheral:(CBPeripheral *)peripheral advertisementData:(NSDictionary *)advertisementData RSSI:(NSNumber *)RSSI {
    [self.scanManager handleDiscoveredPeripheral:peripheral advData:advertisementData RSSI:RSSI];
}

- (void)centralManager:(CBCentralManager *)central didConnectPeripheral:(CBPeripheral *)peripheral {
    [self.connManager connectionManagerDidConnect:peripheral];
    [self updateDevice:peripheral type:ServicesDiscovering message:@"连接成功，发现服务中"];
    
    dispatch_async(self.bleQueue, ^{
        peripheral.delegate = self;
        [peripheral discoverServices:nil];
    });
}

- (void)centralManager:(CBCentralManager *)central didDisconnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self.connManager connectionManagerDidDisconnect:peripheral error:error];
    PHYBLEModel *model = [self findModelByPeripheral:peripheral];
    [self.dataSender clearQueueForUUID:peripheral.identifier.UUIDString];

    // 取消模式切换断连计时器（设备已断开，无需强制断连）
    if (model.disconnectTimer) {
        dispatch_source_cancel(model.disconnectTimer);
        model.disconnectTimer = nil;
    }

    dispatch_async(self.bleQueue, ^{
        @synchronized (self) {
            if (model.OTAType == OTAComplete) {
                [self.deviceArray removeObject:model];
                [self updateDevice:peripheral type:OTASuccessReboot message:NSLocalizedStringFromTable(@"OTASuccessfully", @"PHYOTA", @"升级成功后断开连接")];
            } else if (model.OTAType < SBKAppModeOver) {
                model.disconnectTimes++;
                if (model.disconnectTimes >= ReconectTime) {
                    [self updateDevice:peripheral type:MAXDisconnectedTime message:@"重连次数超限"];
                } else {
                    NSString *msg = [NSString stringWithFormat:@"%d time %@",model.disconnectTimes+1,NSLocalizedStringFromTable(@"StartConnect", @"PHYOTA", @"开始连接设备")];
                    [self updateDevice:peripheral type:DeviceConnecting message:msg];
                    [self.connManager connectModel:model central:self.myCentralManager];
                    return;
                }
            } else if (model.OTAType == SBKAppModeOver) {
                [self updateDevice:peripheral type:SBKAppModeOver message:NSLocalizedStringFromTable(@"RebootToOTAModel", @"PHYOTA", @"重启设备成功，进入升级模式！")];
            }
        }
        
        [self connectNextDevice];
    });
}

- (void)connectNextDevice {
    dispatch_async(self.bleQueue, ^{
        __block BOOL needRescan = false;
        __block BOOL isOTAEnd = YES;
        __block NSArray *devices;
        
        @synchronized (self) {
            devices = [self.deviceArray copy];
        }
        
        for (int i=0; i<devices.count; i++) {
            PHYBLEModel *tempModel = devices[i];
            if (tempModel.OTAType == None){
                [self.connManager connectModel:tempModel central:self.myCentralManager];
                [self updateDevice:tempModel.peripheral type:DeviceConnecting message:NSLocalizedStringFromTable(@"StartConnect", @"PHYOTA", @"开始连接设备")];
                return;
            }else if(tempModel.OTAType == SBKAppModeOver){
                needRescan = YES;
            }else if (tempModel.OTAType < SBKAppModeOver) {
                isOTAEnd = NO;
            }
        }

        if (self.connManager.connectedPeripherals.count == 0 && needRescan) {
            [self centerMessage:NSLocalizedStringFromTable(@"Rescan", @"PHYOTA", @"SBK开始第二次扫描") code:RESCANStart];
            [self startSBKOTAReScan];
        } else if(self.connManager.connectedPeripherals.count == 0 && isOTAEnd) {
            NSString *otaendStr = NSLocalizedStringFromTable(@"OTA End", @"PHYOTA", @"升级结束");
            NSUInteger failCount = 0;
            
            @synchronized (self) {
                failCount = self.deviceArray.count;
            }
            
            if (failCount > 0 ) {
                NSString *errorCount = NSLocalizedStringFromTable(@"Number of failures", @"PHYOTA", @"失败数量");
                otaendStr = [NSString stringWithFormat:@"%@, %@: %lu, Reasons：", otaendStr, errorCount, (unsigned long)failCount];
                for (int m=0; m<devices.count; m++) {
                    PHYBLEModel *tempModel = devices[m];
                    otaendStr = [NSString stringWithFormat:@"%@ %@", otaendStr, tempModel.OTAMessage];
                }
            }else {
                otaendStr = NSLocalizedStringFromTable(@"OTA End All success", @"PHYOTA", @"升级结束,全部设备升级成功");
            }
            
            [self centerMessage:otaendStr code:OTAEnd];
            
            dispatch_async(self.bleQueue, ^{
                @synchronized (self) {
                    [self.deviceArray removeAllObjects];
                }
            });
        }
    });
}

- (void)centralManager:(CBCentralManager *)central didFailToConnectPeripheral:(CBPeripheral *)peripheral error:(NSError *)error {
    [self.connManager cancelConnection:peripheral central:self.myCentralManager];
}

#pragma mark - CBPeripheralDelegate
- (void)peripheral:(CBPeripheral *)peripheral didDiscoverServices:(NSError *)error {
    PHYBLEModel *model = [self findModelByPeripheral:peripheral];
    __block int flag = 0;
    __block CBService *slbService = nil, *sbkService = nil;

    for (CBService *s in peripheral.services) {
        NSLog(@"服务：%@",s.UUID.UUIDString);
        if ([s.UUID.UUIDString.uppercaseString isEqualToString:SLB_SERVICE_UUID]) {
            flag |= 1; slbService = s;
        }else if ([s.UUID.UUIDString.uppercaseString isEqualToString:SBK_OTA_SERVICE_UUID]) {
            flag |= 2; sbkService = s;
        }else if ([s.UUID.UUIDString.uppercaseString isEqualToString:SLB_SERVICE_UUID_SHORT]) {
            flag |= 4; slbService = s;
        }
    }

    dispatch_async(self.bleQueue, ^{
        if (flag == 0) {
            [self updateDevice:peripheral type:OTAFailed message:@"未找到OTA服务"];
            [self.connManager cancelConnection:peripheral central:self.myCentralManager];
        } else if (flag == 1) {
            if (!model.mSLBContext) {
                model.mSLBContext = [SLBContext new];
            }
            [peripheral discoverCharacteristics:@[
                [CBUUID UUIDWithString:SLB_WRITECharacteristic_ID],
                [CBUUID UUIDWithString:SLB_WRITEWithNoRsp_ID],
                [CBUUID UUIDWithString:SLB_NOTIFYCharacteristic_ID]
            ] forService:slbService];
            [self updateDevice:peripheral type:SLBServiceFound message:NSLocalizedStringFromTable(@"SLBServiceFound", @"PHYOTA", @"SLB服务获取成功,发现特性中！")];
        } else if (flag == 2) {
            model.mSBKContext = [SBKContext new];
            [peripheral discoverCharacteristics:@[
                [CBUUID UUIDWithString:SBK_OTA_WRITE_Characteristic],
                [CBUUID UUIDWithString:SBK_OTA_NOTIFY_Characteristic],
                [CBUUID UUIDWithString:SBK_OTA_WRITE_WithNoResponse]
            ] forService:sbkService];
            [self updateDevice:peripheral type:SBKServiceFound message:NSLocalizedStringFromTable(@"SBKServiceFound", @"PHYOTA", @"SBK服务获取成功,发现特性中！")];
        } else if (flag == 4) {
            if (!model.mSLBContext) {
                model.mSLBContext = [SLBContext new];
            }
            model.mSLBContext.isShortUUID = YES;
            [peripheral discoverCharacteristics:@[
                [CBUUID UUIDWithString:SLB_WRITEChara_SHORT],
                [CBUUID UUIDWithString:SLB_WRITEWithNoRspChara_SHORT],
                [CBUUID UUIDWithString:SLB_NOTIFYChara_SHORT]
            ] forService:slbService];
            [self updateDevice:peripheral type:SLBServiceFound message:NSLocalizedStringFromTable(@"SLBServiceFound", @"PHYOTA", @"SLB短服务获取成功,发现特性中！")];
        }
    });
}

- (void)peripheral:(CBPeripheral *)peripheral didDiscoverCharacteristicsForService:(CBService *)service error:(NSError *)error {
    PHYBLEModel *model = [self findModelByPeripheral:peripheral];
    __block int slb = 0, sbk = 0;

    for (CBCharacteristic *c in service.characteristics) {
        NSString *u = c.UUID.UUIDString.uppercaseString;
        NSLog(@"特性:%@",u);
        if ([u isEqualToString:SLB_WRITEWithNoRsp_ID] || [u isEqualToString:SLB_WRITEWithNoRspChara_SHORT]) {
            slb |= 1;
            model.MTUSize = [peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse] - 4;
        }
        if ([u isEqualToString:SLB_NOTIFYCharacteristic_ID] || [u isEqualToString:SLB_NOTIFYChara_SHORT]) slb |= 2;
        if ([u isEqualToString:SLB_WRITECharacteristic_ID] || [u isEqualToString:SLB_WRITEChara_SHORT]) slb |= 4;

        if ([u isEqualToString:SBK_OTA_NOTIFY_Characteristic]) sbk |= 1;
        if ([u isEqualToString:SBK_OTA_WRITE_Characteristic]) sbk |= 2;
        if ([u isEqualToString:SBK_OTA_WRITE_WithNoResponse]) {
            sbk |= 4;
            model.MTUSize = [peripheral maximumWriteValueLengthForType:CBCharacteristicWriteWithoutResponse];
        }
    }

    dispatch_async(self.bleQueue, ^{
        if (slb == 7 && self.fileDetail.mFileType == SLBFile) {
            [self updateDevice:peripheral type:SLBOTAConfirm message:@"SLB 已就绪"];
            for (CBCharacteristic *c in service.characteristics) {
                if ([c.UUID.UUIDString isEqualToString:SLB_NOTIFYCharacteristic_ID] || [c.UUID.UUIDString isEqualToString:SLB_NOTIFYChara_SHORT]) {
                    [peripheral setNotifyValue:YES forCharacteristic:c];
                }
            }
        } else if ((sbk == 3 || sbk == 7) && self.fileDetail.mFileType == SBKFile) {
            [self updateDevice:peripheral type:(sbk == 3 ? SBKAppConfirm : SBKOTAConfirm) message:@"SBK 已就绪"];
            for (CBCharacteristic *c in service.characteristics) {
                if ([c.UUID.UUIDString isEqualToString:SBK_OTA_NOTIFY_Characteristic]) {
                    [peripheral setNotifyValue:YES forCharacteristic:c];
                }
            }
        } else if (slb == 7 && self.fileDetail.mFileType == SBKFile) {
            [self updateDevice:peripheral type:OTAFailed message:@"SLB设备和SBK升级文件不匹配！"];
        } else if ((sbk == 3 || sbk == 7) && self.fileDetail.mFileType == SLBFile) {
            [self updateDevice:peripheral type:OTAFailed message:@"SBK设备和SLB升级文件不匹配！"];
        } else {
            [self updateDevice:peripheral type:OTAFailed message:@"设备特性异常！"];
        }
    });
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateNotificationStateForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    PHYBLEModel *model = [self findModelByPeripheral:peripheral];
    dispatch_async(self.bleQueue, ^{
        if ([characteristic.UUID.UUIDString isEqualToString:SLB_NOTIFYCharacteristic_ID]
            || [characteristic.UUID.UUIDString isEqualToString:SLB_NOTIFYChara_SHORT]) {
            [self updateDevice:peripheral type:SLBDeviceReady message:NSLocalizedStringFromTable(@"EnableCharacteristicSuccessful", @"PHYOTA", @"SLB双向通信建立成功")];
            [self.slbProtocol startOTAWithModel:model];
        } else if ([characteristic.UUID.UUIDString isEqualToString:SBK_OTA_NOTIFY_Characteristic]){
            if (model.OTAType == SBKAppConfirm) {
                [self updateDevice:peripheral type:SBKAppDeviceReady message:NSLocalizedStringFromTable(@"EnableCharacteristicSuccessful", @"PHYOTA", @"SBK App设备准备好！设备双向通信建立成功")];
                [self.sbkProtocol startAppOTAWithModel:model];
            }else if (model.OTAType == SBKOTAConfirm){
                [self updateDevice:peripheral type:SBKOTADeviceReady message:NSLocalizedStringFromTable(@"EnableCharacteristicSuccessful", @"PHYOTA", @"SBK OTA设备准备好！设备双向通信建立成功")];
                [self.sbkProtocol startOTAWithModel:model];
            }
        }
    });
}

- (void)peripheral:(CBPeripheral *)peripheral didUpdateValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    NSData *data = characteristic.value;
    PHYBLEModel *model = [self findModelByPeripheral:peripheral];
    
    dispatch_async(self.bleQueue, ^{
        if ([characteristic.UUID.UUIDString isEqualToString:SLB_NOTIFYCharacteristic_ID] || [characteristic.UUID.UUIDString isEqualToString:SLB_NOTIFYChara_SHORT]) {
            NSLog(@"receive SLB %@ data: %@ ", peripheral.name, [JCDataConvert convertDataToHexStr:data]);
            [self.slbProtocol parseNotifyData:data model:model];
        } else if([characteristic.UUID.UUIDString isEqualToString:SBK_OTA_NOTIFY_Characteristic]){
            NSLog(@"receive SBK %@ data: %@ ", peripheral.name, [JCDataConvert convertDataToHexStr:data]);
            [self.sbkProtocol parseNotifyData:data model:model];
        }
    });
}

- (void)peripheral:(CBPeripheral *)peripheral didWriteValueForCharacteristic:(CBCharacteristic *)characteristic error:(NSError *)error {
    [self.dataSender didWriteValueForCharacteristic:peripheral characteristic:characteristic];
}

#pragma mark - OTA Protocol Delegate
- (void)slbOTA:(CBPeripheral *)peripheral updateState:(NSInteger)state message:(NSString *)msg {
    [self updateDevice:peripheral type:state message:msg];
    if (state == OTAFailed) {
        [self.connManager cancelConnection:peripheral central:self.myCentralManager];
    }
}

- (void)slbOTA:(CBPeripheral *)peripheral didComplete:(BOOL)success {
    [self updateDevice:peripheral type:success ? OTAComplete : OTAFailed message:success ? @"升级成功" : @"升级失败"];
    [self.connManager cancelConnection:peripheral central:self.myCentralManager];
}

- (void)sbkOTA:(CBPeripheral *)peripheral updateState:(NSInteger)state message:(NSString *)msg {
    [self updateDevice:peripheral type:state message:msg];
    if (state == OTAFailed) {
        [self.connManager cancelConnection:peripheral central:self.myCentralManager];
    }
}

- (void)sbkOTA:(CBPeripheral *)peripheral didComplete:(BOOL)success {
    [self updateDevice:peripheral type:success ? OTAComplete : OTAFailed message:success ? @"升级成功" : @"升级失败"];
    [self.connManager cancelConnection:peripheral central:self.myCentralManager];
}

- (void)dataSend:(CBPeripheral *)peripheral updateState:(NSInteger)state message:(NSString *)msg {
    [self updateDevice:peripheral type:state message:msg];
    
    if (state == SBKAppModeOver) {
        [self startModeSwitchDisconnectTimer:peripheral];
    }
}

/// 发送0102/0103后启动2秒断连计时器：若设备未自动断开，则强制断开
- (void)startModeSwitchDisconnectTimer:(CBPeripheral *)peripheral {
    PHYBLEModel *model = [self findModelByPeripheral:peripheral];
    if (!model) return;

    if (model.disconnectTimer) {
        dispatch_source_cancel(model.disconnectTimer);
        model.disconnectTimer = nil;
    }

    dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.bleQueue);
    dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0);

    __weak typeof(self) weakSelf = self;
    __weak typeof(CBPeripheral *) weakPeripheral = peripheral;
    dispatch_source_set_event_handler(timer, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        CBPeripheral *p = weakPeripheral;
        if (p.state == CBPeripheralStateConnected) {
            NSLog(@"模式切换超时(2s)，强制断开蓝牙连接");
            [strongSelf.connManager cancelConnection:p central:strongSelf.myCentralManager];
        }

        PHYBLEModel *m = [strongSelf findModelByPeripheral:p];
        if (m.disconnectTimer) {
            dispatch_source_cancel(m.disconnectTimer);
            m.disconnectTimer = nil;
        }
    });

    model.disconnectTimer = timer;
    dispatch_resume(timer);

}

@end
