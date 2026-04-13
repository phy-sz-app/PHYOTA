//
//  JCDataConvert.m
//  Zebra
//
//  Created by han on 2018/10/13.
//  Copyright © 2018年 phy. All rights reserved.
//

#import "JCDataConvert.h"

@implementation JCDataConvert

//删除字符串中的制定字符
+ (NSString *) stringDeleteString:(NSString *)str by:(unichar)deleChar{
    NSMutableString *str1 = [NSMutableString stringWithString:str];
    for (int i = 0; i < str1.length; i++) {
        unichar c = [str1 characterAtIndex:i];
        NSRange range = NSMakeRange(i, 1);
        if ( c == deleChar ) { //此处可以是任何字符
            [str1 deleteCharactersInRange:range];
            --i;
        }
    }
    NSString *newstr = [NSString stringWithString:str1];
    return newstr;
}

//data转字符串
+ (NSString *)ConvertHexToString:(NSData *)needConvertHex{
    NSString *str = nil;
    const char *valueString = [[needConvertHex description] cStringUsingEncoding: NSUTF8StringEncoding];
    str = [[NSString alloc]initWithCString:valueString encoding:NSUTF8StringEncoding];
    str = [str substringWithRange:NSMakeRange(1, str.length - 2)];
    str = [JCDataConvert stringDeleteString:str by:' '];
    if ([UIDevice currentDevice].systemVersion.floatValue >= 13.0 && [str containsString:@"length"]&& [str containsString:@"bytes"]) {
        NSRange rangeTemp = [str rangeOfString:@"0x"];
        str = [str substringFromIndex:rangeTemp.location+rangeTemp.length];
        str = [str stringByReplacingOccurrencesOfString:@"{" withString:@""];
        str = [str stringByReplacingOccurrencesOfString:@"}" withString:@""];
    }
    return str;
}

//字符串转data 不带0x
+ (NSData*)hexToBytes:(NSString *)str
{
    NSMutableData* data = [NSMutableData data];
    int idx;
    for (idx = 0; idx+2 <= str.length; idx+=2) {
        NSRange range = NSMakeRange(idx, 2);
        NSString* hexStr = [str substringWithRange:range];
        NSScanner* scanner = [NSScanner scannerWithString:hexStr];
        unsigned int intValue;
        [scanner scanHexInt:&intValue];
        [data appendBytes:&intValue length:1];
    }
    return data;
}
//16进制字符串转data
+ (NSData *) stringToHexData:(NSString *)hexStr {
    NSInteger len = [hexStr length] / 2;    // Target length
    unsigned char *buf = malloc(len);
    unsigned char *whole_byte = buf;
    char byte_chars[3] = {'\0','\0','\0'};
    
    int i;
    for (i=0; i < [hexStr length] / 2; i++) {
        byte_chars[0] = [hexStr characterAtIndex:i*2];
        byte_chars[1] = [hexStr characterAtIndex:i*2+1];
        *whole_byte = strtol(byte_chars, NULL, 16);
        whole_byte++;
    }
    
    NSData *data = [NSData dataWithBytes:buf length:len];
    free( buf );
    return data;
}

//将十进制转化为十六进制
+ (NSString *)ToHex:(NSInteger)tmpid {
    NSString *nLetterValue;
    NSString *str =@"";
    int ttmpig;
    for (int i = 0; i<9; i++) {
        ttmpig=tmpid%16;
        tmpid=tmpid/16;
        switch (ttmpig)
        {
            case 10:
                nLetterValue =@"A";break;
            case 11:
                nLetterValue =@"B";break;
            case 12:
                nLetterValue =@"C";break;
            case 13:
                nLetterValue =@"D";break;
            case 14:
                nLetterValue =@"E";break;
            case 15:
                nLetterValue =@"F";break;
            default:
                nLetterValue = [NSString stringWithFormat:@"%u",ttmpig];
                
        }
        str = [nLetterValue stringByAppendingString:str];
        if (tmpid == 0) {
            break;
        }
    }
    if(str.length == 1 || str.length%2){
        return [NSString stringWithFormat:@"0%@",str];
    }else{
        return str;
    }
}

+ (NSString *)ToHex:(NSInteger)tmpid withLength:(int)length{
    NSString *resultStr = [JCDataConvert ToHex:tmpid];
    while (resultStr.length < length) {
        resultStr = [NSString stringWithFormat:@"0%@",resultStr];
    }
    return resultStr;
}

//data转int
+ (int)dataToInt:(NSData *)data {
    int i;
    [data getBytes:&i length:sizeof(i)];
    return i;
}

//将NSData转化为16进制字符串
+ (NSString *)convertDataToHexStr:(NSData *)data {
    if (!data || [data length] == 0) {
        return @"";
    }
    NSMutableString *string = [[NSMutableString alloc] initWithCapacity:[data length]];
    
    [data enumerateByteRangesUsingBlock:^(const void *bytes, NSRange byteRange, BOOL *stop) {
        unsigned char *dataBytes = (unsigned char*)bytes;
        for (NSInteger i = 0; i < byteRange.length; i++) {
            NSString *hexStr = [NSString stringWithFormat:@"%X", (dataBytes[i]) & 0xff];
            if ([hexStr length] == 2) {
                [string appendString:hexStr];
            } else {
                [string appendFormat:@"0%@", hexStr];
            }
        }
    }];
    return string;
}

