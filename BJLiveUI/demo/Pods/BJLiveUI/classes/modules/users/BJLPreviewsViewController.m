//
//  BJLPreviewsViewController.m
//  BJLiveUI
//
//  Created by MingLQ on 2017-06-05.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import <BJLiveBase/NSInvocation+BJL_M9Dev.h>
#import <BJLiveBase/NSObject+BJL_M9Dev.h>

#import "BJLPreviewsViewController.h"

#import "BJLPreviewCell.h"

NS_ASSUME_NONNULL_BEGIN

@interface BJLPreviewItem ()

@property (nonatomic, readwrite) BJLPreviewsType type;
@property (nonatomic, readwrite, nullable) UIView *view;
@property (nonatomic, readwrite, nullable) UIViewController *viewController;
@property (nonatomic, readwrite) CGFloat aspectRatio;
@property (nonatomic, readwrite) BJLContentMode contentMode;
@property (nonatomic, readwrite, nullable) BJLMediaUser *playingUser;

@end

@implementation BJLPreviewItem

@end

#pragma mark -

@interface _BJLPreviewsRootView : BJLHitTestView

@property (nonatomic, weak) UIButton *outsideButton;

@end

@implementation _BJLPreviewsRootView

// 解决 button 超出 bounds 之后点击失效的问题
// @see https://stackoverflow.com/questions/5432995/interaction-beyond-bounds-of-uiview
// @see https://developer.apple.com/library/content/qa/qa2013/qa1812.html
- (BOOL)pointInside:(CGPoint)point withEvent:(nullable UIEvent *)event {
    if (!self.outsideButton.hidden) {
        if (CGRectContainsPoint(self.outsideButton.frame, point)) {
            return YES;
        }
    }
    return [super pointInside:point withEvent:event];
}

@end

@interface _BJLPreviewsMoreButton : BJLImageRightButton

@end

@implementation _BJLPreviewsMoreButton

- (CGRect)contentRectForBounds:(CGRect)bounds {
    return UIEdgeInsetsInsetRect([super contentRectForBounds:bounds],
                                 UIEdgeInsetsMake(0.0, - BJLViewSpaceS, 0.0, BJLViewSpaceS));
}

@end

#pragma mark -

typedef NS_ENUM(NSInteger, BJLPreviewsSection) {
    BJLPreviewsSection_PPT,
    BJLPreviewsSection_presenter,
    BJLPreviewsSection_recording,
    BJLPreviewsSection_videoUsers,
    BJLPreviewsSection_audioUsers,
    BJLPreviewsSection_requestUsers,
    _BJLPreviewsSection_count
};

static const CGSize moreButtonSize = { .width = 85.0, .height = BJLButtonSizeS };

@interface BJLPreviewsViewController ()

@property (nonatomic, readonly, weak) BJLRoom *room;

@property (nonatomic, readwrite) UICollectionView *collectionView;
@property (nonatomic, readwrite) UIView *backgroundView;
@property (nonatomic, readwrite) UIButton *moreButton;

@property (nonatomic, readwrite, nullable) BJLPreviewItem *fullScreenItem;
@property (nonatomic, readwrite) NSInteger numberOfItems;
@property (nonatomic) BOOL didLoadAllDocuments;

@property (nonatomic, readonly) __kindof BJLUser *presenter; // NON-KVO
@property (nonatomic) BOOL presenterVideoPlaying;
@property (nonatomic, readonly) NSMutableSet *autoPlayVideoBlacklist;
@property (nonatomic, readonly) NSMutableArray<BJLMediaUser *> *videoUsers, *audioUsers;
@property (nonatomic, readwrite) NSMutableDictionary *videoLoadingList;
@property (nonatomic, readwrite) UIView *headerView;
@property (nonatomic, readwrite) UILabel *movL;

@end

@implementation BJLPreviewsViewController

- (instancetype)initWithRoom:(BJLRoom *)room {
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self->_room = room;
        self->_autoPlayVideoBlacklist = [NSMutableSet new];
        self->_videoUsers = [NSMutableArray new];
        self->_audioUsers = [NSMutableArray new];
        self->_videoLoadingList = [NSMutableDictionary new];
        // make sure collectionView, moreButton NOT be nil
        [self makeSubviews];
    }
    return self;
}

- (void)loadView {
    bjl_weakify(self);
    self.view = [_BJLPreviewsRootView viewWithFrame:[UIScreen mainScreen].bounds hitTestBlock:^UIView * _Nullable(UIView * _Nullable hitView, CGPoint point, UIEvent * _Nullable event) {
        bjl_strongify(self);
        if (hitView != self.view && hitView != self.collectionView) {
            return hitView;
        }
        return nil;
    }];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor clearColor];
    
    bjl_weakify(self);
    [self bjl_kvo:BJLMakeProperty(self.room, vmsAvailable)
           filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
               // bjl_strongify(self);
               return now.boolValue;
           }
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             [self makeConstraints];
             [self makeObserving];
             return YES;
         }];
}

#pragma mark -

- (__kindof BJLUser *)presenter {
    return (self.room.loginUserIsPresenter
            ? nil : self.room.onlineUsersVM.currentPresenter);
}

#pragma mark -

