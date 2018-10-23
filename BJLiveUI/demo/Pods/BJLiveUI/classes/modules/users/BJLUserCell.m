//
//  BJLUserCell.m
//  BJLiveUI
//
//  Created by MingLQ on 2017-02-15.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import "BJLUserCell.h"

#import "BJLViewImports.h"

NS_ASSUME_NONNULL_BEGIN

#define canManageFormat     @"[manage-%d]"
#define isPresenterFormat   @"[presenter-%d]"

#define userRoleFormat      @"[userRole-%td]"
#define userStateFormat     @"[userState-%td]"

#define hasVideoFormat      @"[hasVideo-%d]"
#define videoPlayingFormat  @"[videoPlaying-%d]"

#define scanIdentifier(IDENTIFIER, FORMAT, VALUE) ({ \
    [IDENTIFIER rangeOfString:[NSString stringWithFormat:FORMAT, VALUE]].location != NSNotFound; \
})

static const CGFloat avatarSize = 25.0;

@interface BJLUserCell ()

@property (nonatomic) BOOL canManage;
@property (nonatomic) BOOL isTeacher, isAssistant;
@property (nonatomic) BOOL isPresenter;
@property (nonatomic) BOOL online, request, speaking;
@property (nonatomic) BOOL hasVideo, videoPlaying;

@property (nonatomic) UIImageView *avatarView;
@property (nonatomic) UILabel *nameLabel, *roleLabel, *presenterLabel;
@property (nonatomic, nullable) UIButton *videoStateButton;

@property (nonatomic, nullable) UIButton *leftButton, *rightButton;

//2018-10-22 13:49:43 miaksa 根据视觉标注添加底部分割线
@property (nonatomic) UIView *bottomLine;
//2018-10-22 13:49:43 miaksa 根据视觉标注添加底部分割线
@end

@implementation BJLUserCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(nullable NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.canManage = scanIdentifier(reuseIdentifier, canManageFormat, YES);
        self.isTeacher = scanIdentifier(reuseIdentifier, userRoleFormat, BJLUserRole_teacher);
        self.isAssistant = scanIdentifier(reuseIdentifier, userRoleFormat, BJLUserRole_assistant);
        self.isPresenter = self.isAssistant && scanIdentifier(reuseIdentifier, isPresenterFormat, YES);
        self.request = scanIdentifier(reuseIdentifier, userStateFormat, BJLUserState_request);
        self.speaking = scanIdentifier(reuseIdentifier, userStateFormat, BJLUserState_speaking);
        self.online = scanIdentifier(reuseIdentifier, userStateFormat, BJLUserState_online);
        self.hasVideo = scanIdentifier(reuseIdentifier, hasVideoFormat, YES);
        self.videoPlaying = self.hasVideo && scanIdentifier(reuseIdentifier, videoPlayingFormat, YES);
        
        [self makeSubviews];
        [self makeConstraints];
        [self makeActions];
        
        [self prepareForReuse];
    }
    return self;
}

