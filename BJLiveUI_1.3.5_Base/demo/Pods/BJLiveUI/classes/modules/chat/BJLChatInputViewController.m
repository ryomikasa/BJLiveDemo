//
//  BJLChatInputViewController.m
//  BJLiveUI
//
//  Created by MingLQ on 2017-03-03.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import <BJLiveBase/BJLAuthorization.h>
#import <BJLiveBase/UITextView+BJLPlaceholder.h>
#import <MobileCoreServices/MobileCoreServices.h>

#import "BJLChatInputViewController.h"

#import "BJLEmoticonKeyboardView.h"
#import "BJLPrivateChatUsersView.h"

NS_ASSUME_NONNULL_BEGIN

static const CGFloat textViewMinHeight = 32.0, iconButtonSize = 24.0 + 5 * 2;

@interface BJLChatInputViewController ()

@property (nonatomic, readonly, weak) BJLRoom *room;

@property (nonatomic) UIView *contentView;

@property (nonatomic) UITextView *textView;
@property (nonatomic) UIButton *emoticonButton, *imageButton, *privateChatButton/*, *sendButton*/;
@property (nonatomic) UILabel *privateChatLabel;
@property (nonatomic) UIView *textViewTapMask;
@property (nonatomic) BJLEmoticonKeyboardView *emoticonKeyboardView;
@property (nonatomic) BJLPrivateChatUsersView *privateChatUsersView;
@property (nonatomic) UIViewController *emoticonViewController;
@property (nonatomic, weak) UIPopoverPresentationController *emoticonPopover;
@property (nonatomic) BOOL interruptedRecordingVideo;

@property (nonatomic) BJLChatStatus chatStatus;
@property (nonatomic, nullable) BJLUser *targetUser;

@end

@implementation BJLChatInputViewController

#pragma mark - lifecycle & <BJLRoomChildViewController>

- (instancetype)initWithRoom:(BJLRoom *)room {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self->_room = room;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    bjl_weakify(self);
    [self bjl_kvo:BJLMakeProperty(self.room, vmsAvailable)
           filter:^BOOL(id _Nullable old, NSNumber * _Nullable now) {
               // bjl_strongify(self);
               return now.boolValue;
           }
         observer:^BOOL(id _Nullable old, id _Nullable now) {
             bjl_strongify(self);
             [self makeSubviews];
             [self makeConstraints];
             [self makeObserving];
             [self makeCallbacks];
             return NO;
         }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillChangeFrameWithNotification:)
                                                 name:UIKeyboardWillChangeFrameNotification
                                               object:nil];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    self.emoticonButton.selected = NO;
    self.emoticonKeyboardView.emoticons = [BJLEmoticon allEmoticons];
    
    [self.textView becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardWillChangeFrameNotification
                                                  object:nil];
}

- (void)keyboardWillChangeFrameWithNotification:(NSNotification *)notification {
    NSDictionary *userInfo = notification.userInfo;
    if (!userInfo) {
        return;
    }
    
    CGRect keyboardFrame = bjl_cast(NSValue, userInfo[UIKeyboardFrameEndUserInfoKey]).CGRectValue;
    NSTimeInterval animationDuration = bjl_cast(NSNumber, userInfo[UIKeyboardAnimationDurationUserInfoKey]).doubleValue;
    UIViewAnimationOptions animationOptions = ({
        NSNumber *animationCurveNumber = bjl_cast(NSNumber, userInfo[UIKeyboardAnimationCurveUserInfoKey]);
        UIViewAnimationCurve animationCurve = (animationCurveNumber != nil
                                               ? animationCurveNumber.unsignedIntegerValue
                                               : UIViewAnimationCurveEaseInOut);
        // @see http://stackoverflow.com/a/19490788/456536
        animationCurve | animationCurve << 16; // @see UIViewAnimationOptionCurveXxxx
    });
    
    [self.view layoutIfNeeded];
    [self.contentView mas_updateConstraints:^(MASConstraintMaker *make) {
        CGFloat offset = (CGRectGetMinY(keyboardFrame) >= CGRectGetHeight([UIScreen mainScreen].bounds)
                          ? 0.0 : - CGRectGetHeight(keyboardFrame));
        make.bottom.equalTo(self.view).with.offset(offset);
    }];
    [self.view setNeedsLayout];
    // TODO: MingLQ - animate not working
    [UIView animateWithDuration:animationDuration
                          delay:0.0
                        options:animationOptions
                     animations:^{
                         [self.view layoutIfNeeded];
                     }
                     completion:nil];
}

