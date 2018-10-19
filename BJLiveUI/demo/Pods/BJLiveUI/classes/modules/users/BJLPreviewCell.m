//
//  BJLPreviewCell.m
//  BJLiveUI
//
//  Created by MingLQ on 2017-06-05.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import "BJLPreviewCell.h"

#import "BJLViewImports.h"

NS_ASSUME_NONNULL_BEGIN

//static const CGFloat heightM = 75., heightL = 100.0;

static const CGFloat heightM = 55., heightL = 100.0;

NSString
* const BJLPreviewCellID_view = @"view",
* const BJLPreviewCellID_view_label = @"view+label",
* const BJLPreviewCellID_avatar_label = @"avatar+label",
* const BJLPreviewCellID_avatar_label_buttons = @"avatar+label+buttons";

@interface BJLPreviewCell ()

@property (nonatomic, nullable) UIView *customView;
@property (nonatomic, readonly, nullable) UIView *customCoverView;

@property (nonatomic, readonly, nullable) UIImageView *avatarView;
@property (nonatomic, readonly, nullable) UIImageView *cameraView;
@property (nonatomic, readonly, nullable) UIButton *nameView;

@property (nonatomic, readonly, nullable) UIView *actionGroupView;
@property (nonatomic, readonly, nullable) UILabel *messageLabel;
@property (nonatomic, readonly, nullable) UIButton *disallowButton, *allowButton;

@property (nonatomic, readonly, nullable) UIView *videoLoadingView;
@property (nonatomic, readonly, nullable) UIImageView *videoLoadingImageView;

@end

@implementation BJLPreviewCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        // self.contentView.backgroundColor = [UIColor bjl_grayImagePlaceholderColor];
        self.contentView.clipsToBounds = YES;
        
        bjl_weakify(self);
        [self bjl_kvo:BJLMakeProperty(self, reuseIdentifier)
               filter:^BOOL(id _Nullable old, id _Nullable now) {
                   // bjl_strongify(self);
                   return !!now;
               }
             observer:^BOOL(id _Nullable old, id _Nullable now) {
                 bjl_strongify(self);
                 [self makeSubviews];
                 [self makeConstraints];
                 [self prepareForReuse];
                 return NO;
             }];
    }
    return self;
}

