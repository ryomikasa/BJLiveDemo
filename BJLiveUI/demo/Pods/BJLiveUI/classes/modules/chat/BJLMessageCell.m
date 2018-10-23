//
//  BJLMessageCell.m
//  BJLiveUI
//
//  Created by MingLQ on 2017-03-02.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import "BJLMessageCell.h"

#import "BJLViewImports.h"
#import "UITextView+BJLAttributeTapAction.h"

NS_ASSUME_NONNULL_BEGIN

@interface BJLMessageTextView : UITextView

@end

@implementation BJLMessageTextView

- (BOOL)canPerformAction:(SEL)action withSender:(nullable id)sender {
    if (action == @selector(select:)
        || action == @selector(selectAll:)
        || action == @selector(copy:)
        || action == @selector(cut:)
        || action == @selector(paste:)
        || action == @selector(delete:)) {
        return NO;
    }
    return [super canPerformAction:action withSender:sender];
}

- (CGRect)caretRectForPosition:(UITextPosition *)position {
    return CGRectZero;
}

// @see http://torimaru.com/2014/12/preventing-text-selection-in-uitextview-with-auto-detection-on/
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    // checking if a gesture is a double tap and saying NO if it is
    if ([gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]]) {
        // Apple uses private classes that are kinds of UITapGestureRecognizer
        if (![gestureRecognizer isMemberOfClass:[UITapGestureRecognizer class]]) {
            UITapGestureRecognizer *tap = (UITapGestureRecognizer *)gestureRecognizer;
            if (tap.numberOfTapsRequired > 1) {
                return NO;
            }
        }
    }
    // checking if a gesture is a long press and saying NO if it is
    else if ([gestureRecognizer isKindOfClass:[UILongPressGestureRecognizer class]]) {
        // Apple uses private classes that are kinds of UITapGestureRecognizer
        if (![gestureRecognizer isMemberOfClass:[UILongPressGestureRecognizer class]]) {
            return NO;
        }
    }
    return [super gestureRecognizerShouldBegin:gestureRecognizer];
}

@end

#pragma mark -

static NSString * const BJLMessageDefaultIdentifier = @"default";
static NSString * const BJLMessageEmoticonIdentifier = @"emoticon";
static NSString * const BJLMessageImageIdentifier = @"image";
static NSString * const BJLMessageUploadingImageIdentifier = @"image-uploading";

// verMargins = (BJLViewSpaceM + BJLViewSpaceS + BJLViewSpaceM) + BJLViewSpaceS
static const CGFloat verMargins = (10.0 + 5.0 + 10.0) + 5.0; // last 5.0: bgView.top+bottom

static const CGFloat fontSize = 14.0;
static const CGFloat oneLineMessageCellHeight = fontSize + verMargins;

static const CGFloat emoticonSize = 32.0;
static const CGFloat emoticonMessageCellHeight = emoticonSize + verMargins;

static const CGFloat imageMinWidth = 50.0, imageMinHeight = 50.0;
static const CGFloat imageMaxWidth = 100.0, imageMaxHeight = 100.0;
static const CGFloat imageMessageCellMinHeight = imageMinHeight + verMargins;

@interface BJLMessageCell () <UITextViewDelegate, BJLAttributeTapActionDelegate>

@property (nonatomic) UITextView *textView;
@property (nonatomic, readwrite) UIImageView *imgView;
@property (nonatomic) UIView *imgProgressView;
@property (nonatomic) MASConstraint *imgProgressViewHeightConstraint;
@property (nonatomic) UIButton *failedBadgeButton;
@property (nonatomic) UIView *bgView;
//2018-10-22 17:59:47 mikasa 追加用户身份tag
@property (nonatomic) UILabel *authTagL;
//2018-10-22 17:59:47 mikasa 追加用户身份tag
@property (nonatomic) BJLChatStatus chatStatus;
@property (nonatomic) CGFloat tableViewWidth;
@property (nonatomic) NSRange range_activeUserName;

@end

@implementation BJLMessageCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(nullable NSString *)reuseIdentifier {
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        [self setupSubviews];
        [self setupConstraints];
        [self prepareForReuse];
    }
    return self;
}