#pragma mark - subviews

- (void)makeSubviews {
    self.contentView = ({
        UIView *view = [UIView new];
        view.backgroundColor = [UIColor bjl_lightGrayBackgroundColor];
        view;
    });
    [self.view addSubview:self.contentView];
    
    // 聊天输入框
    self.textView = ({
        UITextView *textView = [UITextView new];
        textView.backgroundColor = [UIColor whiteColor];
        textView.font = [UIFont systemFontOfSize:16.0];
        textView.textColor = [UIColor bjl_darkGrayTextColor];
        textView.bjl_placeholder = @"输入聊天内容";
        textView.bjl_placeholderColor = textView.bjl_placeholderColor ?: [UIColor colorWithRed:0.0 green:0.0 blue:0.0980392 alpha:0.22];
        textView.textContainer.lineFragmentPadding = 0.0;
        textView.textContainerInset = UIEdgeInsetsMake(8.0, BJLViewSpaceM, 8.0, BJLViewSpaceM);
        textView.layer.cornerRadius = BJLButtonCornerRadius;
        textView.layer.masksToBounds = YES;
        textView.returnKeyType = UIReturnKeySend;
        textView.enablesReturnKeyAutomatically = YES;
        textView.delegate = self;
        textView;
    });
    [self.contentView addSubview:self.textView];
    
    // 聊天框点击响应视图
    self.textViewTapMask = ({
        UIView *view = [UIView new];
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                     action:@selector(clearInputView)];
        [view addGestureRecognizer:tapGesture];
        UIPanGestureRecognizer *panGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                     action:@selector(clearInputView)];
        [view addGestureRecognizer:panGesture];

        view.hidden = YES;
        view;
    });
    [self.contentView addSubview:self.textViewTapMask];
    
    // 私聊
    if (self.room.featureConfig.enableWhisper) {
        self.privateChatButton = ({
            UIButton *button = [UIButton new];
            button.backgroundColor = [UIColor whiteColor];
            UILabel *label = ({
                UILabel *label = [UILabel new];
                label.backgroundColor = [UIColor clearColor];
                label.textColor = [UIColor bjl_grayTextColor];
                label.text = @"私聊";
                label.textAlignment = NSTextAlignmentCenter;
                label.adjustsFontSizeToFitWidth = YES;
                label.font = [UIFont systemFontOfSize:12.0];
                label.layer.masksToBounds = YES;
                label.layer.borderWidth = 0.5;
                label.layer.borderColor = [UIColor bjl_grayTextColor].CGColor;
                label.layer.cornerRadius = 2.0;
                label;
            });
            [button addSubview:label];
            [label mas_makeConstraints:^(MASConstraintMaker *make) {
                make.centerY.equalTo(button);
                make.left.right.equalTo(button).with.insets(UIEdgeInsetsMake(0.0, 8.0, 0.0, 8.0));
                make.size.mas_equalTo(CGSizeMake(32.0, 20.0));
            }];
            self.privateChatLabel = label;
            
            UIView *verticalSeparateLine = ({
                UIView *view = [[UIView alloc] init];
                view.backgroundColor = [UIColor bjl_lightGrayTextColor];
                view;
            });
            [button addSubview:verticalSeparateLine];
            [verticalSeparateLine mas_makeConstraints:^(MASConstraintMaker *make) {
                make.top.bottom.equalTo(label);
                make.right.equalTo(button);
                make.width.equalTo(@0.5);
            }];
            
            button.layer.cornerRadius = BJLButtonCornerRadius;
            button.titleLabel.adjustsFontSizeToFitWidth = YES;
            button.clipsToBounds = YES;
            button;
        });
        [self.contentView addSubview:self.privateChatButton];
    }
    
    // 自定义表情／键盘 切换
    self.emoticonButton = ({
        UIButton *button = [UIButton new];
        [button setImage:[UIImage imageNamed:@"bjl_ic_emotion"] forState:UIControlStateNormal];
        [button setImage:[UIImage imageNamed:@"bjl_ic_emotion"] forState:UIControlStateHighlighted];
        [button setImage:[UIImage imageNamed:@"bjl_ic_keybord"] forState:UIControlStateSelected];
        [button setImage:[UIImage imageNamed:@"bjl_ic_keybord"] forState:UIControlStateSelected | UIControlStateHighlighted];
        button;
    });
    [self.contentView addSubview:self.emoticonButton];
    
    // 图片消息入口，仅限老师和助教
    if (self.room.loginUser.isTeacherOrAssistant
        || self.room.loginUser.isGroupTeacherOrAssistant
        || self.room.roomInfo.roomType != BJLRoomType_1toN) {
        self.imageButton = ({
            UIButton *button = [UIButton new];
            [button setImage:[UIImage imageNamed:@"bjl_ic_img"] forState:UIControlStateNormal];
            button;
        });
        [self.contentView addSubview:self.imageButton];
    }
    
    /*
    self.sendButton = ({
        UIButton *button = [BJLButton makeRoundedRectButtonHighlighted:YES];
        [button setTitle:@"发送" forState:UIControlStateNormal];
        [self.contentView addSubview:button];
        button;
    }); */
    
    BOOL iPad = (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad);
    self.emoticonKeyboardView = [[BJLEmoticonKeyboardView alloc] initForIdiomPad:iPad];
    if (iPad) {
        self.emoticonViewController = [UIViewController new];
        [self.emoticonViewController.view addSubview:self.emoticonKeyboardView];
        [self.emoticonKeyboardView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.edges.equalTo(self.emoticonViewController.view);
        }];
    }
}

