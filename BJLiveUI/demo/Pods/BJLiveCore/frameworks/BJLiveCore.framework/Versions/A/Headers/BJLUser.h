//
//  BJLUser.h
//  BJLiveCore
//
//  Created by MingLQ on 2016-11-15.
//  Copyright © 2016 BaijiaYun. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "BJLConstants.h"

NS_ASSUME_NONNULL_BEGIN

/** 用户 */
@interface BJLUser : NSObject

@property (nonatomic, readonly) NSString *number, *name, *ID;
@property (nonatomic, readonly) NSInteger groupID;
@property (nonatomic, readonly, nullable) NSString *avatar;
@property (nonatomic, readonly) BJLUserRole role;
@property (nonatomic, readonly) BJLClientType clientType;
@property (nonatomic, readonly) BJLOnlineState onlineState;

/** !!!: 这里的老师、助教特指 groupID 为 0 的 */
@property (nonatomic, readonly) BOOL isTeacher, isAssistant, isStudent, isGuest;
@property (nonatomic, readonly) BOOL isGroupAssistant, isTeacherOrAssistant;

/** !!!: 这里的老师、助教特指 groupID 不为 0 的
 groupID 不为 0 的老师、助教的权限收到极大限制 —— 只能对其组内单个学生进行管理
 */
@property (nonatomic, readonly) BOOL isGroupTeacherOrAssistant;

@property (nonatomic, readonly) BOOL audioOn, videoOn DEPRECATED_MSG_ATTRIBUTE("#see BJLMediaUser");

- (BOOL)isSameUser:(__kindof BJLUser *)user;
- (BOOL)isSameUserWithID:(nullable NSString *)userID number:(nullable NSString *)userNumber;
- (BOOL)containedInUsers:(NSArray<__kindof BJLUser *> *)users;
/** 分组教室：是否为对象用户所在小组的 老师/助教 */
- (BOOL)isSameGroupTeacherOrAssistantWithUser:(BJLUser *)user;
/**「老师/助教」或「对象用户所在小组的 老师/助教」*/
- (BOOL)canManageUser:(BJLUser *)user;

/** 初始化 user */
+ (instancetype)userWithNumber:(NSString *)number
                          name:(NSString *)name
                       groupID:(NSInteger)groupID
                        avatar:(nullable NSString *)avatar
                          role:(BJLUserRole)role;
/**
 此方法没有传入 groupID，因此不 groupID 不参与签名计算
 */
+ (instancetype)userWithNumber:(NSString *)number
                          name:(NSString *)name
                        avatar:(nullable NSString *)avatar
                          role:(BJLUserRole)role DEPRECATED_MSG_ATTRIBUTE("use `userWithNumber:name:avatar:role:groupID:` instead");

@end

// @compatibility_alias BJLOnlineUser BJLUser;
DEPRECATED_MSG_ATTRIBUTE("use `BJLUser` instead")
@interface BJLOnlineUser : BJLUser
@end

#pragma mark -

@interface BJLMediaUser : BJLUser

@property (nonatomic, readonly) BOOL audioOn, videoOn;
// 参考 `BJLLiveDefinitionKey`、`BJLLiveDefinitionNameForKey()`
@property (nonatomic, readonly) NSArray<BJLLiveDefinitionKey> *definitions;

@end

NS_ASSUME_NONNULL_END
