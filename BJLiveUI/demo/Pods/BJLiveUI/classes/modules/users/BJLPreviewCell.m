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

static const CGFloat heightM = 103.0, heightL = 100.0;

NSString
* const BJLPreviewCellID_view = @"view",
* const BJLPreviewCellID_view_label = @"view+label",
* const BJLPreviewCellID_avatar_label = @"avatar+label",
* const BJLPreviewCellID_avatar_label_buttons = @"avatar+label+buttons",
* const BJLPreviewCellID_default = @"default";
@interface BJLPreviewCell ()

@property (nonatomic, nullable) UIView *customView;
@property (nonatomic, readonly, nullable) UIView *customCoverView;


@property (nonatomic, readonly, nullable) UIImageView *cameraView;
@property (nonatomic, readonly, nullable) UIButton *nameView;
@property (nonatomic, readonly, nullable) UILabel *identity;

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
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        
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
        self->_customCoverView = ({
            UIView *view = [UIView new];
            [self.contentView addSubview:view];
            view;
        });
    }
    
    if ([self.reuseIdentifier isEqualToString:BJLPreviewCellID_view_label]) {
        self->_customCoverView = ({
            UIView *view = [UIView new];
            [self.contentView addSubview:view];
            view;
        });
        
        
        self->_avatarView = ({
            UIImageView *imageView = [UIImageView new];
            imageView.contentMode = UIViewContentModeCenter;
            imageView.layer.cornerRadius = 3;
            imageView.clipsToBounds = YES;
            [imageView setBackgroundColor:[UIColor whiteColor]];
            [self.contentView addSubview:imageView];
            imageView;
            
        });
        
        self->_videoLoadingView = ({
            UIView *view = [UIView new];
            view.backgroundColor = [UIColor bjl_colorWithHexString:@"4A4A4A"];
            view.hidden = YES;
            view.layer.cornerRadius = 3;
            view.clipsToBounds = YES;
            [self.contentView addSubview:view];
            view;
        });
        
        self->_videoLoadingImageView = ({
            UIImageView *imageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"bjl_ic_user_loading"]];
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            [self.videoLoadingView addSubview:imageView];
            imageView;
        });
    }
    
    if ([self.reuseIdentifier isEqualToString:BJLPreviewCellID_avatar_label]
        || [self.reuseIdentifier isEqualToString:BJLPreviewCellID_avatar_label_buttons]||[self.reuseIdentifier isEqualToString:BJLPreviewCellID_default]) {
        self->_avatarView = ({
            UIImageView *imageView = [UIImageView new];
            imageView.contentMode = UIViewContentModeCenter;
            imageView.layer.cornerRadius = 3;
            imageView.clipsToBounds = YES;
            [imageView setBackgroundColor:[UIColor whiteColor]];
            [self.contentView addSubview:imageView];
            imageView;
        
        });
    }
    
    if ([self.reuseIdentifier isEqualToString:BJLPreviewCellID_avatar_label]) {
        self->_cameraView = ({
            UIImageView *imageView = [UIImageView new];
            imageView.image = [UIImage imageNamed:@"bjl_ic_video_on"];
            [self.contentView addSubview:imageView];
            imageView;
        });
        self.cameraView.hidden = YES;
    }
    
    if ([self.reuseIdentifier isEqualToString:BJLPreviewCellID_view_label]
        || [self.reuseIdentifier isEqualToString:BJLPreviewCellID_avatar_label]||[self.reuseIdentifier isEqualToString:BJLPreviewCellID_default]) {
        self->_nameView = ({
            UIButton *button = [BJLImageRightButton new];
            button.titleLabel.font = [UIFont fontWithName:@"PingFangSC-Regular" size:13];
            [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
            [self.contentView addSubview:button];
            button;
        });
        if (![self.reuseIdentifier isEqualToString:BJLPreviewCellID_default]) {
            self->_identity = ({
                UILabel *identity = [UILabel new];
                identity.font = [UIFont fontWithName:@"PingFangSC-Regular" size:11];
                [identity setTextColor:[UIColor whiteColor]];
                [self.contentView addSubview:identity];
                identity.layer.cornerRadius = 5;
                identity.clipsToBounds = YES;
                identity.textAlignment = NSTextAlignmentCenter;
                identity;
            });
        }
    
    }
    
    if ([self.reuseIdentifier isEqualToString:BJLPreviewCellID_avatar_label_buttons]) {
        self->_actionGroupView = ({
            UIView *view = [UIView new];
            view.backgroundColor = [UIColor bjl_darkDimColor];
            [self.contentView addSubview:view];
            view;
        });
        
        self->_messageLabel = ({
            UILabel *label = [UILabel new];
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
            make.top.equalTo(self.contentView).offset(5);
            make.centerX.equalTo(self.contentView.mas_centerX);
            //判断横竖屏
            if(([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait) || ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown)){
                make.width.equalTo(@(74 * [UIScreen mainScreen].bounds.size.width/375));
                make.height.equalTo(@(55 * [UIScreen mainScreen].bounds.size.width/375));
            }else{
                
                make.width.equalTo(@(74 * [UIScreen mainScreen].bounds.size.height/375));
                make.height.equalTo(@(55 * [UIScreen mainScreen].bounds.size.height/375));
            }
            
        }];
    }
    
    if (self.avatarView) {
        [self.avatarView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.contentView).offset(5);
            make.centerX.equalTo(self.contentView.mas_centerX);
            if(([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait) || ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown)){
                make.width.equalTo(@(74 * [UIScreen mainScreen].bounds.size.width/375));
                make.height.equalTo(@(55 * [UIScreen mainScreen].bounds.size.width/375));
            }else{
                
                make.width.equalTo(@(74 * [UIScreen mainScreen].bounds.size.height/375));
                make.height.equalTo(@(55 * [UIScreen mainScreen].bounds.size.height/375));
            }
            
        }];
    }
    
    if (self.cameraView) {
        [self.cameraView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.top.equalTo(self.contentView);
        }];
    }
    
    if (self.nameView) {
        [self.nameView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.left.right.equalTo(self.contentView);
            make.height.equalTo(@18.0);
            make.top.equalTo(self.avatarView.mas_bottom).offset(5);
        }];
    }
    
    if (self.identity) {
        [self.identity mas_makeConstraints:^(MASConstraintMaker *make) {
            make.centerX.equalTo(self.nameView.mas_centerX);
            make.top.equalTo(self.nameView.mas_bottom).offset(3);
            make.width.equalTo(@30);
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
            make.top.equalTo(self.contentView).offset(5);
            make.centerX.equalTo(self.contentView.mas_centerX);
            if(([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait) || ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown)){
                make.width.equalTo(@(74 * [UIScreen mainScreen].bounds.size.width/375));
                make.height.equalTo(@(55 * [UIScreen mainScreen].bounds.size.width/375));
            }else{
                
                make.width.equalTo(@(74 * [UIScreen mainScreen].bounds.size.height/375));
                make.height.equalTo(@(55 * [UIScreen mainScreen].bounds.size.height/375));
            }
            
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
        [self.contentView insertSubview:view atIndex:2];
        //判断显示的图片还是视频
        if ([view isKindOfClass:[UIImageView class]]) {
            [view setBackgroundColor:[UIColor whiteColor]];
        }else{
            _avatarView.backgroundColor = [UIColor clearColor];
             [view setBackgroundColor:[UIColor clearColor]];
        }
        view.layer.cornerRadius = 3;
        view.clipsToBounds = YES;
        [view mas_remakeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.contentView).offset(5);
            make.centerX.equalTo(self.contentView.mas_centerX);
            if(([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait) || ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown)){
                make.width.equalTo(@(74 * [UIScreen mainScreen].bounds.size.width/375));
                make.height.equalTo(@(55 * [UIScreen mainScreen].bounds.size.width/375));
            }else{

                make.width.equalTo(@(74 * [UIScreen mainScreen].bounds.size.height/375));
                make.height.equalTo(@(55 * [UIScreen mainScreen].bounds.size.height/375));
            }
          
        }];
    }
}

