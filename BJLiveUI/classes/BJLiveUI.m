//
//  BJLiveUI.m
//  BJLiveUI
//
//  Created by MingLQ on 2017-01-19.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import "BJLiveUI.h"

NSString * BJLiveUIName(void) {
    return BJLStringFromPreprocessor(BJLIVEUI_NAME, @"BJLiveUI");
}

NSString * BJLiveUIVersion(void) {
    return BJLStringFromPreprocessor(BJLIVEUI_VERSION, @"-");
}
