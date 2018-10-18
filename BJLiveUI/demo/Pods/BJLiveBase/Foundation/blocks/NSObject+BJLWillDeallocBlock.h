//
//  NSObject+BJLWillDeallocBlock.h
//  M9Dev
//
//  Created by MingLQ on 2016-11-28.
//  Copyright © 2016 MingLQ <minglq.9@gmail.com>. Released under the MIT license.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^BJLWillDeallocBlock)(id instance);

@interface NSObject (BJLWillDeallocBlock)

@property (nonatomic, readonly, nullable) BJLWillDeallocBlock bjl_willDeallocBlock;
- (void)bjl_setWillDeallocBlock:(void (^ _Nullable)(id instance))willDeallocBlock;

@end

#pragma mark -

#define BJLWatchdogMake(FORMAT, ...) ({ \
    id watchdog = [NSObject new]; \
    [watchdog bjl_setWillDeallocBlock:^(id _Nonnull instance) { \
        NSCAssert(NO, (FORMAT), ##__VA_ARGS__); \
    }]; \
    watchdog; \
})
#define BJLWatchdogShutUp(WATCHDOG)     { [WATCHDOG bjl_setWillDeallocBlock:nil]; }
#define BJLWatchdogUnleash(WATCHDOG)    { WATCHDOG = nil; }

NS_ASSUME_NONNULL_END
