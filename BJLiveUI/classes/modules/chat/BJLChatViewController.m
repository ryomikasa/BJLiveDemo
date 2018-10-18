//
//  BJLChatViewController.m
//  BJLiveUI
//
//  Created by MingLQ on 2017-03-02.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import <BJLiveBase/BJLHitTestView.h>
#import <SafariServices/SafariServices.h>

#import "BJLChatViewController.h"
#import "BJLChatViewController+recentMessages.h"

#import "BJLChatUploadingTask.h"

#import "BJLMessageCell.h"

#import "UITableView+HeightCache.h"

NS_ASSUME_NONNULL_BEGIN

static const NSTimeInterval highlightingDelay = 5.0;
static const NSTimeInterval updateAlphaInterval = 0.2;

#pragma mark -

/**
 关于发送图片：
 1、每次只能选择一张图片，尽量避免同时上传多张图片引发的问题；
 2、前一张图片没上传完成时，允许选择另一张图片上传，这样体验稍好；
 3、上传图片与其它消息混在一起显示，不使用单独的 section 显示发送队列，避免上传多张图片时引发新消息不显示在底部、点击未读消息的滚动等问题；
 4、上传过程中收到消息显示在消息列表末尾，上传成功后不改变上传图片在列表中的位置，这可能会导致发送者与接收者看到的顺序不一致 —— 微信也是如此；
 5、图片的上传、发送完全并行，不保证发送、接收顺序，避免一个失败其它都无法发送、第一个上传很慢的上传完成后瞬间发送消息过多等问题，这与其它消息的处理保持一致；
 */
@interface BJLChatViewController ()

@property (nonatomic, readonly, weak) BJLRoom *room;

// 私聊
@property (nonatomic) BJLChatStatus chatStatus;
@property (nonatomic, nullable) BJLUser *targetUser;

@property (nonatomic) UIButton *unreadMessagesTipButton;
@property (nonatomic, readwrite) UIView *chatStatusView;
@property (nonatomic) UILabel *chatStatusLabel;

// NOTE: show sendingMessages in the second section
@property (nonatomic) NSMutableArray<id/* BJLMessage * || BJLChatUploadingTask * */> *allMessages, *currentDataSource;
@property (nonatomic) NSMutableDictionary<NSString *, NSMutableArray *> *whisperMessageDict;

@property (nonatomic) NSMutableArray<BJLMessage *> *unreadMessages, *unreadWhisperMessages;/*, *sendingMessages*/
@property (nonatomic) NSInteger unreadMessagesCount;
@property (nonatomic) NSMutableDictionary<NSString *, UIImage *> *thumbnailForURLString;

// @property (nonatomic, copy) NSDictionary<NSString *, BJLEmoticon *> *allEmoticons;

@property (nonatomic, nullable) NSTimer *updateAlphaTimer;

@property (nonatomic) BOOL wasAtTheBottomOfTableView;

@property (nonatomic) CGFloat movementForShowing, movementForHiding;
@property (nonatomic) CGRect frameForShowing, frameForHiding;

@end

@implementation BJLChatViewController

#pragma mark -

#pragma mark - lifecycle & <BJLRoomChildViewController>

- (instancetype)initWithStyle:(UITableViewStyle)style {
    return nil;
}

- (instancetype)initWithRoom:(BJLRoom *)room {
    self = [super initWithStyle:UITableViewStylePlain];
    if (self) {
        self->_room = room;
        
        /*
        self.allEmoticons = ({
            NSMutableDictionary *allEmoticons = [NSMutableDictionary new];
            for (BJLEmoticon *emoticon in [BJLEmoticon allEmoticons]) {
                [allEmoticons bjl_setObjectOrNil:emoticon
                                     forKeyOrNil:emoticon.key];
            }
            allEmoticons;
        }); */
        
        self.allMessages = [NSMutableArray new];
        self.currentDataSource = self.allMessages;
        self.unreadMessages = [NSMutableArray new];
        self->_messagesReceivingTimeInterval = [NSMutableArray new];
        
        self.thumbnailForURLString = [NSMutableDictionary new];
        
        self.alphaMin = 0.2;
        self.alphaMax = 1.0;
    }
    return self;
}