//16进制字符串转10进制
+ (NSUInteger)hexNumberStringToNumber:(NSString *)hexNumberString
{
    NSString * temp10 = [NSString stringWithFormat:@"%lu",strtoul([hexNumberString UTF8String],0,16)];
    //转成数字
    NSUInteger cycleNumber = [temp10 integerValue];
    return cycleNumber;
}


#pragma mark --- 针对表示MAC地址的字节数组 转成字符串


+ (BOOL)compareAppMAc:(NSString *)appmac OTAMAC:(NSString *)otamac rescanByte:(NSUInteger)checkByte {
    if (appmac.length != 17 || otamac.length != 17) {
        return NO;
    }
    NSUInteger bytePosition = 15 - 3*checkByte;
    NSString *firstBytes = [appmac substringToIndex:bytePosition];
    
    NSString *substring = [appmac substringWithRange:NSMakeRange(bytePosition, 2)];
    unsigned int value;
    NSScanner *scanner = [NSScanner scannerWithString:substring];
    [scanner scanHexInt:&value];
    value = (value + 1) & 0xFF;
    NSString *midBytes = [NSString stringWithFormat:@"%02X", value];
    
    NSString *lastByte = [appmac substringFromIndex:bytePosition+2];
    
    NSString *newStr = [NSString stringWithFormat:@"%@%@%@",firstBytes,midBytes,lastByte];
    
    return [newStr.uppercaseString isEqualToString:otamac.uppercaseString];
}


+ (NSString *)getOriginalToDataString:(NSString *)value {
    value = [value stringByReplacingOccurrencesOfString:@" " withString:@""];
    value = [value stringByReplacingOccurrencesOfString:@"<" withString:@""];
    value = [value stringByReplacingOccurrencesOfString:@">" withString:@""];
    if ([UIDevice currentDevice].systemVersion.floatValue >= 13.0 && [value containsString:@"length"]&& [value containsString:@"bytes"]) {
        NSRange rangeTemp = [value rangeOfString:@"0x"];
        value = [value substringFromIndex:rangeTemp.location+rangeTemp.length];
        value = [value stringByReplacingOccurrencesOfString:@"{" withString:@""];
        value = [value stringByReplacingOccurrencesOfString:@"}" withString:@""];
    }
    return value;
}

+ (NSString *)getCommandMac:(NSData *)object {
    if (object == nil)return @"";
   
    NSString *value = [NSString stringWithFormat:@"%@",object];
    value = [JCDataConvert getOriginalToDataString:value];
    if (value.length < 16) {
        return @"";
    }
    NSMutableString *macString = [[NSMutableString alloc] init];
    if (value.length < 16) {
        return @"";
    }
    [macString appendString:[[value substringWithRange:NSMakeRange(12,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(10,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(8,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(6,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(4,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(2,2)]uppercaseString]];
    return macString;
}

+ (NSString *)getPeripheralMac:(NSData *)object {
    if (object == nil)return @"";
   
    NSString *value = [NSString stringWithFormat:@"%@",object];
    value = [JCDataConvert getOriginalToDataString:value];
    if (value.length < 16) {
        return @"";
    }
    NSMutableString *macString = [[NSMutableString alloc] init];
    if (value.length < 16) {
        return @"";
    }
    [macString appendString:[[value substringWithRange:NSMakeRange(14,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(12,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(10,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(8,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(6,2)]uppercaseString]];
    [macString appendString:@":"];
    [macString appendString:[[value substringWithRange:NSMakeRange(4,2)]uppercaseString]];
    return macString;
}

+ (NSString *)strAdd0:(NSString *)str length:(int)lenth overturn:(BOOL)overturn {
    //不足8位 ，高位补0
    NSInteger strLength = str.length;
    for (int i=0;i<lenth*2-strLength;i++){
        str = [NSString stringWithFormat:@"%@%@",@"0",str];
    }
    NSMutableData *mData = [NSMutableData data];
    for (int i = 0; i < lenth ; i++) {
        NSUInteger int1 = 0x00;
        Byte bytes = int1 & 0xff;
        [mData appendBytes:&bytes length:1];
    }
    NSData *contentData = [JCDataConvert hexToBytes:str];
    
    Byte *byte= malloc(sizeof(Byte)*(lenth));
    [mData getBytes:byte length:lenth];
    Byte *contentByte = (Byte *)[contentData bytes];
    for (int j = 0; j < lenth; j++) {
        NSUInteger int1 = contentByte[lenth-j-1];
        if (overturn) {
            int1 = contentByte[j];
        }
        Byte bytes = int1 & 0xff;
        byte[j] = bytes;
    }
    
    NSData *data = [[NSData alloc] initWithBytes:byte length:lenth];
    NSString *contentStr = [JCDataConvert ConvertHexToString:data];//data转string
    free(byte);
    return contentStr;
}

+ (NSString *)reversalStr:(NSString *)string withLength:(int)length {
    NSString *resultStr = @"";
    NSString *newStr = string;
    while (newStr.length < length) {
        newStr = [NSString stringWithFormat:@"0%@",newStr];
    }
    if (newStr.length % 2 == 0) {
        for (int i=0; i<newStr.length; i=i+2) {
            resultStr =  [NSString stringWithFormat:@"%@%@", resultStr, [newStr substringWithRange:NSMakeRange(newStr.length-i-2, 2)] ];
        }
    }
    return resultStr;
}
@end