- (void)makeSubviews {
    self.collectionView = ({
        UICollectionView *collectionView = [[UICollectionView alloc] initWithFrame:self.view.bounds
                                                              collectionViewLayout:({
            UICollectionViewFlowLayout *layout = [UICollectionViewFlowLayout new];
            layout.scrollDirection = UICollectionViewScrollDirectionHorizontal;
            layout.itemSize = [BJLPreviewCell cellSize];
            layout.minimumLineSpacing = 0.0;
            layout.minimumInteritemSpacing = 0.0;
            layout.sectionInset = UIEdgeInsetsZero;
            layout;
        })];
        collectionView.backgroundColor = [UIColor clearColor];
        collectionView.bounces = YES;
        collectionView.alwaysBounceHorizontal = NO;
        collectionView.alwaysBounceVertical = NO;
        collectionView.showsHorizontalScrollIndicator = NO;
        collectionView.showsVerticalScrollIndicator = NO;
//        2018-10-17 11:27:58 mikasa collectionview 禁止滑动 需求设计如此
        [collectionView setScrollEnabled:NO];
        //        2018-10-17 11:27:58 mikasa collectionview 禁止滑动 需求设计如此
        collectionView.clipsToBounds = NO;
        collectionView.dataSource = self;
        collectionView.delegate = self;
        for (NSString *cellIdentifier in [BJLPreviewCell allCellIdentifiers]) {
            [collectionView registerClass:[BJLPreviewCell class]
               forCellWithReuseIdentifier:cellIdentifier];
        }
        [self.view addSubview:collectionView];
        collectionView;
    });
// 2018-10-17 14:39:36 mikasa collectionview 添加假头视图 @“视频”
    self.headerView =({
        UIView *headView = [UIView new];
        headView.backgroundColor = [UIColor whiteColor];
//        //2018-10-17 15:00:26 mikasa 调试 暂时屏蔽
//        [headView setHidden:YES];
//        //2018-10-17 15:00:26 mikasa 调试 暂时屏蔽
        [self.collectionView addSubview:headView];
        headView;
    });
// 2018-10-17 14:39:36 mikasa collectionview 添加假头视图 @“视频”
    
// 2018-10-17 14:39:36 mikasa collectionview 添加假头视图 @“视频”
    self.movL = ({
        UILabel *movL = [UILabel new];
        [movL setText:@"视频"];
        
        [movL setTextColor:[UIColor bjl_colorWithHex:0x222222]];
        [movL setFont:[UIFont fontWithName:@"Helvetica-Bold" size:16.]];
        [movL setTextAlignment:NSTextAlignmentLeft];
        [self.headerView addSubview:movL];
        movL;
    });
// 2018-10-17 14:39:36 mikasa collectionview 添加假头视图 @“视频”
    
    self.backgroundView = ({
        UIView *backgroundView = [UIView new];
        backgroundView.backgroundColor = [UIColor bjl_lightGrayTextColor];
        [self.view insertSubview:backgroundView atIndex:0];
        backgroundView;
    });
    
    self.moreButton = ({
        _BJLPreviewsMoreButton *button = [_BJLPreviewsMoreButton new];
        [button setTitle:@"新请求" forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button setImage:[UIImage imageNamed:@"bjl_ic_speakreq_more"] forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:14.0];
        button.backgroundColor = [UIColor bjl_blueBrandColor];
        button.layer.cornerRadius = moreButtonSize.height / 2;
        button.layer.masksToBounds = YES;
        button.midSpace = BJLViewSpaceS;
        [self.view addSubview:button];
        button;
    });
    self.moreButton.hidden = YES;
    
    bjl_cast(_BJLPreviewsRootView, self.view).outsideButton = self.moreButton;
    bjl_weakify(self);
    [self.moreButton bjl_addHandler:^(__kindof UIControl * _Nullable sender) {
        bjl_strongify(self);
        CGRect rightEdge = CGRectMake(self.collectionView.contentSize.width - 1.0, 0.0, 1.0, 1.0);
        [self.collectionView scrollRectToVisible:rightEdge animated:YES];
    } forControlEvents:UIControlEventTouchUpInside];
}

- (void)makeConstraints {
    [self.collectionView mas_makeConstraints:^(MASConstraintMaker *make) {
        //2018-10-17 15:20:10 mikasa 修改头部视图
//        make.edges.equalTo(self.view).;
        
        make.top.equalTo(self.view.mas_top).with.inset(40.);
        make.left.equalTo(self.view.mas_left);
        make.size.mas_equalTo(CGSizeMake([UIScreen mainScreen].bounds.size.width, 85.));
        //2018-10-17 15:20:10 mikasa 修改头部视图
    }];
    
    [self.backgroundView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.view);
    }];
    
    [self.moreButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.view).with.offset(moreButtonSize.height / 2);
        make.top.equalTo(self.view.mas_bottom).with.offset(BJLViewSpaceM);
        make.size.mas_equalTo(moreButtonSize);
    }];
//    2018-10-17 14:36:28 mikasa 添加假头视图 @“视频”
    [self.headerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view);
        make.top.equalTo(self.view);
        make.size.mas_equalTo(CGSizeMake([UIScreen mainScreen].bounds.size.width, 40.));
    }];
//    2018-10-17 14:36:28 mikasa 添加假头视图 @“视频”
    
    // 2018-10-17 14:39:36 mikasa collectionview 添加假头视图 @“视频”
    [self.movL mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.headerView).with.inset(15.);
        make.centerY.equalTo(self.headerView);
        make.size.mas_equalTo(CGSizeMake([UIScreen mainScreen].bounds.size.width -15., 22.5));
    }];
    // 2018-10-17 14:39:36 mikasa collectionview 添加假头视图 @“视频”
}

