//
//  BJLAnswerSheet.h
//  Pods
//
//  Created by HuangJie on 2018/6/6.
//  Copyright © 2018年 BaijiaYun. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class BJLAnswerSheetOption;

@interface BJLAnswerSheet : NSObject

// 选项
@property (nonatomic, readonly) NSArray<BJLAnswerSheetOption *> *options;

// 倒计时时长
@property (nonatomic, readonly) NSTimeInterval countDownTime;

@end

/**
 答题选项
 */
@interface BJLAnswerSheetOption : NSObject

/** 选项名：A, B, C, D */
@property (nonatomic, readonly) NSString *key;

/** 是否是答案选项 */
@property (nonatomic, readonly) BOOL isAnswer;

/** 提交答案时使用，表示此选项是否被选中 */
@property (nonatomic) BOOL selected;

@end

NS_ASSUME_NONNULL_END