- (void)loadView {
    self.view = [BJLHitTestView viewWithFrame:[UIScreen mainScreen].bounds hitTestBlock:^UIView * _Nullable(UIView * _Nullable hitView, CGPoint point, UIEvent * _Nullable event) {
        if ([hitView isKindOfClass:[UIButton class]]) {
            return hitView;
        }
        UITableViewCell *cell = [hitView bjl_closestViewOfClass:[UITableViewCell class] includeSelf:NO];
        if (cell && hitView != cell.contentView) {
            return hitView;
        }
        return nil;
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    [self setupSubviews];
    
    bjl_weakify(self);
    [self bjl_kvo:BJLMakeProperty(self.room, vmsAvailable)
           filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
               // bjl_strongify(self);
               return now.boolValue;
           }
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             [self makeObserving];
             return YES;
         }];
    
    self.movementForShowing = 0.0;
    self.frameForShowing = CGRectZero;
    
    self.movementForHiding = 0.0;
    self.frameForHiding = CGRectZero;
}

- (void)viewWillLayoutSubviews {
    [super viewWillLayoutSubviews];
    
    self.wasAtTheBottomOfTableView = [self atTheBottomOfTableView];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    
    self.tableView.scrollIndicatorInsets = bjl_structSet(self.tableView.scrollIndicatorInsets, {
        CGFloat adjustment = CGRectGetWidth(self.view.frame) - BJLScrollIndicatorSize;
        set.left = - adjustment;
        set.right = adjustment;
    });
    
    if (self.wasAtTheBottomOfTableView && ![self atTheBottomOfTableView]) {
        [self scrollToTheEndTableView];
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    [self loadUnreadMessages];
    [self scrollToTheEndTableView];
    
    bjl_weakify(self);
    [self.updateAlphaTimer invalidate];
    self.updateAlphaTimer = [NSTimer bjl_scheduledTimerWithTimeInterval:updateAlphaInterval repeats:YES block:^(NSTimer *timer) {
        bjl_strongify(self);
        [self updateAlphaForCellsWithAnimationDuration:updateAlphaInterval];
    }];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.updateAlphaTimer invalidate];
    self.updateAlphaTimer = nil;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    [self.thumbnailForURLString removeAllObjects];
}

- (void)dealloc {
    [self.updateAlphaTimer invalidate];
    self.updateAlphaTimer = nil;
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self];
}

#pragma mark - subviews

- (void)setupSubviews {
    CGFloat margin = 15.0;
    
    // chatStatusView
    self.chatStatusView = ({
        UIView *view = [[UIView alloc] init];
        view.backgroundColor = [UIColor bjl_colorWithHexString:@"#2CA1F8"];
        view.clipsToBounds = YES;
        view.layer.masksToBounds = YES;
        view.layer.cornerRadius = 18.0;
        view;
    });
    [self.view addSubview:self.chatStatusView];
    [self.chatStatusView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.bjl_safeAreaLayoutGuide ?: self.view).offset(10.0);
        make.left.equalTo(self.view.bjl_safeAreaLayoutGuide ?: self.view).offset(-18.0);
        make.right.lessThanOrEqualTo(self.view.bjl_safeAreaLayoutGuide ?: self.view);
        make.height.equalTo(@(0.0));
    }];
    // cancelChatButton
    UIButton *cancelChatButton = ({
        UIButton *button = [[UIButton alloc] init];
        [button setImage:[UIImage imageNamed:@"bjl_ic_close"] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(cancelPrivateChat) forControlEvents:UIControlEventTouchUpInside];
        button;
    });
    [self.chatStatusView addSubview:cancelChatButton];
    [cancelChatButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.chatStatusView).offset(-margin);
        make.centerY.equalTo(self.chatStatusView);
    }];
    // chatStatusLabel
    self.chatStatusLabel = ({
        UILabel *label = [[UILabel alloc] init];
        label.font = [UIFont systemFontOfSize:14.0];
        label.textColor = [UIColor whiteColor];
        label.numberOfLines = 0;
        label;
    });
    [self.chatStatusView addSubview:self.chatStatusLabel];
    [self.chatStatusLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view.bjl_safeAreaLayoutGuide ?: self.view).offset(margin);
        make.centerY.equalTo(self.chatStatusView);
        make.right.equalTo(cancelChatButton.mas_left).offset(-margin);
    }];
    
    // tableView
    [self setupTableView];
    [self.tableView bjl_removeAllConstraints];
    [self.tableView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.chatStatusView.mas_bottom);
        make.left.bottom.right.equalTo(self.view.bjl_safeAreaLayoutGuide ?: self.view);
    }];
    
    // unreadMessage
    [self setupUnreadMessagesTipButton];
}