- (void)updateLoadingViewHidden:(BOOL)hidden {
    //判断横竖屏 竖屏隐藏人名和身份
     if(([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortrait) || ([UIApplication sharedApplication].statusBarOrientation == UIInterfaceOrientationPortraitUpsideDown)){
         self.nameView.hidden = NO;
         self.identity.hidden = NO;
     }else{
         self.nameView.hidden = YES;
         self.identity.hidden = YES;
     }
    
    
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

- (void)updateWithView:(UIView *)view title:(NSString *)title identity:(NSInteger)identity; {
    [self updateWithView:view];
    [self.nameView setTitle:title forState:UIControlStateNormal];
    if (identity == 1) {
        self.identity.text = @"老师";
        [self.identity setBackgroundColor:[UIColor bjl_colorWithHexString:@"#007AFF"]];
    }else if (identity == 2){
        self.identity.text = @"助教";
        [self.identity setBackgroundColor:[UIColor bjl_colorWithHexString:@"#FE754A"]];
    }
    else{
        self.identity.text = @"学生";
        [self.identity setBackgroundColor:[UIColor bjl_colorWithHexString:@"#FF4858"]];
    }
 
}

- (void)updateWithImageURLString:(NSString *)imageURLString title:(NSString *)title hasVideo:(BOOL)hasVideo identity:(NSInteger)identity{
    [self.avatarView setBackgroundColor:[UIColor whiteColor]];
    //对方是否有视频，若果有则为没开
    if(hasVideo) {
         [self.avatarView setImage:[UIImage imageNamed:@"turnOffVideo"]];
    }else{
        if (identity == 5) {
            [self.avatarView setImage:[UIImage imageNamed:@"noPeople"]];
            [self addBorderToLayer:self.avatarView];
        }else{
            [self.avatarView setImage:[UIImage imageNamed:@"turnOffVideo"]];
        }
    }
    if (self.nameView) {
        if (identity == 5) {
            [self.nameView setTitleColor:[UIColor bjl_colorWithHexString:@"#808080"] forState:UIControlStateNormal];
          
        }else{
            [self.nameView setTitleColor:[UIColor bjl_colorWithHexString:@"#020202"] forState:UIControlStateNormal];
        }
        [self.nameView setTitle:title forState:UIControlStateNormal];
        // self.nameView.selected = hasVideo;
        self.cameraView.hidden = YES;
    }
    else {
        
        self.messageLabel.text = title;
    }
    
    if (identity == 1) {
        self.identity.text = @"老师";
        [self.identity setBackgroundColor:[UIColor bjl_colorWithHexString:@"#007AFF"]];
    }else if (identity == 2){
        self.identity.text = @"助教";
        [self.identity setBackgroundColor:[UIColor bjl_colorWithHexString:@"#FE754A"]];
    }
    else{
        self.identity.text = @"学生";
        [self.identity setBackgroundColor:[UIColor bjl_colorWithHexString:@"#FF4858"]];
    }
}

+ (CGSize)cellSize {
    static BOOL iPad = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        iPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
    });
    
    CGFloat height = iPad ? heightL : heightM;
    return CGSizeMake([UIScreen mainScreen].bounds.size.width/4, height);
}

