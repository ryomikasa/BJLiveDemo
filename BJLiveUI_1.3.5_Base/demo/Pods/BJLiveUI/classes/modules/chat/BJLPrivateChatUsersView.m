//
//  BJLPrivateChatUsersView.m
//  BJLiveUI
//
//  Created by HuangJie on 2018/1/2.
//  Copyright © 2018年 BaijiaYun. All rights reserved.
//

#import "BJLPrivateChatUsersView.h"

#import "BJLUserCell.h"

@interface BJLPrivateChatUsersView ()

@property (nonatomic, strong) NSArray<BJLUser *> *userList;
@property (nonatomic, strong) BJLRoom *room;
@property (nonatomic, strong) BJLUser *targetUser;
@property (nonatomic, assign) BJLChatStatus chatStatus;

@property (nonatomic, strong) UIView *chatStatusView;
@property (nonatomic, strong) UIButton *emptyListView;
@property (nonatomic, strong) UILabel *chatStatusLabel;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIRefreshControl *refresh;

@end

@implementation BJLPrivateChatUsersView

- (instancetype)initWithRoom:(BJLRoom *)room {
    if (self) {
        self = [super initWithFrame:bjl_structSet((CGRect)CGRectZero, {
            set.size = [self intrinsicContentSize];
        })];
        self.room = room;
        self.frame = CGRectMake(0.0, 0.0, [UIScreen mainScreen].bounds.size.width, 266.0);
        self.backgroundColor = [UIColor bjl_lightGrayBackgroundColor];
        [self setupSubView];
        [self setupObservers];
    }
    return self;
}

#pragma mark - subViews

- (void)setupSubView {
    CGFloat margin = 15.0;
    
    // chatStatusView
    [self addSubview:self.chatStatusView];
    [self.chatStatusView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.bjl_safeAreaLayoutGuide ?: self);
        make.height.equalTo(@(0.0)); // to be updated
    }];
    
    // cancelChatButton
    UIButton *cancelChatButton = ({
        UIButton *button = [[UIButton alloc] init];
        button.titleLabel.font = [UIFont systemFontOfSize:14.0];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button setTitle:@"取消私聊" forState:UIControlStateNormal];
        [button addTarget:self action:@selector(cancelPrivateChat) forControlEvents:UIControlEventTouchUpInside];
        button;
    });
    [self.chatStatusView addSubview:cancelChatButton];
    [cancelChatButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.chatStatusView).offset(-margin);
        make.centerY.equalTo(self.chatStatusView);
    }];
    
    // chatStatusLabel
    [self.chatStatusView addSubview:self.chatStatusLabel];
    [self.chatStatusLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.chatStatusView).offset(margin);
        make.centerY.equalTo(self.chatStatusView);
        make.right.lessThanOrEqualTo(cancelChatButton.mas_left).offset(-margin);
    }];
    
    // tableView
    [self addSubview:self.tableView];
    [self.tableView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.chatStatusView.mas_bottom);
        make.left.bottom.right.equalTo(self.bjl_safeAreaLayoutGuide ?: self);
    }];
    
    // 添加refreshControl
    [self.tableView insertSubview:self.refresh atIndex:0];
    
    // 列表为空时的视图
    [self addSubview:self.emptyListView];
    [self.emptyListView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.center.equalTo(self);
    }];
}

- (void)setupObservers {
    bjl_weakify(self);
    [self bjl_kvo:BJLMakeProperty(self.room.onlineUsersVM, onlineUsers)
         observer:^BOOL(id  _Nullable old, id  _Nullable now) {
             bjl_strongify(self);
             [self loadUserListData];
             return YES;
         }];
}

#pragma mark - load data

- (void)refreshDataWithRefreshControl:(UIRefreshControl *)refreshControl {
    [self.refresh endRefreshing];
    [self loadUserListData];
}

- (void)loadUserListData {
    [self initializeUserList];
    [self.tableView reloadData];
}

/**
 【0 分组的老师、助教】可以与【所有人】互相私聊
 【非 0 分组的老师、助教】只能与【非 0 分组内所有人】互相私聊
 */
- (void)initializeUserList {
    BOOL loginUserIsAdmin = (self.room.loginUser.isTeacherOrAssistant
                             || self.room.loginUser.isGroupTeacherOrAssistant);
    NSInteger loginUserGroupID = self.room.loginUser.groupID;
    
    NSMutableArray *mutableUserList = [NSMutableArray array];
    for (BJLUser *user in self.room.onlineUsersVM.onlineUsers) {
        if ([user.ID isEqualToString:self.room.loginUser.ID]) {
            continue;
        }
        if (loginUserIsAdmin) {
            if (user.isTeacherOrAssistant
                || loginUserGroupID == 0
                || loginUserGroupID == user.groupID) {
                [mutableUserList addObject:user];
            }
        }
        else {
            if (user.isTeacherOrAssistant
                || (user.isGroupTeacherOrAssistant
                    && loginUserGroupID == user.groupID)) {
                [mutableUserList addObject:user];
            }
        }
    }
    
    self.userList = [NSArray arrayWithArray:mutableUserList];
    self.emptyListView.hidden = (self.userList.count > 0);
}

#pragma mark - chatStatus

- (void)startPrivateChatWithTargetUser:(BJLUser *)user {
    [self updateChatStatus:BJLChatStatus_Private withTargetUser:user];
    if (self.startPrivateChatCallback) {
        self.startPrivateChatCallback(user);
    }
}

