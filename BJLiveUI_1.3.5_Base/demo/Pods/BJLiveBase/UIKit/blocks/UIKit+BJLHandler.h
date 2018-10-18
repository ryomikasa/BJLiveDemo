//
//  UIKit+M9Handler.h
//  M9Dev
//
//  Created by MingLQ on 2015-08-11.
//  Copyright (c) 2015 MingLQ <minglq.9@gmail.com>. Released under the MIT license.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIBarButtonItem (BJLHandler)

- (instancetype)initWithImage:(nullable UIImage *)image
                        style:(UIBarButtonItemStyle)style;
- (instancetype)initWithImage:(nullable UIImage *)image
          landscapeImagePhone:(nullable UIImage *)landscapeImagePhone
                        style:(UIBarButtonItemStyle)style NS_AVAILABLE_IOS(5_0);
- (instancetype)initWithTitle:(nullable NSString *)title
                        style:(UIBarButtonItemStyle)style;
- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem;

/**
 - will RESET the target and action properties
 - supports adding multiple targets
 #return    an actual target(NOT the target property) which can be used for removing this handler
 */
- (id)bjl_addHandler:(void (^)(__kindof UIControl * _Nullable sender))handler;

- (void)bjl_removeHandlerWithTarget:(id)target;

@end

#pragma mark -

@interface UIControl (BJLHandler)

/**
 #return    an actual target which can be used for removing this handler
 */
- (id)bjl_addHandler:(void (^)(__kindof UIControl * _Nullable sender))handler
    forControlEvents:(UIControlEvents)controlEvents;

- (void)bjl_removeHandlerWithTarget:(id)target forControlEvents:(UIControlEvents)controlEvents;
- (void)bjl_removeHandlerForControlEvents:(UIControlEvents)controlEvents;

@end

#pragma mark -

@interface UIGestureRecognizer (BJLHandler)

+ (instancetype)bjl_gestureWithHandler:(void (^)(__kindof UIGestureRecognizer * _Nullable gesture))handler;

/**
 #return    an actual target which can be used for removing this handler
 */
- (id)bjl_addHandler:(void (^)(__kindof UIGestureRecognizer * _Nullable gesture))handler;

- (void)bjl_removeHandlerWithTarget:(id)target;

@end

NS_ASSUME_NONNULL_END
