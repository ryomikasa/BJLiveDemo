//
//  BJLSlideshowUI.h
//  BJLiveCore
//
//  Created by MingLQ on 2016-12-19.
//  Copyright © 2016 BaijiaYun. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol BJLSlideshowUI <NSObject>

/** 静态课件显示模式
 只支持 BJLContentMode_scaleAspectFit, BJLContentMode_scaleAspectFill
 只对静态课件生效，参考 `BJLRoom` 的 `disablePPTAnimation`
 */
@property (nonatomic) BJLContentMode contentMode;
/** 静态课件尺寸
 加载课件图片时对图片做等比缩放，长边小于/等于 `imageSize`，放大时加载 1.5 倍尺寸的图片
 单位为像素，默认初始加载 720、放大加载 1080，取值在 `BJLAliIMGMinSize` 到 `BJLAliIMGMaxSize` 之间 (1 ~ 4096)
 不建议进教室成功后设置此参数，因为会导致已经加载过的图片缓存失效
 只对静态课件生效，参考 `BJLRoom` 的 `disablePPTAnimation`
 */
@property (nonatomic) NSInteger imageSize;

/** 静态课件占位图
 只对静态课件生效，参考 `BJLRoom` 的 `disablePPTAnimation`
 */
@property (nonatomic) UIImage *placeholderImage;
/** 动画课件翻页指示图标
 只对动画课件，参考 `BJLRoom` 的 `disablePPTAnimation`
 */
@property (nonatomic) UIImage *prevPageIndicatorImage, *nextPageIndicatorImage;
/** 页面控制按钮 */
@property (nonatomic) UIButton *pageControlButton;

/** 学生本地翻页是否可以超过教室内的页数 */
@property (nonatomic) BOOL studentCanPreviewForward DEPRECATED_MSG_ATTRIBUTE("will be removed since BJLiveCore 2.0");
/** 学生本地翻页是否可以同步到教室内的页数
 设置为 YES 时忽略 `studentCanPreviewForward` 的值、当 YES 处理 */
@property (nonatomic) BOOL studentCanRemoteControl DEPRECATED_MSG_ATTRIBUTE("will be removed since BJLiveCore 2.0");

/** 本地当前页、可能与教室内的页数不同
 参考 `BJLSlideshowVM` 的 `currentSlidePage.documentPageIndex` */
@property (nonatomic) NSInteger localPageIndex;
/** 是否空白
 只有一页白板、并且没有画笔 */
@property (nonatomic, readonly) BOOL isBlank DEPRECATED_MSG_ATTRIBUTE("always return NO, will be removed since BJLiveCore 2.0");

/** 学生是否被授权使用画笔 */
@property (nonatomic, readonly) BOOL drawingGranted;

/**
 画笔开关状态
 参考 `drawingGranted`、`updateDrawingEnabled:`
 */
@property (nonatomic, readonly) BOOL drawingEnabled;
/** 开启、关闭画笔
 开启画笔时，如果本地页数与服务端页数不同步则无法绘制
 `drawingGranted` 是 YES 时才可以开启，`drawingGranted` 是 NO 时会被自动关闭
 #param drawingEnabled YES：开启，NO：关闭
 #return BJLError:
 BJLErrorCode_invalidCalling    错误调用，当前用户是学生、`drawingGranted` 是 NO
 */
- (nullable BJLError *)updateDrawingEnabled:(BOOL)drawingEnabled;
- (void)setDrawingEnabled:(BOOL)drawingEnabled DEPRECATED_MSG_ATTRIBUTE("use `updateDrawingEnabled:` instead");

/** 清除白板 */
- (void)clearDrawing;

/** 尝试刷新课件
 课件长时间无法加载时调用此方法尝试刷新
 只对动画课件，参考 `BJLRoom` 的 `disablePPTAnimation`
 */
- (void)tryToReload;

#pragma mark - UNSTABLE

/** 老师、助教: 所有被授权使用画笔的学生 */
@property (nonatomic, readonly, copy) NSArray *drawingGrantedUserNumbers __APPLE_API_UNSTABLE;

/** 老师、助教: 给学生授权/取消画笔
 #param granted     是否授权
 #param userNumber  要操作的用户
 #return BJLError:
 BJLErrorCode_invalidUserRole   当前用户不是老师或者助教
 BJLErrorCode_invalidArguments  参数错误
 */
- (nullable BJLError *)updateDrawingGranted:(BOOL)granted userNumber:(NSString *)userNumber __APPLE_API_UNSTABLE;

@end

NS_ASSUME_NONNULL_END