- (void)makeConstraints {
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.view);
        make.bottom.equalTo(self.view).with.offset(0); // to be update
    }];
    
    [self.textView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.contentView.bjl_safeAreaLayoutGuide ?: self.contentView).with.offset(-BJLViewSpaceM);
        make.top.bottom.equalTo(self.contentView).with.insets(UIEdgeInsetsMake(7.0, 0.0, 7.0, 0.0));
        make.height.greaterThanOrEqualTo(@(textViewMinHeight));
        make.height.equalTo(@(textViewMinHeight)).priorityHigh(); // 解决 iOS9 发送图片后 UI 不正常的问题
    }];
    
    [self.textViewTapMask mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.textView);
    }];
    
    [self.imageButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.contentView.bjl_safeAreaLayoutGuide ?: self.contentView).with.offset(BJLViewSpaceS);
        make.bottom.equalTo(self.textView).with.offset((iconButtonSize - textViewMinHeight) / 2);
        make.width.height.equalTo(@(iconButtonSize));
    }];
    
    [self.emoticonButton mas_makeConstraints:^(MASConstraintMaker *make) {
        // 可发图片
        if (self.imageButton) {
            make.left.equalTo(self.imageButton.mas_right).with.offset(BJLViewSpaceS);
        }
        else {
            make.left.equalTo(self.contentView.bjl_safeAreaLayoutGuide ?: self.contentView).with.offset(BJLViewSpaceS);
        }
        // 可私聊
        if (self.privateChatButton) {
            make.right.equalTo(self.privateChatButton.mas_left).offset(- BJLViewSpaceS);
        }
        else {
            make.right.equalTo(self.textView.mas_left).offset(- BJLViewSpaceS);
        }
        make.bottom.equalTo(self.textView).with.offset((iconButtonSize - textViewMinHeight) / 2);
        make.width.height.equalTo(@(iconButtonSize));
    }];
    
    [self.privateChatButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.emoticonButton.mas_right).with.offset(BJLViewSpaceS);
        make.right.equalTo(self.textView.mas_left);
        make.top.bottom.equalTo(self.textView);
    }];
    
    /*
    [self.sendButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.textView.mas_right).with.offset(BJLViewSpaceM);
        make.right.equalTo(self.contentView.bjl_safeAreaLayoutGuide ?: self.contentView).with.offset(- BJLViewSpaceM);
        make.bottom.equalTo(self.textView);
    }]; */
}

#pragma mark - observers

