//
//  BJLNetworking.h
//  M9Dev
//
//  Created by MingLQ on 2016-08-20.
//  Copyright © 2016 MingLQ <minglq.9@gmail.com>. Released under the MIT license.
//

#import <Foundation/Foundation.h>
#import <MobileCoreServices/MobileCoreServices.h>

#if __has_include("BJLAFNetworking.h")
#import "BJLAFNetworking.h"
@compatibility_alias BJLNetworking BJLAFHTTPSessionManager;
@protocol BJLMultipartFormData <BJLAFMultipartFormData>
@end
#else
#import <AFNetworking/AFNetworking.h>
@compatibility_alias BJLNetworking AFHTTPSessionManager;
@protocol BJLMultipartFormData <AFMultipartFormData>
@end
#endif

NS_ASSUME_NONNULL_BEGIN

@interface BJLAFNeverStopNetworkReachabilityManager : BJLAFNetworkReachabilityManager

+ (instancetype)bjl_sharedManager;

- (void)stopMonitoring NS_UNAVAILABLE;

@end

#define BJLNeverStopReachability [BJLAFNeverStopNetworkReachabilityManager bjl_sharedManager]

#pragma mark -

@protocol BJLResponse;

// copied from AFURLRequestSerialization.m - `AFContentTypeForPathExtension`
static inline NSString * BJLMimeTypeForPathExtension(NSString *extension) {
    NSString *UTI = (__bridge_transfer NSString *)UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)extension, NULL);
    NSString *contentType = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass((__bridge CFStringRef)UTI, kUTTagClassMIMEType);
    return contentType ?: @"application/octet-stream";
}

#pragma mark -

/*
@interface BJLNetworking <BJLResponseType: id<BJLResponse>> : AFHTTPSessionManager
@end */

// NSURLSessionTask: All task properties support key-value observing.
// NSProgress: At least totalUnitCount, completedUnitCount, and fractionCompleted, support Key-Value Observing.

@interface BJLNetworking (BJLNetworkingExt)

+ (instancetype)bjl_manager;
+ (instancetype)bjl_managerWithBaseURL:(nullable NSURL *)url;
+ (instancetype)bjl_managerWithSessionConfiguration:(nullable NSURLSessionConfiguration *)configuration;
+ (instancetype)bjl_managerWithBaseURL:(nullable NSURL *)url
                  sessionConfiguration:(nullable NSURLSessionConfiguration *)configuration;

+ (instancetype)bjl_defaultManager;

@property (nonatomic, copy, nullable) NSDictionary * _Nullable (^parametersHandler)(NSString *urlString, NSDictionary * _Nullable parameters);
@property (nonatomic, copy, nullable) NSURLRequest * _Nullable (^requestHandler)(NSString *urlString, NSMutableURLRequest * _Nullable request, NSError * _Nullable __autoreleasing *error);
// return responseObject && !error ? [BJLResponse responseWithObject:responseObject] : [BJLResponse responseWithError:error]
// !!!: return nil to cancel - will not call success or failure
@property (nonatomic, copy, nullable) __kindof NSObject<BJLResponse> * _Nullable (^responseHandler)(id _Nullable responseObject, NSError * _Nullable error);

@property (nonatomic) BOOL autoResume; // default: YES

- (nullable NSURLSessionDataTask *)bjl_GET:(NSString *)urlString
                                parameters:(nullable NSDictionary *)parameters
                                   success:(nullable void (^)(NSURLSessionDataTask *task, __kindof NSObject<BJLResponse> *response))success
                                   failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure;

- (nullable NSURLSessionDataTask *)bjl_POST:(NSString *)urlString
                                 parameters:(nullable NSDictionary *)parameters
                                    success:(nullable void (^)(NSURLSessionDataTask *task, __kindof NSObject<BJLResponse> *response))success
                                    failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure;

/*
- (nullable NSURLSessionDataTask *)bjl_requestWithMethod:(NSString *)method
                                               urlString:(NSString *)urlString
                                              parameters:(nullable NSDictionary *)parameters
                                                 success:(nullable void (^)(NSURLSessionDataTask *task, __kindof NSObject<BJLResponse> *response))success
                                                 failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure;
 */