#pragma mark - private

- (void)setupUnreadMessagesTipButton {
    self.unreadMessagesTipButton = ({
        UIButton *button = [UIButton new];
        button.titleLabel.font = [UIFont systemFontOfSize:14.0];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        UIImage *icon = [UIImage imageNamed:@"bjl_ic_arrow_moremsg"];
        [button setImage:icon forState:UIControlStateNormal];
        button.backgroundColor = [UIColor bjl_darkDimColor];
        CGFloat midSpace = 3.0;
        button.titleEdgeInsets = UIEdgeInsetsMake(0.0, midSpace, 0.0, - midSpace);
        button.contentEdgeInsets = UIEdgeInsetsMake(0.0, BJLViewSpaceM, 0.0, BJLViewSpaceM + midSpace);
        button.layer.cornerRadius = 5.0;
        button;
    });
    [self.view addSubview:self.unreadMessagesTipButton];
    [self.unreadMessagesTipButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.view).offset(BJLScrollIndicatorSize);
        make.bottom.equalTo(self.view);
        CGFloat height = [BJLMessageCell estimatedRowHeightForMessageType:BJLMessageType_text];
        make.height.equalTo(@(height));
    }];
    
    bjl_weakify(self);
    [self.unreadMessagesTipButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        if (self.unreadMessagesCount > 0) {
            [self loadUnreadMessages];
            [self scrollToTheEndTableView];
        }
        else {
            [self updateUnreadMessagesTipWithCount:0];
        }
    } forControlEvents:UIControlEventTouchUpInside];
    
    self.unreadMessagesTipButton.hidden = YES;
}

- (void)updateUnreadMessagesTipWithCount:(NSInteger)unreadMessagesCount {
    if (unreadMessagesCount > 0) {
        NSString *title = [NSString stringWithFormat:@"%td条新消息", unreadMessagesCount];
        [self.unreadMessagesTipButton setTitle:title forState:UIControlStateNormal];
        self.unreadMessagesTipButton.hidden = NO;
    }
    else {
        [self.unreadMessagesTipButton setTitle:nil forState:UIControlStateNormal];
        self.unreadMessagesTipButton.hidden = YES;
    }
}

- (void)loadUnreadMessages {
    if (self.unreadMessages.count <= 0) {
        return;
    }
    [self.unreadMessages removeAllObjects];
    self.unreadMessagesCount = [self.unreadMessages count];
    [self updateUnreadMessagesTipWithCount:self.unreadMessagesCount];
    [self updateReceivingTimeIntervalWithAllMessagesCount:self.currentDataSource.count];
}

- (void)startHighlighting {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(stopHighlighting)
                                               object:nil];
    _messagesHighlighting = YES;
    [self updateAlphaForCellsWithAnimationDuration:updateAlphaInterval];
}

- (void)stopHighlighting {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(stopHighlighting)
                                               object:nil];
    _messagesHighlighting = NO;
    [self updateAlphaForCellsWithAnimationDuration:updateAlphaInterval];
}

- (void)stopHighlightingWithDelay {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(stopHighlighting)
                                               object:nil];
    [self performSelector:@selector(stopHighlighting)
               withObject:nil
               afterDelay:highlightingDelay];
}

