//
//  BJLPlayingVM.h
//  BJLiveCore
//
//  Created by MingLQ on 2016-12-16.
//  Copyright © 2016 BaijiaYun. All rights reserved.
//

#import "BJLBaseVM.h"

#import "BJLUser.h"

NS_ASSUME_NONNULL_BEGIN

/** ### 音视频播放 */
@interface BJLPlayingVM : BJLBaseVM

/** 音视频用户列表
 #discussion 包含 `videoPlayingUser`
 #discussion 所有用户的音频会自动播放，视频需要调用 `updatePlayingUserWithID:videoOn:` 打开或者通过 `videoPlayingBlock` 控制打开
 #discussion SDK 会处理音视频打断、恢复、前后台切换等情况
 */
@property (nonatomic, readonly, copy, nullable) NSArray<BJLMediaUser *> *playingUsers;
/** 从 `playingUsers` 查找用户
 #param userID 用户 ID
 #param userNumber 用户编号
 */
- (nullable __kindof BJLMediaUser *)playingUserWithID:(nullable NSString *)userID
                                               number:(nullable NSString *)userNumber;

/** 用户开关音、视频
 #discussion - 某个用户主动开关自己的音视频、切换清晰度时发送此通知，但不包含意外掉线等情况
 #discussion - 正在播放的视频用户 关闭视频时 `videoPlayingUser` 将被设置为 nil、同时发送此通知
 #discussion - 进教室后批量更新 `playingUsers` 时『不』发送此通知
 #discussion - 音视频开关状态通过 `BJLMediaUser` 的 `audioOn`、`videoOn` 获得
 #discussion - definitionIndex 可能会发生变化，调用 `definitionIndexForUserWithID:` 可获取最新的取值
 #param now 新用户信息
 #param old 旧用户信息
 TODO: 增加方法支持同时监听初始音视频状态
 */
- (BJLObservable)playingUserDidUpdate:(nullable BJLMediaUser *)now
                                  old:(nullable BJLMediaUser *)old;
/** 用户开改变视频清晰度
 #param now 新用户信息
 #param old 旧用户信息
 */
- (BJLObservable)playingUserDidUpdateVideoDefinitions:(nullable BJLMediaUser *)now
                                                  old:(nullable BJLMediaUser *)old;
/** 老师在 PC 上更改共享桌面设置
 #param user            老师
 #param desktopSharing  开启/关闭桌面共享
 */
- (BJLObservable)playingUser:(BJLMediaUser *)user didUpdateDesktopSharing:(BOOL)desktopSharing;
/** 老师在 PC 上更改媒体文件播放状态
 #param user            老师
 #param mediaPlaying  播放/停止播放媒体文件
 */
- (BJLObservable)playingUser:(BJLMediaUser *)user didUpdateMediaPlaying:(BOOL)mediaPlaying;

/** `playingUsers` 被覆盖更新
 #discussion 进教室后批量更新才调用，增量更新不调用
 #param playingUsers 音视频用户列表
 TODO: 改进此方法，使之与监听 playingUsers 区别更小
 */
- (BJLObservable)playingUsersDidOverwrite:(nullable NSArray<BJLMediaUser *> *)playingUsers;

/** 将要播放视频
 #discussion 播放或者关闭视频的方法被成功调用
 #param playingUser 将要播放视频用户
 */
- (BJLObservable)playingUserDidStartLoadingVideo:(nullable BJLMediaUser *)playingUser;
/** 播放成功
 #discussion 用户视频开启或者关闭成功
 #param playingUser 播放视频的用户
 */
- (BJLObservable)playingUserDidFinishLoadingVideo:(nullable BJLMediaUser *)playingUser;

#pragma mark -

/** 正在播放的视频用户
 #discussion `playingUsers` 的子集
 #discussion 断开重连、暂停恢复等操作不自动重置 `videoPlayingUsers`，除非对方用户掉线、离线等 */
@property (nonatomic, readonly, copy, nullable) NSArray<BJLMediaUser *> *videoPlayingUsers;
/** 从 `videoPlayingUsers` 查找用户
 #param userID 用户 ID
 #param userNumber 用户编号
 */
- (nullable __kindof BJLMediaUser *)videoPlayingUserWithID:(nullable NSString *)userID
                                                    number:(nullable NSString *)userNumber;

