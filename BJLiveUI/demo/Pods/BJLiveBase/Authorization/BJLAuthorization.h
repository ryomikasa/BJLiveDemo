//
//  BJLAuthorization.h
//  M9Dev
//
//  Created by MingLQ on 2016-06-04.
//  Copyright © 2016 MingLQ <minglq.9@gmail.com>. Released under the MIT license.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_OPTIONS(NSInteger, BJLAuthorizationType) {
    BJLAuthorizationType_photos     = 1 << 0,
    BJLAuthorizationType_microphone = 1 << 1,
    BJLAuthorizationType_camera     = 1 << 2
};

typedef void (^BJLAuthorizationCallback)(BOOL granted, UIAlertController * _Nullable alert);

@interface BJLAuthorization : NSObject

/* NSMicrophoneUsageDescription, NSCameraUsageDescription, NSPhotoLibraryUsageDescription
 * now: crash if no these keys in info.plist
 * TODO: not crash if debugging
 */

+ (void)checkPhotosAccessAndRequest:(BOOL)request callback:(BJLAuthorizationCallback)callback;
+ (void)checkMicrophoneAccessAndRequest:(BOOL)request callback:(BJLAuthorizationCallback)callback;
+ (void)checkCameraAccessAndRequest:(BOOL)request callback:(BJLAuthorizationCallback)callback;

+ (void)checkAccessTypes:(BJLAuthorizationType)types request:(BOOL)request callback:(BJLAuthorizationCallback)callback DEPRECATED_ATTRIBUTE;

@end

NS_ASSUME_NONNULL_END
