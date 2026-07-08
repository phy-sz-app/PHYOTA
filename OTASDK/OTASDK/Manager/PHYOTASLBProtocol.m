//
//  PHYOTASLBProtocol.m
//  OTASDK
//
//  Created by di lu on 2026/4/1.
//  Copyright © 2026 phy. All rights reserved.
//

#import "PHYOTASLBProtocol.h"
#import "JCDataConvert.h"
#import "PHYOTASDKLogger.h"

NS_ASSUME_NONNULL_BEGIN

//SLB OTA指令部分
UInt8 const MESG_OPCO_ISSU_VERS_REQU = 0x20;//获取蓝牙设备固件版本信息
UInt8 const MESG_OPCO_RESP_VERS_REQU = 0x21;//返回蓝牙设备固件版本信息
UInt8 const MESG_OPCO_ISSU_OTAS_REQU = 0x22;//发送升级请求及固件信息
UInt8 const MESG_OPCO_RESP_OTAS_REQU = 0x23;//返回是否允许升级、上次传输大小以及是否支持快速升级模式
UInt8 const MESG_OPCO_ISSU_OTAS_SEGM = 0x2F;//发送升级包（OTA数据命令头）
UInt8 const MESG_OPCO_RESP_OTAS_SEGM = 0x24;//回复接收到的最后帧序号和已接收固件大小
UInt8 const MESG_OPCO_ISSU_OTAS_COMP = 0x25;//通知固件发送完成并进行校验
UInt8 const MESG_OPCO_RESP_OTAS_COMP = 0x26;//上报固件校验结果

@implementation PHYOTASLBProtocol

- (void)startOTAWithModel:(PHYBLEModel *)model {
    if (model.MTUSize + 4 < 20) {
        [self.delegate slbOTA:model.peripheral updateState:OTAFailed message:@"没有获取到设备MTUSize!"];
        return;
    }
    model.mSLBContext.dataIndex = 0;
    NSData *commandData = [self newSegmMesg:MESG_OPCO_ISSU_VERS_REQU encr:NO data:[JCDataConvert hexToBytes:@"00"] totalSize:1 current:0 model:model];
    NSString *charaStr = model.mSLBContext.isShortUUID ? SLB_WRITEChara_SHORT : SLB_WRITECharacteristic_ID;
    [self.dataSender sendData:commandData peripheral:model.peripheral charUUID:charaStr noResponse:NO];
    [[PHYOTASDKLogger sharedLogger] logSend:@"SLBProtocol"
                                    message:@"获取设备固件版本(0x20)"
                                    hexData:[JCDataConvert convertDataToHexStr:commandData]
                                 deviceName:model.peripheral.name
                                 deviceUUID:model.peripheral.identifier.UUIDString];
}

// totalSize代表的是当前一个块有多少帧,encr:数据加密指示,data:负载部分，frag：总拆包帧数，current：当前帧序号，从0开始。
- (NSData *)newSegmMesg:(UInt16)opco encr:(BOOL)encr data:(NSData*)data totalSize:(NSUInteger)frag current:(int)current model:(PHYBLEModel *)model  {
    
    NSUInteger pksz = model.MTUSize;  // package size
    NSUInteger frsz = MIN(data.length, pksz);  // actual  size,最后一包的大小可能不为pksz
    
    NSString *dataStr = [JCDataConvert convertDataToHexStr:data];
    NSString *resultStr;
    Byte mesg[4];
    mesg[0] = (Byte) (((encr?1:0)<<4)|((model.mSLBContext.mMesgNumb & 0x0F)<<0)); // mesg id
    mesg[1] = (Byte) opco;
    mesg[2] = (Byte) ((((frag-1)&0x0F)<<4)|((current&0x0F)<<0));
    mesg[3] = (Byte) frsz;
    
    model.mSLBContext.mMesgNumb += 1;
    model.mSLBContext.mMesgNumb %= 16;
    
    NSData *mesgData = [NSData dataWithBytes:mesg length:4];
    NSString *mesgStr = [JCDataConvert ConvertHexToString:mesgData];
    resultStr = [NSString stringWithFormat:@"%@%@",mesgStr,dataStr];
    
    NSData *resultData = [JCDataConvert hexToBytes:resultStr];
//    NSLog(@"要发的指令:%@",resultData);
    return resultData;
}

