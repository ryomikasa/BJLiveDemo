//
//  BJLPreviewCell.h
//  BJLiveUI
//
//  Created by MingLQ on 2017-06-05.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSString
* const BJLPreviewCellID_view, // PPT
* const BJLPreviewCellID_view_label, // video teacher, students, recording
* const BJLPreviewCellID_avatar_label, // audio teacher, students - hasVideo?
* const BJLPreviewCellID_avatar_label_buttons, // request students
* const BJLPreviewCellID_default;// 暂无 的标识
@interface BJLPreviewCell : UICollectionViewCell

@property (nonatomic, copy) void (^doubleTapsCallback)(BJLPreviewCell *cell);
@property (nonatomic, copy) void (^actionCallback)(BJLPreviewCell *cell, BOOL allowed);
@property (nonatomic, readonly, nullable) UIImageView *avatarView;
- (void)updateWithView:(UIView *)view;
- (void)updateLoadingViewHidden:(BOOL)hidden;
- (void)updateWithView:(UIView *)view title:(NSString *)title identity:(NSInteger)identity;
- (void)updateWithImageURLString:(NSString *)imageURLString title:(NSString *)title hasVideo:(BOOL)hasVideo identity:(NSInteger)identity;

+ (CGSize)cellSize;
+ (NSArray<NSString *> *)allCellIdentifiers;
//2018-10-17 15:45:37 mikasa 视频区域ctrl.view  大小挑中
+ (CGSize)previewctrlSelfviewSsize;
//2018-10-17 15:45:37 mikasa 视频区域ctrl.view  大小挑中

//2018-10-17 16:16:28 mikasa 视频区域cell view 新size 调整
+ (CGSize)mikiCellSize;
//2018-10-17 16:16:28 mikasa 视频区域cell view 新size 调整

+ (CGSize)cellSize2;

@end

NS_ASSUME_NONNULL_END
