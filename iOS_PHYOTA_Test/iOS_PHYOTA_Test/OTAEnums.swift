//
//  OTAEnums.swift
//  iOS_PHYOTA_Test
//
//  Created by di lu on 2026/1/19.
//

import Foundation

// 将 Objective-C 枚举转换为 Swift 可访问的常量
public enum OTASwiftConstants {
    // OTA 状态 (对应原 OTAType 枚举)
    static let None: UInt = 0
    
    static let DeviceConnecting: UInt = 1       //开始连接
    static let DeviceConnectFail: UInt = 2
    static let DeviceDisconnected: UInt = 3
    
    static let ServicesDiscovering: UInt = 4    //连接成功
    
    static let SLBServiceFound: UInt = 5        //确认服务
    static let SBKServiceFound: UInt = 6
    
    static let SLBOTAConfirm: UInt = 7          //确认特性
    static let SBKAppConfirm: UInt = 8
    static let SBKOTAConfirm: UInt = 9
    
    static let SLBDeviceReady: UInt = 10        //Notify特性Enabled
    static let SBKAppDeviceReady: UInt = 11
    static let SBKOTADeviceReady: UInt = 12
    
    static let DeviceVersion: UInt = 13         //设备端芯片型号和版本号，可用于控制是否进行OTA
    
    static let ProgressCallBack: UInt = 14
    
    static let OTAComplete: UInt = 15           //传输数据完成且校验成功，等待设备重启
    
    static let OTASuccessReboot: UInt = 16      //升级成功后断开连接重启
    
    static let SBKAppModeOver: UInt = 17        //App模式交互结束
    
    static let OTAEnd: UInt = 18                //升级结束，不代表一定升级成功
    
    static let DeviceErrorCode: UInt = 19       //收到固件端错误码
    static let OTAFailed: UInt = 20             //升级失败
    static let MAXDisconnectedTime: UInt = 21   //超过重连次数限制
    
    static let BLENOTActive: UInt = 101
    static let BLEActive: UInt = 102
    static let FileVersion: UInt = 103
    static let DeviceParaError: UInt = 104
    static let RESCANStart: UInt = 105
    
}
