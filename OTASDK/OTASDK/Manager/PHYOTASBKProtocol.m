//
//  PHYOTASBKProtocol.m
//  OTASDK
//
//  Created by di lu on 2026/4/1.
//  Copyright © 2026 phy. All rights reserved.
//

#import "PHYOTASBKProtocol.h"
#import "JCDataConvert.h"
#import "Partition.h"

NS_ASSUME_NONNULL_BEGIN

@implementation PHYOTASBKProtocol

- (void)startAppOTAWithModel:(PHYBLEModel *)model {
    if (model.mSBKContext == nil) {
        model.mSBKContext = [SBKContext new];
        NSLog(@"App模式此刻初始化是个意外");
    }
    [self.dataSender sendHex:@"02" peripheral:model.peripheral charUUID:SBK_OTA_WRITE_Characteristic];
}

- (void)startOTAWithModel:(PHYBLEModel *)model {
    if (model.MTUSize < 20) {
        [self.delegate sbkOTA:model.peripheral updateState:OTAFailed message:@"没有获取到设备MTUSize!"];
        return;
    }
    if (model.mSBKContext == nil) {
        NSLog(@"OTA模式下初始化是个意外");
        model.mSBKContext = [SBKContext new];
    }
    model.mSBKContext.partitionIndex = 0;
    
    if (!model.mSBKContext.isFamewareCheck && _fileDetail.productID.length>0 && _fileDetail.booterVerson.length>0) {
        model.mSBKContext.isFamewareCheck = YES;
        NSString *versionInfoCMD = [NSString stringWithFormat:@"21%@%@",[JCDataConvert strAdd0:_fileDetail.productID length:2 overturn:NO],_fileDetail.booterVerson];
        [self.dataSender sendHex:versionInfoCMD peripheral:model.peripheral charUUID:SBK_OTA_WRITE_Characteristic];
        return;
    }
    NSString *commandStr = [NSString stringWithFormat:@"01%@00",[JCDataConvert ToHex:(int)_fileDetail.fileResult.count]];
    [self.dataSender sendHex:commandStr peripheral:model.peripheral charUUID:SBK_OTA_WRITE_Characteristic];
}

- (void)SBKAPPReceiveData:(NSData *)data model:(PHYBLEModel *)model {
    
    if (data.length == 18) {
        NSString *macString = [JCDataConvert getCommandMac:data];
        // 00 DD55552262A2 2262 56332E312E3500 00 00 -> A262225555DD
        NSLog(@"%@ MAC Address: %@", model.peripheral.name, macString);
        
        NSString *productID = [JCDataConvert convertDataToHexStr:[data subdataWithRange:NSMakeRange(7, 2)]];
        productID = [JCDataConvert strAdd0:productID length:2 overturn:NO];
        NSData *subData = [data subdataWithRange:NSMakeRange(9, 7)];
        NSString *versionID = [[NSString alloc] initWithData:subData encoding:NSASCIIStringEncoding];
        [self.delegate sbkOTA:model.peripheral updateState:DeviceVersion message:[NSString stringWithFormat:@"%@%@",productID,versionID]];
        
        // booter315及以后的版本，升级文件中必须包含PID和VID，否则芯片端会主动断开
        if (_fileDetail.productID.length>0 && _fileDetail.booterVerson.length>0) {
            //对比升级文件中芯片型号跟设备中芯片型号是否一致
            if (![_fileDetail.productID isEqualToString:productID]) {
                [self.delegate sbkOTA:model.peripheral updateState:OTAFailed message:@"升级文件与芯片类型不一致，无法升级！"];
                return;
            }
            //booter315及以后的版本,新增0x04指令用于设备端对比芯片型号和版本号，控制是否进行升级
            NSString *versionInfoCMD = [NSString stringWithFormat:@"04%@%@",[JCDataConvert strAdd0:_fileDetail.productID length:2 overturn:NO],_fileDetail.booterVerson];
            [self.dataSender sendHex:versionInfoCMD peripheral:model.peripheral charUUID:SBK_OTA_WRITE_Characteristic];
        }
        
        //默认情况下为0，指最后一位MAC地址加一；如需特殊处理，可以通过该字节指定加一的字节位置
        int rescanByte = [JCDataConvert dataToInt:[data subdataWithRange:NSMakeRange(16, 1)]];
        if (rescanByte >= 0x06) {
            rescanByte = 0;
        }
        
        @synchronized (self) {
            model.adverMacAddr = macString;
            model.mSBKContext.checkByte = rescanByte;
        }
        
        [self sendDeviceModeChange:model];
    }else {
        // 当做315以前的版本处理
        NSLog(@"App模式下收到数据：%@",data);
        [self sendDeviceModeChange:model];
    }
}

