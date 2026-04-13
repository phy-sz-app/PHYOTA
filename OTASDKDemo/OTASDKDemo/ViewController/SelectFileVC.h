//
//  SelectFileVC.h
//  OTASDKDemo
//
//  Created by 陈双超 on 2022/6/14.
//  Copyright © 2022 phy. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "OTCModel.h"

NS_ASSUME_NONNULL_BEGIN

@protocol SelectFileDelegate <NSObject>

@required
- (void)selectedFile:(NSArray *)fileModelArray;

@end

@interface SelectFileVC : UIViewController

@property (nonatomic, weak, nullable) id <SelectFileDelegate> delegate;

@property (nonatomic, assign) BOOL isRepeat;

@end

NS_ASSUME_NONNULL_END
