//
//  BJLAnswerSheetViewController.m
//  BJLiveUI
//
//  Created by HuangJie on 2018/6/8.
//  Copyright © 2018年 BaijiaYun. All rights reserved.
//

#import <BJLiveBase/NSObject+BJL_M9Dev.h>
#import <BJLiveBase/BJL_EXTScope.h>
#import <Masonry/Masonry.h>

#import "BJLAppearance.h"
#import "BJLAnswerSheetViewController.h"
#import "BJLAnswerSheetOptionCell.h"

static NSString * const cellReuseIdentifier = @"QuizOptionCell";
static CGFloat const optionButtonWH = 34.5;
static NSUInteger const optionCountForRow = 4;

@interface BJLAnswerSheetViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout>

@property (nonatomic) BJLAnswerSheet *answerSheet;
@property (nonatomic) NSTimer *countDownTimer;

@property (nonatomic) UIView *contentView;
@property (nonatomic) UIView *topBar;
@property (nonatomic) UIView *countDownView;
@property (nonatomic) UILabel *countDownTimeLabel;
@property (nonatomic) UIScrollView *scrollView;
@property (nonatomic) UICollectionView *optionsView;
@property (nonatomic) UIView *correctAnswerView;
@property (nonatomic) UILabel *correctAnswerLabel;
@property (nonatomic) UIButton *finishButton;
@property (nonatomic) UIButton *submitButton;

@end

@implementation BJLAnswerSheetViewController

- (instancetype)initWithAnswerSheet:(BJLAnswerSheet *)answerSheet {
    self = [super init];
    if (self) {
        self.answerSheet = answerSheet;
        [self setupSubViews];
        [self checkSubmitButtonEnable];
        [self startCountDown];
    }
    return self;
}

#pragma mark - subViews

- (void)setupSubViews {
    // contentView
    [self.view addSubview:self.contentView];
    [self.contentView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view).priorityHigh(); // to update
        make.centerY.equalTo(self.view).multipliedBy(1.2).priorityHigh(); // to update
        make.width.equalTo(@(200.0)); // 指定宽度，高度自动计算
        // 边界限制
        make.top.left.greaterThanOrEqualTo(self.view);
        make.bottom.right.lessThanOrEqualTo(self.view);
    }];
    
    // top bar
    [self.contentView addSubview:self.topBar];
    [self.topBar mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.left.right.equalTo(self.contentView);
        make.height.equalTo(@(27.0));
    }];
    [self setupTopBar];
    
    // count down view
    [self.contentView addSubview:self.countDownView];
    [self.countDownView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.topBar.mas_bottom).offset(7.5);
        make.left.equalTo(self.contentView).offset(15.0);
        make.right.equalTo(self.contentView).offset(-15.0);
        make.height.equalTo(@(30.0));
    }];
    [self setupCountDownView];
    
    // options view
    CGFloat optionsViewHeight = (self.answerSheet.options.count <= optionCountForRow) ? optionButtonWH : optionButtonWH * 2 + 15.0; // 1~2 行选项
    [self.contentView addSubview:self.optionsView];
    [self.optionsView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.countDownView.mas_bottom).offset(7.0);
        make.left.right.equalTo(self.countDownView);
        make.height.equalTo(@(optionsViewHeight));
    }];
    
    // correct answer view
    [self.contentView addSubview:self.correctAnswerView];
    [self.correctAnswerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.optionsView.mas_bottom).offset(15.0);
        make.left.right.equalTo(self.countDownView);
        make.height.equalTo(@(0.0)); // to update
    }];
    [self setupCorrectAnswerView];
    
    // submit button
    [self.contentView addSubview:self.submitButton];
    [self.submitButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.correctAnswerView.mas_bottom);
        make.centerX.equalTo(self.contentView);
        make.width.equalTo(@(60.0));
        make.height.equalTo(@(27.0)); // to update
    }];
    
    // finish button
    [self.contentView addSubview:self.finishButton];
    [self.finishButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.submitButton.mas_bottom).offset(15.0);
        make.centerX.equalTo(self.contentView);
        make.width.equalTo(@(60.0));
        make.height.equalTo(@(0.0)); // to update
        make.bottom.equalTo(self.contentView).offset(-5.0);
    }];
}

