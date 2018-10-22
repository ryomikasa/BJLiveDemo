//
//  BJLControlsViewController.m
//  BJLiveUI
//
//  Created by MingLQ on 2017-02-15.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import <BJLiveBase/BJLHitTestView.h>

#import "BJLControlsViewController.h"

#import "BJLAnnularProgressView.h"

NS_ASSUME_NONNULL_BEGIN

@interface BJLControlsViewController ()

@property (nonatomic, readonly, weak) BJLRoom *room;

@property (nonatomic) UIView *rightToolBar, *bottomToolBar;

@property (nonatomic) UIButton *pptButton, *handButton, *penButton, *usersButton;
@property (nonatomic) BJLAnnularProgressView *handProgressView;

@property (nonatomic) UIButton *micButton, *cameraButton, *rotateButton, *moreButton,*voiceButton;

@property (nonatomic) UIButton *chatButton, *lineroadButton,*sharpButton;

@end

@implementation BJLControlsViewController

#pragma mark - lifecycle & <BJLRoomChildViewController>

- (instancetype)initWithRoom:(BJLRoom *)room {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self->_room = room;
    }
    return self;
}

- (void)loadView {
    bjl_weakify(self);
    self.view = [BJLHitTestView viewWithFrame:[UIScreen mainScreen].bounds hitTestBlock:^UIView * _Nullable(UIView * _Nullable hitView, CGPoint point, UIEvent * _Nullable event) {
        bjl_strongify(self);
        
        NSArray *containerViews = @[self.view, self.rightToolBar, self.bottomToolBar];
        
        // 非 container-view 才响应点击事件
        if (![containerViews containsObject:hitView]) {
            return hitView;
        }
        
        // 避免按钮禁用状态下点击穿透到 contentView，导致 controls 被隐藏
        // @see https://stackoverflow.com/a/40786920/456536
        for (UIView *superview in containerViews) {
            for (UIView *subview in superview.subviews) {
                UIControl *control = bjl_cast(UIControl, subview);
                CGPoint pointInControl = [self.view convertPoint:point toView:control];
                if (control && !control.enabled && [control pointInside:pointInControl withEvent:event]) {
                    return self.view; // !!!: self.view.userInteractionEnabled = YES;
                }
            }
        }
        
        return nil;
    }];
    self.view.userInteractionEnabled = YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self makeSubviews];
    [self makeConstraints];
    
    [self updateButtonStates];
    
    bjl_weakify(self);
    [self bjl_kvo:BJLMakeProperty(self.room, vmsAvailable)
           filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
               // bjl_strongify(self);
               return now.boolValue;
           }
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             [self updateRightToolBarButtons];
             [self updateButtonStates];
             [self makeObserving];
             return YES;
         }];
    [self bjl_observe:BJLMakeMethod(self.room, enterRoomSuccess)
             observer:^BOOL {
                 bjl_strongify(self);
                 [self updateButtonStates];
                 return YES;
             }];
    
    [self makeActions];
}

// NOTE: trigger by [self.view setNeedsUpdateConstraints];
- (void)updateViewConstraints {
    [self updateButtonStates];
    [super updateViewConstraints];
}

#pragma mark - <UIContentContainer>

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    NSLog(@"%@ willTransitionToSizeClasses: %td-%td",
          NSStringFromClass([self class]), newCollection.horizontalSizeClass, newCollection.verticalSizeClass);
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
        // @see - [self updateViewConstraints]
        [self.view setNeedsUpdateConstraints];
    } completion:nil];
}

#pragma mark - makeSubviews

