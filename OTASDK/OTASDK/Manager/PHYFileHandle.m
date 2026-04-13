//
//  PHYFileHandle.m
//  OTASDK
//
//  Created by 陈双超 on 2022/6/12.
//  Copyright © 2022 phy. All rights reserved.
//

#import "PHYFileHandle.h"
#import "JCDataConvert.h"
#import "Partition.h"

@implementation PHYFileHandle

- (instancetype)initWithPath:(NSString *)filePath {
    self = [super init];
    if (self) {
        fileHandle = [NSFileHandle fileHandleForReadingAtPath:filePath];
        if (fileHandle == nil) {
            return nil;
        }
        
        _filePath = [filePath.lowercaseString copy];
        _fileResult = [[NSMutableArray alloc] init];
        
        @try {
            [fileHandle seekToEndOfFile]; //先移到文件尾部计算长度
            _totalFileLength = [fileHandle offsetInFile];
            [fileHandle seekToFileOffset:0];//再移到文件开头，开始读取数据
        } @catch (NSException *exception) {
            NSLog(@"File Handle Error: %@",exception.reason);
            return nil;
        }
        
        if ([_filePath hasSuffix:@"hex"] || [_filePath hasSuffix:@"hex4"] || [_filePath hasSuffix:@"hex16"] || [_filePath hasSuffix:@"res"]) {
            [self parseHexFile];
        }else if ([self.filePath hasSuffix:@"bin"]) {
            [self parseBinFile];
        }else {
            NSLog(@"文件格式错误");
            return nil;
        }
    }
    return self;
}

- (BOOL)isDataOK {
    return _fileResult.count > 0;
}

- (FileType)mFileType {
    if ([_filePath hasSuffix:@"bin"]) {
        return SLBFile;
    }else if ([_filePath hasSuffix:@"hex"] || [_filePath hasSuffix:@"hex4"] || [_filePath hasSuffix:@"hex16"] || [_filePath hasSuffix:@"res"]){
        return SBKFile;
    }
    return NoneFile;
}

- (void)dealloc {
    [fileHandle closeFile];
}

- (void)parseHexFile {
    NSString *address = @"";
    NSMutableString *result = [NSMutableString string];//缓存当前Partition的内容
    int flag = 0;
    
    // 使用缓冲区逐行读取，避免一次性加载整个文件
    const NSUInteger bufferSize = 1024 * 10; // 10KB缓冲区
    NSMutableData *buffer = [NSMutableData dataWithCapacity:bufferSize];
    NSMutableString *lineBuffer = [NSMutableString string];
    
    while (YES) {
        @autoreleasepool { // 及时释放临时内存
            NSData *chunk = [fileHandle readDataOfLength:bufferSize];
            if (chunk.length == 0) break;
            
            [buffer appendData:chunk];
            
            // 将buffer转换为字符串，处理行分割
            NSString *chunkStr = [[NSString alloc] initWithData:buffer encoding:NSASCIIStringEncoding];
            [lineBuffer appendString:chunkStr];
            
            NSRange range = NSMakeRange(0, lineBuffer.length);
            while (YES) {
                NSRange newlineRange = [lineBuffer rangeOfString:@"\n" options:0 range:range];
                if (newlineRange.location == NSNotFound) break;
                
                // 提取一行
                NSString *readline = [lineBuffer substringWithRange:NSMakeRange(range.location, newlineRange.location - range.location)];
                [self processHexLine:readline
                           addressPtr:&address
                              result:result
                              flagPtr:&flag];
                
                range.location = newlineRange.location + 1;
                range.length = lineBuffer.length - range.location;
            }
            
            // 保留未处理的部分
            if (range.location < lineBuffer.length) {
                lineBuffer = [NSMutableString stringWithString:[lineBuffer substringFromIndex:range.location]];
            } else {
                lineBuffer = [NSMutableString string];
            }
            
            [buffer setLength:0]; // 清空buffer
        }
    }
    
    // 处理最后一行
    if (lineBuffer.length > 0) {
        [self processHexLine:lineBuffer addressPtr:&address result:result flagPtr:&flag];
    }
    
    // 计算总长度
    [self calculateTotalLength];
}