- (void)sendDeviceModeChange:(PHYBLEModel *)model {
    if ([_fileDetail.filePath hasSuffix:@"res"]) {
        [self.dataSender sendHex:@"0103" peripheral:model.peripheral charUUID:SBK_OTA_WRITE_Characteristic];
    }else if ([_fileDetail.filePath hasSuffix:@"hex"] || [_fileDetail.filePath hasSuffix:@"hex4"] || [_fileDetail.filePath hasSuffix:@"hex16"]) {
        [self.dataSender sendHex:@"0102" peripheral:model.peripheral charUUID:SBK_OTA_WRITE_Characteristic];
    }
}

//收到返回的0x0081,开始发送升级文件信息，flash地址
- (void)SBKStepOne:(PHYBLEModel *)model {
    
    Partition *partition = _fileDetail.fileResult[model.mSBKContext.partitionIndex];
    NSInteger temp_flash_addr = model.mSBKContext.flash_addr;
    //run addr 在11000000 ~ 1107ffff， flash addr=run addr，其余的，flash addr从0开始递增
    if( (0x11000000 <= [JCDataConvert hexNumberStringToNumber:partition.address]) && ([JCDataConvert hexNumberStringToNumber:partition.address] <= 0x1107ffff)){
        temp_flash_addr = [JCDataConvert hexNumberStringToNumber:partition.address];
    }
    if ([_fileDetail.filePath hasSuffix:@"res"]) {
        temp_flash_addr = 0;
        @synchronized (self) {
            model.mSBKContext.flash_addr = 0;
        }
    }
    NSString *cmd = [self make_part_cmd:(int)model.mSBKContext.partitionIndex flash_addr:(int)temp_flash_addr run_addr:partition.address size:(int)partition.partitionLength checksum:partition.checkSum];
    [self.dataSender sendHex:cmd peripheral:model.peripheral charUUID:SBK_OTA_WRITE_Characteristic];
    
}

///收到0x0084收到0x0087
- (void)SBKStepFour:(PHYBLEModel *)model {
    if (!model) return;
    
    dispatch_source_t timer = model.myTimer;
    if (timer == nil) {
        // 创建 dispatch_source 定时器
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0),
                                  (uint64_t)(kLoopCheckTime * NSEC_PER_MSEC),
                                  (uint64_t)(kLoopCheckTime * NSEC_PER_MSEC / 10));
        
        __weak typeof(self) weakSelf = self;
        dispatch_source_set_event_handler(timer, ^{
            [weakSelf loopCheckCommandBuffer:model];
        });
        
        @synchronized (self) {
            model.myTimer = timer;
        }
        dispatch_resume(timer);
    } else {
        // 直接恢复定时器
        dispatch_source_set_timer(timer,
                                  dispatch_time(DISPATCH_TIME_NOW, 0),
                                  (uint64_t)(kLoopCheckTime * NSEC_PER_MSEC),
                                  (uint64_t)(kLoopCheckTime * NSEC_PER_MSEC / 10));
    }
}

//收到0X0085
- (void)SBKStepThree:(PHYBLEModel *)deviceModel {
    @synchronized (self) {
        deviceModel.mSBKContext.partitionIndex++;
    }
    
    NSInteger partitionIndex;
    @synchronized (self) {
        partitionIndex = deviceModel.mSBKContext.partitionIndex;
    }
    
    if(partitionIndex < _fileDetail.fileResult.count){
        //后面地址由前一个长度决定
        Partition *prePartition = _fileDetail.fileResult[partitionIndex-1];
        //run addr 在11000000 ~ 1107ffff， flash addr=run addr，其余的，flash addr从0开始递增
        if( (0x11000000 > [JCDataConvert hexNumberStringToNumber:prePartition.address]) || ([JCDataConvert hexNumberStringToNumber:prePartition.address] > 0x1107ffff)){
            @synchronized (self) {
                deviceModel.mSBKContext.flash_addr = deviceModel.mSBKContext.flash_addr + prePartition.partitionLength + 8;
            }
        }
        Partition *partition = _fileDetail.fileResult[partitionIndex];
        
        NSInteger flash_addr;
        @synchronized (self) {
            flash_addr = deviceModel.mSBKContext.flash_addr;
        }
        
        NSInteger temp_flash_addr = flash_addr;
        //run addr 在11000000 ~ 1107ffff， flash addr=run addr，其余的，flash addr从0开始递增
        if( (0x11000000 <= [JCDataConvert hexNumberStringToNumber:partition.address]) && ([JCDataConvert hexNumberStringToNumber:partition.address] <= 0x1107ffff)){
            temp_flash_addr = [JCDataConvert hexNumberStringToNumber:partition.address];
        }
        if ([_fileDetail.filePath hasSuffix:@"res"]) {
            temp_flash_addr = 0;
            @synchronized (self) {
                deviceModel.mSBKContext.flash_addr = 0;
            }
        }
        NSString *cmd = [self make_part_cmd:(int)partitionIndex flash_addr:(int)temp_flash_addr run_addr:partition.address size:(int)partition.partitionLength checksum:partition.checkSum];
        [self.dataSender sendHex:cmd peripheral:deviceModel.peripheral charUUID:SBK_OTA_WRITE_Characteristic];
    }
}