- (void)parseNotifyData:(NSData *)data model:(PHYBLEModel *)model {
    
    int respondType = [JCDataConvert dataToInt:[data subdataWithRange:NSMakeRange(1, 1)]];
    switch (respondType) {
        
        case MESG_OPCO_RESP_VERS_REQU:{
            [[PHYOTASDKLogger sharedLogger] logRecv:@"SLBProtocol"
                                            message:@"收到固件版本响应(0x21)"
                                            hexData:[JCDataConvert convertDataToHexStr:data]
                                         deviceName:model.peripheral.name
                                         deviceUUID:model.peripheral.identifier.UUIDString];
            if (data.length == 9 || data.length >= 13) {
                //新版本固件 data.length：13，  收到数据：01210009002262030105000000
                //旧版本固件 data.length：9，   收到数据：012100050000000100
                NSUInteger SLBContentLength = [JCDataConvert dataToInt:[data subdataWithRange:NSMakeRange(3, 1)]];//取长度标志位，第三个字节，转换成int类型，得到9
                NSRange range = NSMakeRange(4, SLBContentLength);//确定范围：从第4字节开始，取长度为9的数据。
                NSData *subData = [data subdataWithRange:range];//按范围从原数据中取出指定二进制数据 <00226203 01050000 00>
                NSString *string = [JCDataConvert convertDataToHexStr:subData];//将二进制数据转成字符串 002262030105000000
                //PayLoad部分：旧版本是5字节，新版本是9字节。
                //固件类型   PID      VID
                // 00      2262  030105000000
                if (string.length >= 18) { //新版本固件 string.length 18
                    //新版本文件 或 RES_资源文件升级
                    if ((_fileDetail.productID.length>0 && _fileDetail.booterVerson.length>0)|| [_fileDetail.filePath containsString:@"res_"]) {
                        model.mSLBContext.SLBProductID = [string substringWithRange:NSMakeRange(2, 4)];
                        model.mSLBContext.SLBBooterVerson = [string substringWithRange:NSMakeRange(6, 6)] ;
                        NSString *msg = [NSString stringWithFormat:@"%@%@%@",model.mSLBContext.SLBProductID,model.mSLBContext.SLBBooterVerson,[string substringFromIndex:12]];
                        [self.delegate slbOTA:model.peripheral updateState:DeviceVersion message:msg];
                        [self SLBOTAStart:model];
                    }else {//如果是新版315固件，旧文件升级报错
                        [self.delegate slbOTA:model.peripheral updateState:OTAFailed message:NSLocalizedStringFromTable(@"File and device do not match", @"PHYOTA", @"V315新版本Booter固件必须使用包含PID和VID的新文件！")];
                    }
                }else {
                    //旧版本固件，使用默认00000000
                    [self SLBOTAStart:model];
                }
            }else {
                NSLog(@"固件端反馈版本号长度有误！");
            }
        }
            break;
        case MESG_OPCO_RESP_OTAS_REQU:{
            [[PHYOTASDKLogger sharedLogger] logRecv:@"SLBProtocol"
                                            message:@"收到升级请求响应(0x23)"
                                            hexData:[JCDataConvert convertDataToHexStr:data]
                                         deviceName:model.peripheral.name
                                         deviceUUID:model.peripheral.identifier.UUIDString];
            //获取23指令中固件端是否允许升级的标志位
            int isFWAllowOTA = [JCDataConvert dataToInt:[data subdataWithRange:NSMakeRange(4, 1)]];
            if (isFWAllowOTA == 0x01) {
                [self SLBStepOne:data model:model];
            }else {
                [self.delegate slbOTA:model.peripheral updateState:OTAFailed message:NSLocalizedStringFromTable(@"Version number restriction", @"PHYOTA", @"版本号限制，固件端拒绝OTA！")];
            }
            break;
        }
        case MESG_OPCO_RESP_OTAS_SEGM:{
            [[PHYOTASDKLogger sharedLogger] logRecv:@"SLBProtocol"
                                            message:@"收到数据段确认(0x24)"
                                            hexData:[JCDataConvert convertDataToHexStr:data]
                                         deviceName:model.peripheral.name
                                         deviceUUID:model.peripheral.identifier.UUIDString];
            int frameNumber = [self frameNumberCheck:data];
            NSInteger confirmLength = [JCDataConvert dataToInt:[data subdataWithRange:NSMakeRange(5, 4)]]; //confirmLength已确认字节数，dataIndex为字符数
            if (frameNumber == -1) {
                NSLog(@"反馈数据发生错误");
            }else if(frameNumber == 0x0f && model.mSLBContext.dataIndex == confirmLength*2){
                //反馈数据显示正常
                [self SLBStepTwo:model];
            }else {
                NSLog(@"反馈数据显示丢包");
                model.mSLBContext.dataIndex = confirmLength/(model.MTUSize);
                NSLog(@"新的游标位置是%lu",(unsigned long)model.mSLBContext.dataIndex);
                if (model.mSLBContext.dataIndex >= _fileDetail.fileResult.count) {
                    [self.delegate slbOTA:model.peripheral updateState:OTAFailed message:@"数据异常，断开连接！"];
                    return;
                }
                @synchronized (self) {
                    if (model.myTimer){
                        dispatch_source_cancel(model.myTimer);
                        model.myTimer = nil;
                    }
                }
            }
            break;
        }
        case MESG_OPCO_RESP_OTAS_COMP:{
            [[PHYOTASDKLogger sharedLogger] logRecv:@"SLBProtocol"
                                            message:@"收到升级完成响应(0x26)"
                                            hexData:[JCDataConvert convertDataToHexStr:data]
                                         deviceName:model.peripheral.name
                                         deviceUUID:model.peripheral.identifier.UUIDString];
            [self SLBStepThree:data model:model];
            break;
        }
            
    };
}

