//
//  PHYOTAType.h
//  OTASDK
//
//  Created by di lu on 2026/4/1.
//  Copyright © 2026 phy. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, OTAType) {
    None = 0,
    
    DeviceConnecting,       //开始连接
    DeviceConnectFail,
    DeviceDisconnected,
    
    ServicesDiscovering,    //连接成功
    
    SLBServiceFound,        //确认服务
    SBKServiceFound,
    
    SLBOTAConfirm,          //确认特性
    SBKAppConfirm,
    SBKOTAConfirm,
    
    SLBDeviceReady,         //Notify特性Enabled
    SBKAppDeviceReady,
    SBKOTADeviceReady,
    
    DeviceVersion,          //设备端芯片型号和版本号，可用于控制是否进行OTA
    
    ProgressCallBack,
    OTAComplete,            //传输数据完成且校验成功，等待设备重启
    
    OTASuccessReboot,       //升级成功后断开连接重启
    
    SBKAppModeOver,         //App模式交互结束
    
    OTAEnd,                 //升级结束，不代表一定升级成功
    
    DeviceErrorCode,        //收到固件端错误码
    OTAFailed,              //升级失败
    MAXDisconnectedTime,    //超过重连次数限制
};

typedef NS_ENUM(NSInteger, BLECenterType) {
    BLENOTActive,
    BLEActive,
    FileVersion,
    FileError,
    DeviceError,
    RESCANStart,
};

#define SBK_OTA_SERVICE_UUID            @"5833FF01-9B8B-5191-6142-22A4536EF123"
#define SBK_OTA_WRITE_Characteristic    @"5833FF02-9B8B-5191-6142-22A4536EF123"
#define SBK_OTA_NOTIFY_Characteristic   @"5833FF03-9B8B-5191-6142-22A4536EF123"
#define SBK_OTA_WRITE_WithNoResponse    @"5833FF04-9B8B-5191-6142-22A4536EF123"

#define SLB_SERVICE_UUID_SHORT          @"FEB3"
#define SLB_WRITEChara_SHORT            @"FED5"
#define SLB_WRITEWithNoRspChara_SHORT   @"FED7"
#define SLB_NOTIFYChara_SHORT           @"FED8"

#define SLB_SERVICE_UUID                @"0000FEB3-0000-1000-8000-00805F9B34FB"
#define SLB_WRITECharacteristic_ID      @"0000FED5-0000-1000-8000-00805F9B34FB"
#define SLB_WRITEWithNoRsp_ID           @"0000FED7-0000-1000-8000-00805F9B34FB"
#define SLB_NOTIFYCharacteristic_ID     @"0000FED8-0000-1000-8000-00805F9B34FB"

typedef enum {
    NoneFile = 0,
    SLBFile,
    SBKFile,
}FileType;

#define MAXConnection 6
#define kLoopCheckTime 10
#define ReconectTime 4
#define MAX_CMD_QUEUE_SIZE 100