- (void)makeSubviews {
    if ([self.reuseIdentifier isEqualToString:BJLPreviewCellID_view]) {
        self.contentView.backgroundColor = [UIColor whiteColor];
        self->_customCoverView = ({
            UIView *view = [UIView new];
            [view setTag:111];
            [self.contentView addSubview:view];
            view;
        });
    }
    
    if ([self.reuseIdentifier isEqualToString:BJLPreviewCellID_view_label]) {
//        2018-10-18 18:38:02 mikasa 视屏view
        self->_customCoverView = ({
            UIView *view = [UIView new];
            [view setTag:222];
            [self.contentView addSubview:view];
            view;
        });
        
        self->_videoLoadingView = ({
            UIView *view = [UIView new];
            [view setTag:333];
            view.backgroundColor = [UIColor bjl_colorWithHexString:@"4A4A4A"];
            view.hidden = YES;
            [self.contentView addSubview:view];
            view;
        });
        
        self->_videoLoadingImageView = ({
            UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bjl_ic_user_loading"]];
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            [imageView setTag:444];
            [self.videoLoadingView addSubview:imageView];
            imageView;
        });
    }
    
    if ([self.reuseIdentifier isEqualToString:BJLPreviewCellID_avatar_label]
        || [self.reuseIdentifier isEqualToString:BJLPreviewCellID_avatar_label_buttons]) {
        self->_avatarView = ({
            UIImageView *imageView = [UIImageView new];
            [imageView setTag:555];
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            [self.contentView addSubview:imageView];
            imageView;
        });
    }
    
    if ([self.reuseIdentifier isEqualToString:BJLPreviewCellID_avatar_label]) {
        self->_cameraView = ({
            UIImageView *imageView = [UIImageView new];
            [imageView setTag:666];
            imageView.image = [UIImage imageNamed:@"bjl_ic_video_on"];
            [self.contentView addSubview:imageView];
            imageView;
        });
    }
    
    if ([self.reuseIdentifier isEqualToString:BJLPreviewCellID_view_label]
        || [self.reuseIdentifier isEqualToString:BJLPreviewCellID_avatar_label]) {
        self->_nameView = ({
            UIButton *button = [BJLImageRightButton new];
            [button setTag:777];
            button.titleLabel.font = [UIFont systemFontOfSize:13.0];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            // [button setImage:[[UIImage imageNamed:@"bjl_ic_video_on"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] forState:UIControlStateSelected];
            [button setBackgroundImage:[UIImage imageNamed:@"bjl_bg_name"] forState:UIControlStateNormal];
            button.tintColor = [UIColor whiteColor];
            [self.contentView addSubview:button];
            button;
        });
    }
    
    if ([self.reuseIdentifier isEqualToString:BJLPreviewCellID_avatar_label_buttons]) {
        self->_actionGroupView = ({
            UIView *view = [UIView new];
            [view setTag:888];
            view.backgroundColor = [UIColor bjl_darkDimColor];
            [self.contentView addSubview:view];
            view;
        });
        
        self->_messageLabel = ({
            UILabel *label = [UILabel new];
            [label setTag:999];
            label.textAlignment = NSTextAlignmentCenter;
            label.font = [UIFont systemFontOfSize:12.0];
            label.textColor = [UIColor whiteColor];
            label.backgroundColor = [UIColor clearColor];
            label.numberOfLines = 2;
            label.lineBreakMode = NSLineBreakByTruncatingMiddle;
            [self.actionGroupView addSubview:label];
            label;
        });
        
        self->_disallowButton = ({
            UIButton *button = [UIButton new];
            [button setTitle:@"拒绝" forState:UIControlStateNormal];
            [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont systemFontOfSize:14.0];
            [self.actionGroupView addSubview:button];
            button;
        });
        
        self->_allowButton = ({
            UIButton *button = [UIButton new];
            [button setTitle:@"同意" forState:UIControlStateNormal];
            [button setTitleColor:[UIColor bjl_blueBrandColor] forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont systemFontOfSize:14.0];
            [self.actionGroupView addSubview:button];
            button;
        });
        
        bjl_weakify(self);
        [self.disallowButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
            bjl_strongify(self);
            if (self.actionCallback) self.actionCallback(self, NO);
        } forControlEvents:UIControlEventTouchUpInside];
        [self.allowButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
            bjl_strongify(self);
            if (self.actionCallback) self.actionCallback(self, YES);
        } forControlEvents:UIControlEventTouchUpInside];
    }
    
    bjl_weakify(self);
    [self.contentView addGestureRecognizer:({
        UITapGestureRecognizer *tap = [UITapGestureRecognizer bjl_gestureWithHandler:^(__kindof UIGestureRecognizer * _Nullable gesture) {
            bjl_strongify(self);
            if (self.doubleTapsCallback) self.doubleTapsCallback(self);
        }];
        tap.numberOfTapsRequired = 2;
        tap.numberOfTouchesRequired = 1;
        tap.delaysTouchesBegan = YES;
        tap;
    })];
}

- (void)makeConstraints {
    if (self.customCoverView) {
        [self.customCoverView mas_makeConstraints:^(MASConstraintMaker *make) {
//            make.edges.equalTo(self.contentView);
            make.edges.centerX.equalTo(self.contentView);
//            make.edges.bottom.equalTo(self.contentView).bottom.inset(30.);
            make.edges.top.equalTo(self.contentView);
            make.size.mas_equalTo(CGSizeMake(([UIScreen mainScreen].bounds.size.width - 16*5)/4, ([UIScreen mainScreen].bounds.size.width - 16*5)/4*3/4));
        }];
    }
    
    if (self.avatarView) {
        [self.avatarView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.contentView);
        }];
    }
    
    if (self.cameraView) {
        [self.cameraView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.top.equalTo(self.contentView);
        }];
    }
    
    if (self.nameView) {
        [self.nameView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.bottom.equalTo(self.contentView);
            make.height.equalTo(@18.0);
        }];
    }
    
    if (self.actionGroupView) {
        [self.actionGroupView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.contentView);
        }];
        [self.messageLabel mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(self.actionGroupView).with.inset(BJLViewSpaceS);
            // label 底边到 actionGroupView 底边的距离是 actionGroupView 高度的 1/2
            make.bottom.equalTo(self.actionGroupView).multipliedBy(1.0 / 2);
        }];
        [self.disallowButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.equalTo(self.actionGroupView).with.inset(BJLViewSpaceL);
            make.bottom.equalTo(self.actionGroupView).with.inset(BJLViewSpaceS);
        }];
        [self.allowButton mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(self.actionGroupView).with.inset(BJLViewSpaceL);
            make.bottom.equalTo(self.actionGroupView).with.inset(BJLViewSpaceS);
        }];
    }
    
    if (self.videoLoadingView) {
        [self.videoLoadingView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.contentView);
        }];
    }
    
    if (self.videoLoadingImageView) {
        [self.videoLoadingImageView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.height.width.equalTo(@40.0);
            make.center.equalTo(self.videoLoadingView);
        }];
    }
}

