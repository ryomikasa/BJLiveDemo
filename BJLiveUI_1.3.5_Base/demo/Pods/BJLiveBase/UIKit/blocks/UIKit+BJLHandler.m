//
//  UIKit+M9Handler.m
//  M9Dev
//
//  Created by MingLQ on 2015-08-11.
//  Copyright (c) 2015 MingLQ <minglq.9@gmail.com>. Released under the MIT license.
//

#import <objc/runtime.h>

#import "UIKit+BJLHandler.h"

NS_ASSUME_NONNULL_BEGIN

typedef void (^BJLActionHandler)(id _Nullable sender);

static void *BJLHandlerWrappers = &BJLHandlerWrappers;

#pragma mark -

@interface BJLActionHandlerWrapper : NSObject

@property (nonatomic, copy) BJLActionHandler actionHandler;

- (void)actionWithSender:(nullable id)sender;

+ (instancetype)wrapperWithHandler:(BJLActionHandler)actionHandler;

@end

@implementation BJLActionHandlerWrapper

- (void)actionWithSender:(nullable id)sender {
    if (self.actionHandler) self.actionHandler(sender);
}

+ (instancetype)wrapperWithHandler:(BJLActionHandler)actionHandler {
    BJLActionHandlerWrapper *wrapper = [self new];
    wrapper.actionHandler = actionHandler;
    return wrapper;
}

@end

#pragma mark -

@implementation UIBarButtonItem (BJLHandler)

- (instancetype)initWithImage:(nullable UIImage *)image
                        style:(UIBarButtonItemStyle)style {
    return [self initWithImage:image style:style target:nil action:nil];
}

- (instancetype)initWithImage:(nullable UIImage *)image
          landscapeImagePhone:(nullable UIImage *)landscapeImagePhone
                        style:(UIBarButtonItemStyle)style {
    return [self initWithImage:image landscapeImagePhone:landscapeImagePhone style:style target:nil action:nil];
}

- (instancetype)initWithTitle:(nullable NSString *)title
                        style:(UIBarButtonItemStyle)style {
    return [self initWithTitle:title style:style target:nil action:nil];
}

- (instancetype)initWithBarButtonSystemItem:(UIBarButtonSystemItem)systemItem {
    return [self initWithBarButtonSystemItem:systemItem target:nil action:nil];
}

