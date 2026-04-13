//
//  Partition.h
//  OTASDK
//
//  Created by di lu on 2024/10/25.
//  Copyright © 2024 phy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Partition : NSObject

@property (strong, nonatomic) NSString *address;

@property (assign, nonatomic) NSUInteger partitionLength;

@property (assign, nonatomic) NSUInteger checkSum;

@property (copy, nonatomic) NSString *totalStr;

@property (strong, nonatomic) NSString *productID;

@property (strong, nonatomic) NSString *booterVerson;

- (instancetype)initWithAddress:(NSString *)address content:(NSString *)contentStr;

@end
