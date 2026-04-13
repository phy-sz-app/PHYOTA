//
//  PHYBLEModel.m
//  OTASDK
//
//  Created by 陈双超 on 2022/6/10.
//  Copyright © 2022 phy. All rights reserved.
//

#import "PHYBLEModel.h"

@implementation PHYBLEModel

- (void)dealloc {
    // 对象释放时自动取消并释放定时器
    if (_myTimer) {
        dispatch_source_cancel(_myTimer);
        _myTimer = nil;
    }
}

@end

@implementation SLBContext

@end

@implementation SBKContext

@end


