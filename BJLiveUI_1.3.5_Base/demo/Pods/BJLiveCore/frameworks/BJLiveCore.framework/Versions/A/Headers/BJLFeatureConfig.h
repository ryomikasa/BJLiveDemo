//
//  BJLFeatureConfig.h
//  BJLiveCore
//
//  Created by 杨磊 on 16/7/18.
//  Copyright © 2016 BaijiaYun. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BJLConstants.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BJLPointsCompressType) {
    BJLPointsCompressTypeNone           = 0,
    BJLPointsCompressTypeCustomized     = 1,
    BJLPointsCompressTypeCustomizedV2   = 2
};

@interface BJLFeatureConfig : NSObject <NSCopying, NSCoding>

// 禁止举手
@property (nonatomic, readonly) BOOL disableSpeakingRequest;
@property (nonatomic, readonly, copy, nullable) NSString *disableSpeakingRequestReason;
// 举手通过后自动打开摄像头
@property (nonatomic, readonly) BOOL autoPublishVideoStudent;

// 分享
@property (nonatomic, readonly) BOOL enableShare;

#pragma mark - from class_data

@property (nonatomic, readonly) BJLMediaLimit mediaLimit;
@property (nonatomic, readonly) BOOL autoStartServerRecording;

#pragma mark -

// 隐藏技术支持消息, #see BJLClientType
@property (nonatomic, readonly) NSArray<NSNumber *> *forbiddenClientTypes;

// 隐藏技术支持消息
@property (nonatomic, readonly) BOOL hideSupportMessage;
// 隐藏用户列表
@property (nonatomic, readonly) BOOL hideUserList;
// 禁用 H5 实现的 PPT 动画
@property (nonatomic, readonly) BOOL disablePPTAnimation;

// 支持私聊
@property (nonatomic, readonly) BOOL enableWhisper;
// 支持答题器
@property (nonatomic, readonly) BOOL enableAnswerSheet;
// 支持切换主讲
@property (nonatomic, readonly) BOOL canChangePresenter;
// 【禁用】授权画笔功能 - 可上麦状态就有画笔
@property (nonatomic, readonly) BOOL disableGrantDrawing;
// 举手超时时间
@property (nonatomic, readonly) NSTimeInterval speakingRequestTimeoutInterval;
// 最大发言用户数
@property (nonatomic, readonly) NSInteger maxSpeakerCount;

@end

NS_ASSUME_NONNULL_END
