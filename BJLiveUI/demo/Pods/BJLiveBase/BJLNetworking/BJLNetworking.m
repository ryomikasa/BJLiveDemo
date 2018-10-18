//
//  BJLNetworking.m
//  M9Dev
//
//  Created by MingLQ on 2016-08-20.
//  Copyright © 2016 MingLQ <minglq.9@gmail.com>. Released under the MIT license.
//

#import <objc/runtime.h>

#import "BJLNetworking.h"

NS_ASSUME_NONNULL_BEGIN

@implementation BJLAFNeverStopNetworkReachabilityManager

+ (void)load {
    [self bjl_sharedManager];
}

+ (instancetype)bjl_sharedManager {
    static BJLAFNeverStopNetworkReachabilityManager *_sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [self manager];
        [_sharedManager startMonitoring];
    });
    return _sharedManager;
}

- (void)stopMonitoring {
    // NeverStopMonitoring
}

@end

#pragma mark -

static NSString * const GET = @"GET", * const POST = @"POST";

@implementation BJLNetworking (BJLNetworkingExt)

+ (instancetype)bjl_manager {
    return [self bjl_managerWithBaseURL:nil];
}

+ (instancetype)bjl_managerWithBaseURL:(nullable NSURL *)url {
    return [self bjl_managerWithBaseURL:url sessionConfiguration:nil];
}

+ (instancetype)bjl_managerWithSessionConfiguration:(nullable NSURLSessionConfiguration *)configuration {
    return [self bjl_managerWithBaseURL:nil sessionConfiguration:configuration];
}

+ (instancetype)bjl_managerWithBaseURL:(nullable NSURL *)url
                  sessionConfiguration:(nullable NSURLSessionConfiguration *)configuration {
    configuration = configuration ?: [NSURLSessionConfiguration defaultSessionConfiguration];
    BJLNetworking *manager = (url
                              ? [[self alloc] initWithBaseURL:url
                                         sessionConfiguration:configuration]
                              : [[self alloc] initWithSessionConfiguration:configuration]);
    // NOTE: Strong TLS is not enough, Certificate ensures that you’re talking to the right server
    /* ATS security policy
    manager.securityPolicy = ({
        BJLAFSecurityPolicy *policy = [BJLAFSecurityPolicy defaultPolicy]; // BJLAFSSLPinningModeNone
        policy.allowInvalidCertificates = NO; // MUST be NO
        policy.validatesDomainName = YES;
        policy;
    }); // */
#if DEBUG
    // !!!: only for *.test-at.baijiayun.com and *.beta-at.baijiayun.com
    manager.securityPolicy = ({
        BJLAFSecurityPolicy *policy = [BJLAFSecurityPolicy defaultPolicy];
        policy.allowInvalidCertificates = YES;
        policy.validatesDomainName = NO;
        policy;
    });
#endif
    manager.autoResume = YES;
    return manager;
}

+ (instancetype)bjl_defaultManager {
    static BJLNetworking *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [self bjl_manager];
    });
    return manager;
}

#pragma mark -

@dynamic parametersHandler, requestHandler, responseHandler, autoResume;

static void *BJLNetworking_parametersHandler = &BJLNetworking_parametersHandler;
static void *BJLNetworking_requestHandler = &BJLNetworking_requestHandler;
static void *BJLNetworking_responseHandler = &BJLNetworking_responseHandler;
static void *BJLNetworking_autoResume = &BJLNetworking_autoResume;

- (NSDictionary * _Nullable (^ _Nullable)(NSString *urlString, NSDictionary * _Nullable parameters))parametersHandler {
    return objc_getAssociatedObject(self, BJLNetworking_parametersHandler);
}

