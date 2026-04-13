//
//  PHYFileHandle.h
//  OTASDK
//
//  Created by 陈双超 on 2022/6/12.
//  Copyright © 2022 phy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "PHYOTAType.h"

NS_ASSUME_NONNULL_BEGIN

@interface PHYFileHandle : NSObject {
    NSFileHandle * fileHandle;
    unsigned long long currentOffset;
}

@property (nonatomic, assign) NSUInteger totalFileLength;//整个文件的长度

@property (nonatomic, strong) NSString *filePath;

@property (nonatomic, strong) NSMutableArray *fileResult;

@property (strong, nonatomic) NSString *productID; // IC Name
@property (strong, nonatomic) NSString *booterVerson; // Fameware version

@property (nonatomic, assign) int SLBCheckSum;

- (instancetype)initWithPath:(NSString *)filePath;

- (BOOL)isDataOK;

- (FileType)mFileType;

@end

NS_ASSUME_NONNULL_END
