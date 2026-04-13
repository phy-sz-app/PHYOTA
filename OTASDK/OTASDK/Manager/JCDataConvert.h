//
//  JCDataConvert.h
//  Zebra
//
//  Created by han on 2018/10/13.
//  Copyright © 2018年 phy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface JCDataConvert : NSObject

/*!
 *  @将十六进制NSData转换成十六进制字符串
 *  @needConvertHex -[in] 需要转换的Hex
 *  @return -[out] 转换后的字符串
 */
+ (NSString *)ConvertHexToString:(NSData *)needConvertHex;

+ (NSString *)convertDataToHexStr:(NSData *)data;

/*!
 *  @字符串转data（十六进制）
 *  @str -[in] 需要转换的字符串
 *  @return -[out] 转换后的字符串(十六进制)
 */
+ (NSData *)hexToBytes:(NSString *)str;

+ (NSData *)stringToHexData:(NSString *)hexStr;

/*!
 *  @将十进制转化为十六进制
 *  @tmpid -[in] 需要转换的数字
 *  @return -[out] 转换后的字符串
 */
+ (NSString *)ToHex:(NSInteger)tmpid;
+ (NSString *)ToHex:(NSInteger)tmpid withLength:(int)length;


//NSData转int(10进制),注意数值范围，别越界
+(int)dataToInt:(NSData *)data;


//16进制字符串转10进制int
+ (NSUInteger)hexNumberStringToNumber:(NSString *)hexNumberString;


#pragma mark ---  MAC地址识别

+ (BOOL)compareAppMAc:(NSString *)appmac OTAMAC:(NSString *)otamac rescanByte:(NSUInteger)checkByte;

+ (NSString *)getOriginalToDataString:(NSString *)value;
+ (NSString *)getPeripheralMac:(NSData *)macStr;
+ (NSString *)getCommandMac:(NSData *)object;

//将目标字符串按指定长度输出，如文件长度0x51234，需要按4字节发送，设置lenth=4，overturn设置大小端
+ (NSString *)strAdd0:(NSString *)str length:(int)lenth overturn:(BOOL)overturn;

+ (NSString *)reversalStr:(NSString *)string withLength:(int)length;

@end
