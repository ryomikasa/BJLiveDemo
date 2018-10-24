//
//  BJLRoomViewController+constraints.m
//  BJLiveUI
//
//  Created by MingLQ on 2017-05-18.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import "BJLRoomViewController+protected.h"

NS_ASSUME_NONNULL_BEGIN

static const CGFloat chatViewWidth = 260.0;

@implementation BJLRoomViewController (constraints)

- (void)updateConstraintsForHorizontal:(BOOL)isHorizontal {
    self.chatViewController.alphaMin = isHorizontal ? 0.2 : 0.8;
    
    // degbug
    MASAttachKeys(self.view,
                  self.topBarView,
                  self.previewsViewController.view,
                  self.contentView,
                  self.controlsViewController.view,
                  self.chatViewController.view,
                  self.recordingStateView,
                  self.overlayViewController.view,
                  self.loadingViewController.view,
                  self.videoLoadingView,
                  self.videoLoadingImageView);
    
    // clean all constraints at first to fix warnings
    [@[// !!!: NO self.view
       self.topBarView,
       self.previewsViewController.view,
       self.contentView,
       self.backgroundView,
       self.controlsViewController.view,
       self.chatViewController.view,
       self.recordingStateView,
       self.overlayViewController.view,
       self.loadingViewController.view,
       self.videoLoadingImageView]
     mas_remakeConstraints:^(MASConstraintMaker *make) {}];
    
    CGFloat statusBarHeight = CGRectGetHeight([UIApplication sharedApplication].statusBarFrame);
    [self.topBarView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view);
        make.height.equalTo(@(statusBarHeight));
        make.left.right.equalTo(self.controlsViewController.view);
    }];
    [self updateStatusBarAndTopBar];
    
    [self updatePreviewsAndContentConstraintsForHorizontal:isHorizontal];
    
    [self.backgroundView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.contentView.mas_bottom);
        make.left.right.bottom.equalTo(self.view);
    }];
    
    [self updateControlsConstraintsForHorizontal:isHorizontal];
    
    [self.recordingStateView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView.bjl_safeAreaLayoutGuide ?: self.contentView).with.offset(- BJLViewSpaceM);
        // TODO: 对其到画笔清除按钮
        CGFloat offset = - BJLViewSpaceM - (BJLButtonSizeM - BJLButtonSizeS) / 2;
        make.bottom.equalTo(self.contentView).with.offset(offset);
    }];
    [self updateRecordingStateViewForHorizontal:isHorizontal];
    
    [self.overlayViewController.view mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self.loadingViewController.view mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self.videoLoadingView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.contentView);
    }];
    
    [self.videoLoadingImageView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.height.width.equalTo(@80.0);
        make.center.equalTo(self.videoLoadingView);
    }];
}

- (void)updateStatusBarAndTopBar {
    [self setNeedsStatusBarAppearanceUpdate];
    self.topBarView.hidden = self.controlsHidden;
    self.topBarView.backgroundView.hidden = [UIApplication sharedApplication].statusBarHidden;
}

- (void)updateRecordingStateViewForHorizontal:(BOOL)isHorizontal {
    self.recordingStateView.hidden = (!self.room.loginUser.isTeacher
                                      || !self.room.serverRecordingVM.serverRecording
                                      || (isHorizontal && !(self.controlsHidden || self.room.slideshowViewController.drawingEnabled)));
}

- (void)updatePreviewsAndContentConstraintsForHorizontal:(BOOL)isHorizontal {
    UIEdgeInsets insets = [self safeAreaInsetsForHorizontal:isHorizontal];
    
    BOOL showBackgroundView = (self.previewsViewController.numberOfItems > 0
                               && (!isHorizontal || self.previewsViewController.numberOfItems > 2)
                               && !self.previewBackgroundImageHidden);
    self.previewsViewController.backgroundView.hidden = !showBackgroundView;
    
    [self.previewsViewController.view mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.right.equalTo(self.view);
        make.top.equalTo(isHorizontal ? self.view : self.contentView.mas_bottom);
        [self.previewsViewController makeContentSize:make forHorizontal:isHorizontal];
    }];
    
    [self.contentView mas_remakeConstraints:^(MASConstraintMaker *make) {
        if (isHorizontal) {
            make.top.left.right.bottom.equalTo(self.view).insets(insets);

          
        }
        else {
            make.left.right.top.equalTo(self.view).insets(UIEdgeInsetsMake(20.0, 44.0, 0.0, 44.0));
            // !!!: .priorityHigh() - fix warnings during ver to hor
            make.height.equalTo(self.contentView.mas_width).multipliedBy(3.0 / 4).priorityHigh();
        }
    }];
    
    [self updateChatConstraintsForHorizontal:isHorizontal];
}

