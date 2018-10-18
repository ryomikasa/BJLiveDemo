//
//  BJLProgressView.m
//  BJLiveUI
//
//  Created by MingLQ on 2017-01-19.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import <Masonry/Masonry.h>

#import "BJLProgressView.h"

NS_ASSUME_NONNULL_BEGIN

@interface BJLProgressView ()

@property (nonatomic) UIView *completionView;

@end

@implementation BJLProgressView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        self.completionView = ({
            UIView *view = [UIView new];
            [self addSubview:view];
            view;
        });
        self.color = nil;
        self.progress = 0.0;
    }
    return self;
}

// KVO-setter
- (void)setProgress:(double)progress {
    _progress = MAX(0.0, MIN(progress, 1.0));
    [self.completionView mas_remakeConstraints:^(MASConstraintMaker *make) {
        make.left.top.bottom.equalTo(self);
        make.width.equalTo(self.mas_width).multipliedBy(self.progress);
    }];
    [self setNeedsLayout];
}

// KVO-setter
- (void)setColor:(nullable UIColor *)color {
    self->_color = color ?: ({
        const CGFloat _7B = 123.0 / 255;
        [UIColor colorWithRed:_7B
                        green:_7B
                         blue:_7B
                        alpha:1.0];
    });
    self.completionView.backgroundColor = self.color;
}

@end

NS_ASSUME_NONNULL_END