- (void)prepareForReuse {
    [super prepareForReuse];
    
    if (self.customView.superview == self.contentView) {
        [self.customView removeFromSuperview];
    }
    self.customView = nil;
    
    // [self.avatarView sd_setImageWithURL:nil]; // cancel image loading
    [self.avatarView bjl_cancelCurrentImageLoading];
    self.avatarView.image = nil;
    
    [self.nameView setTitle:nil forState:UIControlStateNormal];
    // self.nameView.selected = NO;
    self.cameraView.hidden = YES;
    
    self.messageLabel.text = nil;
}

- (void)updateWithView:(UIView *)view {
    self.customView = view;
    if (view) {
        [self.contentView insertSubview:view atIndex:0];
        [view mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.contentView);
        }];
    }
}

- (void)updateLoadingViewHidden:(BOOL)hidden {
    if (!self.videoLoadingView) {
        return;
    }
    self.videoLoadingView.hidden = hidden;
    if (!self.videoLoadingView.hidden && !self.videoLoadingImageView.isAnimating) {
        // 显示旋转动画
        [self.videoLoadingView.layer removeAllAnimations];
        [self startAnimation:0];
    }
}

- (void)startAnimation:(CGFloat)angle {
    __block float nextAngle = angle + 10;
    CGAffineTransform endAngle = CGAffineTransformMakeRotation(angle * (M_PI / 180.0f));
    [UIView animateWithDuration:0.02 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.videoLoadingImageView.transform = endAngle;
    } completion:^(BOOL finished) {
        if (!self.videoLoadingView.hidden && finished) {
            [self startAnimation:nextAngle];
        }
    }];
}

- (void)updateWithView:(UIView *)view title:(NSString *)title {
    [self updateWithView:view];
    [self.nameView setTitle:title forState:UIControlStateNormal];
}

- (void)updateWithImageURLString:(NSString *)imageURLString title:(NSString *)title hasVideo:(BOOL)hasVideo {
    [self.avatarView bjl_setImageWithURL:[NSURL URLWithString:imageURLString]
                             placeholder:[UIImage bjl_imageWithColor:[UIColor bjl_grayImagePlaceholderColor]]
                              completion:nil];
    if (self.nameView) {
        [self.nameView setTitle:title forState:UIControlStateNormal];
        // self.nameView.selected = hasVideo;
        self.cameraView.hidden = !hasVideo;
    }
    else {
        self.messageLabel.text = title;
    }
}

+ (CGSize)cellSize {
//    static BOOL iPad = NO;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        iPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
//    });
//
//    CGFloat height = iPad ? heightL : heightM;
    return CGSizeMake(([UIScreen mainScreen].bounds.size.width - 16*5)/4, ([UIScreen mainScreen].bounds.size.width - 16*5)/4*3/4);
}

//2018-10-17 15:44:12  mikasa 修改视频区域大小

+ (CGSize)previewctrlSelfviewSsize {
    CGFloat height = heightM+30.+40.;
    return CGSizeMake([UIScreen mainScreen].bounds.size.width , height);
}
//2018-10-17 15:44:12  mikasa 修改视频区域大小

//2018-10-17 16:16:28 mikasa 视频区域cell view 新size 调整
+ (CGSize)mikiCellSize{
//    CGFloat height = heightN;
    
    return CGSizeMake(([UIScreen mainScreen].bounds.size.width - 16*5)/4, heightM+30);
}
//2018-10-17 16:16:28 mikasa 视频区域cell view 新size 调整



+ (NSArray<NSString *> *)allCellIdentifiers {
    return @[BJLPreviewCellID_view,
             BJLPreviewCellID_view_label,
             BJLPreviewCellID_avatar_label,
             BJLPreviewCellID_avatar_label_buttons];
}

@end

NS_ASSUME_NONNULL_END
