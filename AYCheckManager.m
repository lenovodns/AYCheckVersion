//
//  AYCheckManager.m
//  AYCheckVersion
//  com.ayjkdev.AYCheckVersion
//  Created by Andy on 16/4/6.
//  Copyright © 2016年 AYJkdev. All rights reserved.
//

#import "AYCheckManager.h"
#import <StoreKit/StoreKit.h>

#define REQUEST_SUCCEED 200
#define CURRENT_VERSION [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]
#define BUNDLE_IDENTIFIER [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleIdentifier"]
#define SYSTEM_VERSION_8_OR_ABOVE (([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0)? (YES):(NO))
#define TRACK_ID @"TRACKID"
#define APP_LAST_VERSION @"APPLastVersion"
#define APP_RELEASE_NOTES @"APPReleaseNotes"
#define APP_TRACK_VIEW_URL @"APPTRACKVIEWURL"
#define SPECIAL_MODE_CHECK_URL @"https://itunes.apple.com/lookup?country=%@&bundleId=%@"
#define NORMAL_MODE_CHECK_URL @"https://itunes.apple.com/lookup?bundleId=%@"
#define SKIP_CURRENT_VERSION @"SKIPCURRENTVERSION"
#define SKIP_VERSION @"SKIPVERSION"

@interface UIAlertAYCheckManager()

@property(nonatomic,strong)UIWindow *alertWindow;

@end

@implementation UIAlertAYCheckManager

- (void)showAnimated:(BOOL)animated
{
    UIWindow *window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    [window setBackgroundColor:[UIColor clearColor]];
    UIViewController*rootViewController = [[UIViewController alloc] init];
    [[rootViewController view] setBackgroundColor:[UIColor clearColor]];
    // set window level
    [window setWindowLevel:UIWindowLevelAlert + 1];
    [window makeKeyAndVisible];
    [self setAlertWindow:window];
    [window setRootViewController:rootViewController];
    
    [rootViewController presentViewController:self animated:animated completion:nil];
}

@end

@interface AYCheckManager ()<SKStoreProductViewControllerDelegate, UIAlertViewDelegate>

@property (nonatomic, copy) NSString *nextTimeTitle;
@property (nonatomic, copy) NSString *confimTitle;
@property (nonatomic, copy) NSString *alertTitle;
@property (nonatomic, copy) NSString *skipVersionTitle;
@end

@implementation AYCheckManager

static AYCheckManager *checkManager = nil;

+ (instancetype)sharedCheckManager {
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        checkManager = [[AYCheckManager alloc] init];
        checkManager.nextTimeTitle = [COM_Manager changeLanguages:@"下次提示"];
        checkManager.confimTitle = [COM_Manager changeLanguages:@"前往更新"];
        checkManager.alertTitle = [COM_Manager changeLanguages:@"发现新版本"];
        checkManager.skipVersionTitle = nil;
    });
    return checkManager;
}

- (void)checkVersion {
    
    [self checkVersionWithAlertTitle:self.alertTitle nextTimeTitle:self.nextTimeTitle confimTitle:self.confimTitle];
}

- (void)checkVersionWithAlertTitle:(NSString *)alertTitle nextTimeTitle:(NSString *)nextTimeTitle confimTitle:(NSString *)confimTitle {
    
    [self checkVersionWithAlertTitle:alertTitle nextTimeTitle:nextTimeTitle confimTitle:confimTitle skipVersionTitle:nil];
}

- (void)checkVersionWithAlertTitle:(NSString *)alertTitle nextTimeTitle:(NSString *)nextTimeTitle confimTitle:(NSString *)confimTitle skipVersionTitle:(NSString *)skipVersionTitle {
    
    self.alertTitle = alertTitle;
    self.nextTimeTitle = nextTimeTitle;
    self.confimTitle = confimTitle;
    self.skipVersionTitle = skipVersionTitle;
    [checkManager getInfoFromAppStore];
}

