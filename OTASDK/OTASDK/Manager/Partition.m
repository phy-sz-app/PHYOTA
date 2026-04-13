//
//  Partition.m
//  OTASDK
//
//  Created by di lu on 2024/10/25.
//  Copyright © 2024 phy. All rights reserved.
//

#import "Partition.h"
#import "JCDataConvert.h"

@implementation Partition
    
- (instancetype)initWithAddress:(NSString *)address content:(NSString *)contentStr {
    self = [super init];
    if (self) {
        self.address = address;
        self.totalStr = contentStr;
        self.partitionLength = contentStr.length/2;
        self.checkSum = [self calculateCheckSum];
        [self checkPIDAndVID];
    }
    return self;
}

//计算校验码
- (NSUInteger)calculateCheckSum {
    NSUInteger number = 0;
    NSData *data = [JCDataConvert hexToBytes:_totalStr];
    number = [self checkSum:(int)number byte:data];
    return number;
}

- (void)checkPIDAndVID {
    NSString *versionRandomStr = @"3B03F2C00112EC9815F75357228A61330ACA4C23C47477CBA6AB1E2F04CC8269EF96CA95B02EDF949FC5297E684CB1F1CEDF50E2EF976EB54AAB6C751DBDE3AA51622C9E838F0F286F34E2073D4519477FE971558AE969BC92E366E70E1692297359E7B7FB8179F845C1D829D538A66647A8130D6D52F559AD99052062B6CFC6";
    if ([_totalStr.uppercaseString containsString:versionRandomStr]) {
        NSRange range = [_totalStr rangeOfString:versionRandomStr];
        NSString *string = [_totalStr substringFromIndex:range.location+range.length];
        if (string.length < 16) {
            NSLog(@"文件版本信息不全");
            return;
        }
        //NSLog(@"%@",string);
        self.productID = [NSString stringWithFormat:@"%@%@",[string substringWithRange:NSMakeRange(2, 2)],[string substringWithRange:NSMakeRange(0, 2)]];
        self.booterVerson = [NSString stringWithFormat:@"%@",[string substringWithRange:NSMakeRange(4, 12)]];
    }
}

- (int) checkSum:(int)crc byte:(NSData *)data {
    NSUInteger length = data.length;
    Byte *buf = malloc(sizeof(Byte)*(length));
    [data getBytes:buf length:length];
    for (int pos = 0; pos < length; pos++) {
        if (buf[pos] < 0) {
            crc ^= (int) buf[pos] + 256; // XOR byte into least sig. byte of
            // crc
        } else {
            crc ^= (int) buf[pos]; // XOR byte into least sig. byte of crc
        }
        for (int i = 8; i != 0; i--) { // Loop over each bit
            if ((crc & 0x0001) != 0) { // If the LSB is set
                crc >>= 1; // Shift right and XOR 0xA001
                crc ^= 0xA001;
            } else{
                // Else LSB is not set
                crc >>= 1; // Just shift right
            }
        }
    }
    
    return crc;
}

@end