- (void)makeSubviews {
    self.rightToolBar = ({
        UIView *view = [UIView new];
        [self.view addSubview:view];
        view;
    });
    
    self.bottomToolBar = ({
        UIView *view = [UIView new];
        [self.view addSubview:view];
        view;
    });
    
    self.pptButton = [self makeButtonWithIconName:@"bjl_ic_ppt"
                                 selectedIconName:nil
                                             size:BJLButtonSizeL
                                        superview:nil]; // add to self.rightToolBar later
    
    self.handButton = [self makeButtonWithIconName:@"bjl_ic_handup"
                                  selectedIconName:@"bjl_ic_handup_on"
                                              size:BJLButtonSizeL
//                       2018-10-19 14:16:57 mikasa 修改举手按钮位置
//                                         superview:nil]; // add to self.rightToolBar later
                                             superview:self.bottomToolBar]; // add to self.rightToolBar later
//                       2018-10-19 14:16:57 mikasa 修改举手按钮位置
    
    
    self.handProgressView = ({
        BJLAnnularProgressView *progressView = [BJLAnnularProgressView new];
        progressView.size = BJLButtonSizeL;
        progressView.annularWidth = 2.0;
        progressView.color = [UIColor bjl_blueBrandColor];
        progressView.userInteractionEnabled = NO;
        [self.handButton addSubview:progressView];
        [progressView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.handButton);
        }];
        progressView;
    });
    
    self.penButton = [self makeButtonWithIconName:@"bjl_ic_lightpen"
                                 selectedIconName:@"bjl_ic_lightpen_on"
                                             size:BJLButtonSizeL
                                        superview:nil]; // add to self.rightToolBar later
    
    self.usersButton = [self makeButtonWithIconName:@"bjl_ic_users"
                                   selectedIconName:nil
                                               size:BJLButtonSizeL
                                          superview:nil]; // add to self.rightToolBar later
    
    self.micButton = [self makeButtonWithIconName:@"bjl_ic_stopaudio_closed"
                                 selectedIconName:nil
                                             size:BJLButtonSizeM
//                      2018-10-19 14:52:16 mikasa 修改mic 按钮位置大小图片
//                                        superview:self.bottomToolBar];
                                        superview:self.rightToolBar];
//                      2018-10-19 14:52:16 mikasa 修改mic 按钮位置大小图片
//    2018-10-19 16:14:00 mikasa 追加mic 音量lv按钮
    self.voiceButton = [[UIButton alloc]init];
//    2018-10-19 16:14:00 mikasa 追加mic 音量lv按钮
    
    
    self.cameraButton = [self makeButtonWithIconName:@"bjl_ic_stopvideo_closed"
                                    selectedIconName:@"bjl_ic_stopvideo_open"
                                                size:BJLButtonSizeM
                                           superview:self.bottomToolBar];
    
    self.rotateButton = [self makeButtonWithIconName:@"bjl_ic_rotate_hor" // 竖屏时 normal，点击切到横屏
                                    selectedIconName:@"bjl_ic_rotate_ver" // 横屏时 selected，点击切到竖屏
                                                size:BJLButtonSizeM
                                           superview:self.bottomToolBar];
    
    self.moreButton = [self makeButtonWithIconName:@"bjl_ic_more"
                                  selectedIconName:nil
                                              size:BJLButtonSizeM
                                         superview:self.bottomToolBar];
    
    self.chatButton = [self makeButtonWithIconName:@"bjl_ic_sentmsg"
                                  selectedIconName:nil
                                              size:BJLButtonSizeM
                                         superview:self.bottomToolBar];
    
//    2018-10-19 10:13:15 mikasa 底部添加线路按钮
    self.lineroadButton = [self makeButtonWithIconName:@"" selectedIconName:@"" size:BJButtonSizeNB superview:self.bottomToolBar];
    [self.lineroadButton setBackgroundColor:[UIColor bjl_colorWithHexString:@"#020202"]];
    [self.lineroadButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.lineroadButton setAlpha:0.5];
    [self.lineroadButton setHidden:YES];
   
//    2018-10-19 10:13:15 mikasa 底部添加线路按钮
    