- (void)getInfoFromAppStore {
    
    NSURL *requestURL;
    if (self.countryAbbreviation == nil) {
        requestURL = [NSURL URLWithString:[NSString stringWithFormat:NORMAL_MODE_CHECK_URL,BUNDLE_IDENTIFIER]];
    } else {
        requestURL = [NSURL URLWithString:[NSString stringWithFormat:SPECIAL_MODE_CHECK_URL,self.countryAbbreviation,BUNDLE_IDENTIFIER]];
    }
    NSURLRequest *request = [NSURLRequest requestWithURL:requestURL];
    NSURLSession *session = [NSURLSession sharedSession];

    NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        
        NSHTTPURLResponse *urlResponse = (NSHTTPURLResponse *)response;
        
        if (urlResponse.statusCode == REQUEST_SUCCEED) {
            NSDictionary *responseDic = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
            NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
            if ([responseDic[@"resultCount"] intValue] == 1) {
                
                NSArray *results = responseDic[@"results"];
                NSDictionary *resultDic = [results firstObject];
                [userDefault setObject:resultDic[@"version"] forKey:APP_LAST_VERSION];
                [userDefault setObject:resultDic[@"releaseNotes"] forKey:APP_RELEASE_NOTES];
                [userDefault setObject:resultDic[@"trackViewUrl"] forKey:APP_TRACK_VIEW_URL];
                [userDefault setObject:[resultDic[@"trackId"] stringValue] forKey:TRACK_ID];
                if ([resultDic[@"version"] isEqualToString:CURRENT_VERSION] || ![[userDefault objectForKey:SKIP_VERSION] isEqualToString:resultDic[@"version"]]) {
                    [userDefault setBool:NO forKey:SKIP_CURRENT_VERSION];
                }
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    if (![[userDefault objectForKey:SKIP_CURRENT_VERSION] boolValue]) {
                        NSArray *AppStoreVersionArray = [resultDic[@"version"] componentsSeparatedByString:@"."];
                        NSArray *localVersionArray = [CURRENT_VERSION componentsSeparatedByString:@"."];
                        for (int index = 0; index < AppStoreVersionArray.count; index ++) {
                            if ([AppStoreVersionArray[index] intValue] > [localVersionArray[index] intValue]) {
                                [self compareWithCurrentVersion];
                                break;
                            }
                            else if ([AppStoreVersionArray[index] intValue] < [localVersionArray[index] intValue]) {
                                break;
                            }
                        }
                    }
                });
            }
            NSLog(@"苹果商店版本检查！   \n更新版本：%@   \n更新说明：\n%@",[userDefault objectForKey:APP_LAST_VERSION],[userDefault objectForKey:APP_RELEASE_NOTES]);
        }
    }];
    [dataTask resume];
}