/** 自动播放视频回调
 #discussion 其他用户视频可用时调用，返回 YES 表示自动播放视频，不设置此 block 不会自动播放
 */
@property (nonatomic, copy, nullable) BOOL (^videoPlayingBlock)(BJLMediaUser *user);
/** 自动播放视频并指定清晰度回调
 #discussion 传入参数 user 和 cachedDefinitionIndex 分别为 用户 和 上次播放该用户视频时使用的清晰度
 #discussion 返回结果 autoPlay 和 definitionIndex 分别为 是否自动播放视频 和 播放视频使用的视频清晰度，例如
 |  self.room.playingVM.autoPlayVideoBlock = ^BJLTupleType(BOOL autoPlay, NSInteger definitionIndex)(BJLMediaUser *user, NSInteger cachedDefinitionIndex) {
 |      BOOL autoPlay = user.number && ![self.autoPlayVideoBlacklist containsObject:user.number];
 |      NSInteger definitionIndex = cachedDefinitionIndex;
 |      if (autoPlay) {
 |          NSInteger maxDefinitionIndex = MAX(0, (NSInteger)user.definitions.count - 1);
 |          definitionIndex = (cachedDefinitionIndex <= maxDefinitionIndex
 |                             ? cachedDefinitionIndex : maxDefinitionIndex);
 |      }
 |      return BJLTuplePack((BOOL, NSInteger), autoPlay, definitionIndex);
 |  };
 */
@property (nonatomic, copy, nullable)
    BJLTupleType(BOOL autoPlay, NSInteger definitionIndex)
    (^autoPlayVideoBlock)(BJLMediaUser *user, NSInteger cachedDefinitionIndex);

/** 设置播放用户的视频
 #param userID 用户 ID
 #param videoOn YES：打开视频，NO：关闭视频
 #param definitionIndex `BJLMediaUser` 的 `definitions` 属性的 index，参考 `BJLLiveDefinitionKey`、`BJLLiveDefinitionNameForKey()`
 #return BJLError:
 BJLErrorCode_invalidArguments  错误参数，如 `playingUsers` 中不存在此用户；
 BJLErrorCode_invalidCalling    错误调用，如用户视频已经在播放、或用户没有开启摄像头。
 */
- (nullable BJLError *)updatePlayingUserWithID:(NSString *)userID
                                       videoOn:(BOOL)videoOn;
- (nullable BJLError *)updatePlayingUserWithID:(NSString *)userID
                                       videoOn:(BOOL)videoOn
                               definitionIndex:(NSInteger)definitionIndex;


/** 获取播放用户的清晰度
 #param userID 用户 ID
 #return 播放时传入的 `definitionIndex`
 */
- (NSInteger)definitionIndexForUserWithID:(NSString *)userID;

/** 获取播放用户的视频视图
 #param userID 用户 ID
 */
- (nullable UIView *)playingViewForUserWithID:(NSString *)userID;

/** 获取播放用户的视频视图宽高比
 #param userID 用户 ID
 */
- (CGFloat)playingViewAspectRatioForUserWithID:(NSString *)userID;

/** 用户视频宽高比发生变化的通知
 #param videoAspectRatio 视频宽高比
 #param userID 用户 ID
 */
- (BJLObservable)playingViewAspectRatioChanged:(CGFloat)videoAspectRatio
                                 forUserWithID:(NSString *)userID;

/** 重新开始播放视频 */
- (void)restartPlaying;

#pragma mark - DEPRECATED

- (nullable __kindof BJLMediaUser *)userWithID:(nullable NSString *)userID
                                        number:(nullable NSString *)userNumber DEPRECATED_MSG_ATTRIBUTE("use `playingUserWithID:number:` instead");

/** 用户希望被全屏显示
 #discussion 比如在 PC 上共享桌面、播放本地视频
 #discussion 目前只支持老师（不支持主讲）
 #param user 对象用户
 */
- (BJLObservable)playingUserWantsShowInFullScreen:(BJLMediaUser *)user DEPRECATED_MSG_ATTRIBUTE("use `playingUser:didUpdateDesktopSharing:` or `playingUser:didUpdateMediaPlaying:` instead");

@end

NS_ASSUME_NONNULL_END