//    2018-10-19 13:10:54 mikasa 底部添加 “清晰度”按钮
    self.sharpButton = [self makeButtonWithIconName:@"" selectedIconName:@"" size:BJButtonSizeNB superview:self.bottomToolBar];
    [self.sharpButton setBackgroundColor:[UIColor bjl_colorWithHexString:@"#020202"]];
    [self.sharpButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.sharpButton setAlpha:0.5];
    [self.sharpButton setHidden:YES];
//    2018-10-19 13:10:54 mikasa 底部添加 “清晰度”按钮
    
}

- (UIButton *)makeButtonWithIconName:(nullable NSString *)iconName
                    selectedIconName:(nullable NSString *)selectedIconName
                                size:(CGFloat)size
                           superview:(nullable UIView *)superview {
    UIButton *button = [UIButton new];
    if (iconName) {
        [button setImage:[UIImage imageNamed:iconName] forState:UIControlStateNormal];
        /*
        if (selectedImage) {
            [button setImage:selectedImage forState:UIControlStateNormal | UIControlStateHighlighted];
        } */
        if (selectedIconName) {
            UIImage *selectedImage = [UIImage imageNamed:selectedIconName];
            [button setImage:selectedImage forState:UIControlStateSelected];
            [button setImage:selectedImage forState:UIControlStateSelected | UIControlStateHighlighted];
        }
    }
    
    button.layer.cornerRadius = size / 2;
    button.layer.masksToBounds = YES;
    
    [superview addSubview:button];
    
    return button;
}

- (void)updateRightToolBarButtons {
    if (!self.room.loginUser) {
        return;
    }
    
    NSArray<UIButton *> *buttons;
    if (self.room.loginUser.isTeacherOrAssistant) {
        buttons = @[self.penButton, self.pptButton, self.usersButton];
    }
    else if (self.room.roomInfo.roomType != BJLRoomType_1toN) {
        buttons = @[self.penButton, self.usersButton];
    }
    else {
        if (self.room.loginUser.groupID == 0) {
            // self.room.speakingRequestVM.speakingEnabled || NOT
//            2018-10-19 14:11:21 mikasa 修改举手按钮位置大小
//            buttons = @[self.penButton, self.handButton, self.usersButton];
//            2018-10-19 17:03:47 mikasa 修改camera按钮大小位置图标
//            buttons = @[self.penButton, self.usersButton,self.micButton,self.voiceButton];
            buttons = @[self.penButton, self.usersButton,self.micButton,self.voiceButton,self.cameraButton];
//            2018-10-19 17:03:47 mikasa 修改camera按钮大小位置图标
//            2018-10-19 14:11:21 mikasa 修改举手按钮位置大小
        }
        else {
            buttons = @[self.penButton, self.usersButton];
        }
    }
    
    [self.rightToolBar.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    UIButton *last = nil;
    for (UIButton *button in buttons) {
        [self.rightToolBar addSubview:button];
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
//  2018-10-19 15:37:23 mikasa 修改右侧mic 视频按钮位置
//            make.top.equalTo(last.mas_bottom ?: self.rightToolBar).with.offset(last ? BJLViewSpaceM : 0.0);
            if ([button isEqual:self.micButton]) {
                make.bottom.equalTo(self.rightToolBar);
                make.right.equalTo(self.rightToolBar);
                make.width.height.equalTo(@(BJButtonSizeNB));
            }
//  2018-10-19 15:37:23 mikasa 修改右侧mic 视频按钮位置
//            2018-10-19 16:15:38 mikasa 追加音量大小按钮位置
            else if ([button isEqual:self.voiceButton]){
                make.bottom.equalTo(self.rightToolBar);
                make.left.equalTo(self.rightToolBar);
                make.width.height.equalTo(@(CGSizeMake(15., 25.)));
            }
//            2018-10-19 16:15:38 mikasa 追加音量大小按钮位置
            
//            2018-10-19 17:01:10 mikasa 调整camera按钮大小位置图片
            else if ([button isEqual:self.cameraButton]){
                make.bottom.equalTo(self.rightToolBar).inset(BJButtonSizeNB +BJLViewSpaceNBM);
                make.right.equalTo(self.rightToolBar);
                make.width.height.equalTo(@(BJButtonSizeNB));
            }
//            2018-10-19 17:01:10 mikasa 调整camera按钮大小位置图片
            else{
                make.left.right.equalTo(self.rightToolBar);
                make.width.height.equalTo(@(BJLButtonSizeL));
            }
        }];
        last = button;
    }
    [last mas_makeConstraints:^(MASConstraintMaker *make) {
        make.bottom.equalTo(self.rightToolBar);
    }];
}

