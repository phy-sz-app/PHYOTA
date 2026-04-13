//
//  AppDelegate.m
//  OTASDKDemo
//
//  Created by Han on 2018/10/25.
//  Copyright © 2018年 phy. All rights reserved.
//

#import "AppDelegate.h"
@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    return YES;
}

#pragma mark - ApplicationDelegate
- (BOOL)application:(UIApplication *)application openURL:(nonnull NSURL *)url options:(nonnull NSDictionary<NSString *,id> *)options {
    if (options) {
        NSString *str = [NSString stringWithFormat:@"\n发送请求的应用程序的 Bundle ID：%@\n\n文件的NSURL：%@", options[UIApplicationOpenURLOptionsSourceApplicationKey], url];
        NSLog(@"%@", str);
        
        if (self.window && url) {
            // 根据“其他应用” 用“本应用”打开，通过url，进入列表页
            [self pushDocListViewControllerWithUrl:url];
        }
    }
    return YES;
}

#pragma mark ApplicationDelegate Method
/** 根据“其他应用” 用“本应用”打开，通过url，进入列表页 */
- (void)pushDocListViewControllerWithUrl:(NSURL *)url {

}
@end