- (void)makeObserving {
    bjl_weakify(self);
    
    [self enterFullScreenWithPPTView];
    // 【PPT 为空时（不管画笔），老师视频全屏】
    [self bjl_observe:BJLMakeMethod(self.room.slideshowVM, allDocumentsDidOverwrite:)
               filter:^BOOL(NSArray<BJLDocument *> * _Nullable allDocuments) {
                   bjl_strongify(self);
                   self.didLoadAllDocuments = YES;
                   return allDocuments.count <= 1;
               }
             observer:^BOOL(NSArray<BJLDocument *> * _Nullable allDocuments) {
                 bjl_strongify(self);
                 if (self.room.loginUser.isTeacher) {
                     [self enterFullScreenWithRecordingView];
                 }
                 else {
                     BJLUser *onlineTeacher = self.room.onlineUsersVM.onlineTeacher;
                     BJLMediaUser *videoPlayingTeacher = [self.room.playingVM videoPlayingUserWithID:onlineTeacher.ID number:onlineTeacher.number];
                     if (videoPlayingTeacher) {
                         [self enterFullScreenWithViewForVideoPlayingUser:videoPlayingTeacher];
                     }
                 }
                 return YES;
             }];
    
    // 举手用户
    [self bjl_kvo:BJLMakeProperty(self.room.speakingRequestVM, speakingRequestUsers)
         observer:^BOOL(NSArray<BJLUser *> * _Nullable old, NSArray<BJLUser *> * _Nullable now) {
             bjl_strongify(self);
             [self reloadCollectionView];
             // 举手提示
             if (self.room.loginUser.isTeacherOrAssistant) {
                 if (now.count > old.count) {
                     [self tryToShowMoreButton];
                 }
                 else {
                     [self tryToHideMoreButton];
                 }
             }
             return YES;
         }];
    // 举手提示
    if (self.room.loginUser.isTeacherOrAssistant) {
        [self bjl_kvo:BJLMakeProperty(self.collectionView, contentSize)
             observer:^BOOL(id _Nullable old, id _Nullable now) {
                 bjl_strongify(self);
                 if (!self.moreButton.hidden) {
                     [self tryToHideMoreButton];
                 }
                 return YES;
             }];
        [self bjl_kvo:BJLMakeProperty(self.collectionView, contentOffset)
             observer:^BOOL(id _Nullable old, id _Nullable now) {
                 bjl_strongify(self);
                 if (!self.moreButton.hidden) {
                     [self tryToHideMoreButton];
                 }
                 return YES;
             }];
    }
    
    // 音视频用户 - 覆盖更新
    [self bjl_observe:BJLMakeMethod(self.room.playingVM, playingUsersDidOverwrite:)
             observer:^BOOL(NSArray<BJLMediaUser *> * _Nullable users) {
                 bjl_strongify(self);
                 [self updateVideoUsers];
                 [self updateAudioUsers];
                 [self reloadCollectionView];
                 return YES;
             }];
    // 音视频用户 - 单个更新
    [self bjl_observeMerge:@[BJLMakeMethod(self.room.playingVM, playingUserDidUpdate:old:),
                             BJLMakeMethod(self.room.playingVM, playingUserDidUpdateVideoDefinitions:old:)]
                  observer:^(BJLMediaUser * _Nullable user, BJLMediaUser * _Nullable old) {
                      bjl_strongify(self);
                      [self updateVideoUsers];
                      [self updateAudioUsers];
                      [self reloadCollectionView];
                  }];
    
    // 播放视频
    self.room.playingVM.autoPlayVideoBlock = ^BJLTupleType(BOOL autoPlay, NSInteger definitionIndex)(BJLMediaUser *user, NSInteger cachedDefinitionIndex) {
        bjl_strongify(self);
        BOOL autoPlay = user.number && ![self.autoPlayVideoBlacklist containsObject:user.number];
        NSInteger definitionIndex = cachedDefinitionIndex;
        if (autoPlay) {
            NSInteger maxDefinitionIndex = MAX(0, (NSInteger)user.definitions.count - 1);
            definitionIndex = (cachedDefinitionIndex <= maxDefinitionIndex
                               ? cachedDefinitionIndex : maxDefinitionIndex);
        }
        // 等待 self.room.playingVM.videoPlayingUsers 更新
        bjl_dispatch_async_main_queue(^{
            // 【PPT 为空时（不管画笔），老师视频全屏】
            if (!self.room.loginUser.isTeacher
                && self.didLoadAllDocuments
                && self.room.slideshowVM.allDocuments.count <= 1) {
                BJLUser *onlineTeacher = self.room.onlineUsersVM.onlineTeacher;
                BJLMediaUser *videoPlayingTeacher = [self.room.playingVM videoPlayingUserWithID:onlineTeacher.ID number:onlineTeacher.number];
                if (videoPlayingTeacher) {
                    [self enterFullScreenWithViewForVideoPlayingUser:videoPlayingTeacher];
                }
            }
        });
        return BJLTuplePack((BOOL, NSInteger), autoPlay, definitionIndex);
    };
    [self bjl_kvo:BJLMakeProperty(self.room.playingVM, videoPlayingUsers)
         observer:^BOOL(NSArray<BJLMediaUser *> * _Nullable old, id _Nullable now) {
             bjl_strongify(self);
             [self updateVideoUsers];
             [self updateAudioUsers];
             [self reloadCollectionView];
             return YES;
         }];
    
    // 主讲
    [self bjl_kvo:BJLMakeProperty(self.room.onlineUsersVM, currentPresenter)
           filter:^BOOL(id _Nullable old, id _Nullable now) {
               // bjl_strongify(self);
               return now != old;
           }
         observer:^BOOL(__kindof BJLUser * _Nullable old, __kindof BJLUser * _Nullable user) {
             bjl_strongify(self);
             [self updateVideoUsers];
             [self updateAudioUsers];
             [self reloadCollectionView];
             return YES;
         }];
    
    // 全屏
    [self bjl_kvo:BJLMakeProperty(self, fullScreenItem)
         observer:^BOOL(BJLPreviewItem * _Nullable old, BJLPreviewItem * _Nullable now) {
             bjl_strongify(self);
             if (old.type == BJLPreviewsType_playing
                 || now.type == BJLPreviewsType_playing) {
                 [self updateVideoUsers];
             }
             [self reloadCollectionView];
             return YES;
         }];
    [self bjl_observe:BJLMakeMethod(self.room.playingVM, playingViewAspectRatioChanged:forUserWithID:)
               filter:(BJLMethodFilter)^BOOL(CGFloat videoAspectRatio, NSString *userID) {
                   bjl_strongify(self);
                   return (self.fullScreenItem.type == BJLPreviewsType_playing
                           && [self.fullScreenItem.playingUser.ID isEqualToString:userID]);
               }
             observer:(BJLMethodObserver)^BOOL(CGFloat videoAspectRatio, NSString *userID) {
                 bjl_strongify(self);
                 self.fullScreenItem.aspectRatio = videoAspectRatio;
                 return YES;
             }];
    [self bjl_observeMerge:@[BJLMakeMethod(self.room.playingVM, playingUser:didUpdateDesktopSharing:),
                             BJLMakeMethod(self.room.playingVM, playingUser:didUpdateMediaPlaying:)]
               filter:(BJLMethodFilter)^BOOL(BJLMediaUser *user, BOOL on) {
                   bjl_strongify(self);
                   return (// 开始共享屏幕或者播放媒体文件
                           on
                           // 老师或者主讲触发的操作
                           && [user isSameUser:self.presenter]
                           // 正在播视频
                           && [user containedInUsers:self.room.playingVM.videoPlayingUsers]
                           // 但没有全屏
                           && !(self.fullScreenItem.type == BJLPreviewsType_playing
                                && [self.fullScreenItem.playingUser isSameUser:user]));
               }
             observer:(BJLMethodsObserver)^(BJLMediaUser *user, BOOL on) {
                 bjl_strongify(self);
                 [self enterFullScreenWithViewForVideoPlayingUser:user];
             }];
    
    [self bjl_observe:BJLMakeMethod(self.room.playingVM, playingUserDidStartLoadingVideo:)
             observer:^BOOL(BJLMediaUser *user) {
                 bjl_strongify(self);
                 [self tryToShowLoadingViewWithUser:user];
                 return YES;
             }];
    
    [self bjl_observe:BJLMakeMethod(self.room.playingVM, playingUserDidFinishLoadingVideo:)
             observer:^BOOL(BJLMediaUser *user) {
                 bjl_strongify(self);
                 [self tryToCloseLoadingViewWithUser:user];
                 return YES;
             }];
    
    // 自己
    [self bjl_kvo:BJLMakeProperty(self.room.recordingVM, recordingVideo)
         observer:^BOOL(id _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             if (self.fullScreenItem.type == BJLPreviewsType_recording) {
                 if (!now.boolValue) {
                     self.fullScreenItem = nil;
                 }
             }
             else {
                 [self reloadCollectionView];
                 // 【PPT 为空时（不管画笔），老师视频全屏】
                 if (self.room.loginUser.isTeacher
                     && self.didLoadAllDocuments
                     && self.room.slideshowVM.allDocuments.count <= 1) {
                     [self enterFullScreenWithRecordingView];
                 }
             }
             return YES;
         }];
    
    // PPT
//    [self bjl_kvo:BJLMakeProperty(self.room.slideshowViewController, isBlank)
//         observer:^BOOL(id _Nullable old, id _Nullable now) {
//             bjl_strongify(self);
//             [self reloadCollectionView];
//             return YES;
//         }];
}