- (void)updateMicButtonSelectedIconWithInputVolumeLevel:(CGFloat)inputVolumeLevel {
    if (!self.micButton.selected) {
        return;
    }
    
    bjl_returnIfRobot(0.2);
    
    NSArray<NSString *> * const imageNames = @[@"bjl_ic_stopaudio_2",
                                               @"bjl_ic_stopaudio_3",
                                               @"bjl_ic_stopaudio_4",
                                               @"bjl_ic_stopaudio_5",
                                               @"bjl_ic_stopaudio_6",
                                               @"bjl_ic_stopaudio_7"];
    NSInteger imageIndex = round(imageNames.count * inputVolumeLevel);
    NSString *imageName = [imageNames bjl_objectOrNilAtIndex:imageIndex] ?: imageNames.firstObject;
    UIImage *image = [UIImage imageNamed:imageName];
    [self.micButton setImage:[UIImage imageNamed:@"bjl_ic_stopaudio_1"] forState:UIControlStateSelected];
    [self.micButton setImage:[UIImage imageNamed:@"bjl_ic_stopaudio_1"] forState:UIControlStateSelected | UIControlStateHighlighted];
//    2018-10-19 16:17:44 mikasa 追加音量大小按钮 变化
    [self.voiceButton setImage:image forState:UIControlStateNormal];
    
//    2018-10-19 16:17:44 mikasa 追加音量大小按钮 变化
}

#pragma mark - makeConstraints

- (void)makeConstraints {
    
    [self.bottomToolBar mas_makeConstraints:^(MASConstraintMaker *make) {
        //2018-10-19 10:00:50 mikasa bottombar 布局修改
        make.left.right.bottom.equalTo(self.view).inset(BJLViewSpaceNM);
        make.height.equalTo(@(BJButtonSizeNB));
//        make.centerX.equalTo(self.view);
//        make.bottom.equalTo(self.view).inset(17.);
//        make.size.mas_equalTo(CGSizeMake(([UIScreen mainScreen].bounds.size.width - 2*17.), 45.));
        //2018-10-19 10:00:50 mikasa bottombar 布局修改
    }];
//    2018-10-19 14:41:38 mikasa 修改右侧工具条位置大小
    [self.rightToolBar mas_makeConstraints:^(MASConstraintMaker *make) {
        //        make.right.equalTo(self.view).inset(BJLViewSpaceM);
        //        // 纵向居中时【不能】从 bottomToolBar 顶部算起，因为竖屏时上边有发言列表、横屏时上边有退出按钮
        //        make.centerY.equalTo(self.view);
        make.right.equalTo(self.view).inset(BJLViewSpaceNM);
        make.bottom.equalTo(self.view).inset(BJLViewSpaceNBM+BJButtonSizeNB+BJLViewSpaceNM);
        make.size.mas_equalTo(CGSizeMake(BJButtonSizeNB+4.+25., BJButtonSizeNB+BJLViewSpaceNBM+BJButtonSizeNB));
        
    }];
//    2018-10-19 14:41:38 mikasa 修改右侧工具条位置大小
    
//    2018-10-19 13:48:59 mikasa 修改横屏按钮位置约束 图片内容
    UIButton *last = nil;
    NSArray<UIButton *> *buttons = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad

//                                    2018-10-19 14:53:19 mikasa 修改mic 按钮大小位置图片
//                                    ? @[self.moreButton/* , self.rotateButton */, self.cameraButton, self.micButton]
                                    
//                                    2018-10-19 16:57:56 mikasa 修改视频d按钮大小位置图片
//                                    ? @[self.moreButton/* , self.rotateButton */, self.cameraButton]
                                    ? @[self.moreButton/* , self.rotateButton */]
//                                    2018-10-19 16:57:56 mikasa 修改视频d按钮大小位置图片
                                    
//                                    2018-10-19 14:53:19 mikasa 修改mic 按钮大小位置图片
                                    
//                                    : @[self.moreButton, self.rotateButton, self.cameraButton, self.micButton]);
                                    
//                                    2018-10-19 14:53:19 mikasa 修改mic 按钮大小位置图片
//                                    : @[self.moreButton, self.cameraButton, self.micButton]);
                                    
//                                    2018-10-19 16:57:56 mikasa 修改视频d按钮大小位置图片
//                                    : @[self.moreButton, self.cameraButton]);
                                    : @[self.moreButton]);