- (void)cancelPrivateChat {
    [self updateChatStatus:BJLChatStatus_Default withTargetUser:nil];
    if (self.cancelPrivateChatCallback) {
        self.cancelPrivateChatCallback();
    }
}

- (void)updateChatStatus:(BJLChatStatus)chatStatus withTargetUser:(nullable BJLUser *)targetUser {
    self.chatStatus = chatStatus;
    self.targetUser = (chatStatus == BJLChatStatus_Private)? targetUser : nil;
    
    // update content
    if (chatStatus == BJLChatStatus_Private) {
        // show view
        [self.chatStatusView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.equalTo(@36.0);
        }];
        
        // text
        self.chatStatusLabel.text = [NSString stringWithFormat:@"正在和 %@ 私聊中...", self.targetUser.name];
    }
    else {
        // reset
        [self.chatStatusView mas_updateConstraints:^(MASConstraintMaker *make) {
            make.height.equalTo(@0.0);
        }];
    }
    [self.tableView reloadData];
}

#pragma mark - <UITableViewDataSource>

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.userList.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    BJLUser *user = [self.userList bjl_objectOrNilAtIndex:indexPath.row];
    NSString *cellIdentifier = [BJLUserCell cellIdentifierForUserState:BJLUserState_online
                                                  isTeacherOrAssistant:self.room.loginUser.isTeacherOrAssistant
                                                           isPresenter:NO // need not
                                                              userRole:user.role
                                                              hasVideo:NO
                                                          videoPlaying:NO];
    BJLUserCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier forIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.backgroundColor = ([self.targetUser.ID isEqualToString:user.ID])? [UIColor whiteColor] : [UIColor clearColor];
    [cell updateWithUser:user];
    return cell;
}

#pragma mark - <UITableViewDelegate>

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    BJLUser *user = [self.userList bjl_objectOrNilAtIndex:indexPath.row];
    [self startPrivateChatWithTargetUser:user];
}

#pragma mark - <UIScrollViewDelegate>

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (!scrollView.dragging && !scrollView.decelerating) {
        return;
    }
    if (self.room.onlineUsersVM.hasMoreOnlineUsers
        && [self atTheBottomOfTableView]) {
        [self.room.onlineUsersVM loadMoreOnlineUsersWithCount:20];
    }
}

- (BOOL)atTheBottomOfTableView {
    CGFloat contentOffsetY = self.tableView.contentOffset.y;
    CGFloat bottom = self.tableView.contentInset.bottom;
    CGFloat viewHeight = CGRectGetHeight(self.tableView.frame);
    CGFloat contentHeight = self.tableView.contentSize.height;
    CGFloat bottomOffset = contentOffsetY + viewHeight - bottom - contentHeight;
    CGFloat margin = 5.0;
    return (bottomOffset >= 0.0 - margin);
}

#pragma mark - getters

- (UIView *)chatStatusView {
    if (!_chatStatusView) {
        _chatStatusView = ({
            UIView *view = [[UIView alloc] init];
            view.backgroundColor = [UIColor bjl_colorWithHexString:@"#2CA1F8"];
            view.clipsToBounds = YES;
            view;
        });
    }
    return _chatStatusView;
}

- (UILabel *)chatStatusLabel {
    if (!_chatStatusLabel) {
        _chatStatusLabel = ({
            UILabel *label = [[UILabel alloc] init];
            label.font = [UIFont systemFontOfSize:14.0];
            label.textColor = [UIColor whiteColor];
            label.numberOfLines = 0;
            label;
        });
    }
    return _chatStatusLabel;
}

- (UITableView *)tableView {
    if (!_tableView) {
        _tableView = ({
            UITableView *tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
            tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
            tableView.backgroundColor = [UIColor clearColor];
            tableView.rowHeight = 46.0;
            if (@available(iOS 9.0, *)) {
                tableView.cellLayoutMarginsFollowReadableWidth = NO;
            }
            tableView.dataSource = self;
            tableView.delegate = self;
            for (NSString *cellIdentifier in [BJLUserCell allCellIdentifiers]) {
                [tableView registerClass:[BJLUserCell class] forCellReuseIdentifier:cellIdentifier];
            }
            tableView;
        });
    }
    return _tableView;
}

- (UIRefreshControl *)refresh {
    if (!_refresh) {
        _refresh = [[UIRefreshControl alloc] init];
        [_refresh addTarget:self
                     action:@selector(refreshDataWithRefreshControl:)
           forControlEvents:UIControlEventValueChanged];
    }
    return _refresh;
}

- (UIButton *)emptyListView {
    if (!_emptyListView) {
        _emptyListView = ({
            UIButton *button = [[UIButton alloc] init];
            button.titleLabel.font = [UIFont systemFontOfSize:14.0];
            [button setTitleColor:[UIColor bjl_grayTextColor] forState:UIControlStateNormal];
            [button setTitleColor:[UIColor bjl_lightGrayTextColor] forState:UIControlStateHighlighted];
            [button setTitle:@"暂无可私聊对象，点击刷新" forState:UIControlStateNormal];
            [button addTarget:self action:@selector(loadUserListData) forControlEvents:UIControlEventTouchUpInside];
            button.hidden = YES;
            button;
        });
    }
    return _emptyListView;
}

- (NSArray<BJLUser *> *)userList {
    if (!_userList) {
        _userList = [NSArray array];
    }
    return _userList;
}

@end