- (void)setupSubviews {
    self.backgroundColor = [UIColor clearColor];
    
    self.contentView.backgroundColor = [UIColor clearColor];
    
    self.bgView = ({
        UIView *view = [UIView new];
        view.backgroundColor = [UIColor whiteColor];
        view.layer.cornerRadius = 8.;
        view.layer.masksToBounds = YES;
        [self.contentView addSubview:view];
        view;
    });
    
    self.textView = ({
        UITextView *textView = [BJLMessageTextView new];
        textView.textAlignment = NSTextAlignmentLeft;
        // textView.font = [UIFont systemFontOfSize:fontSize];
        // textView.textColor = [UIColor blackColor];
        {
            textView.textContainerInset = UIEdgeInsetsZero;
            textView.textContainer.lineFragmentPadding = 0;
            // textView.textContainer.maximumNumberOfLines = 0;
            // textView.dataDetectorTypes = UIDataDetectorTypeAll;
            textView.backgroundColor = [UIColor clearColor];
            textView.selectable = YES;
            textView.editable = NO;
            textView.scrollEnabled = NO;
            textView.userInteractionEnabled = YES;
            textView.delegate = self;
        }
        [self.bgView addSubview:textView];
        textView;
    });
    
    self.authTagL = ({
        UILabel *label = [UILabel new];
        [label setTextAlignment:NSTextAlignmentCenter];
        [label setFont:[UIFont systemFontOfSize:9.]];
        [label setTextColor:[UIColor whiteColor]];
        [label.layer setCornerRadius:7.];
        [label.layer setMasksToBounds:YES];
        [label setBackgroundColor:[UIColor bjl_colorWithHexString:@"#FE754A"]];
        [self.contentView addSubview:label];
        label;
    });
    
    BOOL isEmoticon = [self.reuseIdentifier isEqualToString:BJLMessageEmoticonIdentifier];
    BOOL isImage = [self.reuseIdentifier isEqualToString:BJLMessageImageIdentifier];
    BOOL isUploadingImage = [self.reuseIdentifier isEqualToString:BJLMessageUploadingImageIdentifier];
    if (isEmoticon || isImage || isUploadingImage) {
        self.imgView = ({
            UIImageView *imageView = [UIImageView new];
            imageView.clipsToBounds = YES;
            imageView.contentMode = (isEmoticon
                                     ? UIViewContentModeScaleAspectFit
                                     : UIViewContentModeScaleAspectFill);
            [self.bgView addSubview:imageView];
            imageView;
        });
        
        if (isUploadingImage) {
            self.imgProgressView = ({
                UIView *view = [UIView new];
                view.backgroundColor = [UIColor bjl_darkDimColor];
                [self.bgView addSubview:view];
                view;
            });
            self.failedBadgeButton = ({
                UIButton *button = [UIButton new];
                [button setTitle:@"!" forState:UIControlStateNormal];
                [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
                button.backgroundColor = [UIColor bjl_redColor];
                button.layer.cornerRadius = BJLBadgeSize / 2;
                button.layer.masksToBounds = YES;
                [self.contentView addSubview:button];
                button;
            });
            bjl_weakify(self);
            [self.failedBadgeButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
                bjl_strongify(self);
                if (self.retryUploadingCallback) self.retryUploadingCallback(self);
            } forControlEvents:UIControlEventTouchUpInside];
        }
    }
}

- (void)setupConstraints {
    // <right>
    [self.bgView mas_makeConstraints:^(MASConstraintMaker *make) {
        CGFloat spaceLeft = BJLScrollIndicatorSize, spaceBottom = 3.0, spaceTop = BJLViewSpaceS;
        make.left.top.bottom.equalTo(self.contentView).insets(UIEdgeInsetsMake(spaceTop, spaceLeft, spaceBottom, 0.0));
        // <right>
        make.right.lessThanOrEqualTo(self.contentView).with.offset(self.imgView ? - (BJLBadgeSize + BJLViewSpaceS) : 0.0);
    }];
    
    [self.textView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.top.equalTo(self.bgView).with.offset(BJLViewSpaceM);
        // <right>
        make.right.equalTo(self.bgView).with.offset(- BJLViewSpaceM);
        make.right.lessThanOrEqualTo(self.bgView).with.offset(- BJLViewSpaceM);
        if (!self.imgView) {
            make.bottom.equalTo(self.bgView).with.offset(- BJLViewSpaceM);
        }
        else {
            make.bottom.equalTo(self.imgView.mas_top).with.offset(- BJLViewSpaceS);
        }
    }];
    