- (void)SLBOTAStart:(PHYBLEModel *)model {
    //bin文件升级：   00+版本号(4字节)+文件总大小(4字节)+crc16_ccitt(2字节)+00
    //resbin文件升级：01+版本号(4字节)+文件总大小(4字节)+crc16_ccitt(2字节)+00
    //V(315)版之后为：01+版本号(8字节)+文件总大小(4字节)+crc16_ccitt(2字节)+00
    //02220010 01 00030000 00000000 A4790000 EE95 00
    //0222000C 01 00030000          A4790000 EE95 00
    NSString *typeStr = @"00";
    NSString *versionS = @"00000000";
    BOOL is315Boot = model.mSLBContext != nil && model.mSLBContext.SLBProductID != nil && model.mSLBContext.SLBProductID.length > 0;
    if (is315Boot) {
        versionS = [NSString stringWithFormat:@"%@%@",[JCDataConvert reversalStr:_fileDetail.productID withLength:4], _fileDetail.booterVerson];
    }
    if([_fileDetail.filePath containsString:@"res_"]){
        typeStr = @"01";
        NSArray *tempArr = [_fileDetail.filePath componentsSeparatedByString:@"res_"];
        if(tempArr.count == 2 && ((NSString *)tempArr[1]).length > 8){
            if (is315Boot) {
                versionS = [NSString stringWithFormat:@"%@00000000", [tempArr[1] substringToIndex:8]];
            }else {
                versionS = [tempArr[1] substringToIndex:8];
            }
        }
    }
    
    NSString *commandStr = [NSString stringWithFormat:@"%@%@%@%@00",
                            typeStr,
                            versionS,
                            [JCDataConvert reversalStr:[JCDataConvert ToHex:(int)_fileDetail.totalFileLength] withLength:8],
                            [JCDataConvert reversalStr:[JCDataConvert ToHex:_fileDetail.SLBCheckSum] withLength:4]];
    
    NSData *commandData = [self newSegmMesg:MESG_OPCO_ISSU_OTAS_REQU encr:NO data:[JCDataConvert hexToBytes:commandStr] totalSize:1 current:0 model:model];
    NSString *charaStr = model.mSLBContext.isShortUUID ? SLB_WRITEChara_SHORT : SLB_WRITECharacteristic_ID;
    [self.dataSender sendData:commandData peripheral:model.peripheral charUUID:charaStr noResponse:NO];
    [[PHYOTASDKLogger sharedLogger] logSend:@"SLBProtocol"
                                    message:@"发送升级请求及固件信息(0x22)"
                                    hexData:[JCDataConvert convertDataToHexStr:commandData]
                                 deviceName:model.peripheral.name
                                 deviceUUID:model.peripheral.identifier.UUIDString];
}