/**
 *  #param constructing Different from `AFNetworking` - Call `failure` if an error occurs when constructing the HTTP body.
 *  - #param error      Pass it directly to the method `[formData appendPartWith...:error]`.
 *  - #return           The value returned from the method `[formData appendPartWith...]`.
 *  #param progress     Note this block is called on the session queue, not the main queue.
 *  background uploading:
 *  + [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:]
 *  - [UIApplicationDelegate application:handleEventsForBackgroundURLSession:completionHandler:]
 */
- (nullable NSURLSessionUploadTask *)bjl_upload:(NSString *)urlString
                                     parameters:(nullable NSDictionary *)parameters
                                   constructing:(nullable BOOL (^)(id <BJLMultipartFormData> formData, NSError * _Nullable __autoreleasing *error))constructing
                                       progress:(nullable void (^)(NSProgress *uploadProgress))progress
                                        success:(nullable void (^)(NSURLSessionUploadTask *task, __kindof NSObject<BJLResponse> *response))success
                                        failure:(nullable void (^)(NSURLSessionUploadTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure;

/**
 *  #param progress     Note this block is called on the session queue, not the main queue.
 *  background downloading:
 *  + [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:]
 *  - [UIApplicationDelegate application:handleEventsForBackgroundURLSession:completionHandler:]
 */
- (nullable NSURLSessionDownloadTask *)bjl_download:(NSString *)urlString
                                         parameters:(nullable NSDictionary *)parameters
                                           progress:(nullable void (^)(NSProgress *downloadProgress))progress
                                        destination:(nullable NSURL *(^)(NSURL *targetPath, NSURLResponse *response))destination
                                            success:(nullable void (^)(NSURLSessionDownloadTask *task, __kindof NSObject<BJLResponse> *response))success
                                            failure:(nullable void (^)(NSURLSessionDownloadTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure;
/**
 *  #param progress     At least one of `urlString` and `resumeData` MUST NOT be nil.
 *  #see `bjl_updateHandlersForDownloadTask:progress:destination:completionHandler:`
 */
- (nullable NSURLSessionDownloadTask *)bjl_download:(nullable NSString *)urlString
                                         parameters:(nullable NSDictionary *)parameters
                                         resumeData:(nullable NSData *)resumeData
                                           progress:(nullable void (^)(NSProgress *downloadProgress))progress
                                        destination:(nullable NSURL *(^)(NSURL *targetPath, NSURLResponse *response))destination
                                            success:(nullable void (^)(NSURLSessionDownloadTask *task, __kindof NSObject<BJLResponse> *response))success
                                            failure:(nullable void (^)(NSURLSessionDownloadTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure;

/*
- (nullable __kindof NSURLSessionTask *)bjl_makeRequest:(NSMutableURLRequest * _Nullable (^)(NSString *absoluteURLString, NSDictionary * _Nullable parameters, NSError * _Nullable __autoreleasing *serializationError))makeRequest
                                               makeTask:(__kindof NSURLSessionTask * _Nullable (^)(NSURLRequest *request, void (^ _Nullable completionHandler)(NSURLResponse *response, id _Nullable responseObject, NSError * _Nullable error), NSError * _Nullable __autoreleasing *makeTaskError))makeTask
                                              urlString:(NSString *)urlString
                                             parameters:(nullable NSDictionary *)parameters
                                                success:(nullable void (^)(__kindof NSURLSessionTask *task, __kindof NSObject<BJLResponse> *response))success
                                                failure:(nullable void (^)(__kindof NSURLSessionTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure;
 */

@end

#pragma mark -

@protocol BJLResponse <NSObject>

/**
 *  #param responseObject   JSON object, or NSURL for NSURLSessionDownloadTask
 */
+ (instancetype)responseWithObject:(nullable id)responseObject;
+ (instancetype)responseWithError:(nullable NSError *)error;

@property (nonatomic, readonly) BOOL isSuccess;
@property (nonatomic, readonly, nullable) id responseObject;
@property (nonatomic, readonly, nullable) NSError *error;

@end

#pragma mark -

@interface BJLResponse : NSObject <BJLResponse>

@end

NS_ASSUME_NONNULL_END