//                                    2018-10-19 16:57:56 mikasa 修改视频d按钮大小位置图片

//                                    2018-10-19 14:53:19 mikasa 修改mic 按钮大小位置图片
    for (UIButton *button in buttons) {
        [button mas_makeConstraints:^(MASConstraintMaker *make) {
            make.right.equalTo(last.mas_left ?: self.bottomToolBar).with.offset(last ? - BJLViewSpaceM : 0.0);
            make.centerY.equalTo(self.bottomToolBar);
            make.width.height.equalTo(@(BJLButtonSizeM));
        }];
        last = button;
    }
    
    [self.rotateButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.bottomToolBar).inset(BJLViewSpaceNBM+BJButtonSizeNB);
        make.centerY.equalTo(self.bottomToolBar);
        make.width.height.equalTo(@(BJButtonSizeNB));
    }];
//    2018-10-19 13:48:59 mikasa 修改横屏按钮位置约束 图片内容
    
    [self.chatButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.centerY.equalTo(self.bottomToolBar);
        make.width.height.equalTo(@(BJButtonSizeNB));
    }];
    
//    2018-10-19 13:11:53 mikasa 底部‘线路a’按钮约束
    [self.lineroadButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.bottomToolBar).inset((BJLViewSpaceNBM+BJButtonSizeNB)*3);
        make.centerY.equalTo(self.bottomToolBar);
        make.width.height.equalTo(@(BJButtonSizeNB));
    }];
//    2018-10-19 13:11:53 mikasa 底部‘线路a’按钮约束
//    2018-10-19 13:12:23 mikasa 底部 ‘清晰度’ 按钮约束
    [self.sharpButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.bottomToolBar).inset((BJLViewSpaceNBM+BJButtonSizeNB)*2);
        make.centerY.equalTo(self.bottomToolBar);
        make.width.height.equalTo(@(BJButtonSizeNB));
    }];
//    2018-10-19 13:12:23 mikasa 底部 ‘清晰度’ 按钮约束
//    2018-10-19 14:12:47 mikasa 底部 ‘举手’按钮约束
    [self.handButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.bottomToolBar);
        make.centerY.equalTo(self.bottomToolBar);
        make.width.height.equalTo(@(BJButtonSizeNB));
    }];
//    2018-10-19 14:12:47 mikasa 底部 ‘举手’按钮约束
//    2018-10-19 14:56:31 mikasa 右侧 ‘mic’按钮约束
    [self.micButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.rightToolBar);
        make.bottom.equalTo(self.rightToolBar);
        make.width.height.equalTo(@(BJButtonSizeNB));
    }];
//    2018-10-19 14:56:31 mikasa 右侧 ‘mic’按钮约束
}