- (void)makeSubviews {
//  2018-10-22 13:47:13 mikasa 根据视觉稿修改颜色
//    [self.contentView setBackgroundColor:[UIColor whiteColor]];
//  2018-10-22 13:47:13 mikasa 根据视觉稿修改颜色
    self.avatarView = ({
        UIImageView *imageView = [UIImageView new];
        imageView.backgroundColor = [UIColor bjl_grayImagePlaceholderColor];
        imageView.layer.cornerRadius = avatarSize / 2;
        imageView.layer.masksToBounds = YES;
        [self.contentView addSubview:imageView];
        imageView;
    });
    
    self.nameLabel = ({
        UILabel *label = [UILabel new];
        label.textAlignment = NSTextAlignmentLeft;
        label.textColor = [UIColor bjl_colorWithHexString:@"#4A4A4A"];
        label.font = [UIFont systemFontOfSize:14.0];
        [self.contentView addSubview:label];
        label;
    });
    
//2018-10-22 13:49:43 miaksa 根据视觉标注添加底部分割线
    self.bottomLine = ({
        UIView *view = [UIView new];
        [view setBackgroundColor:[UIColor bjl_colorWithHexString:@"#cccccc"]];
        [self.contentView addSubview:view];
        view;
    });
//2018-10-22 13:49:43 miaksa 根据视觉标注添加底部分割线
    
    if (self.isTeacher || self.isAssistant) {
        NSString *roleText = self.isTeacher ? @"老师" : @"助教";
        self.roleLabel = ({
            UILabel *label = [UILabel new];
            label.text = roleText;
            label.textAlignment = NSTextAlignmentCenter;
//2018-10-22 17:05:38 mikasa 按照标注图修改身份标识
            [label setBackgroundColor:self.isTeacher?[UIColor bjl_colorWithHexString:@"#007AFF"]:[UIColor bjl_colorWithHexString:@"#FE754A"]];
            label.textColor = [UIColor whiteColor];
            label.font = [UIFont systemFontOfSize:9.0];
//            label.layer.borderWidth = BJLOnePixel;
//            label.layer.borderColor = [UIColor bjl_blueBrandColor].CGColor;
            label.layer.cornerRadius = 7.;
//2018-10-22 17:05:38 mikasa 按照标注图修改身份标识
            label.layer.masksToBounds = YES;
            [self.contentView addSubview:label];
            label;
        });
        if (self.isPresenter) {
            self.presenterLabel = ({
                UILabel *label = [UILabel new];
                label.text = @"主讲";
                label.textAlignment = NSTextAlignmentCenter;
                label.textColor = [UIColor bjl_blueBrandColor];
                label.font = [UIFont systemFontOfSize:11.0];
                label.layer.borderWidth = BJLOnePixel;
                label.layer.borderColor = [UIColor bjl_blueBrandColor].CGColor;
                label.layer.cornerRadius = BJLButtonCornerRadius;
                label.layer.masksToBounds = YES;
                [self.contentView addSubview:label];
                label;
            });
        }
    }
    
    if (self.hasVideo) {
        self.videoStateButton = ({
            UIButton *button = [UIButton new];
            UIImage *icon = [UIImage imageNamed:(self.videoPlaying ? @"bjl_ic_video_opening" : @"bjl_ic_video_close")];
            [button setImage:icon forState:UIControlStateNormal];
            [button setTitleColor:[UIColor bjl_lightGrayTextColor] forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont systemFontOfSize:12.0];
            button.userInteractionEnabled = NO;
            [self.contentView addSubview:button];
            button;
        });
    }
    
    const CGFloat buttonWidth = 64.0, buttonHeight = BJLButtonSizeS;
    if (self.request) {
        if (self.canManage) {
            self.leftButton = ({
                BJLButton *button = [BJLButton makeRoundedRectButtonHighlighted:YES];
                button.intrinsicContentSize = CGSizeMake(buttonWidth, buttonHeight);
                [button setTitle:@"同意" forState:UIControlStateNormal];
                [self.contentView addSubview:button];
                button;
            });
            self.rightButton = ({
                BJLButton *button = [BJLButton makeRoundedRectButtonHighlighted:NO];
                button.intrinsicContentSize = CGSizeMake(buttonWidth, buttonHeight);
                [button setTitle:@"拒绝" forState:UIControlStateNormal];
                [self.contentView addSubview:button];
                button;
            });
        }
    }
    else if (self.speaking) {
        if (self.hasVideo) {
            self.leftButton = ({
                BJLButton *button = [BJLButton makeTextButtonDestructive:NO];
                button.intrinsicContentSize = CGSizeMake(buttonWidth, buttonHeight);
                [button setTitle:self.videoPlaying ? @"关闭视频" : @"打开视频" forState:UIControlStateNormal];
                [self.contentView addSubview:button];
                button;
            });
        }
        if (self.canManage && !self.isTeacher) {
            self.rightButton = ({
                BJLButton *button = [BJLButton makeTextButtonDestructive:YES];
                button.intrinsicContentSize = CGSizeMake(buttonWidth, buttonHeight);
                [button setTitle:@"结束发言" forState:UIControlStateNormal];
                [self.contentView addSubview:button];
                button;
            });
        }
    }
}

- (void)makeConstraints {
    [self.nameLabel setContentCompressionResistancePriority:UILayoutPriorityDefaultLow
                                                     forAxis:UILayoutConstraintAxisHorizontal];
    
    [self.avatarView mas_makeConstraints:^(MASConstraintMaker *make) {
//        2018-10-22 14:28:14 mikasa 根据标注图 修改私聊列表头像图标大小
//        make.width.height.equalTo(@(avatarSize));
        make.width.height.mas_equalTo(avatarSize);
//        2018-10-22 14:28:14 mikasa 根据标注图 修改私聊列表头像图标大小
        make.left.equalTo(self.contentView).with.offset(BJLViewSpaceL);
        make.centerY.equalTo(self.contentView);
    }];
    
    [self.nameLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.avatarView.mas_right).with.offset(9.);
        make.centerY.equalTo(self.contentView);
        make.right.lessThanOrEqualTo(self.roleLabel.mas_left
                                     ?: self.presenterLabel.mas_left
                                     ?: self.videoStateButton.mas_left
                                     ?: self.leftButton.mas_left
                                     ?: self.rightButton.mas_left
                                     ?: self.contentView).with.offset(- BJLViewSpaceM);
    }];
    
//2018-10-22 13:49:43 mikasa 根据视觉标注添加底部分割线
    [self.bottomLine mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView).inset(15.);
        make.bottom.equalTo(self.contentView);
        make.right.equalTo(self.contentView);
        make.height.mas_equalTo(.5);
    }];
//2018-10-22 13:49:43 mikasa 根据视觉标注添加底部分割线
    
    [self.roleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
//        2018-10-22 17:06:56 mikasa 根据视觉标注修改身份标识位置
//        make.left.equalTo(self.nameLabel.mas_right).with.offset(BJLViewSpaceM);
        make.left.equalTo(self.nameLabel.mas_right).with.offset(7.);
        make.centerY.equalTo(self.contentView);
        make.size.mas_equalTo(CGSizeMake(26., 14.0));
        make.right.lessThanOrEqualTo(self.presenterLabel.mas_left
                                     ?: self.videoStateButton.mas_left
                                     ?: self.leftButton.mas_left
                                     ?: self.rightButton.mas_left
                                     ?: self.contentView).with.offset(- BJLViewSpaceM);
    }];