//2018-10-22 18:06:20 mikasa 追加用户聊天身份标识
    [self.authTagL mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.bgView).inset(5.);
        make.top.equalTo(self.bgView).inset(11.);
        make.size.mas_equalTo(CGSizeMake(26., 14.));
    }];
    
//2018-10-22 18:06:20 mikasa 追加用户聊天身份标识
    
    
    if (self.imgView) {
        [self.imgView mas_makeConstraints:^(MASConstraintMaker *make) {
            make.top.equalTo(self.textView.mas_bottom).offset(BJLViewSpaceS);
            make.left.equalTo(self.bgView).with.offset(BJLViewSpaceM);
            make.bottom.equalTo(self.bgView).with.offset(- BJLViewSpaceM);
            make.right.lessThanOrEqualTo(self.bgView).with.offset(- BJLViewSpaceM);
            make.width.equalTo(@(imageMinWidth));
            make.height.equalTo(@(imageMinHeight)).priorityHigh();
        }];
        
        if ([self.reuseIdentifier isEqualToString:BJLMessageEmoticonIdentifier]) {
            [self updateImgViewConstraintsWithSize:CGSizeMake(emoticonSize, emoticonSize)];
        }
        // else if BJLMessageImageIdentifier || BJLMessageUploadingImageIdentifier:
        // init/reset in prepareForReuse, and update in updateCell
        
        if (self.imgProgressView) {
            [self.imgProgressView mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.right.bottom.equalTo(self.imgView);
                self.imgProgressViewHeightConstraint = make.height.equalTo(@0.0);
            }];
        }
        if (self.failedBadgeButton) {
            [self.failedBadgeButton mas_makeConstraints:^(MASConstraintMaker *make) {
                make.left.equalTo(self.bgView.mas_right).with.offset(BJLViewSpaceS);
                make.centerY.equalTo(self.imgView);
                make.width.height.equalTo(@(BJLBadgeSize));
            }];
        }
    }
}

- (void)updateImgViewConstraintsWithSize:(CGSize)size {
    [self.imgView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.width.equalTo(@(size.width));
        make.height.equalTo(@(size.height)).priorityHigh();
    }];
}

- (void)prepareForReuse {
    [super prepareForReuse];
    self.textView.text = nil;
    self.imgView.image = nil;
    self.failedBadgeButton.hidden = YES;
}

#pragma mark - private updating