#pragma mark - makeObserving

- (void)makeObserving {
    bjl_weakify(self);
    
    BJLPropertyFilter ifIntegerChanged = ^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
        // bjl_strongify(self);
        return now.integerValue != old.integerValue;
    };
    
    [self bjl_kvo:BJLMakeProperty(self.room.speakingRequestVM, speakingRequestTimeRemaining)
          options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
           filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable timeRemaining) {
               // bjl_strongify(self);
               return timeRemaining.doubleValue != old.doubleValue;
           }
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable timeRemaining) {
             bjl_strongify(self);
             if (timeRemaining.doubleValue <= 0.0) {
                 self.handProgressView.progress = 0.0;
             }
             else {
                 CGFloat progress = timeRemaining.doubleValue / self.room.speakingRequestVM.speakingRequestTimeoutInterval; // 1.0 ~ 0.0
                 self.handProgressView.progress = progress;
             }
             return YES;
         }];
    
    [self bjl_kvo:BJLMakeProperty(self.room.speakingRequestVM, speakingEnabled)
          options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
           filter:ifIntegerChanged
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             [self updateButtonStates];
             return YES;
         }];
    
    [self bjl_kvo:BJLMakeProperty(self.room.slideshowViewController, drawingGranted)
          options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
           filter:ifIntegerChanged
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             [self updateButtonStates];
             return YES;
         }];
    
    [self bjl_kvo:BJLMakeProperty(self.room.slideshowViewController, drawingEnabled)
          options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
           filter:ifIntegerChanged
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             [self updateButtonStates];
             return YES;
         }];
    
    [self bjl_kvo:BJLMakeProperty(self.room.playingVM, playingUsers)
          options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
           filter:^BOOL(NSArray<BJLMediaUser *> * _Nullable old, NSArray<BJLMediaUser *> * _Nullable now) {
               // bjl_strongify(self);
               return now != old;
           }
         observer:^BOOL(NSArray<BJLMediaUser *> * _Nullable old, NSArray<BJLMediaUser *> * _Nullable now) {
             bjl_strongify(self);
             if (now.count > 0 != old.count > 0) {
                 [self updateButtonStates];
             }
             return YES;
         }];
    
    [self bjl_kvo:BJLMakeProperty(self.room.recordingVM, recordingAudio)
          options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
           filter:ifIntegerChanged
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             self.micButton.selected = self.room.recordingVM.recordingAudio;
             if (self.micButton.selected) {
                 [self updateMicButtonSelectedIconWithInputVolumeLevel:1.0];
             }else{
//                 2018-10-19 16:55:19 mikasa 追加的音量按钮再切换开关时需要有 或者 无图片
                 [self.voiceButton setImage: nil forState:UIControlStateNormal];
//                 2018-10-19 16:55:19 mikasa 追加的音量按钮再切换开关时需要有 或者 无图片
             }
             return YES;
         }];
    
    [self bjl_kvo:BJLMakeProperty(self.room.recordingVM, inputVolumeLevel)
          options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
           filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
               // bjl_strongify(self);
               return ABS(round(old.doubleValue * 10) - round(now.doubleValue * 10)) >= 1.0;
           }
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             [self updateMicButtonSelectedIconWithInputVolumeLevel:now.doubleValue];
             return YES;
         }];
    
    [self bjl_kvo:BJLMakeProperty(self.room.recordingVM, recordingVideo)
          options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
           filter:ifIntegerChanged
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             self.cameraButton.selected = self.room.recordingVM.recordingVideo;
             return YES;
         }];
//2018-10-19 11:10:56 mikasa 监听线路变化
    [self bjl_kvo:BJLMakeProperty(self.room.mediaVM, downLinkType)
          options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
           filter:ifIntegerChanged
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             [self updateButtonStates];
             return YES;
         }];
//2018-10-19 11:10:56 mikasa 监听线路变化
    