- (void)makeObserving {
    bjl_weakify(self);
    
    [self bjl_observe:BJLMakeMethod(self.room.chatVM, receivedMessagesDidOverwrite:)
             observer:^BOOL(NSArray<BJLMessage *> * _Nullable messages) {
                 bjl_strongify(self);
                 
                 [self.unreadMessages removeAllObjects];
                 self.unreadMessagesCount = [self.unreadMessages count];
                 
                 [self clearDataSource]; // 清空群聊、私聊数据源 及 高度缓存
                 [self.allMessages addObjectsFromArray:self.room.chatVM.receivedMessages];
                 [self updateCurrentDataSource];
                 [self scrollToTheEndTableView];
                 return YES;
             }];
    
    [self bjl_observe:BJLMakeMethod(self.room.chatVM, didReceiveMessage:)
             observer:^BOOL(BJLMessage *message) {
                 bjl_strongify(self);
                 BOOL wasAtTheBottomOfTableView = [self atTheBottomOfTableView];
                 if (message) {
                     BOOL replacedTask = NO;
                     if (message.type == BJLMessageType_image
                         && [message.fromUser.number isEqualToString:self.room.loginUser.number]) {
                         for (id object in [self.currentDataSource copy]) {
                             BJLChatUploadingTask *task = bjl_cast(BJLChatUploadingTask, object);
                             if (task.state == BJLUploadState_uploaded
                                 && [task.result isEqualToString:message.imageURLString]) {
                                 [self.thumbnailForURLString bjl_setObjectOrNil:task.thumbnail
                                                                    forKeyOrNil:message.imageURLString];
                                 [self replaceTask:task withMessage:message];
                                 replacedTask = YES;
                                 break;
                             }
                         }
                     }
                     
                     // targetUserNumber：群聊消息中为空，私聊消息中为私聊对象的 number
                     NSString *targetUserNumber;
                     NSString *toUserNumber = message.toUser.number;
                     if (toUserNumber.length > 0) {
                         NSString *fromUserNumber = message.fromUser.number;
                         targetUserNumber = [self.room.loginUser.number isEqualToString:toUserNumber]? fromUserNumber : toUserNumber;
                     }
                     
                     // 新增消息而非替换
                     if (!replacedTask) {
                         // 未读消息
                         BOOL shouldUpdateUnreadMessage = (self.chatStatus != BJLChatStatus_Private);
                         if (self.chatStatus == BJLChatStatus_Private) {
                             // 私聊状态时，收到当前私聊的消息才更新未读消息数
                             shouldUpdateUnreadMessage = [targetUserNumber isEqualToString:self.targetUser.number];
                         }
                         
                         // 更新未读消息数
                         if (shouldUpdateUnreadMessage) {
                             [self.unreadMessages addObject:message];
                             self.unreadMessagesCount = [self.unreadMessages count];
                         }
                         
                         // 添加 messgae
                         [self addMessageToCurrentDataSource:message targetUserNumber:targetUserNumber];
                         
                         // 更新接收消息时间戳数组，必须先更新 dataSource
                         [self updateReceivingTimeIntervalWithAllMessagesCount:self.currentDataSource.count];
                     }
                     
                     // 滑动到底部
                     if ([message.fromUser.number isEqualToString:self.room.loginUser.number] || wasAtTheBottomOfTableView) {
                         [self scrollToTheEndTableView];
                     }
                 }
                 return YES;
             }];
    
    [self bjl_kvo:BJLMakeProperty(self, unreadMessagesCount)
         observer:^BOOL(id _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             NSInteger unreadMessagesCount = now.integerValue;
             if (unreadMessagesCount > 0 && [self atTheBottomOfTableView]) {
                 [self loadUnreadMessages];
                 [self scrollToTheEndTableView];
             }
             else {
                 [self updateUnreadMessagesTipWithCount:unreadMessagesCount];
             }
             return YES;
         }];
}

#pragma mark - public

- (void)refreshMessages {
    [self loadUnreadMessages];
    [self scrollToTheEndTableView];
    [self startHighlighting];
    [self stopHighlightingWithDelay];
}

- (void)sendImageFile:(ICLImageFile *)file image:(nullable UIImage *)image {
    [self loadUnreadMessages];
    
    BJLChatUploadingTask *task = [BJLChatUploadingTask uploadingTaskWithImageFile:file room:self.room];
    [self addTaskToCurrentDataSource:task];
    
    [self startObservingUploadingTask:task];
    [task upload];
}

