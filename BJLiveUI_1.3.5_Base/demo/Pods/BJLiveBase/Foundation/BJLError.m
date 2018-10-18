//
//  BJLError.m
//  BJLiveBase
//
//  Created by MingLQ on 2018-05-11.
//  Copyright © 2018 BaijiaYun. All rights reserved.
//

#import "BJLError.h"

NS_ASSUME_NONNULL_BEGIN

NSString * const BJLErrorSourceErrorKey = @"BJLErrorSourceErrorKey";

@implementation NSError (BJLError)
- (nullable NSError *)bjl_sourceError {
    return self.userInfo[BJLErrorSourceErrorKey];
}
@end

NS_ASSUME_NONNULL_END