- (void)setupTopBar {
    // title label
    UILabel *titleLabel = [self labelWithTitle:@"答题器" color:[UIColor whiteColor]];
    [self.topBar addSubview:titleLabel];
    [titleLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.topBar).offset(10.0);
        make.centerY.equalTo(self.topBar);
    }];
    
    // close button
    UIButton *closeButton = ({
        UIButton *button = [[UIButton alloc] init];
        [button setImage:[UIImage imageNamed:@"bjl_ic_close"] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(closeButtonOnClick:) forControlEvents:UIControlEventTouchUpInside];
        button;
    });
    [self.topBar addSubview:closeButton];
    [closeButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.topBar).offset(-10.0);
        make.top.bottom.equalTo(self.topBar);
    }];
}

- (void)setupCountDownView {
    // descript label
    UILabel *descriptLabel = [self labelWithTitle:@"答题倒计时" color:[self grayTextColor]];
    [self.countDownView addSubview:descriptLabel];
    [descriptLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.countDownView).offset(7.5);
        make.centerY.equalTo(self.countDownView);
    }];
    
    // count down time label
    [self.countDownView addSubview:self.countDownTimeLabel];
    [self.countDownTimeLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.countDownView).offset(-7.5);
        make.centerY.equalTo(self.countDownView);
    }];
}

- (void)setupCorrectAnswerView {
    // descript label
    UILabel *descriptLabel = [self labelWithTitle:@"正确答案" color:[self grayTextColor]];
    [self.correctAnswerView addSubview:descriptLabel];
    [descriptLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.left.equalTo(self.correctAnswerView).offset(7.5);
        make.centerY.equalTo(self.correctAnswerView);
    }];
    
    // correct answer label
    [self.correctAnswerView addSubview:self.correctAnswerLabel];
    [self.correctAnswerLabel mas_makeConstraints:^(MASConstraintMaker *make) {
        make.right.equalTo(self.correctAnswerView).offset(-7.5);
        make.centerY.equalTo(self.correctAnswerView);
    }];
}

#pragma mark - action

- (void)closeButtonOnClick:(UIButton *)button {
    [self close];
}

- (void)checkSubmitButtonEnable {
    BOOL enable = NO;
    for (BJLAnswerSheetOption *option in self.answerSheet.options) {
        if (option.selected) {
            enable = YES;
            break;
        }
    }
    
    self.submitButton.enabled = enable;
    self.submitButton.backgroundColor = [UIColor bjl_colorWithHexString:enable ? @"#1694FF" : @"#D7D7D7"];
}

- (void)submitButtonOnClick:(UIButton *)button {
    if (self.submitCallback) {
        BOOL success = self.submitCallback(self.answerSheet);
        if (success) {
            // 提交成功才显示正确答案
            [self showCorrectAnswerView];
        }
    }
}

- (void)finishButtonOnClick:(UIButton *)button {
    [self close];
}

- (void)close {
    if (self.closeCallback) {
        self.closeCallback();
    }
}

- (void)showCorrectAnswerView {
    // 显示答案视图
    [self.correctAnswerView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(30.0));
    }];
    
    // 隐藏提交按钮
    [self.submitButton mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(0.0));
    }];
    
    // 显示确定按钮
    [self.finishButton mas_updateConstraints:^(MASConstraintMaker *make) {
        make.height.equalTo(@(27.0));
    }];
}

#pragma mark - count down