- (void)startObservingUploadingTask:(BJLChatUploadingTask *)task {
    bjl_weakify(self, task);
    
    [self bjl_kvo:BJLMakeProperty(task, state)
         observer:^BOOL(id _Nullable old, id _Nullable now) {
             bjl_strongify(self, task);
             [self updateCellWithUploadingTask:task];
             if (task.state == BJLUploadState_uploaded) {
                 [self sendMessageWithUploadingTask:task];
             }
             return YES;
         }];
    
    [self bjl_kvo:BJLMakeProperty(task, progress)
         observer:^BOOL(id _Nullable old, id _Nullable now) {
             bjl_strongify(self, task);
             [self updateCellWithUploadingTask:task];
             return YES;
         }];
}

- (void)updateCellWithUploadingTask:(BJLChatUploadingTask *)task {
    NSUInteger index = [self.currentDataSource indexOfObject:task];
    if (index == NSNotFound || self.currentDataSource.count <= 0) {
        return;
    }
    [self.tableView reloadData];
}

- (void)sendMessageWithUploadingTask:(BJLChatUploadingTask *)task {
    BJLUser *targetUser = (self.chatStatus == BJLChatStatus_Private)? self.targetUser : nil;
    NSDictionary *data = [BJLMessage messageDataWithImageURLString:task.result imageSize:task.imageSize];
    BJLError *error = [self.room.chatVM sendMessageData:data toUser:targetUser];
    if (error) {
        task.error = error;
        [self updateCellWithUploadingTask:task];
        [self showProgressHUDWithText:error.localizedFailureReason ?: error.localizedDescription];
    }
}

#pragma mark - chatStatus

- (void)updateChatStatus:(BJLChatStatus)chatStatus withTargetUser:(nullable BJLUser *)targetUser {
    self.chatStatus = chatStatus;
    self.targetUser = (chatStatus == BJLChatStatus_Private)? targetUser : nil;
    
    CGFloat statusViewHeight = 0.0;
    if (chatStatus == BJLChatStatus_Private) {
        self.currentDataSource = [self.whisperMessageDict bjl_objectForKey:self.targetUser.number class:[NSMutableArray class]];
        self.chatStatusLabel.text = [NSString stringWithFormat:@"正在和 %@ 私聊中...", targetUser.name];
        statusViewHeight = 36.0;
    }
    else {
        [self showProgressHUDWithText:@"私聊已取消"];
    }
    [self.chatStatusView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(statusViewHeight));
    }];
    [self updateCurrentDataSource];
    [self scrollToTheEndTableView];
}

- (void)startPrivateChatWithTargetUser:(BJLUser *)targetUser {
    [self updateChatStatus:BJLChatStatus_Private withTargetUser:targetUser];
    if (self.changeChatStatusCallback) {
        self.changeChatStatusCallback(BJLChatStatus_Private, targetUser);
    }
}

- (void)cancelPrivateChat {
    [self updateChatStatus:BJLChatStatus_Default withTargetUser:nil];
    if (self.changeChatStatusCallback) {
        self.changeChatStatusCallback(BJLChatStatus_Default, nil);
    }
}

#pragma mark - dataSource

// 整体更新数据源
- (void)updateCurrentDataSource {
    // ！！！：私聊消息在不同的聊天状态下样式不同，在切换前需要清除高度缓存
    [self.tableView clearHeightCaches];
    
    // 清空接收时间戳
    [self clearReceivingTimeInterval];
    
    // 切换数据源时清空
    if (self.chatStatus == BJLChatStatus_Private) {
        self.currentDataSource = [self.whisperMessageDict bjl_objectForKey:self.targetUser.number class:[NSMutableArray class]] ?: [NSMutableArray array];
        [self.whisperMessageDict bjl_setObjectOrNil:self.currentDataSource
                                        forKeyOrNil:self.targetUser.number];
    }
    else {
        self.currentDataSource = self.allMessages;
    }
    [self updateReceivingTimeIntervalWithAllMessagesCount:self.currentDataSource.count];
    [self.tableView reloadData];
}

// 清空数据源
- (void)clearDataSource {
    [self.allMessages removeAllObjects];
    [self.whisperMessageDict removeAllObjects];
    [self clearReceivingTimeInterval];
    [self.tableView clearHeightCaches]; //清除高度缓存
}

