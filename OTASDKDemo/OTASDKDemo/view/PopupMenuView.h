//
//  PopupMenuView.h
//  OTASDKDemo
//
//  Created by di lu on 2024/6/5.
//  Copyright © 2024 phy. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN


@protocol PopupMenuViewDelegate <NSObject>

@required
- (void)didSelectedAtIndexPath:(NSIndexPath *)indexPath;

@end

typedef void(^dismissWithOperation)(void);

@interface PopupMenuView : UIView

@property (nonatomic, weak) id<PopupMenuViewDelegate> delegate;
@property (nonatomic, strong) dismissWithOperation dismissOperation;

//初始化方法
//传入参数：模型数组，弹出原点，宽度，高度（每个cell的高度）
- (instancetype)initWithDataArray:(NSArray *)dataArray
                           origin:(CGPoint)origin
                            width:(CGFloat)width
                           height:(CGFloat)height;

//弹出
- (void)pop;
//消失
- (void)dismiss;

@end

NS_ASSUME_NONNULL_END