- (void)startCountDown {
    if (self.countDownTimer.isValid) {
        return;
    }
    
    // 倒计时
    __block NSTimeInterval remainingTime = self.answerSheet.countDownTime;
    self.countDownTimeLabel.text = [self stringFromTimeInterval:remainingTime];
    NSTimeInterval countStep = 0.5;
    bjl_weakify(self);
    self.countDownTimer = [NSTimer bjl_scheduledTimerWithTimeInterval:countStep repeats:YES block:^(NSTimer * _Nonnull timer) {
        bjl_strongify(self);
        if (!self) {
            [timer invalidate];
            return;
        }
        
        remainingTime -= countStep;
        self.countDownTimeLabel.text = [self stringFromTimeInterval:remainingTime];
        if (remainingTime <= 0) {
            [timer invalidate];
            [self close];
        }
    }];
}

#pragma mark - touch & move

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    if (touch.view != self.topBar) {
        return;
    }
    
    // 当前触摸点
    CGPoint currentPoint = [touch locationInView:self.view];
    // 上一个触摸点
    CGPoint previousPoint = [touch previousLocationInView:self.view];
    
    // 更新偏移量: 需要注意的是 self.contentView 的 centerY 默认是 self.view 的 contentY 的 1.2 倍
    CGFloat offsetX = (self.contentView.center.x - self.view.center.x) + (currentPoint.x - previousPoint.x);
    CGFloat offsetY = (self.contentView.center.y - self.view.center.y*1.2) + (currentPoint.y - previousPoint.y);
    
    // 修改当前 contentView 的中点
    [self.contentView mas_updateConstraints:^(MASConstraintMaker *make) {
        make.centerX.equalTo(self.view).offset(offsetX).priorityHigh();
        make.centerY.equalTo(self.view).multipliedBy(1.2).offset(offsetY).priorityHigh();
    }];
}

#pragma mark - <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return self.answerSheet.options.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    BJLAnswerSheetOption *option = [[self.answerSheet.options bjl_objectOrNilAtIndex:indexPath.row] bjl_as:[BJLAnswerSheetOption class]];
    BJLAnswerSheetOptionCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:cellReuseIdentifier forIndexPath:indexPath];
    [cell updateContentWithOptionKey:option.key isSelected:option.selected];
    [cell setOptionSelectedCallback:^(BOOL selected) {
        option.selected = selected;
        [self checkSubmitButtonEnable];
    }];
    
    return cell;
}

#pragma mark - <UICollectionViewDelegateFlowLayout>

- (UIEdgeInsets)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout insetForSectionAtIndex:(NSInteger)section {
    CGFloat combinedItemWidth = (optionCountForRow * optionButtonWH) + ((optionCountForRow - 1) * 15.0);
    CGFloat padding = (collectionView.frame.size.width - combinedItemWidth) / 2;
    padding = MAX(0, padding);
    return UIEdgeInsetsMake(0, padding,0, padding);
}

#pragma mark - getters

- (UIView *)contentView {
    if (!_contentView) {
        _contentView = ({
            UIView *view = [[UIView alloc] init];
            view.backgroundColor = [UIColor whiteColor];
            view.clipsToBounds = YES;
            view.layer.masksToBounds = YES;
            view.layer.cornerRadius = 4.5;
            view;
        });
    }
    return _contentView;
}

- (UIView *)topBar {
    if (!_topBar) {
        _topBar = ({
            UIView *view = [[UIView alloc] init];
            view.backgroundColor = [self blueBackgroundColor];
            view;
        });
    }
    return _topBar;
}

- (UIView *)countDownView {
    if (!_countDownView) {
        _countDownView = ({
            UIView *view = [[UIView alloc] init];
            view.backgroundColor = [self grayBackgroundColor];
            view;
        });
    }
    return _countDownView;
}

- (UILabel *)countDownTimeLabel {
    if (!_countDownTimeLabel) {
        _countDownTimeLabel = [self labelWithTitle:nil color:[self grayTextColor]];
    }
    return _countDownTimeLabel;
}