- (BOOL)atTheEndOfCollectionView {
    CGFloat contentOffsetX = self.collectionView.contentOffset.x;
    CGFloat rightInset = self.collectionView.contentInset.right;
    CGFloat viewWidth = CGRectGetWidth(self.collectionView.frame);
    CGFloat contentWidth = self.collectionView.contentSize.width;
    CGFloat bottomOffset = contentOffsetX + viewWidth - rightInset - contentWidth;
    return bottomOffset >= 0.0 - [BJLPreviewCell cellSize].width / 2;
}

- (void)tryToShowMoreButton {
    if (self.moreButton.hidden && ![self atTheEndOfCollectionView]) {
        self.moreButton.hidden = NO;
    }
}

- (void)tryToHideMoreButton {
    if (!self.moreButton.hidden && [self atTheEndOfCollectionView]) {
        self.moreButton.hidden = YES;
    }
}

// videoUsers = playingVM.videoPlayingUsers - self.presenter - fullScreenItem.playingUser
- (void)updateVideoUsers {
    [self.videoUsers removeAllObjects];
    
    self.presenterVideoPlaying = NO;
    
    BOOL fullScreenPlaying = (self.fullScreenItem.type == BJLPreviewsType_playing);
    BJLMediaUser *fullScreenUser = nil;
    
    for (BJLMediaUser *videoPlayingUser in self.room.playingVM.videoPlayingUsers) {
        BOOL isPresenter = [videoPlayingUser isSameUser:self.presenter];
        if (isPresenter) {
            self.presenterVideoPlaying = YES;
        }
        
        BOOL isFullScreenUser = fullScreenPlaying && [videoPlayingUser isSameUser:self.fullScreenItem.playingUser];
        if (isFullScreenUser) {
            fullScreenUser = videoPlayingUser;
        }
        
        if (!isPresenter && !isFullScreenUser) {
            [self.videoUsers addObject:videoPlayingUser];
        }
    }
    
    if (fullScreenPlaying) {
        if (fullScreenUser) {
            self.fullScreenItem.playingUser = fullScreenUser;
        }
        else {
            self.fullScreenItem = nil;
        }
    }
}

// audioUsers = playingVM.playingUsers - self.presenter - playingVM.videoPlayingUsers
- (void)updateAudioUsers {
    [self.audioUsers removeAllObjects];
    
    for (BJLMediaUser *playingUser in self.room.playingVM.playingUsers) {
        if (![playingUser isSameUser:self.presenter]
            && ![playingUser containedInUsers:self.room.playingVM.videoPlayingUsers]) {
            [self.audioUsers addObject:playingUser];
        }
    }
}

- (void)autoEnterFullScreen {
    if (self.fullScreenItem && self.fullScreenItem.type != BJLPreviewsType_None) {
        return;
    }
    [self enterFullScreenWithPPTView];
}

- (void)enterFullScreenWithPPTView {
    self.fullScreenItem = ({
        BJLPreviewItem *item = [BJLPreviewItem new];
        item.type = BJLPreviewsType_PPT;
        item.view = nil;
        item.viewController = self.room.slideshowViewController;
        item.aspectRatio = 4.0 / 3;
        item.contentMode = BJLContentMode_scaleToFill;
        item.playingUser = nil;
        item;
    });
    [self fullScreenDidFinishLoadingVideo];
}

- (void)enterFullScreenWithRecordingView {
    if (!self.room.recordingVM.recordingVideo) {
        return;
    }
    self.fullScreenItem = ({
        BJLPreviewItem *item = [BJLPreviewItem new];
        item.type = BJLPreviewsType_recording;
        item.view = self.room.recordingView;
        item.viewController = nil;
        item.aspectRatio = self.room.recordingVM.inputVideoAspectRatio;
        item.contentMode = BJLContentMode_scaleToFill;
        item.playingUser = nil;
        item;
    });
    [self fullScreenDidFinishLoadingVideo];
}

- (void)enterFullScreenWithViewForVideoPlayingUser:(BJLMediaUser *)videoPlayingUser {
//    2018-10-18 15:57:51 mikasa 禁用单击 “全屏”||双击而触发的全屏效果 donothing
//    videoPlayingUser = [self.room.playingVM playingUserWithID:videoPlayingUser.ID number:videoPlayingUser.number];
//    if (![videoPlayingUser containedInUsers:self.room.playingVM.videoPlayingUsers]) {
//        return;
//    }
//    self.fullScreenItem = ({
//        BJLPreviewItem *item = [BJLPreviewItem new];
//        item.type = BJLPreviewsType_playing;
//        item.view = [self.room.playingVM playingViewForUserWithID:videoPlayingUser.ID];
//        item.viewController = nil;
//        item.aspectRatio = [self.room.playingVM playingViewAspectRatioForUserWithID:videoPlayingUser.ID];
//        item.contentMode = BJLContentMode_scaleToFill;
//        item.playingUser = videoPlayingUser;
//        item;
//    });
//    BOOL isLoadingViewHidden = [[self.videoLoadingList bjl_objectForKey:videoPlayingUser.ID class:[NSNumber class] defaultValue:@(YES)] boolValue];
//    if (isLoadingViewHidden) {
//        [self fullScreenDidFinishLoadingVideo];
//    }
//    else {
//        [self fullScreenDidStartLoadingVideo];
//    }
//    2018-10-18 15:57:51 mikasa 禁用单击 “全屏”||双击而触发的全屏效果 donothing
}

#pragma mark - video loading

- (void)tryToShowLoadingViewWithUser:(BJLMediaUser *)user {
    if (!user.videoOn) {
        return;
    }
    [self.videoLoadingList setValue:@(NO) forKey:user.ID];
    if (self.fullScreenItem.type == BJLPreviewsType_playing
        && [self.fullScreenItem.playingUser.ID isEqualToString:user.ID]) {
        [self fullScreenDidStartLoadingVideo];
    }
    else {
        [self reloadCollectionView];
    }
}