- (void)_updateLabelsWithMessage:(nullable NSString *)message
                        fromUser:(BJLUser *)fromUser
                          toUser:(BJLUser *)toUser
                   fromLoginUser:(BOOL)fromLoginUser
                    isHorizontal:(BOOL)isHorizontal {
    // self.textView.textColor = isHorizontal ? [UIColor whiteColor] : [UIColor blackColor];
    self.bgView.backgroundColor = isHorizontal ? [UIColor bjl_darkDimColor] : [UIColor whiteColor];
    self.bgView.layer.borderWidth = isHorizontal ? 0.0 : BJLOnePixel;
    self.bgView.layer.borderColor = isHorizontal ? nil : [UIColor bjl_grayBorderColor].CGColor;
    [self.bgView.layer setMasksToBounds:YES];
    
    // 重置点击事件
    [self.textView bjl_removeAllAttributeTapActions];
    
    // 是否为私聊消息
    BOOL isWisperMessage = (toUser.ID.length > 0 && ![toUser.ID isEqualToString:@"-1"]);
    NSString *tapActionString; // 可点击字样
  
    
    if (tapActionString.length) {
        [self.textView bjl_addAttributeTapActionWithString:tapActionString range:self.range_activeUserName delegate:self];
    }
    self.textView.dataDetectorTypes = (fromUser.isTeacherOrAssistant || fromUser.isGroupTeacherOrAssistant
                                          ? UIDataDetectorTypeLink
                                          : UIDataDetectorTypeNone);
    self.textView.linkTextAttributes = @{ NSForegroundColorAttributeName: (fromUser.isTeacherOrAssistant || fromUser.isGroupTeacherOrAssistant
                                                                           ? [UIColor bjl_blueBrandColor]
                                                                           : [UIColor bjl_lightGrayTextColor]) };
//    2018-10-23 10:47:49 mikasa 判断是否需要标签显示隐藏
    if ( [fromUser isTeacher] && self.chatStatus != BJLChatStatus_Private &&!toUser) {
        [self.authTagL setBackgroundColor:[UIColor bjl_colorWithHexString:@"#007AFF"]];
        [self.authTagL setText:@"老师"];
        [self.authTagL setHidden:NO];
    }else if ( [fromUser isAssistant] && self.chatStatus != BJLChatStatus_Private && !toUser){
        [self.authTagL setBackgroundColor:[UIColor bjl_colorWithHexString:@"#FE754A"]];
        [self.authTagL setText:@"助教"];
        [self.authTagL setHidden:NO];
    }else{
        [self.authTagL setHidden:YES];
    }
    
    self.textView.attributedText = ({
        NSMutableAttributedString *string = [[NSMutableAttributedString alloc] init];
        
        // fromUser
        //        NSString *fromUserName = fromLoginUser? @"我" : (fromUser.name.length > 0? fromUser.name : @"?");
        //2018-10-22 17:55:08 mikasa 修改聊天区域文字颜色显示
        //        UIColor *fromUserColor = fromLoginUser? [UIColor orangeColor] : ([fromUser canManageUser:toUser]? [UIColor bjl_blueBrandColor] : [UIColor bjl_lightGrayTextColor]);
        //        UIColor *fromUserColor = fromLoginUser? [UIColor orangeColor] : [UIColor bjl_colorWithHexString:@"#999999"];
        if ([message isEqualToString:@"mikasa"]) {
            NSLog(@"2222");
        }
        UIColor *fromUserColor;
        if (fromLoginUser) {
            fromUserColor = [UIColor orangeColor];
            if (isWisperMessage) {
                if ( self.chatStatus != BJLChatStatus_Private) {
                    self.bgView.layer.borderColor = isHorizontal ? nil : [UIColor bjl_colorWithHexString:@"#FE754A"].CGColor;
                }else{
                    self.bgView.layer.borderColor = isHorizontal ? nil : [UIColor whiteColor].CGColor;
                }
            }else{
                self.bgView.layer.borderColor = isHorizontal ? nil : [UIColor bjl_grayBorderColor].CGColor;
            }
        }else{
            if (isWisperMessage) {
                if ( self.chatStatus != BJLChatStatus_Private) {
                    self.bgView.layer.borderColor = isHorizontal ? nil : [UIColor bjl_colorWithHexString:@"#FE754A"].CGColor;
                }else{
                    self.bgView.layer.borderColor = [UIColor whiteColor].CGColor;
                }
                fromUserColor = [UIColor bjl_colorWithHexString:@"#007AFF"];
            }else{
                self.bgView.layer.borderColor = isHorizontal ? nil : [UIColor bjl_grayBorderColor].CGColor;
                fromUserColor = [UIColor bjl_colorWithHexString:@"#999999"];
            }
        }
        //2018-10-22 17:55:08 mikasa 修改聊天区域文字颜色显示
        NSString *fromUserName;
        if (fromLoginUser) { //我： || 我对xxx说
            if (isWisperMessage && self.chatStatus != BJLChatStatus_Private) {//我对xxx说
                fromUserName = @"我";
            }else{//我：
                fromUserName = @"我:";
            }
        }else{//xxx： || xxx对我说
            if (isWisperMessage && self.chatStatus != BJLChatStatus_Private) {//xxx对我说
                fromUserName = fromUser.name;
            }else{//xxx:
                fromUserName = [NSString stringWithFormat:@"%@:",fromUser.name];
            }
        }
        
        NSAttributedString *fromAttrStr = [self createAttributeStringWithText:fromUserName color:fromUserColor];
        [string appendAttributedString:fromAttrStr];
        
        if (isWisperMessage && self.chatStatus != BJLChatStatus_Private) {
            // 私聊字样
            NSAttributedString *whisperString = [self createAttributeStringWithText:@"对" color:[UIColor bjl_lightGrayTextColor]];
            [string appendAttributedString:whisperString];
            
            // toUser
            NSString *toUserName = (fromLoginUser
                                    ? (toUser.name.length > 0? toUser.name : @"?")
                                    : @"我");
            UIColor *toUserColor = (fromLoginUser
                                    ? ([toUser canManageUser:fromUser]? [UIColor bjl_blueBrandColor] : [UIColor bjl_lightGrayTextColor])
                                    : [UIColor orangeColor]);
            NSAttributedString *toAttrStr = [self createAttributeStringWithText:toUserName color:toUserColor];
            [string appendAttributedString:toAttrStr];
            
            self.range_activeUserName = (fromLoginUser
                                         ? NSMakeRange(fromAttrStr.length + whisperString.length, toAttrStr.length)
                                         : NSMakeRange(0, fromAttrStr.length));
            tapActionString = fromLoginUser ? toUserName : fromUserName;
            
            NSAttributedString *speakString = [self createAttributeStringWithText:@"说:" color:[UIColor bjl_lightGrayTextColor]];
            [string appendAttributedString:speakString];
        }
        else {
            tapActionString = fromLoginUser? nil : fromUserName;
            self.range_activeUserName = fromLoginUser? NSMakeRange(0, 0) : NSMakeRange(0, fromAttrStr.length);
        }
        
        NSString *text = message.length ? [NSString stringWithFormat:@" %@", message] : @"";
        NSMutableAttributedString *textAttrStr = [[NSMutableAttributedString alloc]
                                                  initWithString:text
                                                  attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:fontSize],
                                                               NSForegroundColorAttributeName: (isHorizontal
                                                                                                ? [UIColor whiteColor]
                                                                                                : [UIColor blackColor])
                                                               }];
        
        [string appendAttributedString:textAttrStr];
        
        //        2018-10-23 11:22:33 mikasa 判断是否需要因为加标签导致需要进行缩进
        if (([fromUser isTeacher] && self.chatStatus != BJLChatStatus_Private && !isWisperMessage) || ([fromUser isAssistant] && self.chatStatus != BJLChatStatus_Private && !isWisperMessage) ) {
            //            NSMutableParagraphStyle *paragraphStyle = [[ NSMutableParagraphStyle alloc ] init ];
            //            paragraphStyle. alignment = NSTextAlignmentLeft ;
            //            [paragraphStyle setFirstLineHeadIndent : 25.];
            //            [string addAttribute : NSParagraphStyleAttributeName value :paragraphStyle range : NSMakeRange ( 0 ,string.length)];
            [_textView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(self.bgView).with.offset(BJLViewSpaceM);
                // <right>
                make.right.equalTo(self.bgView).with.offset(- BJLViewSpaceM);
                make.right.lessThanOrEqualTo(self.bgView).with.offset(- BJLViewSpaceM);
                if (!self.imgView) {
                    make.bottom.equalTo(self.bgView).with.offset(- BJLViewSpaceM);
                }
                else {
                    make.bottom.equalTo(self.imgView.mas_top).with.offset(- BJLViewSpaceS);
                }
                NSLog(@"%@",self.authTagL);
                if (self.authTagL.hidden ==  YES) {
                    make.left.equalTo(self.bgView).offset(3);
                    //                authTagL
                }else{
                    make.left.equalTo(self.authTagL.mas_right).offset(3);
                }
                //                authTagL
            }];
        }else{
            [_textView mas_remakeConstraints:^(MASConstraintMaker *make) {
                make.top.equalTo(self.bgView).with.offset(BJLViewSpaceM);
                // <right>
                make.right.equalTo(self.bgView).with.offset(- BJLViewSpaceM);
                make.right.lessThanOrEqualTo(self.bgView).with.offset(- BJLViewSpaceM);
                if (!self.imgView) {
                    make.bottom.equalTo(self.bgView).with.offset(- BJLViewSpaceM);
                }
                else {
                    make.bottom.equalTo(self.imgView.mas_top).with.offset(- BJLViewSpaceS);
                }
                    make.left.equalTo(self.bgView).offset(3);
                
                //                authTagL
            }];
        }
        //        2018-10-23 11:22:33 mikasa 判断是否需要因为加标签导致需要进行缩进
        string;
    });
}
//    2018-10-23 10:47:49 mikasa 判断是否需要标签显示隐藏