- (void)calculateTotalLength {
    self.totalFileLength = 0;
    for (Partition *tempPa in self.fileResult) {
        self.totalFileLength += tempPa.partitionLength;
        if (tempPa.productID.length > 0 && tempPa.booterVerson.length > 0) {
            _productID = tempPa.productID;
            _booterVerson = tempPa.booterVerson;
        }
    }
}

- (void)processHexLine:(NSString *)readline
             addressPtr:(NSString **)addressPtr
                result:(NSMutableString *)result
                flagPtr:(int *)flagPtr {
    
    if (readline.length < 11) return; // 最小有效行长度
    
    NSString *hexSize = [readline substringWithRange:NSMakeRange(1, 2)];
    NSUInteger size = [JCDataConvert hexNumberStringToNumber:hexSize];
    
    NSString *recordType = [readline substringWithRange:NSMakeRange(7, 2)];
    
    if ([recordType isEqualToString:@"04"]) { // 扩展线性地址记录
        if (result.length > 0) {
            Partition *partition = [[Partition alloc] initWithAddress:*addressPtr content:result];
            [self.fileResult addObject:partition];
            [result setString:@""]; // 清空result
        }
        
        *addressPtr = [readline substringWithRange:NSMakeRange(9, 4)];
        *flagPtr = 0;
        return;
    }
    
    if ([recordType isEqualToString:@"05"] || [recordType isEqualToString:@"01"]) { // 结束记录
        if (result.length > 0) {
            Partition *partition = [[Partition alloc] initWithAddress:*addressPtr content:result];
            [self.fileResult addObject:partition];
        }
        return;
    }
    
    if (*flagPtr == 0) {
        *flagPtr = 1;
        NSString *str = [readline substringWithRange:NSMakeRange(3, 4)];
        *addressPtr = [NSString stringWithFormat:@"%@%@", *addressPtr, str];
    }
    
    if (readline.length >= 9 + size * 2) {
        NSString *resultStr = [readline substringWithRange:NSMakeRange(9, size * 2)];
        [result appendString:resultStr];
    }
}

- (void)parseBinFile {
    
    // 1. 先读取整个文件到_fileResult（必须保留原功能）
    [fileHandle seekToFileOffset:0];
    NSData *chunk = [fileHandle readDataOfLength:self.totalFileLength];
    NSString *allFileStr = [JCDataConvert convertDataToHexStr:chunk];
    [_fileResult addObject:allFileStr.uppercaseString];
    
    // 2. 计算CRC（可以使用流式或直接计算）
    self.SLBCheckSum = [self cal_CRC16_CCITT:chunk];
    
    // 3. 提取版本信息
    NSString *versionRandomStr = @"3B03F2C00112EC9815F75357228A61330ACA4C23C47477CBA6AB1E2F04CC8269EF96CA95B02EDF949FC5297E684CB1F1CEDF50E2EF976EB54AAB6C751DBDE3AA51622C9E838F0F286F34E2073D4519477FE971558AE969BC92E366E70E1692297359E7B7FB8179F845C1D829D538A66647A8130D6D52F559AD99052062B6CFC6";
    
    if ([allFileStr containsString:versionRandomStr]) {
        NSRange range = [allFileStr rangeOfString:versionRandomStr];
        NSString *string = [allFileStr substringFromIndex:range.location+range.length];
        if (string.length < 16) {
            NSLog(@"文件版本信息不全");
            return;
        }
        _productID = [NSString stringWithFormat:@"%@%@",[string substringWithRange:NSMakeRange(2, 2)],[string substringWithRange:NSMakeRange(0, 2)]];
        _booterVerson = [NSString stringWithFormat:@"%@",[string substringWithRange:NSMakeRange(4, 12)]];
    }
}

- (UInt16)cal_CRC16_CCITT:(NSData *)data {
    UInt16 rslt = 0xFFFF;
    UInt16 poly = 0x1021;
    
    for (int itr0 = 0; itr0 < data.length; itr0 += 1) {
        Byte *byteArray = (Byte *)[data bytes];
        rslt ^= (byteArray[itr0] << 8);
        for (int itr1 = 0; itr1 < 8; itr1 += 1) {
            if (0 != (rslt & 0x8000))
                rslt = ((rslt << 1) ^ poly);
            else
                rslt = (rslt << 1);
        }
    }
    
    return rslt;
}

@end