- (void)tryToCloseLoadingViewWithUser:(BJLMediaUser *)user {
    if (!user.videoOn) {
        return;
    }
    [self.videoLoadingList setValue:@(YES) forKey:user.ID];
    if (self.fullScreenItem.type == BJLPreviewsType_playing
        && [self.fullScreenItem.playingUser.ID isEqualToString:user.ID]) {
        [self fullScreenDidFinishLoadingVideo];
    }
    else {
        [self reloadCollectionView];
    }
}

- (BJLObservable)fullScreenDidStartLoadingVideo {
    BJLMethodNotify((void));
}

- (BJLObservable)fullScreenDidFinishLoadingVideo {
    BJLMethodNotify((void));
}

- (void)reloadCollectionView {
    [self.collectionView reloadData];
    
    NSInteger numberOfItems = 0;
    for (BJLPreviewsSection section = (BJLPreviewsSection)0; section < _BJLPreviewsSection_count; section++) {
        numberOfItems += [self.collectionView numberOfItemsInSection:section];
    }
    
    if (numberOfItems != self.numberOfItems) {
        self.numberOfItems = numberOfItems;
        [self.view mas_updateConstraints:^(MASConstraintMaker *make) {
            BOOL isHorizontal = BJLIsHorizontalUI(self);
            [self makeContentSize:make forHorizontal:isHorizontal];
        }];
        // !!!: `collectionView:cellForItemAtIndexPath:` bug
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
        [self.collectionView reloadData];
    }
    
    [self autoEnterFullScreen];
}

// !!!: `collectionView:cellForItemAtIndexPath:` will not be called if height is 0
- (void)makeContentSize:(MASConstraintMaker *)make forHorizontal:(BOOL)isHorizontal {
//    CGSize size = [BJLPreviewCell cellSize];
    CGSize size = [BJLPreviewCell previewctrlSelfviewSsize];
    // size.width = self.numberOfItems > 0 ? size.width *= self.numberOfItems : 0.0;
    size.height = self.numberOfItems > 0 ? size.height : 0.0;
    // make.width.equalTo(@(size.width)).priorityHigh();
    make.height.equalTo(@(size.height));
    
    self.collectionView.contentInset = bjl_structSet(self.collectionView.contentInset, {
        // TODO: - size.width should be BJLTopBarView.customContainerView.left
        set.right = isHorizontal ? size.width : 0.0;
    });
}

- (CGFloat)viewHeightIfDisplay {
    return [BJLPreviewCell cellSize].height;
}

#pragma mark - <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return _BJLPreviewsSection_count;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    switch (section) {
        case BJLPreviewsSection_PPT: {
//            return (self.room.slideshowViewController
//                    && self.fullScreenItem.type != BJLPreviewsType_PPT
//                    && !self.room.slideshowViewController.isBlank) ? 1 : 0;
            return (self.room.slideshowViewController
                    && self.fullScreenItem.type != BJLPreviewsType_PPT) ? 1 : 0;
        }
        case BJLPreviewsSection_presenter: {
            BOOL presenterFullScreen = (self.fullScreenItem.type == BJLPreviewsType_playing
                                        && self.fullScreenItem.playingUser
                                        && [self.fullScreenItem.playingUser isSameUser:self.presenter]);
            return (self.presenter
                    && !presenterFullScreen) ? 1 : 0;
        }
        case BJLPreviewsSection_recording: {
            return (self.room.recordingVM.recordingVideo
                    && self.fullScreenItem.type != BJLPreviewsType_recording) ? 1 : 0;
        }
        case BJLPreviewsSection_videoUsers: {
            return self.videoUsers.count;
        }
        case BJLPreviewsSection_audioUsers: {
            return self.audioUsers.count;
        }
        case BJLPreviewsSection_requestUsers: {
            return (self.room.loginUser.isTeacherOrAssistant
                    ? self.room.speakingRequestVM.speakingRequestUsers.count
                    : 0);
        }
        default: {
            return 0;
        }
    }
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellIdentifier = nil;
    switch (indexPath.section) {
        case BJLPreviewsSection_PPT:
            cellIdentifier = BJLPreviewCellID_view;
            break;
        case BJLPreviewsSection_presenter:
            cellIdentifier = (self.presenter && self.presenterVideoPlaying
                              ? BJLPreviewCellID_view_label
                              : BJLPreviewCellID_avatar_label);
            break;
        case BJLPreviewsSection_recording:
            // cellIdentifier = BJLPreviewCellID_view;
            cellIdentifier = BJLPreviewCellID_view_label;
            break;
        case BJLPreviewsSection_videoUsers:
            cellIdentifier = BJLPreviewCellID_view_label;
            break;
        case BJLPreviewsSection_audioUsers:
            cellIdentifier = BJLPreviewCellID_avatar_label;
            break;
        case BJLPreviewsSection_requestUsers:
            cellIdentifier = BJLPreviewCellID_avatar_label_buttons;
            break;
        default:
            cellIdentifier = BJLPreviewCellID_view;
            break;
    }
    
    BJLPreviewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellIdentifier forIndexPath:indexPath];
    bjl_weakify(self);
    cell.doubleTapsCallback = cell.doubleTapsCallback = ^(BJLPreviewCell *cell) {
        bjl_strongify(self);
        switch (indexPath.section) {
            case BJLPreviewsSection_PPT: {
                [self enterFullScreenWithPPTView];
                break;
            }
            case BJLPreviewsSection_presenter: {
                [self enterFullScreenWithViewForVideoPlayingUser:self.presenter];
                break;
            }
            case BJLPreviewsSection_recording: {
                [self enterFullScreenWithRecordingView];
                break;
            }
            case BJLPreviewsSection_videoUsers: {
                BJLMediaUser *user = [self.videoUsers bjl_objectOrNilAtIndex:indexPath.row];
                [self enterFullScreenWithViewForVideoPlayingUser:user];
                break;
            }
            case BJLPreviewsSection_audioUsers: {
                break;
            }
            case BJLPreviewsSection_requestUsers: {
                break;
            }
            default: {
                break;
            }
        }
    };
    
    switch (indexPath.section) {
        case BJLPreviewsSection_PPT: {
            [self bjl_addChildViewController:self.room.slideshowViewController addSubview:^(UIView * _Nonnull parentView, UIView * _Nonnull childView) {
                [cell updateWithView:self.room.slideshowViewController.view];
            }];
            [cell updateLoadingViewHidden:YES];
            break;
        }
        case BJLPreviewsSection_presenter: {
            NSString *title = [NSString stringWithFormat:@"%@(%@)",
                               self.presenter.name,
                               self.presenter.isTeacher ? @"老师" : @"主讲"];
            if (self.presenterVideoPlaying) {
                [cell updateWithView:[self.room.playingVM playingViewForUserWithID:self.presenter.ID]
                               title:title];
                BOOL isLoadingViewHidden = [[self.videoLoadingList bjl_objectForKey:self.presenter.ID class:[NSNumber class] defaultValue:@(YES)] boolValue];
                [cell updateLoadingViewHidden:isLoadingViewHidden];
            }
            else {
                [cell updateWithImageURLString:self.presenter.avatar
                                         title:title
                                      hasVideo:bjl_cast(BJLMediaUser, self.presenter).videoOn];
                [cell updateLoadingViewHidden:YES];
            }
            break;
        }
        case BJLPreviewsSection_recording: {
            // [cell updateWithView:self.room.recordingView];
            [cell updateWithView:self.room.recordingView
                           title:self.room.loginUser.name];
            [cell updateLoadingViewHidden:YES];
            break;
        }
        case BJLPreviewsSection_videoUsers: {
            BJLMediaUser *user = [self.videoUsers bjl_objectOrNilAtIndex:indexPath.row];
            [cell updateWithView:[self.room.playingVM playingViewForUserWithID:user.ID]
                           title:user.name];
            BOOL isLoadingViewHidden = [[self.videoLoadingList bjl_objectForKey:user.ID class:[NSNumber class] defaultValue:@(YES)] boolValue];
            [cell updateLoadingViewHidden:isLoadingViewHidden];
            break;
        }
        case BJLPreviewsSection_audioUsers: {
            BJLMediaUser *user = [self.audioUsers bjl_objectOrNilAtIndex:indexPath.row];
            [cell updateWithImageURLString:user.avatar
                                     title:user.name
                                  hasVideo:user.videoOn];
            [cell updateLoadingViewHidden:YES];
            break;
        }
        case BJLPreviewsSection_requestUsers: {
            BJLUser *user = [self.room.speakingRequestVM.speakingRequestUsers bjl_objectOrNilAtIndex:indexPath.row];
            [cell updateWithImageURLString:user.avatar
                                     title:[NSString stringWithFormat:@"%@举手中", user.name ?: @""]
                                  hasVideo:NO];
            [cell updateLoadingViewHidden:YES];
            if (self.room.loginUser.isTeacherOrAssistant) {
                bjl_weakify(self);
                cell.actionCallback = cell.actionCallback ?: ^(BJLPreviewCell *cell, BOOL allowed) {
                    bjl_strongify(self);
                    NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
                    BJLUser *user = [self.room.speakingRequestVM.speakingRequestUsers bjl_objectOrNilAtIndex:indexPath.row];
                    if (user) {
                        [self.room.speakingRequestVM replySpeakingRequestToUserID:user.ID allowed:allowed];
                    }
                };
            }
            break;
        }
        default: {
            break;
        }
    }
    
    return cell;
}

