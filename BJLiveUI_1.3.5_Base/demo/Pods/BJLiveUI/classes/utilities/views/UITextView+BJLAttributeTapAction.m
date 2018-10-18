//
//  UITextView+BJLAttributeTapAction.m
//  BJLiveUI
//
//  Created by HuangJie on 2018/1/24.
//  Copyright © 2018年 BaijiaYun. All rights reserved.
//

#import "UITextView+BJLAttributeTapAction.h"

#import <objc/runtime.h>
#import <CoreText/CoreText.h>
#import <Foundation/Foundation.h>

@implementation BJLAttributeModel

@end

@implementation UITextView (BJLAttributeTapAction)

#pragma mark - AssociatedObjects

- (NSMutableArray *)attributeStrings {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setAttributeStrings:(NSMutableArray *)attributeStrings {
    objc_setAssociatedObject(self, @selector(attributeStrings), attributeStrings, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSMutableDictionary *)effectDic {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setEffectDic:(NSMutableDictionary *)effectDic {
    objc_setAssociatedObject(self, @selector(effectDic), effectDic, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)isTapAction {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setIsTapAction:(BOOL)isTapAction {
    objc_setAssociatedObject(self, @selector(isTapAction), @(isTapAction), OBJC_ASSOCIATION_ASSIGN);
}

- (void (^)(NSString *, NSRange, NSInteger))tapBlock {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setTapBlock:(void (^)(NSString *, NSRange, NSInteger))tapBlock {
    objc_setAssociatedObject(self, @selector(tapBlock), tapBlock, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (id<BJLAttributeTapActionDelegate>)actionDelegate {
    return objc_getAssociatedObject(self, _cmd);
}

- (BOOL)enabledTapEffect {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setEnabledTapEffect:(BOOL)enabledTapEffect {
    objc_setAssociatedObject(self, @selector(enabledTapEffect), @(enabledTapEffect), OBJC_ASSOCIATION_ASSIGN);
    self.isTapEffect = enabledTapEffect;
}

- (BOOL)isTapEffect {
    return [objc_getAssociatedObject(self, _cmd) boolValue];
}

- (void)setIsTapEffect:(BOOL)isTapEffect {
    objc_setAssociatedObject(self, @selector(isTapEffect), @(isTapEffect), OBJC_ASSOCIATION_ASSIGN);
}

- (void)setActionDelegate:(id<BJLAttributeTapActionDelegate>)actionDelegate {
    objc_setAssociatedObject(self, @selector(actionDelegate), actionDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

#pragma mark - mainFunction

- (void)bjl_addAttributeTapActionWithStrings:(NSArray <NSString *> *)strings
                                  tapClicked:(void (^) (NSString *string , NSRange range , NSInteger index))tapClick {
    [self bjl_getRangesWithStrings:strings];
    
    if (self.tapBlock != tapClick) {
        self.tapBlock = tapClick;
    }
}

- (void)bjl_addAttributeTapActionWithStrings:(NSArray <NSString *> *)strings
                                   delegate:(id <BJLAttributeTapActionDelegate> )actionDelegate {
    [self bjl_getRangesWithStrings:strings];
    
    if (self.actionDelegate != actionDelegate) {
        self.actionDelegate = actionDelegate;
    }
}

- (void)bjl_addAttributeTapActionWithString:(NSString *)string
                                      range:(NSRange)range
                                   delegate:(id <BJLAttributeTapActionDelegate> )actionDelegate {
    if (self.attributedText == nil) {
        self.isTapAction = NO;
        return;
    }
    
    self.isTapAction = YES;
    self.isTapEffect = YES;
    
    __block  NSString *totalStr = self.attributedText.string;
    self.attributeStrings = [NSMutableArray array];
    if (range.length != 0) {
        totalStr = [totalStr stringByReplacingCharactersInRange:range withString:[self bjl_getStringWithRange:range]];
        BJLAttributeModel *model = [BJLAttributeModel new];
        model.range = range;
        model.str = string;
        [self.attributeStrings addObject:model];
    }
    
    if (self.actionDelegate != actionDelegate) {
        self.actionDelegate = actionDelegate;
    }
}

- (void)bjl_removeAllAttributeTapActions {
    [self.attributeStrings removeAllObjects];
    self.tapBlock = nil;
    self.delegate = nil;
}

#pragma mark - touchAction

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (!self.isTapAction) {
        return;
    }
    
    if (objc_getAssociatedObject(self, @selector(enabledTapEffect))) {
        self.isTapEffect = self.enabledTapEffect;
    }
    
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    __weak typeof(self) weakSelf = self;
    [weakSelf bjl_getTapFrameWithTouchPoint:point result:^(NSString *string, NSRange range, NSInteger index) {
        if (weakSelf.isTapEffect) {
            [weakSelf bjl_saveEffectDicWithRange:range];
            [weakSelf bjl_tapEffectWithStatus:YES];
        }
    }];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.isTapEffect) {
        [self performSelectorOnMainThread:@selector(bjl_tapEffectWithStatus:) withObject:nil waitUntilDone:NO];
        [self callbackActionWithTouchSet:touches];
    }
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if (self.isTapEffect) {
        [self performSelectorOnMainThread:@selector(bjl_tapEffectWithStatus:) withObject:nil waitUntilDone:NO];
        [self callbackActionWithTouchSet:touches];
    }
}

// !!!: 点击响应回调：建议在手势结束时调用
- (void)callbackActionWithTouchSet:(NSSet<UITouch *> *)touches {
    UITouch *touch = [touches anyObject];
    CGPoint point = [touch locationInView:self];
    __weak typeof(self) weakSelf = self;
    [self bjl_getTapFrameWithTouchPoint:point result:^(NSString *string, NSRange range, NSInteger index) {
        if (weakSelf.tapBlock) {
            weakSelf.tapBlock (string , range , index);
        }
        if (weakSelf.actionDelegate && [weakSelf.actionDelegate respondsToSelector:@selector(bjl_attributeTapReturnString:range:index:)]) {
            [weakSelf.actionDelegate bjl_attributeTapReturnString:string range:range index:index];
        }
    }];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    
    if (self.isTapAction) {
        if ([self bjl_getTapFrameWithTouchPoint:point result:nil]) {
            return self;
        }
    }
    return [super hitTest:point withEvent:event];
}

#pragma mark - getTapFrame

- (BOOL)bjl_getTapFrameWithTouchPoint:(CGPoint)point result:(void (^) (NSString *string , NSRange range , NSInteger index))resultBlock {
    CTFramesetterRef framesetter = CTFramesetterCreateWithAttributedString((CFAttributedStringRef)self.attributedText);
    CGMutablePathRef Path = CGPathCreateMutable();
    CGPathAddRect(Path, NULL, CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height));
    CTFrameRef frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), Path, NULL);
    
    CFRange range = CTFrameGetVisibleStringRange(frame);
    
    if (self.attributedText.length > range.length) {
        UIFont *font ;
        if ([self.attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:nil]) {
            font = [self.attributedText attribute:NSFontAttributeName atIndex:0 effectiveRange:nil];
        }
        else if (self.font){
            font = self.font;
        }
        else {
            font = [UIFont systemFontOfSize:17];
        }
        
        CFRelease(frame);
        CGPathRelease(Path);
        Path = CGPathCreateMutable();
        CGPathAddRect(Path, NULL, CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height + font.lineHeight));
        frame = CTFramesetterCreateFrame(framesetter, CFRangeMake(0, 0), Path, NULL);
    }
    
    CFArrayRef lines = CTFrameGetLines(frame);
    if (!lines) {
        CFRelease(frame);
        CFRelease(framesetter);
        CGPathRelease(Path);
        return NO;
    }
    
    CFIndex count = CFArrayGetCount(lines);
    CGPoint origins[count];
    CTFrameGetLineOrigins(frame, CFRangeMake(0, 0), origins);
    CGAffineTransform transform = [self bjl_transformForCoreText];
    CGFloat verticalOffset = 0;
    
    for (CFIndex i = 0; i < count; i++) {
        CGPoint linePoint = origins[i];
        CTLineRef line = CFArrayGetValueAtIndex(lines, i);
        CGRect flippedRect = [self bjl_getLineBounds:line point:linePoint];
        CGRect rect = CGRectApplyAffineTransform(flippedRect, transform);
        rect = CGRectInset(rect, 0, 0);
        rect = CGRectOffset(rect, 0, verticalOffset);
        
        NSParagraphStyle *style = [self.attributedText attribute:NSParagraphStyleAttributeName atIndex:0 effectiveRange:nil];
        CGFloat lineSpace;
        if (style) {
            lineSpace = style.lineSpacing;
        }
        else {
            lineSpace = 0;
        }
        CGFloat lineOutSpace = (self.bounds.size.height - lineSpace * (count - 1) -rect.size.height * count) / 2;
        rect.origin.y = lineOutSpace + rect.size.height * i + lineSpace * i;
        
        if (CGRectContainsPoint(rect, point)) {
            CGPoint relativePoint = CGPointMake(point.x - CGRectGetMinX(rect), point.y - CGRectGetMinY(rect));
            CFIndex index = CTLineGetStringIndexForPosition(line, relativePoint);
            CGFloat offset;
            CTLineGetOffsetForStringIndex(line, index, &offset);
            if (offset > relativePoint.x) {
                index = index - 1;
            }
            NSInteger link_count = self.attributeStrings.count;
            
            for (int j = 0; j < link_count; j++) {
                BJLAttributeModel *model = self.attributeStrings[j];
                NSRange link_range = model.range;
                if (NSLocationInRange(index, link_range)) {
                    if (resultBlock) {
                        resultBlock (model.str , model.range , (NSInteger)j);
                    }
                    CFRelease(frame);
                    CFRelease(framesetter);
                    CGPathRelease(Path);
                    return YES;
                }
            }
        }
    }
    CFRelease(frame);
    CFRelease(framesetter);
    CGPathRelease(Path);
    return NO;
}

- (CGAffineTransform)bjl_transformForCoreText {
    return CGAffineTransformScale(CGAffineTransformMakeTranslation(0, self.bounds.size.height), 1.f, -1.f);
}

- (CGRect)bjl_getLineBounds:(CTLineRef)line point:(CGPoint)point {
    CGFloat ascent = 0.0f;
    CGFloat descent = 0.0f;
    CGFloat leading = 0.0f;
    CGFloat width = (CGFloat)CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
    CGFloat height = ascent + fabs(descent) + leading;
    return CGRectMake(point.x, point.y , width, height);
}

#pragma mark - tapEffect

/**
 !!!: 此方法仅用于实现点击样式。touchBegin 时 status 参数为 YES，将 响应点击的文字 换成高亮样式；touchEnd 时 status 参数为 NO，将 响应点击的文字 换回普通样式
 由于我们 App 没有这个需求且 replace 方法有较高的崩溃风险，在这里先注释掉，今后有需要时直接打开即可。
*/
- (void)bjl_tapEffectWithStatus:(BOOL)status {
//    if (self.isTapEffect) {
//        NSMutableAttributedString *attStr = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
//        NSMutableAttributedString *subAtt = [[NSMutableAttributedString alloc] initWithAttributedString:[[self.effectDic allValues] firstObject]];
//        NSRange range = NSRangeFromString([[self.effectDic allKeys] firstObject]);
//        if (status) {
//            [subAtt addAttribute:NSBackgroundColorAttributeName value:[UIColor clearColor] range:NSMakeRange(0, subAtt.string.length)];
//            [attStr replaceCharactersInRange:range withAttributedString:subAtt];
//        }
//        else {
//            [attStr replaceCharactersInRange:range withAttributedString:subAtt];
//        }
//        self.attributedText = attStr;
//    }
}

- (void)bjl_saveEffectDicWithRange:(NSRange)range {
    self.effectDic = [NSMutableDictionary dictionary];
    NSAttributedString *subAttribute = [self.attributedText attributedSubstringFromRange:range];
    [self.effectDic setObject:subAttribute forKey:NSStringFromRange(range)];
}

#pragma mark - getRange

- (void)bjl_getRangesWithStrings:(NSArray <NSString *>  *)strings {
    if (self.attributedText == nil) {
        self.isTapAction = NO;
        return;
    }
    
    self.isTapAction = YES;
    self.isTapEffect = YES;
    
    __block  NSString *totalStr = self.attributedText.string;
    self.attributeStrings = [NSMutableArray array];
    
    __weak typeof(self) weakSelf = self;
    [strings enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSRange range = [totalStr rangeOfString:obj];
        if (range.length != 0) {
            totalStr = [totalStr stringByReplacingCharactersInRange:range withString:[weakSelf bjl_getStringWithRange:range]];
            BJLAttributeModel *model = [BJLAttributeModel new];
            model.range = range;
            model.str = obj;
            [weakSelf.attributeStrings addObject:model];
        }
    }];
}

- (NSString *)bjl_getStringWithRange:(NSRange)range {
    NSMutableString *string = [NSMutableString string];
    for (int i = 0; i < range.length ; i++) {
        [string appendString:@" "];
    }
    return string;
}

@end