// 增量更新 task
- (void)addTaskToCurrentDataSource:(BJLChatUploadingTask *)task {
    if (!task || ![task isKindOfClass:[BJLChatUploadingTask class]]) {
        return;
    }
    
    [self.currentDataSource addObject:task];
    
    if (self.chatStatus == BJLChatStatus_Private) {
        [self.allMessages addObject:task];
    }
    [self.tableView reloadData];
    [self scrollToTheEndTableView];
}

// message 替换 task
- (void)replaceTask:(BJLChatUploadingTask *)task withMessage:(BJLMessage *)message {
    NSInteger index = [self.currentDataSource indexOfObject:task];
    [self.currentDataSource bjl_replaceObjectAtIndex:index withObjectOrNil:message];
    if (self.chatStatus == BJLChatStatus_Private) {
        // ！！！：私聊状态下，allMessages 也需要更新
        NSInteger indexInAll  = [self.allMessages indexOfObject:task];
        [self.allMessages bjl_replaceObjectAtIndex:indexInAll withObjectOrNil:message];
    }
    [self.tableView reloadData];
}

// 增量更新 messages
- (void)addMessageToCurrentDataSource:(BJLMessage *)message targetUserNumber:(nullable NSString *)targetUserNumber{
    [self.allMessages addObject:message];
    if (targetUserNumber.length > 0) {
        // 私聊消息
        NSMutableArray *whisperMessages = [self.whisperMessageDict bjl_objectForKey:targetUserNumber class:[NSMutableArray class]] ?: [NSMutableArray array];
        [whisperMessages addObject:message];
        [self.whisperMessageDict bjl_setObjectOrNil:whisperMessages
                                        forKeyOrNil:targetUserNumber];
    }
    [self.tableView reloadData];
}

#pragma mark - <UIContentContainer>

- (void)willTransitionToTraitCollection:(UITraitCollection *)newCollection withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super willTransitionToTraitCollection:newCollection withTransitionCoordinator:coordinator];
    NSLog(@"%@ willTransitionToSizeClasses: %td-%td",
          NSStringFromClass([self class]), newCollection.horizontalSizeClass, newCollection.verticalSizeClass);
    
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> _Nonnull context) {
        [self.tableView reloadData]; // 更改聊天背景色
    } completion:nil];
}

#pragma mark - tableView

- (void)setupTableView {
    self.tableView.backgroundColor = [UIColor clearColor];
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.indicatorStyle = UIScrollViewIndicatorStyleBlack;
    
    self.tableView.allowsSelection = YES;
    
    for (NSString *cellIdentifier in [BJLMessageCell allCellIdentifiers]) {
        [self.tableView registerClass:[BJLMessageCell class]
               forCellReuseIdentifier:cellIdentifier];
    }
    
    self.tableView.contentInset = bjl_structSet(self.tableView.contentInset, {
        set.top = /* set.bottom = */ BJLViewSpaceS;
    });
    self.tableView.scrollIndicatorInsets = bjl_structSet(self.tableView.contentInset, {
        set.top = /* set.bottom = */ BJLViewSpaceS;
    });
    
    self.tableView.estimatedRowHeight = [BJLMessageCell estimatedRowHeightForMessageType:BJLMessageType_text];
    
    if (@available(iOS 11.0, *)) {
        self.tableView.insetsContentViewsToSafeArea = NO;
    }
}

- (void)scrollToTheEndTableView {
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
    if ([self atTheBottomOfTableView]) {
        // 已在最底部
        return;
    }
    
    NSInteger section = 0;
    NSInteger numberOfRows = [self.tableView numberOfRowsInSection:section];
    if (numberOfRows <= 0) {
        return;
    }
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:numberOfRows - 1
                                                inSection:section];
    [self.tableView scrollToRowAtIndexPath:indexPath
                          atScrollPosition:UITableViewScrollPositionBottom
                                  animated:NO];
}

- (BOOL)atTheTopOfTableView {
    CGFloat contentOffsetY = self.tableView.contentOffset.y;
    CGFloat top = self.tableView.contentInset.top;
    CGFloat topOffset = contentOffsetY + top;
    return topOffset >= 0.0 + BJLViewSpaceS;
}

- (BOOL)atTheBottomOfTableView {
    CGFloat contentOffsetY = self.tableView.contentOffset.y;
    CGFloat bottom = self.tableView.contentInset.bottom;
    CGFloat viewHeight = CGRectGetHeight(self.tableView.frame);
    CGFloat contentHeight = self.tableView.contentSize.height;
    CGFloat bottomOffset = contentOffsetY + viewHeight - bottom - contentHeight;
    return bottomOffset >= 0.0 - BJLViewSpaceS;
}