- (NSAttributedString *)createAttributeStringWithText:(NSString *)text color:(UIColor *)color {
    return [[NSMutableAttributedString alloc] initWithString:text
                                                  attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:fontSize],
                                                               NSForegroundColorAttributeName: color}];
}

- (void)_updateImageViewWithImageOrNil:(nullable UIImage *)image size:(CGSize)size {
    self.imgView.image = image;
    [self updateImgViewConstraintsWithSize:BJLImageViewSize(image ? image.size : size, CGSizeMake(imageMinWidth, imageMinHeight), ({
        /*
        CGFloat imageMaxWidth = MAX(imageMinWidth, (self.tableViewWidth
                                                    - BJLViewSpaceM * 2
                                                    - BJLBadgeSize
                                                    - BJLViewSpaceS));
        CGFloat imageMaxHeight = MAX(imageMinHeight, imageMaxWidth / 4 * 3);
        CGSizeMake(imageMaxWidth, imageMaxHeight); */
        CGSizeMake(imageMaxWidth, imageMaxHeight);
    }))];
}

- (void)_updateImageViewWithImageURLString:(NSString *)imageURLString
                                      size:(CGSize)size
                               placeholder:(UIImage *)placeholder {
    size = (CGSizeEqualToSize(size, CGSizeZero)
            ? CGSizeMake(imageMinWidth, imageMinHeight)
            : size);
    
    [self _updateImageViewWithImageOrNil:placeholder size:size];
    
    CGSize screenSize = [UIScreen mainScreen].bounds.size;
    CGFloat maxSize = MAX(screenSize.width, screenSize.height);
    NSString *aliURLString = BJLAliIMG_aspectFit(CGSizeMake(maxSize, maxSize),
                                                 0.0,
                                                 imageURLString,
                                                 nil);
    bjl_weakify(self);
    self.imgView.backgroundColor = [UIColor bjl_grayImagePlaceholderColor];
    [self.imgView bjl_setImageWithURL:[NSURL URLWithString:aliURLString]
                          placeholder:placeholder
                           completion:^(UIImage * _Nullable image, NSError * _Nullable error, NSURL * _Nullable imageURL) {
                               bjl_strongify(self);
                               if (image) {
                                   self.imgView.backgroundColor = [UIColor bjl_grayImagePlaceholderColor];
                               }
                               [self _updateImageViewWithImageOrNil:image size:image.size];
                               if (self.updateConstraintsCallback && !error) self.updateConstraintsCallback(self);
                           }];
}

