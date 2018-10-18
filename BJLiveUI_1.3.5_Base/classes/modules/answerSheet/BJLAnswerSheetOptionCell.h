//
//  BJLAnswerSheetOptionCell.h
//  BJLiveUI
//
//  Created by HuangJie on 2018/6/7.
//  Copyright © 2018年 BaijiaYun. All rights reserved.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BJLAnswerSheetOptionCell : UICollectionViewCell

@property (nonatomic, copy, nullable) void (^optionSelectedCallback)(BOOL selected);

- (void)updateContentWithOptionKey:(NSString *)optionKey isSelected:(BOOL)isSelected;

@end

NS_ASSUME_NONNULL_END