- (void)compareWithCurrentVersion {
    
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    NSString *updateMessage = [userDefault objectForKey:APP_RELEASE_NOTES];
    
    if (![[userDefault objectForKey:APP_LAST_VERSION] isEqualToString:CURRENT_VERSION]) {
        
        NSLog(@"最新版本：%f , 当前版本：%f",[[userDefault objectForKey:APP_LAST_VERSION] floatValue],[CURRENT_VERSION floatValue]);
        
        //输出YES（服务器大与本地） 输出NO（服务器小于本地）
        BOOL success = [self compareEditionNumber:[userDefault objectForKey:APP_LAST_VERSION] localNumber:CURRENT_VERSION];
        
        if (success == YES) {
            
            if (SYSTEM_VERSION_8_OR_ABOVE) {
                __weak typeof(self) weakSelf = self;
                
                NSString *alertTitleVersion = [NSString stringWithFormat:@"%@ \n【 Ver %@ 】",self.alertTitle,[userDefault objectForKey:APP_LAST_VERSION]];
                
                UIAlertController *alertControler = [UIAlertController alertControllerWithTitle:alertTitleVersion message:updateMessage preferredStyle:UIAlertControllerStyleAlert];
                
                //下次提示
                UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:self.nextTimeTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                    
                }];
                
                //前往更新
                UIAlertAction *confimAction = [UIAlertAction actionWithTitle:self.confimTitle style:UIAlertActionStyleDestructive handler:^(UIAlertAction * _Nonnull action) {
                    
                    //强制退出App
                    UIWindow *window = [UIApplication sharedApplication].delegate.window;
                    
                    [UIView animateWithDuration:1.0f animations:^{
                        window.alpha = 0;
                        window.frame = CGRectMake(0, window.bounds.size.width, 0, 0);
                    } completion:^(BOOL finished) {
                        exit(0);
                    }];
                    
                    //访问苹果商店上架App
                    [weakSelf openAppStore];
                    
                }];
                [alertControler addAction:confimAction];
                [alertControler addAction:cancelAction];
                
                if (self.skipVersionTitle != nil) {
                    UIAlertAction *skipVersionAction = [UIAlertAction actionWithTitle:self.skipVersionTitle style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
                        
                        [userDefault setBool:YES forKey:SKIP_CURRENT_VERSION];
                        [userDefault setObject:[userDefault objectForKey:APP_LAST_VERSION] forKey:SKIP_VERSION];
                    }];
                    [alertControler addAction:skipVersionAction];
                }
                
                [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:alertControler animated:YES completion:^{
                    NSLog(@"提示更新版本：%@",[userDefault objectForKey:APP_LAST_VERSION]);
                }];
            }
            else
            {
                UIAlertAYCheckManager *alertController = [UIAlertAYCheckManager alertControllerWithTitle:self.alertTitle message:updateMessage preferredStyle:UIAlertControllerStyleAlert];
                
                // 创建更新按钮
                UIAlertAction *confimTitleAction = [UIAlertAction actionWithTitle:self.confimTitle style:(UIAlertActionStyleDestructive) handler:^(UIAlertAction *action) {
                    
                    //访问苹果商店上架App
                    [self openAppStore];
                
                }];
                
                // 创建取消按钮（注意取消按钮只能添加一个）
                UIAlertAction *nextTimeTitleAction = [UIAlertAction actionWithTitle:self.nextTimeTitle style:(UIAlertActionStyleCancel) handler:^(UIAlertAction *action) {
                    
                }];
                
                // 创建跳过按钮
                UIAlertAction *skipVersionTitleAction = [UIAlertAction actionWithTitle:self.skipVersionTitle style:(UIAlertActionStyleDefault) handler:^(UIAlertAction *action) {
                    
                }];
                
                // 添加按钮 将按钮添加到UIAlertController对象上
                [alertController addAction:confimTitleAction];
                [alertController addAction:nextTimeTitleAction];
                [alertController addAction:skipVersionTitleAction];
                
                // 将 UIAlertController 模态出来 相当于 UIAlertView - show 的方法
                [alertController showAnimated:YES];
            }
        }
    }
}

- (void)openAppStore {
    
    NSUserDefaults *userDefault = [NSUserDefaults standardUserDefaults];
    if (!self.openAPPStoreInsideAPP) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[userDefault objectForKey:APP_TRACK_VIEW_URL]]];
    } else {
        SKStoreProductViewController *storeViewController = [[SKStoreProductViewController alloc] init];
        storeViewController.delegate = self;
        
        NSDictionary *parametersDic = @{SKStoreProductParameterITunesItemIdentifier:[userDefault objectForKey:TRACK_ID]};
        [storeViewController loadProductWithParameters:parametersDic completionBlock:^(BOOL result, NSError * _Nullable error) {
            
            if (result) {
                [[UIApplication sharedApplication].keyWindow.rootViewController presentViewController:storeViewController animated:YES completion:^{
                    
                }];
            }
        }];
    }
    
}

- (void)productViewControllerDidFinish:(SKStoreProductViewController *)viewController {
    
    [[UIApplication sharedApplication].keyWindow.rootViewController dismissViewControllerAnimated:YES completion:^{
        
    }];
}

//输出YES（服务器大与本地） 输出NO（服务器小于本地）
- (BOOL)compareEditionNumber:(NSString *)serverNumberStr localNumber:(NSString*)localNumberStr {
    //剔除版本号字符串中的点
    serverNumberStr = [serverNumberStr stringByReplacingOccurrencesOfString:@"." withString:@""];
    localNumberStr = [localNumberStr stringByReplacingOccurrencesOfString:@"." withString:@""];
    //计算版本号位数差
    int placeMistake = (int)(serverNumberStr.length-localNumberStr.length);
    //根据placeMistake的绝对值判断两个版本号是否位数相等
    if (abs(placeMistake) == 0) {
        //位数相等
        return [serverNumberStr integerValue] > [localNumberStr integerValue];
    }else {
        //位数不等
        //multipleMistake差的倍数
        NSInteger multipleMistake = pow(10, abs(placeMistake));
        NSInteger server = [serverNumberStr integerValue];
        NSInteger local = [localNumberStr integerValue];
        if (server > local) {
            return server > local * multipleMistake;
        }else {
            return server * multipleMistake > local;
        }
    }
}

@end
