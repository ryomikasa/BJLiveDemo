//
//  BJLError.h
//  BJLiveBase
//
//  Created by MingLQ on 2018-05-11.
//  Copyright © 2018 BaijiaYun. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString * const BJLErrorSourceErrorKey;

@protocol BJLError <NSObject>
@property (nonatomic, readonly, nullable) NSError *bjl_sourceError;
@end

@interface NSError (BJLError) <BJLError>
@end

typedef NSError<BJLError> BJLError;

NS_ASSUME_NONNULL_END
