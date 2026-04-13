//
//  OTCModel.h
//  PHY
//
//  Created by Han on 2018/10/9.
//  Copyright © 2018年 phy. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface OTCModel : NSObject
@property(nonatomic, strong)NSString *fileName;//文件名
@property(nonatomic, strong)NSString *fileOwner;//所有人
@property(nonatomic, strong)NSDate *filemTime;//创建时间
@property(nonatomic, assign)NSInteger fileSize;
@property(nonatomic, strong)NSString *fileAbsolutePath;//文件路径
@end

NS_ASSUME_NONNULL_END
