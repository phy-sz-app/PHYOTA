//
//  PHYOTASDKLogger.h
//  OTASDK
//
//  Created by di lu on 2026/6/5.
//  Copyright © 2026 phy. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, PHYOTASDKLogLevel) {
    PHYOTASDKLogLevelDebug = 0,
    PHYOTASDKLogLevelInfo,
    PHYOTASDKLogLevelWarning,
    PHYOTASDKLogLevelError
};

@interface PHYOTASDKLogEntry : NSObject
@property (nonatomic, strong) NSDate *timestamp;
@property (nonatomic, assign) PHYOTASDKLogLevel level;
@property (nonatomic, copy) NSString *source;
@property (nonatomic, copy) NSString *direction; // @"SEND" / @"RECV" / @"EVENT"
@property (nonatomic, copy) NSString *message;
@property (nonatomic, copy, nullable) NSString *hexData;
@property (nonatomic, copy, nullable) NSString *deviceName;
@property (nonatomic, copy, nullable) NSString *deviceUUID;
@end

@protocol PHYOTASDKLoggerDelegate <NSObject>
- (void)otaSDKLoggerDidAddEntry:(PHYOTASDKLogEntry *)entry;
@end

@interface PHYOTASDKLogger : NSObject

@property (nonatomic, weak, nullable) id<PHYOTASDKLoggerDelegate> delegate;
@property (nonatomic, assign, getter=isEnabled) BOOL enabled;

+ (instancetype)sharedLogger;

- (void)logWithLevel:(PHYOTASDKLogLevel)level
              source:(NSString *)source
           direction:(NSString *)direction
             message:(NSString *)message
             hexData:(nullable NSString *)hexData
          deviceName:(nullable NSString *)deviceName
          deviceUUID:(nullable NSString *)deviceUUID;

- (void)logSend:(NSString *)source
        message:(NSString *)message
        hexData:(nullable NSString *)hexData
     deviceName:(nullable NSString *)deviceName
     deviceUUID:(nullable NSString *)deviceUUID;

- (void)logRecv:(NSString *)source
        message:(NSString *)message
        hexData:(nullable NSString *)hexData
     deviceName:(nullable NSString *)deviceName
     deviceUUID:(nullable NSString *)deviceUUID;

- (void)logEvent:(NSString *)source
         message:(NSString *)message
      deviceName:(nullable NSString *)deviceName
      deviceUUID:(nullable NSString *)deviceUUID;

@end

NS_ASSUME_NONNULL_END