//        2018-10-22 17:06:56 mikasa 根据视觉标注修改身份标识位置
    [self.presenterLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.roleLabel.mas_right
                          ?: self.nameLabel.mas_right).with.offset(BJLViewSpaceM);
        make.centerY.equalTo(self.roleLabel);
        make.size.equalTo(self.roleLabel);
        make.right.lessThanOrEqualTo(self.videoStateButton.mas_left
                                     ?: self.leftButton.mas_left
                                     ?: self.rightButton.mas_left
                                     ?: self.contentView).with.offset(- BJLViewSpaceM);
    }];
    
    [self.videoStateButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.presenterLabel.mas_right
                          ?: self.roleLabel.mas_right
                          ?: self.nameLabel.mas_right).with.offset(BJLViewSpaceM);
        make.centerY.equalTo(self.contentView);
        make.right.lessThanOrEqualTo(self.leftButton.mas_left
                                     ?: self.rightButton.mas_left
                                     ?: self.contentView).with.offset(- BJLViewSpaceM);
    }];
    
    UIButton *right1st = self.rightButton ?: self.leftButton;
    [right1st mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView).with.offset(- BJLViewSpaceM);
        make.centerY.equalTo(self.contentView);
    }];
    
    UIButton *right2nd = self.rightButton ? self.leftButton : nil;
    [right2nd mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.rightButton.mas_left).with.offset(- BJLViewSpaceM);
        make.centerY.equalTo(self.contentView);
    }];
}

- (void)makeActions {
    bjl_weakify(self);
    
    [self.leftButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        if (self.request) {
            if (self.allowRequestCallback) self.allowRequestCallback(self);
        }
        else if (self.speaking) {
            const NSTimeInterval LIMIT = BJLRobotDelayM;
            static NSTimeInterval LAST = 0;
            NSTimeInterval NOW = [NSDate timeIntervalSinceReferenceDate];
            if (NOW - LAST < LIMIT) {
                return;
            }
            if (self.toggleVideoPlayingRequestCallback) self.toggleVideoPlayingRequestCallback(self);
            LAST = NOW;
        }
    } forControlEvents:UIControlEventTouchUpInside];
    
    [self.rightButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        if (self.request) {
            if (self.disallowRequestCallback) self.disallowRequestCallback(self);
        }
        else if (self.speaking) {
            if (self.stopSpeakingRequestCallback) self.stopSpeakingRequestCallback(self);
        }
    } forControlEvents:UIControlEventTouchUpInside];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.avatarView.image = nil;
    self.nameLabel.text = nil;
}

- (void)updateWithUser:(nullable __kindof BJLUser *)user {
    [self.avatarView bjl_setImageWithURL:[NSURL URLWithString:user.avatar]
                             placeholder:nil
                              completion:nil];
    self.nameLabel.text = user.name;
}

+ (NSString *)cellIdentifierForUserState:(BJLUserState)userState
                    isTeacherOrAssistant:(BOOL)isTeacherOrAssistant
                             isPresenter:(BOOL)isPresenter
                                userRole:(BJLUserRole)userRole
                                hasVideo:(BOOL)hasVideo
                            videoPlaying:(BOOL)videoPlaying {
    return [NSString stringWithFormat:
            canManageFormat isPresenterFormat userRoleFormat userStateFormat hasVideoFormat videoPlayingFormat,
            isTeacherOrAssistant, isPresenter, userRole, userState, hasVideo, hasVideo && videoPlaying];
}

+ (NSArray<NSString *> *)allCellIdentifiers {
    NSMutableArray *allCellIdentifiers = [NSMutableArray new];
    for (NSNumber *userRole in @[@(BJLUserRole_student), @(BJLUserRole_teacher), @(BJLUserRole_assistant), @(BJLUserRole_guest)]) {
        for (BJLUserState userState = (BJLUserState)0; userState < _BJLUserState_count; userState++) {
            for (NSNumber *hasVideo in @[@NO, @YES]) {
                for (NSNumber *videoPlaying in @[@NO, @YES]) {
                    for (NSNumber *isTeacherOrAssistant in @[@NO, @YES]) {
                        for (NSNumber *isPresenter in @[@NO, @YES]) {
                            NSString *cellIdentifier = [self
                                                        cellIdentifierForUserState:userState
                                                        isTeacherOrAssistant:isTeacherOrAssistant.boolValue
                                                        isPresenter:isPresenter.boolValue
                                                        userRole:(BJLUserRole)userRole.integerValue
                                                        hasVideo:hasVideo.boolValue
                                                        videoPlaying:videoPlaying.boolValue];
                            [allCellIdentifiers bjl_addObjectOrNil:cellIdentifier];
                        }
                    }
                }
            }
        }
    }
    return allCellIdentifiers;
}

@end

NS_ASSUME_NONNULL_END