- (UIScrollView *)scrollView {
    if (!_scrollView) {
        _scrollView = ({
            UIScrollView *view = [[UIScrollView alloc] init];
            view.showsVerticalScrollIndicator = NO;
            view.showsHorizontalScrollIndicator = NO;
            view.bounces = NO;
            view;
        });
    }
    return _scrollView;
}

-  (UICollectionView *)optionsView {
    if (!_optionsView) {
        _optionsView = ({
            // layout
            UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
            layout.sectionInset = UIEdgeInsetsZero;
            layout.scrollDirection = UICollectionViewScrollDirectionVertical;
            layout.itemSize = CGSizeMake(optionButtonWH, optionButtonWH);
            
            // view
            UICollectionView *view = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
            view.translatesAutoresizingMaskIntoConstraints = NO;
            view.backgroundColor = [UIColor clearColor];
            view.showsHorizontalScrollIndicator = NO;
            view.bounces = NO;
            view.alwaysBounceVertical = YES;
            view.pagingEnabled = YES;
            view.dataSource = self;
            view.delegate = self;
            [view registerClass:[BJLAnswerSheetOptionCell class] forCellWithReuseIdentifier:cellReuseIdentifier];
            view;
        });
    }
    return _optionsView;
}

- (UIView *)correctAnswerView {
    if (!_correctAnswerView) {
        _correctAnswerView = ({
            UIView *view = [[UIView alloc] init];
            view.backgroundColor = [self grayBackgroundColor];
            view.clipsToBounds = YES;
            view;
        });
    }
    return _correctAnswerView;
}

- (UILabel *)correctAnswerLabel {
    if (!_correctAnswerLabel) {
        NSString *answerString = @"";
        for (BJLAnswerSheetOption *option in self.answerSheet.options) {
            if (option.key.length && option.isAnswer) {
                answerString = [answerString stringByAppendingString:option.key];
            }
        }
        _correctAnswerLabel = [self labelWithTitle:answerString color:[self grayTextColor]];
    }
    return _correctAnswerLabel;
}

-  (UIButton *)finishButton {
    if (!_finishButton) {
        _finishButton = [self buttonWithTitle:@"确定"];
        [_finishButton addTarget:self action:@selector(finishButtonOnClick:) forControlEvents:UIControlEventTouchUpInside];
        _finishButton.backgroundColor = [self blueBackgroundColor];
    }
    return _finishButton;
}

- (UIButton *)submitButton {
    if (!_submitButton) {
        _submitButton = [self buttonWithTitle:@"提交答案"];
        [_submitButton addTarget:self action:@selector(submitButtonOnClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return _submitButton;
}

#pragma mark - private

- (UILabel *)labelWithTitle:(NSString *)title color:(UIColor *)color {
    UILabel *label = [[UILabel alloc] init];
    label.numberOfLines = 0;
    label.textColor = color;
    label.font = [UIFont systemFontOfSize:11.0];
    label.text = title;
    return label;
}

- (NSString *)stringFromTimeInterval:(NSTimeInterval)interval {
    int hours = interval / 3600;
    int minums = ((long long)interval % 3600) / 60;
    int seconds = (long long)interval % 60;
    if (hours > 0) {
        return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, minums, seconds];
    }
    else {
        return [NSString stringWithFormat:@"%02d:%02d", minums, seconds];
    }
}

- (UIButton *)buttonWithTitle:(NSString *)title {
    UIButton *button = [[UIButton alloc] init];
    button.layer.masksToBounds = YES;
    button.layer.cornerRadius = 2.0;
    button.titleLabel.font = [UIFont systemFontOfSize:11.0];
    [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [button setTitle:title forState:UIControlStateNormal];
    return button;
}

- (UIColor *)grayTextColor {
    return [UIColor bjl_colorWithHexString:@"#666666"];
}

- (UIColor *)grayBackgroundColor {
    return [UIColor bjl_colorWithHexString:@"#FAFAFA"];
}

- (UIColor *)blueBackgroundColor {
    return [UIColor bjl_colorWithHexString:@"#1694FF"];
}

@end