- (void)makeObserving {
    bjl_weakify(self);
    
    // emoticom
    [self.emoticonButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        self.emoticonButton.selected = !self.emoticonButton.selected;
    } forControlEvents:UIControlEventTouchUpInside];
    
    [self bjl_kvo:BJLMakeProperty(self.emoticonButton, selected)
           filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
               // bjl_strongify(self);
               return now.boolValue != old.boolValue;
           }
         observer:^BOOL(id _Nullable old, id _Nullable now) {
             bjl_strongify(self);
             if (self.emoticonButton.selected) {
                 [self.emoticonKeyboardView updateLayoutForTraitCollection:self.traitCollection animated:NO];
             }
             if (self.emoticonViewController) {
                 if (self.emoticonButton.selected) {
                     self.emoticonViewController.modalPresentationStyle = UIModalPresentationPopover;
                     self.emoticonViewController.preferredContentSize = self.emoticonKeyboardView.frame.size;
                     self.emoticonPopover = self.emoticonViewController.popoverPresentationController;
                     self.emoticonPopover.sourceView = self.emoticonButton;
                     self.emoticonPopover.sourceRect = self.emoticonButton.bounds;
                     self.emoticonPopover.permittedArrowDirections = UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown;
                     // self.emoticonPopover.backgroundColor = self.emoticonKeyboardView.backgroundColor;
                     self.emoticonPopover.delegate = self;
                     [self presentViewController:self.emoticonViewController animated:YES completion:nil];
                 }
                 else {
                     [self.emoticonViewController bjl_dismissAnimated:YES completion:nil];
                 }
             }
             else {
                 self.textView.inputView = self.emoticonButton.selected ? self.emoticonKeyboardView : nil;
                 [self.textView reloadInputViews];
             }
             return YES;
         }];
    
    // image
    [self.imageButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        [self chooseImagePickerSourceTypeFromButton:sender];
    } forControlEvents:UIControlEventTouchUpInside];
    
    // 私聊
    if (self.privateChatButton) {
        [self.privateChatButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
            bjl_strongify(self);
            if (self.emoticonButton.selected) {
                // ！！！：还原 自定义表情按钮 状态
                self.emoticonButton.selected = NO;
            }
            self.privateChatButton.selected = !self.privateChatButton.selected;
        } forControlEvents:UIControlEventTouchUpInside];
        
        [self bjl_kvo:BJLMakeProperty(self.privateChatButton, selected)
               filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
                   // bjl_strongify(self);
                   return now.boolValue != old.boolValue;
               }
             observer:^BOOL(id  _Nullable old, id  _Nullable now) {
                 bjl_strongify(self);
                 self.textView.inputView = self.privateChatButton.selected ? self.privateChatUsersView : nil;
                 [self.textView reloadInputViews];
                 return YES;
             }];
    }
    
    [self bjl_kvo:BJLMakeProperty(self.textView, inputView)
         observer:^BOOL(UIView *  _Nullable old, UIView *  _Nullable now) {
             bjl_strongify(self);
             // 光标颜色
             self.textView.tintColor = now? [UIColor clearColor] : [UIColor blueColor];
             self.textViewTapMask.hidden = !now;
             return YES;
         }];
    
    /*
    [self.sendButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        BOOL sent = [self send:self.textView.text];
        if (sent) {
            self.textView.text = nil;
            [self textViewDidChange:self.textView];
        }
    } forControlEvents:UIControlEventTouchUpInside]; */
}

#pragma mark - callbacks

- (void)makeCallbacks {
    bjl_weakify(self);
    // 选中自定义表情
    [self.emoticonKeyboardView setSelectEmoticonCallback:^(BJLEmoticon *emoticon) {
        bjl_strongify(self);
        NSDictionary *data = [BJLMessage messageDataWithEmoticonKey:emoticon.key];
        [self send:nil data:data];
    }];
    
    // 开始私聊
    [self.privateChatUsersView setStartPrivateChatCallback:^(BJLUser * _Nonnull targetUser) {
        bjl_strongify(self);
        [self updateChatStatus:BJLChatStatus_Private withTargetUser:targetUser];
        if (self.changeChatStatusCallback) {
            self.changeChatStatusCallback(BJLChatStatus_Private, targetUser);
        }
    }];
    
    // 结束私聊
    [self.privateChatUsersView setCancelPrivateChatCallback:^{
        bjl_strongify(self);
        [self updateChatStatus:BJLChatStatus_Default withTargetUser:nil];
        if (self.changeChatStatusCallback) {
            self.changeChatStatusCallback(BJLChatStatus_Default, nil);
        }
    }];
}

#pragma mark - actions

- (void)clearInputView {
    self.emoticonButton.selected = NO;
    self.textView.inputView = nil;
    [self.textView reloadInputViews];
}