- (void)updateControlsConstraintsForHorizontal:(BOOL)isHorizontal {
    UIEdgeInsets insets = [self safeAreaInsetsForHorizontal:isHorizontal];
    
    [self.controlsViewController.view mas_remakeConstraints:^(MASConstraintMaker *make) {
        // !!!: .priorityHigh() - fix warnings during ver to hor
        make.top.equalTo(self.previewsViewController.view.mas_bottom).priorityHigh();
        if (isHorizontal) {
            MASConstraint *xAxisAnchor = (self.controlsHidden ? make.right : make.left);
            xAxisAnchor.equalTo(self.view.mas_left).with.offset(self.controlsHidden ? 0.0 : insets.left); // maybe update
            make.top.bottom.equalTo(self.view).insets(insets);
            // !!!: 为了可以水平拖动，这里是 width 而不是 right
            make.width.equalTo(self.view).sizeOffset(CGSizeMake(- (insets.left + insets.right), 0.0));
        }
        else {
            make.left.right.bottom.equalTo(self.view).insets(insets);
        }
    }];
//    2018-10-24 10:15:42 mikasa 大范围点击隐藏底部工具条时 展开按钮是否隐藏判定联动
    if (self.controlsHidden == YES) {
        [self.showB setHidden:YES];
    }else{
        [self.showB setHidden:!self.chatHidden];
    }
//    2018-10-24 10:15:42 mikasa 大范围点击隐藏底部工具条时 展开按钮是否隐藏判定联动
}

- (void)updateChatConstraintsForHorizontal:(BOOL)isHorizontal {
    [self.chatViewController.view mas_remakeConstraints:^(MASConstraintMaker *make) {
        MASConstraint *horAlignment;
        CGFloat leftOffset = 0.0;
        if (isHorizontal) {
            if (self.chatHidden) {
                horAlignment = make.right;
                // !!!: 补正 iPhoneX 安全区域的水平位置偏移
                leftOffset = -self.controlsViewController.view.frame.origin.x;
            }
            else {
                horAlignment = make.left;
            }
        }
        else {
            horAlignment = make.left;
        }
        horAlignment.equalTo(self.controlsViewController.view.mas_left).with.offset(leftOffset); // maybe update
        make.right.lessThanOrEqualTo(self.controlsViewController.rightLayoutGuide).with.offset(- BJLViewSpaceM).priorityHigh();
        make.top.equalTo(self.previewsViewController.view.mas_bottom);
        make.bottom.equalTo(self.controlsViewController.bottomLayoutGuide);
        make.width.equalTo(@(chatViewWidth));
    }];
    
    self.chatViewController.view.hidden = isHorizontal && self.room.slideshowViewController.drawingEnabled;
//    2018-10-24 10:16:27 mikasa 展开按钮是否显示隐藏判定
    [self.showB setHidden:!self.chatHidden];
//    2018-10-24 10:16:27 mikasa 展开按钮是否显示隐藏判定
}

- (UIEdgeInsets)safeAreaInsetsForHorizontal:(BOOL)isHorizontal {
    UIEdgeInsets insets = UIEdgeInsetsZero;
    if (@available(iOS 11.0, *)) {
        if (bjl_iPhoneX()) {
            insets = self.view.safeAreaInsets;
            
            // fix bug: safeAreaInsets maybe incorrect - https://stackoverflow.com/questions/47032855/safeareainsets-in-uiview-is-0-on-an-iphone-x
            if (UIEdgeInsetsEqualToEdgeInsets(insets, UIEdgeInsetsZero)) {
                // [self.view layoutIfNeeded]; // 这个货有副作用，导致横屏切竖屏时聊天内容只显示名字
                insets = (isHorizontal
                          ? UIEdgeInsetsMake(0.0, 44.0, 21.0, 44.0)
                          : UIEdgeInsetsMake(44.0, 0.0, 34.0, 0.0));
            }
            
            if (isHorizontal) {
                // 内容紧贴屏幕上下边缘
                insets.top = insets.bottom = 0.0;
                // 内容紧贴左边/右边刘海
                insets.left = MAX(0.0, insets.left - BJLiPhoneXInsetsAdjustment);
                insets.right = MAX(0.0, insets.right - BJLiPhoneXInsetsAdjustment);
            }
        }
    }
    return insets;
}

@end

NS_ASSUME_NONNULL_END