//  2018-10-19 13:16:39 mikasa 监听清晰度变化
    [self bjl_kvo:BJLMakeProperty(self.room.recordingVM, videoDefinition)
         observer:^BOOL(id _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
//            BJLVideoDefinition videoDefinition = now.integerValue;
            [self updateButtonStates];
             return YES;
         }];
//  2018-10-19 13:16:39 mikasa 监听清晰度变化
}

- (void)updateButtonStates {
    BOOL isHorizontal = BJLIsHorizontalUI(self);
    
    // loading == before loading + loading + after exit
    BOOL loading = self.room.loadingVM || !self.room.vmsAvailable;
    
    BOOL is1toN = self.room.roomInfo.roomType == BJLRoomType_1toN;
    BOOL inGroup = self.room.loginUser.groupID != 0;
    // NOT include inGroup
    BOOL isTeacherOrAssistant = self.room.loginUser.isTeacherOrAssistant;
    BOOL isGroupTeacherOrAssistant = self.room.loginUser.isGroupTeacherOrAssistant;
    
    BOOL speakingEnabled = (self.room.speakingRequestVM.speakingEnabled || !is1toN) && !inGroup;
    BOOL drawingGranted = self.room.slideshowViewController.drawingGranted;
    BOOL drawingEnabled = self.room.slideshowViewController.drawingEnabled;
    
    BOOL penOnly = isHorizontal && drawingEnabled;
    
    BOOL hideUserList = self.room.featureConfig.hideUserList && !isTeacherOrAssistant;
    
    /* right */
//2018-10-19 14:22:56  mikasa  隐藏PPT 按钮 只有老师进来时候才有 当前客户端没有老师
//    self.pptButton.hidden = loading || penOnly || !isTeacherOrAssistant;
    self.pptButton.hidden = YES;
//2018-10-19 14:22:56  mikasa  隐藏PPT 按钮 只有老师进来时候才有 当前客户端没有老师
    
    self.handButton.hidden = loading || penOnly || isTeacherOrAssistant || inGroup || !is1toN;
    self.handButton.selected = !isTeacherOrAssistant && !isGroupTeacherOrAssistant && speakingEnabled;
    
//    2018-10-19 14:35:25 mikasa 画笔按钮隐藏 需求设计学生不能画笔PPT
//    self.penButton.hidden = loading || !(isTeacherOrAssistant || (speakingEnabled && drawingGranted));
//    self.penButton.selected = drawingEnabled;
    self.penButton.hidden = YES;
//    2018-10-19 14:35:25 mikasa 画笔按钮隐藏 需求设计学生不能画笔PPT
    
//    2018-10-19 14:36:09 mikasa 当前用户列表按钮隐藏 需求设计 无此功能
//    self.usersButton.hidden = loading || penOnly || hideUserList;
    self.usersButton.hidden = YES;
//    2018-10-19 14:36:09 mikasa 当前用户列表按钮隐藏 需求设计 无此功能
    /* right bottom */
//    2018-10-19 14:07:42 mikasa 隐藏更多按钮
//    self.moreButton.hidden = loading || penOnly;
    self.moreButton.hidden = YES;
//    2018-10-19 14:07:42 mikasa 隐藏更多按钮
    self.rotateButton.hidden = loading || penOnly;
    // 解决旋转动画过程中更改 button 状态无效的问题
    bjl_dispatch_async_main_queue(^{
        self.rotateButton.selected = isHorizontal;
    });
    
    self.micButton.hidden = loading || penOnly || !(isTeacherOrAssistant || speakingEnabled);
    self.micButton.selected = self.room.recordingVM.recordingAudio;
    NSLog(@"mic button if show hidden mikasa %d",(loading || penOnly || !(isTeacherOrAssistant || speakingEnabled)));
    
    self.cameraButton.hidden = loading || penOnly || !(isTeacherOrAssistant || speakingEnabled);
    self.cameraButton.selected = self.room.recordingVM.recordingVideo;
    
    /* left bottom */
    
    self.chatButton.hidden = loading || penOnly;
//    2018-10-19 11:25:57 mikasa 底部添加线路按钮
    self.lineroadButton.hidden = loading || penOnly;
    NSString *titleStr =  self.room.mediaVM.downLinkType == BJLLinkType_TCP ?@"线路1" :@"线路2";
    [self.lineroadButton setTitle:titleStr forState:UIControlStateNormal];
    [self.lineroadButton.titleLabel setFont:[UIFont systemFontOfSize:13.]];
//    2018-10-19 11:25:57 mikasa 底部添加线路按钮
    
//2018-10-19 13:20:59 mikasa 底部添加清晰度按钮
    self.sharpButton.hidden = loading || penOnly;
    NSString *sharpTitle = self.room.recordingVM.videoDefinition == BJLVideoDefinition_std ? @"流畅":@"高清";
    [self.sharpButton setTitle:sharpTitle forState:UIControlStateNormal];
    [self.sharpButton.titleLabel setFont:[UIFont systemFontOfSize:13.]];
//2018-10-19 13:20:59 mikasa 底部添加清晰度按钮
}

