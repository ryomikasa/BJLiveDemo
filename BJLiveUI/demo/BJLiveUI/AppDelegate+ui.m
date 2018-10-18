//
//  AppDelegate+ui.m
//  LivePlayerApp
//
//  Created by MingLQ on 2016-08-19.
//  Copyright © 2016年 BaijiaYun. All rights reserved.
//

#import <BJLiveBase/BJL_EXTScope.h>
#import <BJLiveBase/NSInvocation+BJL_M9Dev.h>
#import <BJLiveBase/UIAlertController+BJLAddAction.h>

#import <BJLiveCore/BJLiveCore.h>

#if DEBUG
#import <FLEX/FLEXManager.h>
#endif

#import "AppDelegate+ui.h"

#import "BJAppearance.h"
#import "UIViewController+BJUtil.h"
#import "UIWindow+motion.h"

#import "BJRootViewController.h"
#import "BJLoginViewController.h"

#import "BJAppConfig.h"

static inline SEL setCheckedSelector() {
    return NSSelectorFromString([NSString stringWithFormat:@"_%@%@%@:", @"set", @"Check", @"ed"]);
}

@implementation AppDelegate (ui)

- (void)setupAppearance {
    UINavigationBar *navigationBar = [UINavigationBar appearance];
    [navigationBar setTintColor:[UIColor bj_navigationBarTintColor]];
    [navigationBar setTitleTextAttributes:@{ NSFontAttributeName: [UIFont systemFontOfSize:18],
                                             NSForegroundColorAttributeName: [UIColor bj_navigationBarTintColor] }];
}

- (void)setupViewControllers {
    [self showViewController];
}

- (void)showViewController {
    Class viewControllerClass = [BJLoginViewController class];
    
    BJRootViewController *rootViewController = [BJRootViewController sharedInstance];
    
    UIViewController *activeViewController = rootViewController.activeViewController;
    if ([activeViewController isKindOfClass:[UINavigationController class]]) {
        UINavigationController *navigationController = (UINavigationController *)activeViewController;
        activeViewController = navigationController.viewControllers.firstObject;
    }
    
    if (![activeViewController isKindOfClass:viewControllerClass]) {
        UIViewController *viewController = [[UINavigationController alloc] initWithRootViewController:[viewControllerClass new]];
        if (rootViewController.presentedViewController) {
            [rootViewController dismissViewControllerAnimated:NO completion:^{
                [rootViewController switchViewController:viewController completion:nil];
            }];
        }
        else {
            [rootViewController switchViewController:viewController completion:nil];
        }
    }
}

#pragma mark - DeveloperTools

#if DEBUG

- (void)setupDeveloperTools {
    [FLEXManager sharedManager].networkDebuggingEnabled = YES;
    
    NSNotificationCenter *notificationCenter = [NSNotificationCenter defaultCenter];
    [notificationCenter addObserver:self
                           selector:@selector(didShakeWithNotification:)
                               name:UIEventSubtypeMotionShakeNotification
                             object:nil];
}

- (void)didShakeWithNotification:(NSNotification *)notification {
    UIEventSubtypeMotionShakeState shakeState = [notification.userInfo bjl_integerForKey:UIEventSubtypeMotionShakeStateKey];
    if (shakeState == UIEventSubtypeMotionShakeStateEnded) {
        [self showDeveloperTools];
    }
}

- (void)showDeveloperTools {
    bjl_weakify(self);
    
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"Developer Tools"
                                          message:nil
                                          preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIAlertAction *flexAction =
    [alertController bjl_addActionWithTitle:@"FLEX"
                                      style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction *action)
     {
         // bjl_strongify(self);
         [[FLEXManager sharedManager] showExplorer];
     }];
    if (![FLEXManager sharedManager].isHidden) {
        SEL sel = setCheckedSelector();
        if ([flexAction respondsToSelector:sel]) {
            BOOL checked = YES;
            [flexAction bjl_invokeWithSelector:sel argument:&checked];
        }
    }
    
    [alertController bjl_addActionWithTitle:[self nameOfDeployType:[BJAppConfig sharedInstance].deployType]
                                      style:UIAlertActionStyleDefault
                                    handler:^(UIAlertAction *action)
     {
         bjl_strongify(self);
         [self askToSwitchDeployType];
     }];
    
    [alertController bjl_addActionWithTitle:@"取消"
                                      style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction *action)
     {
         // bjl_strongify(self);
     }];
    
    [[UIViewController topViewController] presentViewController:alertController
                                                       animated:YES
                                                     completion:nil];
}

- (void)askToSwitchDeployType {
    // bjl_weakify(self);
    
    BJLDeployType currentDeployType = [BJAppConfig sharedInstance].deployType;
    
    UIAlertController *alertController = [UIAlertController
                                          alertControllerWithTitle:@"切换环境"
                                          message:@"注意：切换环境需要重启应用！"
                                          preferredStyle:UIAlertControllerStyleActionSheet];
    
    for (BJLDeployType deployType = 0; deployType < _BJLDeployType_count; deployType++) {
        UIAlertAction *action =
        [alertController bjl_addActionWithTitle:[self nameOfDeployType:deployType]
                                          style:UIAlertActionStyleDestructive
                                        handler:^(UIAlertAction *action)
         {
             // bjl_strongify(self);
             [BJAppConfig sharedInstance].deployType = deployType;
         }];
        if (deployType == currentDeployType) {
            action.enabled = NO;
            SEL sel = setCheckedSelector();
            if ([action respondsToSelector:sel]) {
                BOOL checked = YES;
                [action bjl_invokeWithSelector:sel argument:&checked];
            }
        }
    }
    
    [alertController bjl_addActionWithTitle:@"取消"
                                      style:UIAlertActionStyleCancel
                                    handler:^(UIAlertAction *action)
     {
         // bjl_strongify(self);
     }];
    
    [[UIViewController topViewController] presentViewController:alertController
                                                       animated:YES
                                                     completion:nil];
}

- (NSString *)nameOfDeployType:(BJLDeployType)deployType {
    switch (deployType) {
        case BJLDeployType_test:
            return @"TEST";
        case BJLDeployType_beta:
            return @"BETA";
        case BJLDeployType_www:
            return @"WWW";
        default:
            return bjl_NSStringFromValue(deployType, @"WWW");
    }
}

#endif

@end