#pragma mark - <UITableViewDataSource>

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.currentDataSource.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BJLMessage *message = bjl_cast(BJLMessage, [self.currentDataSource bjl_objectOrNilAtIndex:indexPath.row]);
    BJLChatUploadingTask *task = bjl_cast(BJLChatUploadingTask, [self.currentDataSource bjl_objectOrNilAtIndex:indexPath.row]);
    BOOL isHorizontal = BJLIsHorizontalUI(self);
    
    if (message) {
        NSString *cellIdentifier = [BJLMessageCell cellIdentifierForMessageType:message.type];
        BJLMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier
                                                               forIndexPath:indexPath];
        
        [cell updateWithMessage:message
                    placeholder:message.imageURLString ? [self.thumbnailForURLString objectForKey:message.imageURLString] : nil
                  fromLoginUser:[message.fromUser.number isEqualToString:self.room.loginUser.number]
                     chatStatus:self.chatStatus
                 tableViewWidth:CGRectGetWidth(self.tableView.bounds)
                   isHorizontal:isHorizontal];
        bjl_weakify(self);
        cell.updateConstraintsCallback = cell.updateConstraintsCallback ?: ^(BJLMessageCell * _Nullable cell) {
            bjl_strongify(self);
            NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
            if (indexPath) {
                BOOL wasAtTheBottomOfTableView = [self atTheBottomOfTableView];
                if (wasAtTheBottomOfTableView) {
                    [self scrollToTheEndTableView];
                }
            }
        };
        cell.linkURLCallback = cell.linkURLCallback ?: ^BOOL(BJLMessageCell * _Nullable cell, NSURL * _Nonnull url) {
            bjl_strongify(self);
            BOOL shouldOpen = NO;
            NSString *scheme = url.scheme.lowercaseString;
            if ([scheme isEqualToString:@"http"] || [scheme isEqualToString:@"https"]) {
                if (@available(iOS 9.0, *)) {
                    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:url];
                    [self presentViewController:safari animated:YES completion:nil];
                }
                else {
                    shouldOpen = YES;
                }
            }
            else if ([scheme hasPrefix:@"bjhl"]) {
                shouldOpen = YES;
            }
            else {
                UIAlertController *alert = [UIAlertController
                                            alertControllerWithTitle:@"提示"
                                            message:@"不支持打开此链接"
                                            preferredStyle:UIAlertControllerStyleAlert];
                [alert bjl_addActionWithTitle:@"知道了"
                                        style:UIAlertActionStyleCancel
                                      handler:nil];
                [self presentViewController:alert animated:YES completion:nil];
            }
            return shouldOpen;
        };
        
        // 私聊
        if (self.room.featureConfig.enableWhisper) {
            cell.startPrivateChatCallback = cell.startPrivateChatCallback ?: ^(BJLMessageCell * _Nullable cell){
                bjl_strongify(self);
                NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
                if (indexPath && self.chatStatus != BJLChatStatus_Private) {
                    BJLMessage *message = bjl_cast(BJLMessage, [self.currentDataSource bjl_objectOrNilAtIndex:indexPath.row]);
                    if (message) {
                        // 获取私聊对象
                        BJLUser *targetUser = ([message.fromUser.number isEqualToString:self.room.loginUser.number]
                                               ? message.toUser
                                               : message.fromUser);
                        // 学生只能与老师或助教私聊，老师或助教能与任何人私聊, 分组教室的老师或助教只能与同组学生私聊。
                        BJLUser *loginUser = self.room.loginUser;
                        if ([loginUser canManageUser:targetUser]
                            || [targetUser canManageUser:loginUser]) {
                            [self startPrivateChatWithTargetUser:targetUser];
                        }
                    }
                }
            };
        }
        
        return cell;
    }
    else { // if task
        NSString *cellIdentifier = [BJLMessageCell cellIdentifierForUploadingImage];
        BJLMessageCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier
                                                               forIndexPath:indexPath];
        if (task) {
            [cell updateWithUploadingTask:task
                                 fromUser:self.room.loginUser
                                   toUser:self.targetUser
                               chatStatus:self.chatStatus
                           tableViewWidth:CGRectGetWidth(self.tableView.bounds)
                             isHorizontal:isHorizontal];
        }
        bjl_weakify(self);
        cell.retryUploadingCallback = cell.retryUploadingCallback ?: ^(BJLMessageCell * _Nullable cell) {
            bjl_strongify(self);
            NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
            BJLChatUploadingTask *uploadingTask = bjl_cast(BJLChatUploadingTask, [self.currentDataSource bjl_objectOrNilAtIndex:indexPath.row]);
            if (uploadingTask.error) {
                if (!uploadingTask.result) {
                    [uploadingTask upload];
                }
                else {
                    [self sendMessageWithUploadingTask:uploadingTask];
                }
            }
        };
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    [self updateAlphaForCell:cell atIndexPath:indexPath animationDuration:0.0];
}