- (id)bjl_addHandler:(void (^)(__kindof UIControl * _Nullable sender))handler {
    self.target = self;
    self.action = @selector(bjl_actionWithSender:);
    
    NSMutableArray<BJLActionHandlerWrapper *> *wrappers = objc_getAssociatedObject(self, BJLHandlerWrappers);
    if (!wrappers) {
        wrappers = [NSMutableArray new];
        objc_setAssociatedObject(self, BJLHandlerWrappers, wrappers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    BJLActionHandlerWrapper *wrapper = [BJLActionHandlerWrapper wrapperWithHandler:(BJLActionHandler)handler];
    [wrappers addObject:wrapper];
    
    return wrapper;
}

- (void)bjl_removeHandlerWithTarget:(id)target {
    if ([target isKindOfClass:[BJLActionHandlerWrapper class]]) {
        return;
    }
    
    BJLActionHandlerWrapper *wrapper = (BJLActionHandlerWrapper *)target;
    
    NSMutableArray<BJLActionHandlerWrapper *> *wrappers = objc_getAssociatedObject(self, BJLHandlerWrappers);
    [wrappers removeObject:wrapper];
}

- (void)bjl_actionWithSender:(id)sender {
    NSMutableArray<BJLActionHandlerWrapper *> *wrappers = objc_getAssociatedObject(self, BJLHandlerWrappers);
    [wrappers enumerateObjectsUsingBlock:^(BJLActionHandlerWrapper *wrapper, NSUInteger index, BOOL *stop) {
        [wrapper actionWithSender:sender];
    }];
}

@end

#pragma mark -

@implementation UIControl (BJLHandler)

- (id)bjl_addHandler:(void (^)(__kindof UIControl * _Nullable sender))handler
         forControlEvents:(UIControlEvents)controlEvents {
    NSMutableArray<BJLActionHandlerWrapper *> *wrappers = objc_getAssociatedObject(self, BJLHandlerWrappers);
    if (!wrappers) {
        wrappers = [NSMutableArray new];
        objc_setAssociatedObject(self, BJLHandlerWrappers, wrappers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    BJLActionHandlerWrapper *wrapper = [BJLActionHandlerWrapper wrapperWithHandler:(BJLActionHandler)handler];
    [wrappers addObject:wrapper];
    
    [self addTarget:wrapper action:@selector(actionWithSender:) forControlEvents:controlEvents];
    
    return wrapper;
}

- (void)bjl_removeHandlerWithTarget:(id)target forControlEvents:(UIControlEvents)controlEvents {
    if ([target isKindOfClass:[BJLActionHandlerWrapper class]]) {
        return;
    }
    
    BJLActionHandlerWrapper *wrapper = (BJLActionHandlerWrapper *)target;
    
    [self removeTarget:wrapper action:@selector(actionWithSender:) forControlEvents:controlEvents];
    
    if (![self actionsForTarget:wrapper forControlEvent:UIControlEventAllEvents]) {
        NSMutableArray<BJLActionHandlerWrapper *> *wrappers = objc_getAssociatedObject(self, BJLHandlerWrappers);
        [wrappers removeObject:wrapper];
    }
}

- (void)bjl_removeHandlerForControlEvents:(UIControlEvents)controlEvents {
    NSMutableArray<BJLActionHandlerWrapper *> *wrappers = objc_getAssociatedObject(self, BJLHandlerWrappers);
    
    [self.allTargets enumerateObjectsUsingBlock:^(id target, BOOL *stop) {
        if ([target isKindOfClass:[BJLActionHandlerWrapper class]]) {
            return;
        }
        BJLActionHandlerWrapper *wrapper = (BJLActionHandlerWrapper *)target;
        
        [self removeTarget:wrapper action:@selector(actionWithSender:) forControlEvents:controlEvents];
        
        if (![self actionsForTarget:wrapper forControlEvent:UIControlEventAllEvents]) {
            [wrappers removeObject:wrapper];
        }
    }];
}

@end

#pragma mark -

@implementation UIGestureRecognizer (BJLHandler)

+ (instancetype)bjl_gestureWithHandler:(void (^)(__kindof UIGestureRecognizer * _Nullable gesture))handler {
    UIGestureRecognizer *gesture = [self new];
    [gesture bjl_addHandler:handler];
    return gesture;
}

- (id)bjl_addHandler:(void (^)(__kindof UIGestureRecognizer * _Nullable gesture))handler {
    NSMutableArray<BJLActionHandlerWrapper *> *wrappers = objc_getAssociatedObject(self, BJLHandlerWrappers);
    if (!wrappers) {
        wrappers = [NSMutableArray array];
        objc_setAssociatedObject(self, BJLHandlerWrappers, wrappers, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    
    BJLActionHandlerWrapper *wrapper = [BJLActionHandlerWrapper wrapperWithHandler:handler];
    [wrappers addObject:wrapper];
    
    [self addTarget:wrapper action:@selector(actionWithSender:)];
    
    return wrapper;
}

- (void)bjl_removeHandlerWithTarget:(id)target {
    if ([target isKindOfClass:[BJLActionHandlerWrapper class]]) {
        return;
    }
    
    BJLActionHandlerWrapper *wrapper = (BJLActionHandlerWrapper *)target;
    
    [self removeTarget:wrapper action:@selector(actionWithSender:)];
    
    NSMutableArray<BJLActionHandlerWrapper *> *wrappers = objc_getAssociatedObject(self, BJLHandlerWrappers);
    [wrappers removeObject:wrapper];
}

@end

NS_ASSUME_NONNULL_END