#pragma mark - <UICollectionViewDelegate>

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView cellForItemAtIndexPath:indexPath];
    
    switch (indexPath.section) {
        case BJLPreviewsSection_PPT: {
            [self showMenuForPPTViewSourceView:cell];
            break;
        }
        case BJLPreviewsSection_presenter: {
            [self showMenuForPlayingUser:self.presenter sourceView:cell];
            break;
        }
        case BJLPreviewsSection_recording: {
            [self showMenuForRecordingViewSourceView:cell];
            break;
        }
        case BJLPreviewsSection_videoUsers: {
            BJLMediaUser *user = [self.videoUsers bjl_objectOrNilAtIndex:indexPath.row];
            [self showMenuForPlayingUser:user sourceView:cell];
            break;
        }
        case BJLPreviewsSection_audioUsers: {
            BJLMediaUser *user = [self.audioUsers bjl_objectOrNilAtIndex:indexPath.row];
            [self showMenuForPlayingUser:user sourceView:cell];
            break;
        }
        case BJLPreviewsSection_requestUsers: {
            break;
        }
        default: {
            break;
        }
    }
    
    [collectionView deselectItemAtIndexPath:indexPath animated:YES];
}

#pragma mark - menu

- (void)showMenuForFullScreenItemSourceView:(nullable UIView *)sourceView {
    switch (self.fullScreenItem.type) {
        case BJLPreviewsType_PPT:
            [self showMenuForPPTViewSourceView:sourceView];
            break;
        case BJLPreviewsType_playing:
            [self showMenuForPlayingUser:self.fullScreenItem.playingUser sourceView:sourceView];
            break;
        case BJLPreviewsType_recording:
            [self showMenuForRecordingViewSourceView:sourceView];
            break;
        default:
            break;
    }
}

- (void)showMenuForPPTViewSourceView:(nullable UIView *)sourceView {
    if (self.fullScreenItem.type == BJLPreviewsType_PPT) {
        return;
    }
//2018-10-18 15:52:25 mikasa 禁用视频区左侧白板cell点击吊起函数
//    UIAlertController *alert = [UIAlertController
//                                alertControllerWithTitle:@"PPT"
//                                message:nil
//                                preferredStyle:UIAlertControllerStyleActionSheet];
//
//    [alert bjl_addActionWithTitle:@"全屏"
//                            style:UIAlertActionStyleDefault
//                          handler:^(UIAlertAction * _Nonnull action) {
//                              if (self.fullScreenItem.type == BJLPreviewsType_PPT) {
//                                  return;
//                              }
//                              [self enterFullScreenWithPPTView];
//                          }];
//
//    [alert bjl_addActionWithTitle:@"取消"
//                            style:UIAlertActionStyleCancel
//                          handler:nil];
//
//    [self showAlert:alert sourceView:sourceView];
//    2018-10-18 15:52:25 mikasa 禁用视频区左侧白板cell点击吊起函数
}