#pragma mark - <UITableViewDelegate>

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    BJLMessage *message = bjl_cast(BJLMessage, [self.currentDataSource bjl_objectOrNilAtIndex:indexPath.row]);
    BJLChatUploadingTask *task = bjl_cast(BJLChatUploadingTask, [self.currentDataSource bjl_objectOrNilAtIndex:indexPath.row]);
    BOOL isHorizontal = BJLIsHorizontalUI(self);

    NSString *key, *identifier;
    void (^configuration)(BJLMessageCell *cell); //用于计算 cell 高度的设置
    if (message) {
        key = [NSString stringWithFormat:@"message:%@", message.ID];
        identifier = [BJLMessageCell cellIdentifierForMessageType:message.type];
        configuration = ^(BJLMessageCell *cell) {
            cell.autoSizing = YES;
            [cell updateWithMessage:message
                        placeholder:message.imageURLString ? [self.thumbnailForURLString objectForKey:message.imageURLString] : nil
                      fromLoginUser:[message.fromUser.number isEqualToString:self.room.loginUser.number]
                         chatStatus:self.chatStatus
                     tableViewWidth:CGRectGetWidth(self.tableView.bounds)
                       isHorizontal:isHorizontal];
        };
    }
    else if (task) {
        key = [NSString stringWithFormat:@"task:%@", task.imageFile.filePath];
        identifier = [BJLMessageCell cellIdentifierForUploadingImage];
        configuration = ^(BJLMessageCell *cell) {
            cell.autoSizing = YES;
            [cell updateWithUploadingTask:task
                                 fromUser:self.room.loginUser
                                   toUser:self.targetUser
                               chatStatus:self.chatStatus
                           tableViewWidth:CGRectGetWidth(self.tableView.bounds)
                             isHorizontal:isHorizontal];
        };
    }

    return [tableView bjl_cellHeightWithKey:key identifier:identifier configuration:configuration];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    
    [self startHighlighting];
    [self stopHighlightingWithDelay];
    
    BJLMessage *message = bjl_cast(BJLMessage, [self.currentDataSource bjl_objectOrNilAtIndex:indexPath.row]);
    BJLChatUploadingTask *uploadingTask = bjl_cast(BJLChatUploadingTask, [self.currentDataSource bjl_objectOrNilAtIndex:indexPath.row]);
    if ((message && message.type == BJLMessageType_image)
        || (uploadingTask && uploadingTask.thumbnail)) {
        BJLMessageCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        if (self.showImageViewCallback) self.showImageViewCallback(cell.imgView);
    }
}

#pragma mark - <UIScrollViewDelegate>

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (!scrollView.dragging && !scrollView.decelerating) {
        return;
    }
    if (self.unreadMessagesCount
        && [self atTheBottomOfTableView]) {
        [self loadUnreadMessages];
        // NO [self scrollToTheEndOf...];
    }
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self startHighlighting];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self stopHighlightingWithDelay];
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
}

#pragma mark - getters

- (NSMutableDictionary<NSString *, NSMutableArray *> *)whisperMessageDict {
    if (!_whisperMessageDict) {
        _whisperMessageDict = [[NSMutableDictionary alloc] init];
    }
    return _whisperMessageDict;
}

@end

NS_ASSUME_NONNULL_END