//检查是否发现异常，如果出现异常，则从丢包处重传
- (int)frameNumberCheck:(NSData *)data {
    if(data.length < 9) {
        return -1;//error
    }
    Byte *bytes = (Byte *)[data bytes];
    Byte frameField = bytes[4];
    int headFourBit = (frameField >>4) & 0x0F;
    int footFourBit = frameField & 0x0F;
    if (headFourBit == footFourBit) {
        return 0x0f;
    }
    return footFourBit;
}

- (void)SLBStepOne:(NSData *)data model:(PHYBLEModel *)model {
    // mBinsFrsz指发多少次OTA数据之后，固件给确认反馈,都是16次再确认
    NSUInteger mBinsFrsz = [JCDataConvert dataToInt:[data subdataWithRange:NSMakeRange(9, 1)]];
    mBinsFrsz = (mBinsFrsz & 0x0F) + 1;
    if (mBinsFrsz != 16) {
        NSLog(@"每一组数据必须是16，当前个数：%lu",(unsigned long)mBinsFrsz);
        return;
    }
    [self SLBStepTwo:model];
}

- (void)SLBStepTwo:(PHYBLEModel *)model {
    
    dispatch_source_t timer = model.myTimer;
    if (timer == nil) {
        // 创建 dispatch_source 定时器
        timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
        dispatch_source_set_timer(timer, dispatch_time(DISPATCH_TIME_NOW, 0),
                                  (uint64_t)(kLoopCheckTime * NSEC_PER_MSEC),
                                  (uint64_t)(kLoopCheckTime * NSEC_PER_MSEC / 10));
        
        __weak typeof(self) weakSelf = self;
        dispatch_source_set_event_handler(timer, ^{
            [weakSelf SLBDataSend:model];
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

- (void)SLBStepThree:(NSData *)data model:(PHYBLEModel *)model{
    NSInteger SUCC = [JCDataConvert dataToInt:[data subdataWithRange:NSMakeRange(4, 1)]];
    if (SUCC == 1) {
        [self.delegate slbOTA:model.peripheral updateState:OTAComplete message:@"确认升级成功后等待重启断开连接"];
    }else{
        [self.delegate slbOTA:model.peripheral updateState:OTAFailed message:NSLocalizedStringFromTable(@"OTAFileCRCCheckFail", @"PHYOTA", @"升级文件CRC校验失败！")];
    }
    if (model.myTimer){
        dispatch_source_cancel(model.myTimer);
        model.myTimer = nil;
    }
}

/*
 *@轮询发送指令  定时发送，每隔一段时间就发送
 */
- (void)SLBDataSend:(PHYBLEModel *)model {
    
    NSUInteger mBinsFrsz = 16;//一组的数据包数
    
    NSInteger currentCount = model.mSLBContext.dataIndex / (model.MTUSize*2);
    currentCount = currentCount % 16;
    
    NSString *SLBDataStr = _fileDetail.fileResult.firstObject;
    NSString *charaStr = model.mSLBContext.isShortUUID ? SLB_WRITEWithNoRspChara_SHORT : SLB_WRITEWithNoRsp_ID;
    if (model.mSLBContext.dataIndex + model.MTUSize * 2 <= SLBDataStr.length) {
        NSString *cmd = [SLBDataStr substringWithRange:NSMakeRange(model.mSLBContext.dataIndex, model.MTUSize*2)];
        NSData *commandData = [self newSegmMesg:MESG_OPCO_ISSU_OTAS_SEGM encr:NO data:[JCDataConvert stringToHexData:cmd] totalSize:mBinsFrsz current:(int)currentCount model:model];
        [self.dataSender sendData:commandData peripheral:model.peripheral charUUID:charaStr noResponse:YES];
        if (currentCount == 0) {
            [[PHYOTASDKLogger sharedLogger] logSend:@"SLBProtocol"
                                            message:[NSString stringWithFormat:@"发送固件数据(0x2F) 帧起始 dataIndex:%lu", (unsigned long)model.mSLBContext.dataIndex]
                                            hexData:[JCDataConvert convertDataToHexStr:commandData]
                                         deviceName:model.peripheral.name
                                         deviceUUID:model.peripheral.identifier.UUIDString];
        }

        model.mSLBContext.dataIndex += model.MTUSize * 2;
        currentCount = (currentCount+1) % 16;
    }else if (model.mSLBContext.dataIndex < SLBDataStr.length) {
        NSString *cmd = [SLBDataStr substringWithRange:NSMakeRange(model.mSLBContext.dataIndex, SLBDataStr.length - model.mSLBContext.dataIndex)];
        NSData *commandData = [self newSegmMesg:MESG_OPCO_ISSU_OTAS_SEGM encr:NO data:[JCDataConvert stringToHexData:cmd] totalSize:mBinsFrsz current:(int)currentCount model:model];
        [self.dataSender sendData:commandData peripheral:model.peripheral charUUID:charaStr noResponse:YES];
        
        model.mSLBContext.dataIndex = SLBDataStr.length;
    }
    
    if(currentCount == 0 || model.mSLBContext.dataIndex == SLBDataStr.length) {
        // 一组数据传输完或当前分区数据发送完，暂停定时器
        dispatch_source_set_timer(model.myTimer,
                                  dispatch_time(DISPATCH_TIME_NOW, INT64_MAX),
                                  DISPATCH_TIME_FOREVER,
                                  0);
        
        //实时更新进度条
        float num = model.mSLBContext.dataIndex * 100.0 / SLBDataStr.length;
        [self.delegate slbOTA:model.peripheral updateState:ProgressCallBack message:[NSString stringWithFormat:@"%.2f",num]];
        
        if (model.mSLBContext.dataIndex == SLBDataStr.length) {
            [self.delegate slbOTA:model.peripheral updateState:ProgressCallBack message:NSLocalizedStringFromTable(@"ConfirmFileData", @"PHYOTA", @"发送完成，确认文件数据完整性！")];
            NSData *commandData = [self newSegmMesg:MESG_OPCO_ISSU_OTAS_COMP encr:NO data:[JCDataConvert hexToBytes:@"01"] totalSize:1 current:0 model:model];
            NSString *writeCharaStr = model.mSLBContext.isShortUUID ? SLB_WRITEChara_SHORT : SLB_WRITECharacteristic_ID;
            [self.dataSender sendData:commandData peripheral:model.peripheral charUUID:writeCharaStr noResponse:NO];
            [[PHYOTASDKLogger sharedLogger] logSend:@"SLBProtocol"
                                            message:@"通知固件发送完成并进行校验(0x25)"
                                            hexData:[JCDataConvert convertDataToHexStr:commandData]
                                         deviceName:model.peripheral.name
                                         deviceUUID:model.peripheral.identifier.UUIDString];
        }
    }
}
@end

NS_ASSUME_NONNULL_END