#pragma mark - public updating

- (void)updateWithMessage:(BJLMessage *)message
              placeholder:(nullable UIImage *)placeholder
            fromLoginUser:(BOOL)fromLoginUser
               chatStatus:(BJLChatStatus)chatStatus
           tableViewWidth:(CGFloat)tableViewWidth
             isHorizontal:(BOOL)isHorizontal {
    self.chatStatus = chatStatus;
    self.tableViewWidth = tableViewWidth;
    
    [self _updateLabelsWithMessage:message.type == BJLMessageType_text ? message.text : nil
                          fromUser:message.fromUser
                            toUser:message.toUser
                     fromLoginUser:fromLoginUser
                      isHorizontal:isHorizontal];
    
    if (message.type == BJLMessageType_emoticon) {
        if (message.emoticon.cachedImage) {
            self.imgView.image = message.emoticon.cachedImage;
        }
        else {
            NSString *urlString = BJLAliIMG_aspectFit(CGSizeMake(emoticonSize, emoticonSize),
                                                      0.0,
                                                      message.emoticon.urlString,
                                                      nil);
            bjl_weakify(message);
            // self.imgView.backgroundColor = [UIColor bjl_grayImagePlaceholderColor];
            [self.imgView bjl_setImageWithURL:[NSURL URLWithString:urlString]
                                  placeholder:nil
                                   completion:^(UIImage * _Nullable image, NSError * _Nullable error, NSURL * _Nullable imageURL) {
                                       bjl_strongify(message);
                                       if (image) {
                                           // self.imgView.backgroundColor = nil;
                                           message.emoticon.cachedImage = image;
                                       }
                                   }];
        }
    }
    else if (message.type == BJLMessageType_image) {
        [self _updateImageViewWithImageURLString:message.imageURLString
                                            size:CGSizeMake(message.imageWidth, message.imageHeight)
                                     placeholder:placeholder];
    }
}