- (void)parseNotifyData:(NSData *)data model:(PHYBLEModel *)model {
    if (data.length < 1) return;
    if (![self isOTAMode:model.peripheral]) {
        [self SBKAPPReceiveData:data model:model];
        return;
    }
    
    NSString *cmdStr = [JCDataConvert ConvertHexToString:data].uppercaseString;
    if ([cmdStr isEqualToString:@"0081"]) {
        if ([_fileDetail.filePath hasSuffix:@"res"]) {
            NSString *cmdStr = [self make_resource_cmd];
            [self.dataSender sendHex:cmdStr peripheral:model.peripheral charUUID:SBK_OTA_WRITE_Characteristic];
        }else {
            [self SBKStepOne:model];
        }
    } else if ([cmdStr isEqualToString:@"0084"]) {
        @synchronized (self) {
            model.mSBKContext.blockIndex = 0;
        }
        [self SBKStepFour:model];
    } else if ([cmdStr isEqualToString:@"0087"]) {
        [self SBKStepFour:model];
    } else if ([cmdStr isEqualToString:@"0085"]) {
        [self SBKStepThree:model];
    } else if ([cmdStr isEqualToString:@"0083"]) {
        NSString *msg = NSLocalizedStringFromTable(@"RebootDevice", @"PHYOTA", @"收到0x83,发送Reboot指令!");
        [self.delegate sbkOTA:model.peripheral updateState:OTAComplete message:msg];
        [self.dataSender sendHex:@"04" peripheral:model.peripheral charUUID:SBK_OTA_WRITE_Characteristic];
    } else if ([cmdStr isEqualToString:@"0089"]) {
        [self SBKStepOne:model];
    } else if ([cmdStr isEqualToString:@"00"] || [cmdStr isEqualToString:@"0091"] || [cmdStr isEqualToString:@"FF"]) {
        [self startOTAWithModel:model];
    } else {
        NSString *msg = [NSString stringWithFormat:@"收到固件端错误码:%@",cmdStr];
        [self.delegate sbkOTA:model.peripheral updateState:DeviceErrorCode message:msg];
    }
}

- (BOOL)isOTAMode:(CBPeripheral *)peripheral {
    
    if (!peripheral || !peripheral.services) {
        return NO;
    }
    
    NSString *targetCharacteristicUUID = SBK_OTA_WRITE_WithNoResponse;
    
    for (CBService *service in peripheral.services) {
        if (!service.characteristics) {
            continue;
        }
        
        for (CBCharacteristic *characteristic in service.characteristics) {
            NSString *characteristicUUIDString = characteristic.UUID.UUIDString;
            if ([characteristicUUIDString.uppercaseString isEqualToString:targetCharacteristicUUID.uppercaseString]) {
                return YES;
            }
        }
    }
    
    return NO;
}

/*
 *@轮询发送指令  定时发送，每隔一段时间就发送
 */