#pragma mark - chatStatus

// !!!：NO CALLBACK
- (void)updateChatStatus:(BJLChatStatus)chatStatus withTargetUser:(nullable BJLUser *)targetUser {
    BOOL privateChat = (chatStatus == BJLChatStatus_Private);
    self.chatStatus = chatStatus;
    self.targetUser = privateChat? targetUser : nil;

    // update content
    self.privateChatLabel.textColor = privateChat? [UIColor bjl_blueBrandColor] : [UIColor bjl_grayTextColor];
    self.privateChatLabel.layer.borderColor = (privateChat? [UIColor bjl_blueBrandColor] : [UIColor bjl_grayTextColor]).CGColor;
    self.textView.bjl_placeholder = privateChat? [NSString stringWithFormat:@"私聊%@", self.targetUser.name] : @"输入聊天内容";
    [self.privateChatUsersView updateChatStatus:chatStatus withTargetUser:targetUser];
}

#pragma mark - send

- (BOOL)send:(NSString *)message {
    return [self send:message data:nil];
}

- (BOOL)send:(nullable NSString *)message data:(nullable NSDictionary *)data {
    if (self.presentedViewController == self.emoticonViewController) {
        [self.emoticonViewController bjl_dismissAnimated:NO completion:nil];
        self.emoticonPopover = nil;
    }
    
    BJLUser *targetUser = (self.chatStatus == BJLChatStatus_Private)? self.targetUser : nil;
    BJLError *error = (message
                       ? [self.room.chatVM sendMessage:message toUser:targetUser]
                       : data ? [self.room.chatVM sendMessageData:data toUser:targetUser] : nil);
    if (self.finishCallback) self.finishCallback(error.localizedFailureReason ?: error.localizedDescription);
    return !error;
    
    /*
#if DEBUG
    NSString *command = self.textView.text.lowercaseString;
    if ([command isEqualToString:@"-"]) {
        self.textView.text = nil;
        [self textViewDidChange:self.textView];
        [self sendMessage:@""
         "-c[ av][ log]: 开关控制台、音视频、统计\n"
         "-f: FLEX\n"
         "-g: 新手引导\n"
         "-2: 画笔模式下两指手势\n"
         "-: UNO ;)" delay:5.0];
        return YES;
    }
    if ([command hasPrefix:@"-c"]) {
        self.textView.text = nil;
        [self textViewDidChange:self.textView];
        [self back];
        LPContextInstance.consolePrintAVInfo = ([command rangeOfString:@" av"].location != NSNotFound
                                                || [command hasSuffix:@" av"]);
        LPContextInstance.consolePrintLogStat = ([command rangeOfString:@" log "].location != NSNotFound
                                                 || [command hasSuffix:@" log"]);
        LPContextInstance.consolePrintEnabled = (LPContextInstance.consolePrintAVInfo
                                                 || LPContextInstance.consolePrintLogStat);
        NSMutableArray *onOff = nil;
        if (LPContextInstance.consolePrintEnabled) {
            onOff = [NSMutableArray new];
            if (LPContextInstance.consolePrintLogStat) {
                [onOff addObject:@"统计日志"];
            }
            if (LPContextInstance.consolePrintAVInfo) {
                [onOff addObject:@"音视频日志"];
            }
        }
        [self sendMessageAfterBack:[NSString stringWithFormat:@"%@已%@",
                                    [onOff componentsJoinedByString:@"、"] ?: @"控制台",
                                    LPContextInstance.consolePrintEnabled ? @"开启" : @"关闭"]];
        return YES;
    }
#endif // */
}

#pragma mark - <UITextViewDelegate>

- (void)textViewDidBeginEditing:(UITextView *)textView {
}

- (void)textViewDidEndEditing:(UITextView *)textView {
    if (self.presentedViewController == self.emoticonViewController) {
        [self.presentedViewController bjl_dismissAnimated:NO completion:nil];
        self.emoticonPopover = nil;
    }
    // actionSheet || imagePicker
    else if (self.presentedViewController) {
        return;
    }
    
    if (self.finishCallback) self.finishCallback(nil);
}