- (void)showMenuForRecordingViewSourceView:(nullable UIView *)sourceView {
    if (!self.room.recordingVM.recordingVideo) {
        return;
    }
    
//    UIAlertController *alert = [UIAlertController
//                                alertControllerWithTitle:@"采集视频"
//                                message:nil
//                                preferredStyle:UIAlertControllerStyleActionSheet];
//    2018-10-16 18:16:36 mikasa 根据需求设计 删除alert的title
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:nil
                                message:nil
                                preferredStyle:UIAlertControllerStyleActionSheet];

    
    if (self.fullScreenItem.type != BJLPreviewsType_recording) {
//        2018-10-17 10:29:50 mikasa 根据需求设计 禁用全屏功能 仿照安卓全屏设置为下麦
//        [alert bjl_addActionWithTitle:@"全屏"
//                                style:UIAlertActionStyleDefault
//                              handler:^(UIAlertAction * _Nonnull action) {
//                                  if (!self.room.recordingVM.recordingVideo) {
//                                      return;
//                                  }
//                                  [self enterFullScreenWithRecordingView];
//                              }];
        [alert bjl_addActionWithTitle:@"下麦"
                                style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction * _Nonnull action) {
//                                  if (!self.room.recordingVM.recordingVideo) {
//                                      return;
//                                  }
//                                  [self enterFullScreenWithRecordingView];
                                  
                                  UIAlertController *alert = [UIAlertController
                                                              alertControllerWithTitle:nil
                                                              message:@"确定下麦？"
                                                              preferredStyle:UIAlertControllerStyleAlert];
                                  [alert bjl_addActionWithTitle:@"确定"
                                                          style:UIAlertActionStyleDefault
                                                        handler:^(UIAlertAction * _Nonnull action) {
                                                            [self.room.speakingRequestVM stopSpeakingRequest];
                                                        }];
                                  [alert bjl_addActionWithTitle:@"取消"
                                                          style:UIAlertActionStyleCancel
                                                        handler:nil];
                                  [self presentViewController:alert animated:NO completion:nil];
                              }];
    }
    
    if (self.room.loginUser.isTeacher
        && !self.room.loginUserIsPresenter
        && self.room.featureConfig.canChangePresenter) {
        [alert bjl_addActionWithTitle:@"设为主讲"
                                style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction * _Nonnull action) {
                                  [self.room.onlineUsersVM requestChangePresenterWithUserID:self.room.loginUser.ID];
                              }];
    }
    
    [alert bjl_addActionWithTitle:@"切换摄像头"
                            style:UIAlertActionStyleDefault
                          handler:^(UIAlertAction * _Nonnull action) {
                              if (!self.room.recordingVM.recordingVideo) {
                                  return;
                              }
                              self.room.recordingVM.usingRearCamera = !self.room.recordingVM.usingRearCamera;
                          }];
    
    [alert bjl_addActionWithTitle:(self.room.recordingVM.videoBeautifyLevel == BJLVideoBeautifyLevel_off
                                   ? @"开启美颜" : @"关闭美颜")
                            style:UIAlertActionStyleDefault
                          handler:^(UIAlertAction * _Nonnull action) {
                              if (!self.room.recordingVM.recordingVideo) {
                                  return;
                              }
                              self.room.recordingVM.videoBeautifyLevel = (self.room.recordingVM.videoBeautifyLevel == BJLVideoBeautifyLevel_off
                                                                          ? BJLVideoBeautifyLevel_on : BJLVideoBeautifyLevel_off);
                          }];
    
    [alert bjl_addActionWithTitle:@"关闭摄像头"
                            style:UIAlertActionStyleDestructive
                          handler:^(UIAlertAction * _Nonnull action) {
                              if (!self.room.recordingVM.recordingVideo) {
                                  return;
                              }
                              BJLError *error = [self.room.recordingVM setRecordingAudio:self.room.recordingVM.recordingAudio
                                                                          recordingVideo:NO];
                              if (error) {
                                  [self showProgressHUDWithText:error.localizedFailureReason ?: error.localizedDescription];
                              }
                              else {
                                  [self showProgressHUDWithText:(self.room.recordingVM.recordingVideo
                                                                 ? @"摄像头已打开"
                                                                 : @"摄像头已关闭")];
                              }
                          }];
    
    [alert bjl_addActionWithTitle:@"取消"
                            style:UIAlertActionStyleCancel
                          handler:nil];
    
    [self showAlert:alert sourceView:sourceView];
}

