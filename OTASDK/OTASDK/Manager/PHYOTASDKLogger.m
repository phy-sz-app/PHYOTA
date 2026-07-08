//
//  PHYOTASDKLogger.m
//  OTASDK
//
//  Created by di lu on 2026/6/5.
//  Copyright © 2026 phy. All rights reserved.
//

#import "PHYOTASDKLogger.h"

@implementation PHYOTASDKLogEntry
@end

@interface PHYOTASDKLogger ()
@end

@implementation PHYOTASDKLogger

+ (instancetype)sharedLogger {
    static PHYOTASDKLogger *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    return instance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _enabled = YES;
    }
    return self;
}

- (void)logWithLevel:(PHYOTASDKLogLevel)level
              source:(NSString *)source
           direction:(NSString *)direction
             message:(NSString *)message
             hexData:(nullable NSString *)hexData
          deviceName:(nullable NSString *)deviceName
          deviceUUID:(nullable NSString *)deviceUUID {

    if (!self.enabled) return;

    PHYOTASDKLogEntry *entry = [[PHYOTASDKLogEntry alloc] init];
    entry.timestamp = [NSDate date];
    entry.level = level;
    entry.source = [source copy];
    entry.direction = [direction copy];
    entry.message = [message copy];
    entry.hexData = [hexData copy];
    entry.deviceName = [deviceName copy];
    entry.deviceUUID = [deviceUUID copy];

    id<PHYOTASDKLoggerDelegate> delegate = self.delegate;
    if ([delegate respondsToSelector:@selector(otaSDKLoggerDidAddEntry:)]) {
        [delegate otaSDKLoggerDidAddEntry:entry];
    }
}

- (void)logSend:(NSString *)source
        message:(NSString *)message
        hexData:(nullable NSString *)hexData
     deviceName:(nullable NSString *)deviceName
     deviceUUID:(nullable NSString *)deviceUUID {
    [self logWithLevel:PHYOTASDKLogLevelInfo
                source:source
             direction:@"SEND"
               message:message
               hexData:hexData
            deviceName:deviceName
            deviceUUID:deviceUUID];
}

- (void)logRecv:(NSString *)source
        message:(NSString *)message
        hexData:(nullable NSString *)hexData
     deviceName:(nullable NSString *)deviceName
     deviceUUID:(nullable NSString *)deviceUUID {
    [self logWithLevel:PHYOTASDKLogLevelInfo
                source:source
             direction:@"RECV"
               message:message
               hexData:nil
            deviceName:deviceName
            deviceUUID:deviceUUID];
}

- (void)logEvent:(NSString *)source
         message:(NSString *)message
      deviceName:(nullable NSString *)deviceName
      deviceUUID:(nullable NSString *)deviceUUID {
    [self logWithLevel:PHYOTASDKLogLevelInfo
                source:source
             direction:@"EVENT"
               message:message
               hexData:nil
            deviceName:deviceName
            deviceUUID:deviceUUID];
}

@end