#pragma mark - makeActions

- (void)makeActions {
    bjl_weakify(self);
    
    [self.pptButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        if (self.pptCallback) self.pptCallback(sender);
    } forControlEvents:UIControlEventTouchUpInside];
    
    [self.handButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        [sender bjl_disableForSeconds:BJLRobotDelayS];
        if (self.handCallback) self.handCallback(sender);
    } forControlEvents:UIControlEventTouchUpInside];
    
    [self.penButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        if (self.penCallback) self.penCallback(sender);
    } forControlEvents:UIControlEventTouchUpInside];
    
    [self.usersButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        if (self.usersCallback) self.usersCallback(sender);
    } forControlEvents:UIControlEventTouchUpInside];
    
    [self.moreButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        if (self.moreCallback) self.moreCallback(sender);
    } forControlEvents:UIControlEventTouchUpInside];
    
    [self.rotateButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        if (self.rotateCallback) self.rotateCallback(sender);
    } forControlEvents:UIControlEventTouchUpInside];
    
    [self.micButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        [sender bjl_disableForSeconds:BJLRobotDelayM];
        if (self.micCallback) self.micCallback(sender);
    } forControlEvents:UIControlEventTouchUpInside];
    
    [self.cameraButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        [sender bjl_disableForSeconds:BJLRobotDelayM];
        if (self.cameraCallback) self.cameraCallback(sender);
    } forControlEvents:UIControlEventTouchUpInside];
    
    [self.chatButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        if (self.chatCallback) self.chatCallback(sender);
    } forControlEvents:UIControlEventTouchUpInside];
    
//2018-10-19 10:55:43 mikasa 添加线路按钮的点击处理
    [self.lineroadButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        if (self.lineroadCallback) self.lineroadCallback(sender);
    } forControlEvents:UIControlEventTouchUpInside];
//2018-10-19 10:55:43 mikasa 添加线路按钮的点击处理
    
//    2018-10-19 13:26:03 mikasa 添加清晰度按钮的点击处理
    [self.sharpButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        if (self.sharpCallback) self.sharpCallback(sender);
    } forControlEvents:UIControlEventTouchUpInside];
//    2018-10-19 13:26:03 mikasa 添加清晰度按钮的点击处理
    
}

#pragma mark - public

- (MASViewAttribute *)rightLayoutGuide {
    if (!self.isViewLoaded) {
        [self view];
    }
    return self.rightToolBar.mas_left;
}

- (MASViewAttribute *)bottomLayoutGuide {
    if (!self.isViewLoaded) {
        [self view];
    }
    return self.bottomToolBar.mas_top;
}

@end

NS_ASSUME_NONNULL_END