- (void)updateWithUploadingTask:(BJLChatUploadingTask *)task
                       fromUser:(BJLUser *)fromUser
                         toUser:(BJLUser *)toUser
                     chatStatus:(BJLChatStatus)chatStatus
                 tableViewWidth:(CGFloat)tableViewWidth
                   isHorizontal:(BOOL)isHorizontal {
    self.chatStatus = chatStatus;
    self.tableViewWidth = tableViewWidth;
    
    [self _updateLabelsWithMessage:nil
                          fromUser:fromUser
                            toUser:toUser
                     fromLoginUser:YES
                      isHorizontal:isHorizontal];
    [self _updateImageViewWithImageOrNil:task.thumbnail size:task.thumbnail.size];
    self.failedBadgeButton.hidden = !task.error;
    
    [self.imgProgressView mas_updateConstraints:^(MASConstraintMaker *make) {
        [self.imgProgressViewHeightConstraint uninstall];
        self.imgProgressViewHeightConstraint = make.height.equalTo(self.imgView).multipliedBy(1.0 - task.progress * 0.9);
    }];
}

#pragma mark -

+ (NSArray<NSString *> *)allCellIdentifiers {
    return @[ BJLMessageDefaultIdentifier,
              BJLMessageEmoticonIdentifier,
              BJLMessageImageIdentifier,
              BJLMessageUploadingImageIdentifier ];
}

+ (NSString *)cellIdentifierForMessageType:(BJLMessageType)type {
    switch (type) {
        case BJLMessageType_emoticon:
            return BJLMessageEmoticonIdentifier;
        case BJLMessageType_image:
            return BJLMessageImageIdentifier;
        default:
            return BJLMessageDefaultIdentifier;
    }
}

+ (NSString *)cellIdentifierForUploadingImage {
    return BJLMessageUploadingImageIdentifier;
}

+ (CGFloat)estimatedRowHeightForMessageType:(BJLMessageType)type {
    switch (type) {
        case BJLMessageType_emoticon:
            return emoticonMessageCellHeight;
        case BJLMessageType_image:
            return imageMessageCellMinHeight;
        default:
            return oneLineMessageCellHeight;
    }
}

#pragma mark - <UITextViewDelegate>

- (BOOL)textView:(UITextView *)textView shouldInteractWithURL:(NSURL *)URL inRange:(NSRange)characterRange {
    if (characterRange.location == self.range_activeUserName.location
         && characterRange.length == self.range_activeUserName.length) {
        if (self.startPrivateChatCallback) {
            self.startPrivateChatCallback(self);
        }
        return NO;
    }
    return self.linkURLCallback(self, URL);
}



#pragma mark - <BJLAttributeTapActionDelegate>

- (void)bjl_attributeTapReturnString:(NSString *)string range:(NSRange)range index:(NSInteger)index {
    if (range.location == self.range_activeUserName.location
        && range.length == self.range_activeUserName.length) {
        if (self.startPrivateChatCallback) {
            self.startPrivateChatCallback(self);
        }
    }
}

@end

NS_ASSUME_NONNULL_END