- (void)showMenuForPlayingUser:(BJLMediaUser *)playingUser sourceView:(nullable UIView *)sourceView {
    playingUser = [self.room.playingVM playingUserWithID:playingUser.ID number:playingUser.number];
    if (!playingUser) {
        return;
    }
    
//    UIAlertController *alert = [UIAlertController
//                                alertControllerWithTitle:playingUser.name
//                                message:nil
//                                preferredStyle:UIAlertControllerStyleActionSheet];
//    2018-10-16 17:38:41 mikasa 仿安卓去掉alert title的名字
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:nil
                                message:nil
                                preferredStyle:UIAlertControllerStyleActionSheet];
    
    BOOL playingVideo = (([playingUser isSameUser:self.presenter] && self.presenterVideoPlaying)
                         || [playingUser containedInUsers:self.room.playingVM.videoPlayingUsers]);
    
    if (playingVideo) {
//        2018-10-16 17:34:42 mikasa 根据s需求设计 点击全屏功能禁用
//        BOOL isFullScreen = (self.fullScreenItem.type == BJLPreviewsType_playing
//                             && self.fullScreenItem.playingUser == playingUser);
//        if (!isFullScreen) {
//            [alert bjl_addActionWithTitle:@"全屏"
//                                    style:UIAlertActionStyleDefault
//                                  handler:^(UIAlertAction * _Nonnull action) {
//                                      if (![playingUser containedInUsers:self.videoUsers]
//                                          && [playingUser containedInUsers:self.audioUsers]) {
//                                          return;
//                                      }
//                                      BOOL playingVideo = (([playingUser isSameUser:self.presenter] && self.presenterVideoPlaying)
//                                                           || [playingUser containedInUsers:self.room.playingVM.videoPlayingUsers]);
//                                      BOOL isFullScreen = (self.fullScreenItem.type == BJLPreviewsType_playing
//                                                           && self.fullScreenItem.playingUser == playingUser);
//                                      if (playingVideo && !isFullScreen) {
//                                          [self enterFullScreenWithViewForVideoPlayingUser:playingUser];
//                                      }
//                                  }];
//        }
        
        if (playingUser.definitions.count > 1) {
            NSInteger definitionIndex = 0, currentDefinitionIndex = [self.room.playingVM definitionIndexForUserWithID:playingUser.ID];
            for (BJLLiveDefinitionKey key in playingUser.definitions) {
                NSString *definitionName = BJLLiveDefinitionNameForKey(key) ?: key;
                if (currentDefinitionIndex == definitionIndex) {
                    UIAlertAction *action =
                    [alert bjl_addActionWithTitle:[NSString stringWithFormat:@"正在播放%@视频", definitionName]
                                            style:UIAlertActionStyleDefault
                                          handler:nil];
                    action.enabled = NO;
                    SEL sel = NSSelectorFromString([NSString stringWithFormat:@"_%@%@%@:", @"set", @"Check", @"ed"]);
                    if ([action respondsToSelector:sel]) {
                        BOOL checked = YES;
                        [action bjl_invokeWithSelector:sel argument:&checked];
                    }
                }
                else {
                    [alert bjl_addActionWithTitle:[NSString stringWithFormat:@"打开%@视频", definitionName]
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction * _Nonnull action) {
                                              [self playVideoWithUser:playingUser definitionIndex:definitionIndex];
                                          }];
                }
                definitionIndex++;
            }
        }
        
        [alert bjl_addActionWithTitle:@"关闭视频"
                                style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction * _Nonnull action) {
                                  if (![playingUser containedInUsers:self.videoUsers]
                                      && [playingUser containedInUsers:self.audioUsers]) {
                                      return;
                                  }
                                  BOOL playingVideo = (([playingUser isSameUser:self.presenter] && self.presenterVideoPlaying)
                                                       || [playingUser containedInUsers:self.room.playingVM.videoPlayingUsers]);
                                  if (playingVideo) {
                                      [self.room.playingVM updatePlayingUserWithID:playingUser.ID videoOn:NO];
                                  }
                                  // 主动关闭老师视频后不再自动打开
                                  [self.autoPlayVideoBlacklist addObject:playingUser.number ?: @""];
                              }];
    }
    else if (playingUser.videoOn) {
        if (playingUser.definitions.count > 1) {
            NSInteger definitionIndex = 0;
            for (BJLLiveDefinitionKey key in playingUser.definitions) {
                NSString *definitionName = BJLLiveDefinitionNameForKey(key) ?: key;
                [alert bjl_addActionWithTitle:[NSString stringWithFormat:@"打开%@视频", definitionName]
                                        style:UIAlertActionStyleDefault
                                      handler:^(UIAlertAction * _Nonnull action) {
                                          [self playVideoWithUser:playingUser definitionIndex:definitionIndex];
                                      }];
                definitionIndex++;
            }
        }
        else {
            [alert bjl_addActionWithTitle:@"打开视频"
                                    style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction * _Nonnull action) {
                                      [self playVideoWithUser:playingUser];
                                  }];
        }
    }
    else {
        alert.message = @"对方没有开启摄像头";
    }
    
    if (!self.room.featureConfig.disableGrantDrawing
        && self.room.loginUser.isTeacherOrAssistant
        && !playingUser.isTeacherOrAssistant) {
        BOOL wasGranted = [self.room.slideshowViewController.drawingGrantedUserNumbers containsObject:playingUser.number];
        [alert bjl_addActionWithTitle:wasGranted ? @"收回画笔" : @"授权画笔"
                                style:UIAlertActionStyleDefault
                              handler:^(UIAlertAction * _Nonnull action) {
                                  BJLError *error =
                                  [self.room.slideshowViewController updateDrawingGranted:!wasGranted
                                                                               userNumber:playingUser.number];
                                  if (error) {
                                      [self showProgressHUDWithText:error.localizedFailureReason ?: error.localizedDescription];
                                  }
                              }];
    }
    
    if (self.room.loginUser.isTeacher
        && playingUser.isAssistant
        && self.room.featureConfig.canChangePresenter) {
        if ([self.presenter isSameUser:playingUser]) {
            [alert bjl_addActionWithTitle:@"收回主讲"
                                    style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction * _Nonnull action) {
                                      [self.room.onlineUsersVM requestChangePresenterWithUserID:self.room.loginUser.ID];
                                  }];
        }
        else {
            [alert bjl_addActionWithTitle:@"设为主讲"
                                    style:UIAlertActionStyleDefault
                                  handler:^(UIAlertAction * _Nonnull action) {
                                      [self.room.onlineUsersVM requestChangePresenterWithUserID:playingUser.ID];
                                  }];
        }
    }
    
    if (self.room.loginUser.isTeacherOrAssistant
        && self.room.roomInfo.roomType == BJLRoomType_1toN
        && !playingUser.isTeacher) {
        [alert bjl_addActionWithTitle:@"结束发言"
                                style:UIAlertActionStyleDestructive
                              handler:^(UIAlertAction * _Nonnull action) {
                                  /*
                                  if (![playingUser containedInUsers:self.videoUsers]
                                      && ![playingUser containedInUsers:self.audioUsers]) {
                                      return;
                                  } */
                                  [self.room.recordingVM remoteChangeRecordingWithUser:playingUser
                                                                               audioOn:NO
                                                                               videoOn:NO];
                              }];
    }
    
    [alert bjl_addActionWithTitle:alert.actions.count ? @"取消" : @"知道了"
                            style:UIAlertActionStyleCancel
                          handler:nil];
    
    [self showAlert:alert sourceView:sourceView];
}

#pragma mark - play & auto-play

- (void)playVideoWithUser:(BJLMediaUser *)playingUser {
    [self playVideoWithUser:playingUser definitionIndex:0];
}

- (void)playVideoWithUser:(BJLMediaUser *)playingUser definitionIndex:(NSInteger)definitionIndex {
     playingUser = [self.room.playingVM playingUserWithID:playingUser.ID number:playingUser.number];
    if ([playingUser containedInUsers:self.videoUsers]
        || (![playingUser containedInUsers:self.audioUsers]
            && ![playingUser isSameUser:self.presenter])) {
        return;
    }
    
    BOOL playingVideo = [playingUser containedInUsers:self.room.playingVM.videoPlayingUsers];
    NSInteger currDefinitionIndex = [self.room.playingVM definitionIndexForUserWithID:playingUser.ID];
    if ((!playingVideo || definitionIndex != currDefinitionIndex)
        && playingUser.videoOn) {
        BJLError *error = [self.room.playingVM updatePlayingUserWithID:playingUser.ID videoOn:YES definitionIndex:definitionIndex];
        if (error) {
            [self showProgressHUDWithText:error.localizedFailureReason ?: error.localizedDescription];
        }
    }
    // 播放视频后恢复自动打开逻辑
    [self.autoPlayVideoBlacklist removeObject:playingUser.number ?: @""];
}

#pragma mark -

- (void)showAlert:(UIAlertController *)alert sourceView:(nullable UIView *)sourceView {
    if (alert.preferredStyle == UIAlertControllerStyleActionSheet) {
        sourceView = sourceView ?: self.view;
        alert.popoverPresentationController.sourceView = sourceView;
        alert.popoverPresentationController.sourceRect = ({
            CGRect rect = sourceView.bounds;
            rect.origin.y = CGRectGetMaxY(rect) - 1.0;
            rect.size.height = 1.0;
            rect;
        });
        alert.popoverPresentationController.permittedArrowDirections = UIPopoverArrowDirectionUp | UIPopoverArrowDirectionDown;
    }
    [self presentViewController:alert animated:YES completion:nil];
}

@end

NS_ASSUME_NONNULL_END
