//
//  BJLContentView.m
//  BJLiveUI
//
//  Created by MingLQ on 2017-02-22.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import "BJLContentView.h"

#import "BJLViewImports.h"



@interface BJLContentView ()

@property (nonatomic, readwrite, nullable) UIView *content;
@property (nonatomic) UIButton *clearDrawingButton;

// 记录上一次取值，如果 update 时一样则不重新 layout
@property (nonatomic, readwrite) BJLContentMode contentMode;
@property (nonatomic, readwrite) CGFloat aspectRatio;

@end

@implementation BJLContentView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor bjl_grayImagePlaceholderColor];
//2018-10-19 18:14:35 mikasa 禁用展示白板区域 +禁用展示PPT区域 学生点击手势
        [self setUserInteractionEnabled:NO];
//2018-10-19 18:14:35 mikasa 禁用展示白板区域 +禁用展示PPT区域 学生点击手势
        [self makeSubviews];
        
        
        bjl_weakify(self);
        [self addGestureRecognizer:[UITapGestureRecognizer bjl_gestureWithHandler:^(__kindof UIGestureRecognizer * _Nullable gesture) {
            bjl_strongify(self);
            if (self.toggleTopBarCallback) self.toggleTopBarCallback(nil);
        }]];
        [self addGestureRecognizer:[UILongPressGestureRecognizer bjl_gestureWithHandler:^(__kindof UIGestureRecognizer * _Nullable gesture) {
            bjl_strongify(self);
            if (self.showMenuCallback) self.showMenuCallback(nil);
        }]];
    }
    return self;
}

- (void)makeSubviews {
    bjl_weakify(self);
    
    self.clearDrawingButton = ({
        BJLButton *button = [BJLButton new];
        [button setImage:[UIImage imageNamed:@"bjl_ic_clearall"] forState:UIControlStateNormal];
        [button setTitle:@"清除" forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:15.0];
        // !!!: should be same to `BJLRoomViewController.pageControlButton.backgroundColor`
        button.backgroundColor = [UIColor bjl_dimColor];
        button.layer.cornerRadius = BJLButtonSizeM / 2;
        button.layer.masksToBounds = YES;
        button.midSpace = BJLViewSpaceS;
        [self addSubview:button];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self).with.offset(BJLViewSpaceM);
            make.width.equalTo(@(BJLButtonSizeM * 2 + BJLViewSpaceM));
            make.bottom.equalTo(self).with.offset(- BJLViewSpaceM);
            make.height.equalTo(@(BJLButtonSizeM));
        }];
        button;
    });
    [self bjl_kvo:BJLMakeProperty(self, showsClearDrawingButton)
         observer:^BOOL(id _Nullable old, id _Nullable now) {
             bjl_strongify(self);
             self.clearDrawingButton.hidden = !self.showsClearDrawingButton;
             return YES;
         }];
    [self.clearDrawingButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        if (self.clearDrawingCallback) self.clearDrawingCallback(self);
    } forControlEvents:UIControlEventTouchUpInside];
}

#pragma mark -

// KVO-setter
- (void)setContent:(nullable UIView *)content {
    if (content == self.content) {
        return;
    }
    
    if (self.content.superview == self) {
        [self.content removeFromSuperview];
    }
    
    self->_content = content;
    if (content) {
        [self insertSubview:content atIndex:0];
    }
}

/*
- (void (^)(void))animateUpdateContent:(UIView *)content
                           contentMode:(BJLContentMode)contentMode
                           aspectRatio:(CGFloat)aspectRatio {
    [self layoutContent:content contentMode:contentMode aspectRatio:aspectRatio];
    return ^{
        [self updateContent:content contentMode:contentMode aspectRatio:aspectRatio];
    };
} // */

- (void)updateContent:(UIView *)content
          contentMode:(BJLContentMode)contentMode
          aspectRatio:(CGFloat)aspectRatio {
    if (content == self.content
        && contentMode == self.contentMode
        && aspectRatio == self.aspectRatio) {
        return;
    }
    self.content = content;
    self.contentMode = contentMode;
    self.aspectRatio = aspectRatio;
    
    [self layoutContent:self.content contentMode:contentMode aspectRatio:aspectRatio];
}

- (void)updateWithContentMode:(BJLContentMode)contentMode
                  aspectRatio:(CGFloat)aspectRatio {
    if (contentMode == self.contentMode
        && aspectRatio == self.aspectRatio) {
        return;
    }
    self.contentMode = contentMode;
    self.aspectRatio = aspectRatio;
    
    [self layoutContent:self.content contentMode:contentMode aspectRatio:aspectRatio];
}

- (void)removeContent {
    self.content = nil;
}

- (void)layoutContent:(UIView *)content
          contentMode:(BJLContentMode)contentMode
          aspectRatio:(CGFloat)aspectRatio {
    [content mas_remakeConstraints:^(MASConstraintMaker *make) {
        if (contentMode == BJLContentMode_scaleToFill) {
            make.edges.equalTo(self);
        }
        else {
            make.center.equalTo(self);
            make.edges.equalTo(self).priorityHigh();
            make.width.equalTo(content.mas_height).multipliedBy(aspectRatio);
            if (contentMode == BJLContentMode_scaleAspectFit) {
                make.width.height.lessThanOrEqualTo(self);
            }
            else { // contentMode == BJLContentMode_scaleAspectFill
                make.width.height.greaterThanOrEqualTo(self);
            }
        }
    }];
}




@end