- (void)textViewDidChange:(UITextView *)textView {
    static const NSInteger textMaxLines = 3;
    
    CGFloat textMaxHeight = round(self.textView.font.lineHeight * textMaxLines
                                  + self.textView.textContainerInset.top
                                  + self.textView.textContainerInset.bottom);
    
    // max length
    if (textView.text.length > BJLTextMaxLength_chat) {
        UITextRange *markedTextRange = textView.markedTextRange;
        if (!markedTextRange || markedTextRange.isEmpty) {
            textView.text = [textView.text substringToIndex:BJLTextMaxLength_chat];
        }
    }
    
    // dynamic heigt & max height
    CGFloat currentHeight = CGRectGetHeight(textView.frame);
    CGFloat height = [textView sizeThatFits:CGSizeMake(CGRectGetWidth(textView.frame), 0)].height;
    if (ABS(height - currentHeight) >= 0.5
        && height <= textMaxHeight) {
        [textView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.equalTo(@(height));
        }];
        [UIView animateWithDuration:BJLAnimateDurationS
                         animations:^{
                             [textView setNeedsLayout];
                             [textView layoutIfNeeded];
                         }
                         completion:^(BOOL finished) {
                             [textView scrollRangeToVisible:NSMakeRange(0, 0)];
                             [textView scrollRangeToVisible:textView.selectedRange];
                         }];
    }
    
    // self.sendButton.enabled = !!textView.text.length;
}

- (BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if ([text isEqualToString:@"\n"]) {
        BOOL sent = [self send:self.textView.text];
        if (sent) {
            self.textView.text = nil;
            [self textViewDidChange:self.textView];
        }
        return NO;
    }
    return YES;
}

#pragma mark - <UIPopoverPresentationControllerDelegate>

- (void)popoverPresentationControllerDidDismissPopover:(UIPopoverPresentationController *)popoverPresentationController {
    if (popoverPresentationController == self.emoticonPopover) {
        self.emoticonButton.selected = NO;
        self.emoticonPopover = nil;
    }
}

#pragma mark - <UIContentContainer>

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    NSLog(@"%@ willTransitionToSizeClasses: %td-%td",
          NSStringFromClass([self class]), newCollection.horizontalSizeClass, newCollection.verticalSizeClass);
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
        [self.emoticonKeyboardView updateLayoutForTraitCollection:newCollection animated:YES];
    } completion:nil];
}

#pragma mark - image

- (void)chooseImagePickerSourceTypeFromButton:(UIButton *)button {
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:button.currentTitle ?: @"发送图片"
                                message:nil
                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIImagePickerControllerSourceType sourceType = UIImagePickerControllerSourceTypeCamera;
    if ([UIImagePickerController isSourceTypeAvailable:sourceType]) {
        [alert bjl_addActionWithTitle:@"拍照"
                                style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction *action) {
                                  [self chooseImageWithSourceType:sourceType];
                              }];
    }
    
    sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    if ([UIImagePickerController isSourceTypeAvailable:sourceType]) {
        [alert bjl_addActionWithTitle:@"从相册中选取"
                                style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction *action) {
                                  [self chooseImageWithSourceType:sourceType];
                              }];
    }
    
    [alert bjl_addActionWithTitle:@"取消"
                            style:UIAlertActionStyleCancel
                          handler:nil];
    
    alert.popoverPresentationController.sourceView = button;
    alert.popoverPresentationController.sourceRect = button.bounds;
    alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown;
    
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)chooseImageWithSourceType:(UIImagePickerControllerSourceType)sourceType {
    if (sourceType == UIImagePickerControllerSourceTypeCamera) {
        [BJLAuthorization checkCameraAccessAndRequest:YES callback:^(BOOL granted, UIAlertController * _Nullable alert) {
            if (granted) {
                [self chooseImageWithCamera];
            }
            else if (alert) {
                [self presentViewController:alert animated:YES completion:nil];
            }
        }];
    }
    else {
        [BJLAuthorization checkPhotosAccessAndRequest:YES callback:^(BOOL granted, UIAlertController * _Nullable alert) {
            if (granted) {
                [self chooseImageWithFromPhotoLibrary];
            }
            else if (alert) {
                [self presentViewController:alert animated:YES completion:nil];
            }
        }];
    }
}

#pragma mark - UIImagePickerController