+(CGSize)cellSize2 {
    static BOOL iPad = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        iPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
    });

    return CGSizeMake([UIScreen mainScreen].bounds.size.width/4, 60);
    
}

+ (CGSize)cellSize3 {
    static BOOL iPad = NO;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        iPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
    });
    
    CGFloat height = iPad ? heightL : heightM;
    return CGSizeMake([UIScreen mainScreen].bounds.size.height/4, height);
}

+ (NSArray<NSString *> *)allCellIdentifiers {
    return @[BJLPreviewCellID_view,
             BJLPreviewCellID_view_label,
             BJLPreviewCellID_avatar_label,
             BJLPreviewCellID_avatar_label_buttons,
             BJLPreviewCellID_default,
             ];
}

- (void)addBorderToLayer:(UIView *)view{
    
    CAShapeLayer *border = [CAShapeLayer layer];
    //  线条颜色
    border.strokeColor = [UIColor bjl_colorWithHexString:@"#007AFF"].CGColor;
    border.fillColor = nil;
    border.path = [UIBezierPath bezierPathWithRect:view.bounds].CGPath;
    border.frame = view.bounds;
    border.lineWidth = .5f;
    border.lineCap = @"round";
    //  第一个是 线条长度   第二个是间距    nil时为实线
    border.lineDashPattern = @[@2, @4];
    [view.layer addSublayer:border];
    
}

@end



NS_ASSUME_NONNULL_END