- (void)loopCheckCommandBuffer:(PHYBLEModel *)model {
    
    NSInteger partitionIndex;
    NSInteger blockIndex;
    NSInteger mtuSize;
    OTAType otaType;
    
    @synchronized (self) {
        partitionIndex = model.mSBKContext.partitionIndex;
        blockIndex = model.mSBKContext.blockIndex;
        mtuSize = model.MTUSize;
        otaType = model.OTAType;
    }
    
    // 检查分区索引是否有效
    if (partitionIndex >= _fileDetail.fileResult.count) {
        NSLog(@"分区索引越界，取消定时器");
        @synchronized (self) {
            if (model.myTimer){
                dispatch_source_cancel(model.myTimer);
                model.myTimer = nil;
            }
        }
        
        return;
    }
    
    Partition *partition = _fileDetail.fileResult[partitionIndex];
    
    // 计算当前是一组中的第几包（0-15）
    NSInteger packetInGroup = (blockIndex / (mtuSize * 2)) % 16;
    
    // 这里的长度都用16进制字符数计算，而不是字节数
    if (otaType == SBKOTADeviceReady || otaType == ProgressCallBack) {
        if (blockIndex + mtuSize * 2 <= partition.partitionLength*2) {
            
            NSString *cmd = [partition.totalStr substringWithRange:NSMakeRange(blockIndex, mtuSize*2)];
            @synchronized (self) {
                model.mSBKContext.blockIndex += mtuSize * 2;
            }
            [self.dataSender sendData:[JCDataConvert stringToHexData:cmd] peripheral:model.peripheral charUUID:SBK_OTA_WRITE_WithNoResponse noResponse:YES];
            
        }else if (blockIndex < partition.partitionLength*2) {
            
            NSString *cmd = [partition.totalStr substringWithRange:NSMakeRange(blockIndex, partition.partitionLength*2 - blockIndex)];
            @synchronized (self) {
                model.mSBKContext.blockIndex = partition.partitionLength * 2;
            }
            [self.dataSender sendData:[JCDataConvert stringToHexData:cmd] peripheral:model.peripheral charUUID:SBK_OTA_WRITE_WithNoResponse noResponse:YES];
        }
        
        @synchronized (self) {
            blockIndex = model.mSBKContext.blockIndex;
        }
        
        // 重新计算发送后的包序号
        NSInteger newPacketInGroup = (blockIndex / (mtuSize * 2)) % 16;
        
        // 当一组数据发送完成（刚发送完第15包）或者当前分区数据发送完成时暂停
        BOOL isGroupComplete = (packetInGroup == 15 && newPacketInGroup == 0);
        BOOL isPartitionComplete = (blockIndex >= partition.partitionLength * 2);
        
        if (isGroupComplete || isPartitionComplete) {
            // 一组数据传输完或当前分区数据发送完，暂停定时器
            dispatch_source_set_timer(model.myTimer,
                                      dispatch_time(DISPATCH_TIME_NOW, INT64_MAX),
                                      DISPATCH_TIME_FOREVER,
                                      0);
            
            // 实时更新进度条
            NSUInteger currentLength = 0;
            for (int i=0; i<partitionIndex; i++) {
                currentLength = currentLength + ((Partition*)_fileDetail.fileResult[i]).partitionLength*2;
            }
            currentLength += blockIndex;
            float num = currentLength * 100.0 / (_fileDetail.totalFileLength * 2);
            [self.delegate sbkOTA:model.peripheral updateState:ProgressCallBack message:[NSString stringWithFormat:@"%.2f",num]];
            
            // 检查是否所有分区都已发送完成
            if (isPartitionComplete && partitionIndex == _fileDetail.fileResult.count - 1) {
                @synchronized (self) {
                    if (model.myTimer){
                        dispatch_source_cancel(model.myTimer);
                        model.myTimer = nil;
                    }
                }
            }
        }
    }
}

- (NSString *) make_resource_cmd {
    Partition *one = _fileDetail.fileResult[0];
    NSInteger size = 0;
    for (int i=0; i<_fileDetail.fileResult.count; i++) {
        Partition *temp = _fileDetail.fileResult[i];
        size += temp.partitionLength;
    }
    int a = size % 4096;
    if (a!=0) {
        size = size-a+4096;
    }
    //这里还有问题，one.address字节顺序要改变 11070000改为00000711
    NSString *sz = [JCDataConvert strAdd0:[NSString stringWithFormat:@"%@",[JCDataConvert ToHex:(int)size]] length:4 overturn:NO];
    NSString *commandStr = [NSString stringWithFormat:@"05%@%@",[JCDataConvert reversalStr:one.address withLength:8],sz].lowercaseString;
    return commandStr;
}

- (NSString *) make_part_cmd:(int)index flash_addr:(int)flash_addr run_addr:(NSString *)run_addr size:(int)size checksum:(NSUInteger)checksum {
    NSString *fa = [JCDataConvert strAdd0:[NSString stringWithFormat:@"%@",[JCDataConvert ToHex:flash_addr]] length:4 overturn:NO];
    NSString *ra = [JCDataConvert strAdd0:run_addr length:4 overturn:NO];
    NSString *sz = [JCDataConvert strAdd0:[NSString stringWithFormat:@"%@",[JCDataConvert ToHex:size]] length:4 overturn:NO];
    NSString *cs = [JCDataConvert strAdd0:[NSString stringWithFormat:@"%@",[JCDataConvert ToHex:checksum]] length:2 overturn:NO];
    
    NSString *Idindex = [JCDataConvert strAdd0:[NSString stringWithFormat:@"%@",[JCDataConvert ToHex:index]] length:1 overturn:NO];
    return [NSString stringWithFormat:@"%@%@%@%@%@%@",@"02",Idindex,fa,ra,sz,cs];
}

@end

NS_ASSUME_NONNULL_END
