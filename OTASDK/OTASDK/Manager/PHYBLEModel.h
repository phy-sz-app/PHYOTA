//
//  PHYBLEModel.h
//  OTASDK
//
//  Created by 陈双超 on 2022/6/10.
//  Copyright © 2022 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreBluetooth/CoreBluetooth.h>

NS_ASSUME_NONNULL_BEGIN


@interface SLBContext : NSObject

@property (nonatomic, assign) int           mMesgNumb;//消息ID
@property (nonatomic, assign) NSUInteger    dataIndex;  //发送数据时的游标

@property (nonatomic, strong) NSString      *SLBProductID; //V315添加PID和VID的校验
@property (nonatomic, strong) NSString      *SLBBooterVerson;

@property (nonatomic, assign) BOOL          isShortUUID;

@end

@interface SBKContext : NSObject

@property (nonatomic, assign) NSUInteger    partitionIndex;
@property (nonatomic, assign) NSUInteger    blockIndex; //单个Partition中数据游标
@property (nonatomic, assign) NSUInteger    flash_addr;

@property (nonatomic, assign) BOOL          isFamewareCheck;//是否发起过芯片型号校验
@property (nonatomic, assign) NSUInteger    checkByte;  //MAC地址+1的偏移量标志位，只支持0x00~0x05

@end

@interface PHYBLEModel : NSObject

@property (nonatomic, strong) CBPeripheral *peripheral;
@property (nonatomic, strong) NSNumber     *RSSI;
@property (nonatomic, strong) NSString     *realName;
@property (nonatomic, strong) NSString     *adverMacAddr;
@property (nonatomic, strong) NSDate       *lastUpdateDate;

@property (nonatomic, assign) NSInteger    OTAType;
@property (nonatomic, strong) NSString     *OTAMessage;
@property (nonatomic, assign) int          disconnectTimes;

@property (nonatomic, assign) NSInteger    MTUSize;

@property (nonatomic, strong) SLBContext   *mSLBContext;
@property (nonatomic, strong) SBKContext   *mSBKContext;

@property (nonatomic, strong, nullable) dispatch_source_t   myTimer;

@end


NS_ASSUME_NONNULL_END
