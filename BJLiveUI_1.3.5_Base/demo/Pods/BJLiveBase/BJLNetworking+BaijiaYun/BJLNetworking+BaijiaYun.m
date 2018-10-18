//
//  BJLNetworking+BaijiaYun.m
//  BJLiveBase
//
//  Created by MingLQ on 2017-09-05.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import <BJLiveBase/BJL_M9Dev.h>
#import <BJLiveBase/NSObject+BJL_M9Dev.h>
#import <BJLiveBase/BJLUserAgent.h>

#import "BJLNetworking+BaijiaYun.h"

NS_ASSUME_NONNULL_BEGIN

@implementation BJLNetworking (BaijiaYun)

+ (instancetype)bjl_internalManagerWithBaseURL:(nullable NSURL *)url {
    NSURL *baseURL = url ?: [NSURL URLWithString:@"https://api.baijiayun.com"];
    BJLNetworking *manager = [BJLNetworking bjl_managerWithBaseURL:baseURL];
    manager.requestHandler = ^NSURLRequest * _Nullable (NSString *urlString, NSMutableURLRequest * _Nullable request, NSError * _Nullable __autoreleasing *error) {
        NSString * const userAgentKey = @"User-Agent";
        NSString *userAgent = [request valueForHTTPHeaderField:userAgentKey];
        userAgent = [[BJLUserAgent defaultInstance] userAgentWithDefault:userAgent];
        [request setValue:userAgent forHTTPHeaderField:userAgentKey];
        return request;
    };
    manager.responseHandler = ^__kindof NSObject<BJLResponse> * _Nullable (id _Nullable responseObject, NSError * _Nullable error) {
        return (responseObject && !error
                ? [BJLJSONResponse responseWithObject:responseObject]
                : [BJLJSONResponse responseWithError:error]);
    };
    return manager;
}

static BJLNetworking *_internalManager = nil;
static NSURL *_baseURL = nil;

+ (instancetype)bjl_internalManager {
    if (_internalManager) {
        return _internalManager;
    }
    
    @synchronized(self) {
        if (!_internalManager) {
            _internalManager = [self bjl_internalManagerWithBaseURL:_baseURL];
        }
    }
    
    return _internalManager;
}

+ (void)bjl_setInternalBaseURL:(nullable NSURL *)url {
    BOOL isValid = [url.host hasSuffix:@".baijiayun.com"];
    NSParameterAssert(!url || isValid);
    if (!url || isValid) {
        _baseURL = url;
    }
}

@end

#pragma mark -

@interface BJLJSONResponse ()

@property (nonatomic, nullable) NSDictionary *responseDictionary;

@end

@implementation BJLJSONResponse

- (BJLResponseCode)code {
    return [self.responseDictionary bjl_integerForKey:@"code" defaultValue:BJLResponseCodeFailure];
}

- (nullable NSString *)message {
    NSString *message = [self.responseDictionary bjl_stringForKey:@"msg" defaultValue:nil];
    return message.length ? message : nil;
}

- (NSTimeInterval)timestamp {
    NSTimeInterval timestamp = [self.responseDictionary bjl_doubleForKey:@"ts"];
    if (timestamp <= NSTimeIntervalSince1970) {
        timestamp = [NSDate timeIntervalSinceReferenceDate] + NSTimeIntervalSince1970;
    }
    return timestamp;
}

- (nullable NSDictionary *)data {
    NSDictionary *data = [self.responseDictionary bjl_dictionaryForKey:@"data"];
    return data.count ? data : nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> - %@",
            [self class], self, self.responseDictionary];
}

#pragma mark -

+ (instancetype)responseWithObject:(nullable id)jsonObject {
    BJLJSONResponse *response = [self new];
    response.responseDictionary = bjl_cast(NSDictionary, jsonObject);
    return response;
}

+ (instancetype)responseWithError:(nullable NSError *)error {
    BJLMutableJSONResponse *response = [BJLMutableJSONResponse new];
    response.code = BJLResponseCodeFailure;
    response.message = error.localizedDescription;
    response.data = nil;
    response.error = error;
    return response;
}

+ (instancetype)cancelledResponse { 
    BJLMutableJSONResponse *response = [BJLMutableJSONResponse new];
    response.code = BJLResponseCodeCancelled;
    response.message = nil;
    response.data = nil;
    response.error = [NSError errorWithDomain:NSCocoaErrorDomain
                                         code:NSUserCancelledError
                                     userInfo:nil];
    return response;
}

- (BOOL)isSuccess {
    return self.code == BJLResponseCodeSuccess;
}

- (BOOL)isCancelled {
    return self.code == BJLResponseCodeCancelled;
}

- (nullable id)responseObject {
    return self.responseDictionary;
}

- (nullable NSError *)error {
    return nil;
}

@end

@implementation BJLMutableJSONResponse

@synthesize code = _code, message = _message, timestamp = _timestamp, data = _data, error = _error;

- (instancetype)init {
    self = [super init];
    if (self) {
        self.timestamp = [NSDate timeIntervalSinceReferenceDate] + NSTimeIntervalSince1970;
    }
    return self;
}

- (nullable id)responseObject {
    NSMutableDictionary *responseDictionary = [NSMutableDictionary new];
    if (self.code) {
        [responseDictionary setObject:@(self.code) forKey:@"code"];
    }
    if (self.message) {
        [responseDictionary setObject:self.message forKey:@"msg"];
    }
    if (self.timestamp != 0.0) {
        [responseDictionary setObject:@(self.timestamp) forKey:@"ts"];
    }
    if (self.data) {
        [responseDictionary setObject:self.data forKey:@"data"];
    }
    return responseDictionary.count ? [responseDictionary copy] : nil;
}

- (NSString *)description {
    return [NSString stringWithFormat:@"<%@: %p> - "
            "{\n"
            "    code:  %td,\n"
            "    msg:   %@,\n"
            "    ts:    %f,\n"
            "    data:  %@,\n"
            "    error: %@\n"
            "}",
            [self class], self, self.code, self.message, self.timestamp, self.data, self.error];
}

@end

NS_ASSUME_NONNULL_END
