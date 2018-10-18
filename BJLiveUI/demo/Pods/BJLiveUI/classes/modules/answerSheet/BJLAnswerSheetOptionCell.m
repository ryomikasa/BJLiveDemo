//
//  BJLAnswerSheetOptionCell.m
//  BJLiveUI
//
//  Created by HuangJie on 2018/6/7.
//  Copyright © 2018年 BaijiaYun. All rights reserved.
//

#import "BJLAnswerSheetOptionCell.h"
#import "BJLAppearance.h"
#import <Masonry/Masonry.h>

@interface BJLAnswerSheetOptionCell ()

@property (nonatomic) UIButton *optionButton;

@end

@implementation BJLAnswerSheetOptionCell

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self setupContentView];
    }
    return self;
}

#pragma mark - content view

- (void)setupContentView {
    // option button
    self.optionButton = ({
        UIButton *button = [[UIButton alloc] init];
        button.backgroundColor = [UIColor clearColor];
        // layer
        button.layer.masksToBounds = YES;
        button.layer.borderWidth = 0.5;
        button.layer.borderColor = [UIColor bjl_colorWithHexString:@"#EAEAEA"].CGColor;
        button.layer.cornerRadius = 17.0;
        
        // title
        button.titleLabel.font = [UIFont systemFontOfSize:8.0];
        [button setTitleColor:[UIColor bjl_colorWithHexString:@"#999999"] forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateSelected];
        
        // action
        [button addTarget:self action:@selector(optionButtonOnClick:) forControlEvents:UIControlEventTouchUpInside];
        
        button;
    });
    [self.contentView addSubview:self.optionButton];
    [self.optionButton mas_makeConstraints:^(MASConstraintMaker *make) {
        make.edges.equalTo(self.contentView);
    }];
}

#pragma mark - action

- (void)optionButtonOnClick:(UIButton *)button {
    // 选中状态
    BOOL selected = !button.selected;
    [self setOptionButtonSelected:selected];
    
    // 回调
    if (self.optionSelectedCallback) {
        self.optionSelectedCallback(selected);
    }
}

- (void)setOptionButtonSelected:(BOOL)selected {
    self.optionButton.selected = selected;
    self.optionButton.layer.borderColor = (selected ? [UIColor bjl_colorWithHexString:@"#1694FF"] : [UIColor bjl_colorWithHexString:@"#EAEAEA"]).CGColor;
    self.optionButton.backgroundColor = selected ? [UIColor bjl_colorWithHexString:@"#1694FF"] : [UIColor clearColor];
}

#pragma mark - update

- (void)updateContentWithOptionKey:(NSString *)optionKey isSelected:(BOOL)isSelected {
    [self.optionButton setTitle:optionKey forState:UIControlStateNormal];
    [self setOptionButtonSelected:isSelected];
    self.optionButton.layer.cornerRadius = self.contentView.bounds.size.width / 2.0;
}

@end