- (void)setParametersHandler:(NSDictionary * _Nullable (^ _Nullable)(NSString *urlString, NSDictionary * _Nullable parameters))parametersHandler {
    objc_setAssociatedObject(self, BJLNetworking_parametersHandler, parametersHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSURLRequest * _Nullable (^ _Nullable)(NSString *urlString, NSMutableURLRequest * _Nullable request, NSError * _Nullable __autoreleasing *error))requestHandler {
    return objc_getAssociatedObject(self, BJLNetworking_requestHandler);
}

- (void)setRequestHandler:(NSURLRequest * _Nullable (^ _Nullable)(NSString *urlString, NSMutableURLRequest * _Nullable request, NSError * _Nullable __autoreleasing *error))requestHandler {
    objc_setAssociatedObject(self, BJLNetworking_requestHandler, requestHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (__kindof NSObject<BJLResponse> * _Nullable (^ _Nullable)(id _Nullable responseObject, NSError * _Nullable error))responseHandler {
    return objc_getAssociatedObject(self, BJLNetworking_responseHandler);
}

- (void)setResponseHandler:(__kindof NSObject<BJLResponse> * _Nullable (^ _Nullable)(id _Nullable responseObject, NSError * _Nullable error))responseHandler {
    objc_setAssociatedObject(self, BJLNetworking_responseHandler, responseHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (BOOL)autoResume {
    return [objc_getAssociatedObject(self, BJLNetworking_autoResume) boolValue];
}

- (void)setAutoResume:(BOOL)autoResume {
    objc_setAssociatedObject(self, BJLNetworking_autoResume, autoResume ? @(autoResume) : nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark -

- (nullable NSURLSessionDataTask *)bjl_GET:(NSString *)urlString
                                parameters:(nullable NSDictionary *)parameters
                                   success:(nullable void (^)(NSURLSessionDataTask *task, __kindof NSObject<BJLResponse> *response))success
                                   failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure {
    return [self bjl_requestWithMethod:GET urlString:urlString parameters:parameters success:success failure:failure];
}

- (nullable NSURLSessionDataTask *)bjl_POST:(NSString *)urlString
                                 parameters:(nullable NSDictionary *)parameters
                                    success:(nullable void (^)(NSURLSessionDataTask *task, __kindof NSObject<BJLResponse> *response))success
                                    failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure {
    return [self bjl_requestWithMethod:POST urlString:urlString parameters:parameters success:success failure:failure];
}

- (nullable NSURLSessionDataTask *)bjl_requestWithMethod:(NSString *)method
                                               urlString:(NSString *)urlString
                                              parameters:(nullable NSDictionary *)parameters
                                                 success:(nullable void (^)(NSURLSessionDataTask *task, __kindof NSObject<BJLResponse> *response))success
                                                 failure:(nullable void (^)(NSURLSessionDataTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure {
    return [self bjl_makeRequest:^NSMutableURLRequest *(NSString *absoluteURLString, NSDictionary * _Nullable parameters, NSError * _Nullable __autoreleasing *serializationError) {
        return [self.requestSerializer requestWithMethod:method URLString:absoluteURLString parameters:parameters error:serializationError];
    } makeTask:^__kindof NSURLSessionTask *(NSURLRequest *request, void (^ _Nullable completionHandler)(NSURLResponse *response, id _Nullable responseObject, NSError * _Nullable error), NSError * _Nullable __autoreleasing *makeTaskError) {
        return [self dataTaskWithRequest:request uploadProgress:nil downloadProgress:nil completionHandler:completionHandler];
    } urlString:urlString parameters:parameters success:success failure:failure];
}

- (nullable NSURLSessionUploadTask *)bjl_upload:(NSString *)urlString
                                     parameters:(nullable NSDictionary *)parameters
                                   constructing:(nullable BOOL (^)(id <BJLMultipartFormData> formData, NSError * _Nullable __autoreleasing *error))constructing
                                       progress:(nullable void (^)(NSProgress *uploadProgress))progress
                                        success:(nullable void (^)(NSURLSessionUploadTask *task, __kindof NSObject<BJLResponse> *response))success
                                        failure:(nullable void (^)(NSURLSessionUploadTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure {
    return [self bjl_makeRequest:^NSMutableURLRequest *(NSString *absoluteURLString, NSDictionary * _Nullable parameters, NSError * _Nullable __autoreleasing *serializationError) {
        __block BOOL constructed = !constructing;
        __block NSError *constructError = nil;
        NSMutableURLRequest *request = [self.requestSerializer
                                        multipartFormRequestWithMethod:POST
                                        URLString:absoluteURLString
                                        parameters:parameters
                                        constructingBodyWithBlock:constructing ? ^(id<BJLMultipartFormData> formData) {
                                            constructed = constructing(formData, &constructError);
                                        } : nil
                                        error:serializationError];
        if (request && !constructed) {
            if (serializationError) *serializationError = constructError;
        }
        return constructed ? request : nil;
    } makeTask:^__kindof NSURLSessionTask *(NSURLRequest *request, void (^ _Nullable completionHandler)(NSURLResponse *response, id _Nullable responseObject, NSError * _Nullable error), NSError * _Nullable __autoreleasing *makeTaskError) {
        return [self uploadTaskWithStreamedRequest:request progress:progress completionHandler:completionHandler];
    } urlString:urlString parameters:parameters success:success failure:failure];
}

- (nullable NSURLSessionDownloadTask *)bjl_download:(NSString *)urlString
                                         parameters:(nullable NSDictionary *)parameters
                                           progress:(nullable void (^)(NSProgress *downloadProgress))progress
                                        destination:(nullable NSURL *(^)(NSURL *targetPath, NSURLResponse *response))destination
                                            success:(nullable void (^)(NSURLSessionDownloadTask *task, __kindof NSObject<BJLResponse> *response))success
                                            failure:(nullable void (^)(NSURLSessionDownloadTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure {
    return [self bjl_makeRequest:^NSMutableURLRequest *(NSString *absoluteURLString, NSDictionary * _Nullable parameters, NSError * _Nullable __autoreleasing *serializationError) {
        return [self.requestSerializer requestWithMethod:GET URLString:absoluteURLString parameters:parameters error:serializationError];
    } makeTask:^__kindof NSURLSessionTask *(NSURLRequest *request, void (^ _Nullable completionHandler)(NSURLResponse *response, NSURL * _Nullable fileURL, NSError * _Nullable error), NSError * _Nullable __autoreleasing *makeTaskError) {
        return [self downloadTaskWithRequest:request progress:progress destination:destination completionHandler:completionHandler];
    } urlString:urlString parameters:parameters success:success failure:failure];
}

- (nullable NSURLSessionDownloadTask *)bjl_download:(nullable NSString *)urlString
                                         parameters:(nullable NSDictionary *)parameters
                                         resumeData:(nullable NSData *)resumeData
                                           progress:(nullable void (^)(NSProgress *downloadProgress))progress
                                        destination:(nullable NSURL *(^)(NSURL *targetPath, NSURLResponse *response))destination
                                            success:(nullable void (^)(NSURLSessionDownloadTask *task, __kindof NSObject<BJLResponse> *response))success
                                            failure:(nullable void (^)(NSURLSessionDownloadTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure {
    if (!resumeData) {
        return [self bjl_download:urlString parameters:parameters progress:progress destination:destination success:success failure:failure];
    }
    if (!urlString) {
        return [self bjl_makeTask:^__kindof NSURLSessionTask *(NSURLRequest *request, void (^ _Nullable completionHandler)(NSURLResponse *response, NSURL * _Nullable fileURL, NSError * _Nullable error), NSError * _Nullable __autoreleasing *makeTaskError) {
            return [self downloadTaskWithResumeData:resumeData progress:progress destination:destination completionHandler:completionHandler];
        } request:nil success:success failure:failure];
    }
    return [self bjl_makeRequest:^NSMutableURLRequest *(NSString *absoluteURLString, NSDictionary * _Nullable parameters, NSError * _Nullable __autoreleasing *serializationError) {
        return [self.requestSerializer requestWithMethod:GET URLString:absoluteURLString parameters:parameters error:serializationError];
    } makeTask:^__kindof NSURLSessionTask *(NSURLRequest *request, void (^ _Nullable completionHandler)(NSURLResponse *response, NSURL * _Nullable fileURL, NSError * _Nullable error), NSError * _Nullable __autoreleasing *makeTaskError) {
        // !!!: resume download task with a new url - Thanks to @FengHongen 👍🏿
        NSData *editedResumeData = nil;
        if (resumeData) {
            NSPropertyListFormat format = NSPropertyListBinaryFormat_v1_0;
            id plist = [NSPropertyListSerialization propertyListWithData:resumeData
                                                                 options:NSPropertyListMutableContainersAndLeaves
                                                                  format:&format
                                                                   error:makeTaskError];
            if (!plist && ![plist isKindOfClass:[NSMutableDictionary class]]) return nil;
            static NSString * const urlKey = @"NSURLSessionDownloadURL";
            [(NSMutableDictionary *)plist setObject:request.URL.absoluteString forKey:urlKey];
            editedResumeData = [NSPropertyListSerialization dataWithPropertyList:plist
                                                                          format:format
                                                                         options:0
                                                                           error:makeTaskError];
            if (!editedResumeData) return nil;
        }
        return [self downloadTaskWithResumeData:editedResumeData ?: resumeData progress:progress destination:destination completionHandler:completionHandler];
    } urlString:urlString parameters:parameters success:success failure:failure];
}

- (nullable __kindof NSURLSessionTask *)bjl_makeRequest:(NSMutableURLRequest * _Nullable (^)(NSString *absoluteURLString, NSDictionary * _Nullable parameters, NSError * _Nullable __autoreleasing *serializationError))makeRequest
                                               makeTask:(__kindof NSURLSessionTask * _Nullable (^)(NSURLRequest *request, void (^ _Nullable completionHandler)(NSURLResponse *response, id _Nullable responseObject, NSError * _Nullable error), NSError * _Nullable __autoreleasing *makeTaskError))makeTask
                                              urlString:(NSString *)urlString
                                             parameters:(nullable NSDictionary *)parameters
                                                success:(nullable void (^)(__kindof NSURLSessionTask *task, __kindof NSObject<BJLResponse> *response))success
                                                failure:(nullable void (^)(__kindof NSURLSessionTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure {
    
    // parameters
    NSDictionary * _Nullable (^parametersHandler)(NSString *urlString, NSDictionary * _Nullable parameters) = self.parametersHandler;
    parameters = (parametersHandler ? parametersHandler(urlString, parameters) : parameters);
    
    // url: base url
    NSString *absoluteURLString = [[NSURL URLWithString:urlString relativeToURL:self.baseURL] absoluteString];
    
    // request: serializationError to BJLResponse
    NSError *serializationError = nil;
    NSURLRequest *request = ({
        NSMutableURLRequest *mutableRequest = makeRequest(absoluteURLString, parameters, &serializationError);
        NSURLRequest * _Nullable (^requestHandler)(NSString *urlString, NSMutableURLRequest * _Nullable request, NSError * _Nullable __autoreleasing *error) = self.requestHandler;
        (requestHandler && mutableRequest && !serializationError
         ? requestHandler(urlString, mutableRequest, &serializationError) : mutableRequest);
    });
    if (!request || serializationError) {
        // serializationError to BJLResponse
        if (failure) dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
            __kindof NSObject<BJLResponse> *response = (self.responseHandler ? self.responseHandler(nil, serializationError)
                                                        : [BJLResponse responseWithError:serializationError]);
            if (response) failure(nil, response); // will not to failure if NO response, #see `responseHandler`
        });
        return nil;
    }
    
    return [self bjl_makeTask:makeTask request:request success:success failure:failure];
}

// #param request   nullable for downloadTask+resumeData only
- (nullable __kindof NSURLSessionTask *)bjl_makeTask:(__kindof NSURLSessionTask * _Nullable (^)(NSURLRequest * _Nullable request, void (^ _Nullable completionHandler)(NSURLResponse *response, id _Nullable responseObject, NSError * _Nullable error), NSError * _Nullable __autoreleasing *makeTaskError))makeTask
                                             request:(nullable NSURLRequest *)request
                                             success:(nullable void (^)(__kindof NSURLSessionTask *task, __kindof NSObject<BJLResponse> *response))success
                                             failure:(nullable void (^)(__kindof NSURLSessionTask * _Nullable task, __kindof NSObject<BJLResponse> *response))failure {
    
    // task: response or error to BJLResponse, and call success or failure with task
    typeof(self) __weak __weak_self__ = self;
    NSError *makeTaskError = nil;
    // !!!: task does not retain completionHandler
    __block __kindof NSURLSessionTask *task = makeTask(request, !(success || failure) ? nil : ^(NSURLResponse * __unused urlResponse, id _Nullable responseObject, NSError * _Nullable error) {
        typeof(__weak_self__) __strong self = __weak_self__;
        // canceling & cancelled
        if (!self
            || task.state == NSURLSessionTaskStateCanceling
            || error.code == NSURLErrorCancelled) {
            return;
        }
        // success & failure
        __kindof NSObject<BJLResponse> *response = (self.responseHandler
                                                    ? self.responseHandler(responseObject, error)
                                                    : (error
                                                       ? [BJLResponse responseWithError:error]
                                                       : [BJLResponse responseWithObject:responseObject]));
        if (!response) return; // will not to failure if NO response, #see `responseHandler`
        if (response.isSuccess) {
            if (success) dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                success(task, response);
            });
        }
        else {
            if (failure) dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
                failure(task, response);
            });
        }
    }, &makeTaskError);
    
    if (!task) {
        // serializationError to BJLResponse
        if (failure) dispatch_async(self.completionQueue ?: dispatch_get_main_queue(), ^{
            __kindof NSObject<BJLResponse> *response = (self.responseHandler ? self.responseHandler(nil, makeTaskError)
                                                        : [BJLResponse responseWithError:makeTaskError]);
            if (response) failure(nil, response); // will not to failure if NO response, #see `responseHandler`
        });
        return nil;
    }
    
    // fire
    if (self.autoResume) {
        [task resume];
    }
    
    return task;
}

@end

#pragma mark -

@interface BJLResponse ()

@property (nonatomic, readwrite, setter=setSuccess:) BOOL isSuccess;
@property (nonatomic, readwrite) id responseObject;
@property (nonatomic, readwrite, nullable) NSError *error;

@end

@implementation BJLResponse

+ (instancetype)responseWithObject:(nullable id)responseObject {
    BJLResponse *response = [BJLResponse new];
    response.isSuccess = YES;
    response.responseObject = responseObject;
    return response;
}

+ (instancetype)responseWithError:(nullable NSError *)error {
    BJLResponse *response = [BJLResponse new];
    response.isSuccess = NO;
    response.error = error;
    return response;
}

@end

NS_ASSUME_NONNULL_END
