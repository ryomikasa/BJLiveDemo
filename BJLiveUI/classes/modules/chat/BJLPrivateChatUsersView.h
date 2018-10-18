//
//  BJLPrivateChatUsersView.h 私聊用户列表视图
//  BJLiveUI
//
//  Created by HuangJie on 2018/1/2.
//  Copyright © 2018年 BaijiaYun. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "BJLViewImports.h"

NS_ASSUME_NONNULL_BEGIN

@interface BJLPrivateChatUsersView : UIView <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, copy) void (^startPrivateChatCallback)(BJLUser *targetUser);
@property (nonatomic, copy) void (^cancelPrivateChatCallback)(void);

- (instancetype)initWithRoom:(BJLRoom *)room;

- (void)updateChatStatus:(BJLChatStatus)chatStatus withTargetUser:(nullable BJLUser *)targetUser;

NS_ASSUME_NONNULL_END
@end