- (void)chooseImageWithCamera {
    self.interruptedRecordingVideo = self.room.recordingVM.recordingVideo;
    if (self.interruptedRecordingVideo) {
        [self.room.recordingVM setRecordingAudio:self.room.recordingVM.recordingAudio
                                  recordingVideo:NO];
    }
    
    UIImagePickerController *imagePickerController = [UIImagePickerController new];
    imagePickerController.sourceType = UIImagePickerControllerSourceTypeCamera;
    imagePickerController.mediaTypes = @[(NSString *)kUTTypeImage];
    imagePickerController.allowsEditing = NO;
    imagePickerController.delegate = self;
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

#pragma mark - <UIImagePickerControllerDelegate>

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *, id> *)info {
    [picker dismissViewControllerAnimated:YES completion:^{
        if (self.interruptedRecordingVideo) {
            [self.room.recordingVM setRecordingAudio:self.room.recordingVM.recordingVideo
                                      recordingVideo:YES];
            self.interruptedRecordingVideo = NO;
        }
        
        UIImage *image = info[UIImagePickerControllerOriginalImage];
        UIImage *thumbnail = [image bjl_imageFillSize:BJLAspectFillSize([UIScreen mainScreen].bounds.size,
                                                                        image.size.width / image.size.height)
                                              enlarge:NO];
        NSString *mediaType = info[UIImagePickerControllerMediaType];
        NSError *error = nil;
        ICLImageFile *imageFile = [ICLImageFile imageFileWithImage:image
                                                         thumbnail:thumbnail 
                                                         mediaType:mediaType
                                                             error:&error];
        if (!imageFile) {
            [BJLProgressHUD bjl_showHUDForText:@"照片获取出错" superview:self.view animated:YES];
            return;
        }
        
        if (self.selectImageFileCallback) self.selectImageFileCallback(imageFile, image);
        
        /*
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil);
        }); // */
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:^{
        if (self.interruptedRecordingVideo) {
            [self.room.recordingVM setRecordingAudio:self.room.recordingVM.recordingVideo
                                      recordingVideo:YES];
            self.interruptedRecordingVideo = NO;
        }
    }];
}

#pragma mark - QBImagePickerController

- (void)chooseImageWithFromPhotoLibrary {
    QBImagePickerController *imagePickerController = [QBImagePickerController new];
    imagePickerController.delegate = self;
    imagePickerController.mediaType = QBImagePickerMediaTypeImage;
    imagePickerController.allowsMultipleSelection = YES;
    imagePickerController.showsNumberOfSelectedAssets = YES;
    imagePickerController.maximumNumberOfSelection = 1; // 1: 避免刷屏
    [self presentViewController:imagePickerController animated:YES completion:nil];
}

#pragma mark - <QBImagePickerControllerDelegate>

- (void)qb_imagePickerController:(QBImagePickerController *)picker didFinishPickingAssets:(NSArray<PHAsset *> *)assets {
    NSLog(@"picked assets: %@", assets);
    [picker icl_loadImageFilesWithAssets:assets
                             contentMode:PHImageContentModeAspectFit
                              targetSize:CGSizeMake(BJLAliIMGMaxSize, BJLAliIMGMaxSize)
                           thumbnailSize:[UIScreen mainScreen].bounds.size]; // CGSizeZero
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)picker {
    NSLog(@"picking cancelled");
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - <QBImagePickerControllerDelegate_iCloudLoading>

- (void)icl_imagePickerController:(QBImagePickerController *)picker
       didFinishLoadingImageFiles:(NSArray<ICLImageFile *> *)imageFiles {
    NSLog(@"loaded imageFiles: %@", imageFiles);
    [picker dismissViewControllerAnimated:YES completion:^{
        if (self.selectImageFileCallback) self.selectImageFileCallback(imageFiles.firstObject, nil);
    }];
}

- (void)icl_imagePickerControllerDidCancelLoadingImageFiles:(QBImagePickerController *)picker {
    NSLog(@"loading cancelled");
    // [picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)icl_imagePickerController:(QBImagePickerController *)picker
        didFinishLoadingImageFile:(ICLImageFile *)imageFile {
    NSLog(@"loaded imageFile: %@", imageFile);
}

#pragma mark - getters

- (BJLPrivateChatUsersView *)privateChatUsersView {
    if (!_privateChatUsersView) {
        _privateChatUsersView = [[BJLPrivateChatUsersView alloc] initWithRoom:self.room];
    }
    return _privateChatUsersView;
}

@end

NS_ASSUME_NONNULL_END
