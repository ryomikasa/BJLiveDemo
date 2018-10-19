//
//  BJLRoomViewController+observing.m
//  BJLiveUI
//
//  Created by MingLQ on 2017-01-19.
//  Copyright © 2017 BaijiaYun. All rights reserved.
//

#import <BJLiveBase/UIKit+BJL_M9Dev.h>

#import "BJLRoomViewController+protected.h"

#import "BJLViewImports.h"

NS_ASSUME_NONNULL_BEGIN

@implementation BJLRoomViewController (observing)

/**
 场景:
 1. 有内容出现时: 如果没有全屏内容、并且此内容是 PPT/老师视频 时，不动画全屏显示，否则不动画小窗显示
 2. 小窗内容关闭时: 不动画关闭
 3. 全屏内容关闭时: 不动画关闭，如果小窗存在 PPT/老师视频 时【自动】【动画】全屏，否则保留空白
 4. 双击小窗内容时: 如果有全屏内容【动画】互换，否则【动画】全屏
 事件:
 有事件发生时(有人开启摄像头): 如果对方是老师，并且本地未进行过开关对方摄像头的操作的情况下【自动】打开对方视频
 @see didUpdateVideoPlayingUser，打开老师视频时重置此参数
*/

- (void)makeObservingWhenEnteredInRoom {
    if (self.room.loginUser.isTeacher) {
        [self makeObservingForRecordingAndServerRecording];
    }
    else if (self.room.loginUser.isAssistant
             || self.room.loginUser.isGroupAssistant) {
        // nothing here
    }
    else {
        if (self.room.roomInfo.roomType != BJLRoomType_1toN) {
            [self makeObservingFor1to1OrM];
        }
        else {
            [self makeObservingFor1toN];
        }
        [self makeObservingForSpeakingInvite];
        [self makeObservingForLamp];
        [self makeObservingForRollcall];
        [self makeObservingForNotice];
        [self makeObservingForQuiz];
        // [self makeObservingForAnswerSheet]; - 答题器暂时不上线
    }
    
    [self makeObservingForPPTAndDrawing];
    [self makeObservingForFullScreen];
    [self makeObservingForProgressHUD];
    [self makeObservingForLoadingVideo];
    
    [self.chatViewController refreshMessages];
}

- (void)makeObservingForRecordingAndServerRecording {
    bjl_weakify(self);
    
    [self bjl_kvo:BJLMakeProperty(self.room.roomVM, liveStarted)
           filter:^BOOL(id _Nullable old, NSNumber * _Nullable now) {
               // bjl_strongify(self);
               return now.boolValue;
           }
         observer:^BOOL(id _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             // 自动开启音视频
             [BJLAuthorization checkMicrophoneAccessAndRequest:YES callback:^(BOOL granted, UIAlertController * _Nullable alert) {
                 if (granted) {
                     if (self.room.featureConfig.mediaLimit == BJLMediaLimit_audioOnly) {
                         BJLError *error = [self.room.recordingVM setRecordingAudio:YES recordingVideo:NO];
                         if (error) {
                             [self showProgressHUDWithText:error.localizedFailureReason ?: error.localizedDescription];
                         }
                         else {
                             [self showProgressHUDWithText:(self.room.recordingVM.recordingAudio
                                                            ? @"麦克风已打开"
                                                            : @"麦克风已关闭")];
                         }
                     }
                     else {
                         [BJLAuthorization checkCameraAccessAndRequest:YES callback:^(BOOL granted, UIAlertController * _Nullable alert) {
                             if (granted) {
                                 BJLError *error = [self.room.recordingVM setRecordingAudio:YES recordingVideo:YES];
                                 if (error) {
                                     [self showProgressHUDWithText:error.localizedFailureReason ?: error.localizedDescription];
                                 }
                                 else {
                                     [self showProgressHUDWithText:(self.room.recordingVM.recordingAudio || self.room.recordingVM.recordingVideo
                                                                    ? @"麦克风、摄像头已打开"
                                                                    : @"麦克风、摄像头已关闭")];
                                 }
                             }
                             else if (alert) {
                                 [self presentViewController:alert animated:YES completion:nil];
                             }
                         }];
                     }
                 }
                 else if (alert) {
                     [self presentViewController:alert animated:YES completion:nil];
                 }
             }];
             // 自动开启云端录课
             if (self.room.featureConfig.autoStartServerRecording
                 && !self.room.serverRecordingVM.serverRecording) {
                 [self.room.serverRecordingVM requestServerRecording:YES];
             }
             return NO; // only once
         }];
    
    __block BOOL wasRecordingAudio = YES, wasRecordingVideo = YES;
    [self bjl_kvo:BJLMakeProperty(self.room, state)
           filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
               bjl_strongify(self);
               if (old.integerValue == BJLRoomState_connectedServer
                   && now.integerValue != BJLRoomState_connectedServer) {
                   wasRecordingAudio = self.room.recordingVM.recordingAudio;
                   wasRecordingVideo = self.room.recordingVM.recordingVideo;
               }
               return (now.integerValue != old.integerValue
                       && now.integerValue == BJLRoomState_connectedServer
                       && self.room.roomVM.liveStarted
                       && (wasRecordingAudio || wasRecordingVideo)
                       && (wasRecordingAudio != self.room.recordingVM.recordingAudio
                           || wasRecordingVideo != self.room.recordingVM.recordingVideo));
           }
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             BJLError *error = [self.room.recordingVM setRecordingAudio:wasRecordingAudio
                                                         recordingVideo:wasRecordingVideo];
             if (error) {
                 [self showProgressHUDWithText:error.localizedFailureReason ?: error.localizedDescription];
             }
             /*
             else {
                 [self showProgressHUDWithText:(self.room.recordingVM.recordingVideo
                                                ? @"摄像头已打开"
                                                : @"摄像头已关闭")];
             } */
             return YES;
         }];
    
    __block BOOL isInitial = YES;
    [self bjl_kvo:BJLMakeProperty(self.room.serverRecordingVM, serverRecording)
           filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
               // bjl_strongify(self);
               return now.boolValue != old.boolValue;
           }
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             [self.moreViewController setServerRecordingEnabled:now.boolValue];
             BOOL isHorizontal = BJLIsHorizontalUI(self);
             [self updateRecordingStateViewForHorizontal:isHorizontal];
             if (now.boolValue) {
                 [self showProgressHUDWithText:@"已开启录课"];
             }
             else {
                 if (!isInitial) {
                     [self showProgressHUDWithText:@"已关闭录课"];
                 }
             }
             isInitial = NO;
             return YES;
         }];
    
    [self bjl_observe:BJLMakeMethod(self.room.serverRecordingVM, requestServerRecordingDidFailed:)
             observer:^BOOL(NSString *message) {
                 bjl_strongify(self);
                 [self showProgressHUDWithText:message];
                 return YES;
             }];
}

- (void)makeObservingFor1to1OrM {
    bjl_weakify(self);
    
    [self bjl_kvo:BJLMakeProperty(self.room.roomVM, liveStarted)
           filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
               // bjl_strongify(self);
               return now.boolValue;
           }
         observer:^BOOL(id _Nullable old, id _Nullable now) {
             bjl_strongify(self);
             [BJLAuthorization checkMicrophoneAccessAndRequest:YES callback:^(BOOL granted, UIAlertController * _Nullable alert) {
                 if (granted) {
                     if (self.room.featureConfig.mediaLimit == BJLMediaLimit_audioOnly
                         || !self.room.featureConfig.autoPublishVideoStudent) {
                         BJLError *error = [self.room.recordingVM setRecordingAudio:YES recordingVideo:NO];
                         if (error) {
                             [self showProgressHUDWithText:error.localizedFailureReason ?: error.localizedDescription];
                         }
                         else {
                             [self showProgressHUDWithText:(self.room.recordingVM.recordingAudio
                                                            ? @"麦克风已打开"
                                                            : @"麦克风已关闭")];
                         }
                     }
                     else {
                         [BJLAuthorization checkCameraAccessAndRequest:YES callback:^(BOOL granted, UIAlertController * _Nullable alert) {
                             if (granted) {
                                 BJLError *error = [self.room.recordingVM setRecordingAudio:YES recordingVideo:YES];
                                 if (error) {
                                     [self showProgressHUDWithText:error.localizedFailureReason ?: error.localizedDescription];
                                 }
                                 else {
                                     [self showProgressHUDWithText:(self.room.recordingVM.recordingAudio || self.room.recordingVM.recordingVideo
                                                                    ? @"麦克风、摄像头已打开"
                                                                    : @"麦克风、摄像头已关闭")];
                                 }
                             }
                             else if (alert) {
                                 [self presentViewController:alert animated:YES completion:nil];
                             }
                         }];
                     }
                 }
                 else if (alert) {
                     [self presentViewController:alert animated:YES completion:nil];
                 }
             }];
             return YES;
         }];
}

- (void)makeObservingFor1toN {
    bjl_weakify(self);
    [self bjl_kvo:BJLMakeProperty(self.room.speakingRequestVM, speakingEnabled)
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             if (now.boolValue) {
                 if (!self.room.recordingVM.recordingAudio
                     && !self.room.recordingVM.recordingVideo) {
                     [BJLAuthorization checkMicrophoneAccessAndRequest:YES callback:^(BOOL granted, UIAlertController * _Nullable alert) {
                         if (granted) {
                             if (self.room.featureConfig.mediaLimit == BJLMediaLimit_audioOnly
                                 || !self.room.featureConfig.autoPublishVideoStudent) {
                                 BJLError *error = [self.room.recordingVM setRecordingAudio:YES recordingVideo:NO];
                                 if (error) {
                                     [self showProgressHUDWithText:error.localizedFailureReason ?: error.localizedDescription];
                                 }
                                 else {
                                     [self showProgressHUDWithText:(self.room.recordingVM.recordingAudio
                                                                    ? @"麦克风已打开"
                                                                    : @"麦克风已关闭")];
                                 }
                             }
                             else {
                                 [BJLAuthorization checkCameraAccessAndRequest:YES callback:^(BOOL granted, UIAlertController * _Nullable alert) {
                                     if (granted) {
                                         BJLError *error = [self.room.recordingVM setRecordingAudio:YES recordingVideo:YES];
                                         if (error) {
                                             [self showProgressHUDWithText:error.localizedFailureReason ?: error.localizedDescription];
                                         }
                                         else {
                                             [self showProgressHUDWithText:(self.room.recordingVM.recordingAudio || self.room.recordingVM.recordingVideo
                                                                            ? @"麦克风、摄像头已打开"
                                                                            : @"麦克风、摄像头已关闭")];
                                         }
                                     }
                                     else if (alert) {
                                         [self presentViewController:alert animated:YES completion:nil];
                                     }
                                 }];
                             }
                         }
                         else if (alert) {
                             [self presentViewController:alert animated:YES completion:nil];
                         }
                     }];
                 }
             }
             else {
                 if (self.room.recordingVM.recordingAudio
                     || self.room.recordingVM.recordingVideo) {
                     [self.room.recordingVM setRecordingAudio:NO recordingVideo:NO];
                 }
                 if (self.room.slideshowViewController.drawingEnabled) {
                     [self.room.slideshowViewController updateDrawingEnabled:NO];
                 }
             }
             return YES;
         }];
}

- (void)makeObservingForSpeakingInvite {
    __block UIAlertController *alert = nil;
    bjl_weakify(self);
    [self bjl_observe:BJLMakeMethod(self.room.speakingRequestVM, didReceiveSpeakingInvite:)
             observer:(BJLMethodObserver)^BOOL(BOOL invite) {
                 bjl_strongify(self);
                 if (alert) {
                     [alert dismissViewControllerAnimated:NO completion:nil];
                     alert = nil;
                 }
                 if (invite) {
                     alert = [UIAlertController
                              alertControllerWithTitle:@"提示"
                              message:@"老师邀请你上麦发言"
                              preferredStyle:UIAlertControllerStyleAlert];
                     [alert bjl_addActionWithTitle:@"同意"
                                             style:UIAlertActionStyleDefault
                                           handler:^(UIAlertAction * _Nonnull action) {
                                               alert = nil;
                                               [self.room.speakingRequestVM responseSpeakingInvite:YES];
                                               if (self.room.roomInfo.roomType != BJLRoomType_1toN) {
                                                   if (!self.room.recordingVM.recordingAudio
                                                       && !self.room.recordingVM.recordingVideo) {
                                                       [BJLAuthorization checkMicrophoneAccessAndRequest:YES callback:^(BOOL granted, UIAlertController * _Nullable alert) {
                                                           if (granted) {
                                                               if (self.room.featureConfig.mediaLimit == BJLMediaLimit_audioOnly
                                                                   || !self.room.featureConfig.autoPublishVideoStudent) {
                                                                   BJLError *error = [self.room.recordingVM setRecordingAudio:YES recordingVideo:NO];
                                                                   if (error) {
                                                                       [self showProgressHUDWithText:error.localizedFailureReason ?: error.localizedDescription];
                                                                   }
                                                                   else {
                                                                       [self showProgressHUDWithText:(self.room.recordingVM.recordingAudio
                                                                                                      ? @"麦克风已打开"
                                                                                                      : @"麦克风已关闭")];
                                                                   }
                                                               }
                                                               else {
                                                                   [BJLAuthorization checkCameraAccessAndRequest:YES callback:^(BOOL granted, UIAlertController * _Nullable alert) {
                                                                       if (granted) {
                                                                           BJLError *error = [self.room.recordingVM setRecordingAudio:YES recordingVideo:YES];
                                                                           if (error) {
                                                                               [self showProgressHUDWithText:error.localizedFailureReason ?: error.localizedDescription];
                                                                           }
                                                                           else {
                                                                               [self showProgressHUDWithText:(self.room.recordingVM.recordingAudio || self.room.recordingVM.recordingVideo
                                                                                                              ? @"麦克风、摄像头已打开"
                                                                                                              : @"麦克风、摄像头已关闭")];
                                                                           }
                                                                       }
                                                                       else if (alert) {
                                                                           [self presentViewController:alert animated:YES completion:nil];
                                                                       }
                                                                   }];
                                                               }
                                                           }
                                                           else if (alert) {
                                                               [self presentViewController:alert animated:YES completion:nil];
                                                           }
                                                       }];
                                                   }
                                               }
                                           }];
                     [alert bjl_addActionWithTitle:@"拒绝"
                                             style:UIAlertActionStyleDestructive
                                           handler:^(UIAlertAction * _Nonnull action) {
                                               alert = nil;
                                               [self.room.speakingRequestVM responseSpeakingInvite:NO];
                                               if (self.room.roomInfo.roomType != BJLRoomType_1toN) {
                                                   if (self.room.recordingVM.recordingAudio
                                                       || self.room.recordingVM.recordingVideo) {
                                                       [self.room.recordingVM setRecordingAudio:NO recordingVideo:NO];
                                                   }
                                                   /* 拒绝发言不自动关闭画笔
                                                   if (self.room.slideshowViewController.drawingEnabled) {
                                                       self.room.slideshowViewController.drawingEnabled = NO;
                                                   }
                                                   */
                                               }
                                           }];
                     [self presentViewController:alert animated:YES completion:nil];
                 }
                 return YES;
             }];
}

- (void)makeObservingForLamp {
    // 使用 Initial 会导致开始监听时触发两次
    bjl_weakify(self);
    [self bjl_kvoMerge:@[BJLMakeProperty(self, customLampContent),
                         BJLMakeProperty(self.room.roomVM, lampContent)]
               options:(NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew) 
              observer:^(id _Nullable old, id _Nullable now) {
                  bjl_strongify(self);
                  [self updateLamp];
              }];
    
    // 第一次手动触发
    [self updateLamp];
}

- (void)makeObservingForRollcall {
    bjl_weakify(self);
    
    NSString * const rollcallTitleFormat = @"老师要求你在%.0f秒内响应点名";
    __block UIAlertController *rollcallAlert = nil;
    __block id<BJLObservation> observation = nil;
    [self bjl_observe:BJLMakeMethod(self.room.roomVM, didReceiveRollcallWithTimeout:)
             observer:^BOOL(NSTimeInterval timeout) {
                 bjl_strongify(self);
                 if (rollcallAlert) {
                     [rollcallAlert dismissViewControllerAnimated:NO completion:nil];
                 }
                 
                 rollcallAlert = [UIAlertController alertControllerWithTitle:@"点名"
                                                                     message:[NSString stringWithFormat:rollcallTitleFormat, timeout]
                                                              preferredStyle:UIAlertControllerStyleAlert];
                 [rollcallAlert bjl_addActionWithTitle:@"答到"
                                                 style:UIAlertActionStyleDefault
                                               handler:^(UIAlertAction * _Nonnull action) {
                                                   bjl_strongify(self);
                                                   rollcallAlert = nil;
                                                   [observation stopObserving];
                                                   observation = nil;
                                                   [self.room.roomVM answerToRollcall];
                                               }];
                 [self presentViewController:rollcallAlert animated:YES completion:nil];
                 
                 observation = [self bjl_kvo:BJLMakeProperty(self.room.roomVM, rollcallTimeRemaining)
                                    observer:^BOOL(id _Nullable old, id _Nullable now) {
                                        bjl_strongify(self);
                                        rollcallAlert.message = [NSString stringWithFormat:rollcallTitleFormat, self.room.roomVM.rollcallTimeRemaining];
                                        return YES;
                                    }];
                 return YES;
             }];
    [self bjl_observe:BJLMakeMethod(self.room.roomVM, rollcallDidFinish)
             observer:^BOOL {
                 // bjl_strongify(self);
                 [observation stopObserving];
                 observation = nil;
                 [rollcallAlert dismissViewControllerAnimated:YES completion:nil];
                 rollcallAlert = nil;
                 return YES;
             }];
}

- (void)makeObservingForPPTAndDrawing {
    bjl_weakify(self);
    
    [self bjl_kvo:BJLMakeProperty(self.room.slideshowVM, allDocuments)
         observer:^BOOL(id _Nullable old, id _Nullable now) {
             bjl_strongify(self);
             NSInteger pageCount = 0;
             for (BJLDocument *document in self.room.slideshowVM.allDocuments) {
                 pageCount += document.pageInfo.pageCount;
             }
             self.contentView.pageCount = pageCount;
             return YES;
         }];
    [self bjl_kvo:BJLMakeProperty(self.room.slideshowVM, totalPageCount)
         observer:^BOOL(id _Nullable old, id _Nullable now) {
             bjl_strongify(self);
             self.contentView.pageCount = self.room.slideshowVM.totalPageCount;
             return YES;
         }];
    // BJLMakeProperty(self.room.slideshowVM, currentSlidePage)
    [self bjl_kvo:BJLMakeProperty(self.room.slideshowViewController, localPageIndex)
         observer:^BOOL(id _Nullable old, id _Nullable now) {
             bjl_strongify(self);
             // self.room.slideshowVM.currentSlidePage.documentPageIndex
             self.contentView.pageIndex = self.room.slideshowViewController.localPageIndex;
             if (self.room.slideshowViewController.localPageIndex != self.room.slideshowVM.currentSlidePage.documentPageIndex) {
                 if (!self.room.loginUser.isTeacherOrAssistant
                     && self.room.slideshowViewController.drawingEnabled) {
                     [self.room.slideshowViewController updateDrawingEnabled:NO];
                 }
             }
             return YES;
         }];
    
    [self bjl_kvo:BJLMakeProperty(self.room.slideshowViewController, drawingEnabled)
         observer:^BOOL(id _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             BOOL isHorizontal = BJLIsHorizontalUI(self);
             self.contentView.showsClearDrawingButton = now.boolValue;
             [self updateStatusBarAndTopBar];
             [self updateChatConstraintsForHorizontal:isHorizontal];
             [self updateRecordingStateViewForHorizontal:isHorizontal];
             return YES;
         }];
    // 设置 page control button 的标题
    [self bjl_kvoMerge:@[ BJLMakeProperty(self.contentView, pageCount),
                          BJLMakeProperty(self.contentView, pageIndex) ]
              observer:^(id _Nullable old, id _Nullable now) {
                  bjl_strongify(self);
                  if (self.contentView.pageIndex == 0) {
                      [self.room.slideshowViewController.pageControlButton setTitle:@"白板" forState:UIControlStateNormal];
                  }
                  else {
                      NSString *title = [NSString stringWithFormat:@"%td/%td", self.contentView.pageIndex, self.contentView.pageCount - 1];
                      [self.room.slideshowViewController.pageControlButton setTitle:title forState:UIControlStateNormal];
                  }
              }];
    
    // 设置PPT是否可绘制，page control button 是否可用
    [self bjl_kvo:BJLMakeProperty(self.contentView, content)
         observer:^BOOL(id _Nullable old, id _Nullable now) {
             bjl_strongify(self);
             BOOL isPPT = (now == self.room.slideshowViewController.view);
             if (!isPPT && self.room.slideshowViewController.drawingEnabled) {
                 [self.room.slideshowViewController updateDrawingEnabled:NO];
             }
//           2018-10-19 17:31:06 mikasa 禁用上方’白板’点击
//             self.room.slideshowViewController.pageControlButton.enabled = isPPT;
//           2018-10-19 17:31:06 mikasa 禁用上方’白板’点击
             return YES;
         }];
}

- (void)makeObservingForFullScreen {
    bjl_weakify(self);
    
    [self bjl_kvo:BJLMakeProperty(self.previewsViewController, fullScreenItem)
         observer:^BOOL(id _Nullable old, BJLPreviewItem * _Nullable fullScreenItem) {
             bjl_strongify(self);
             if (fullScreenItem.viewController) {
                 [self bjl_addChildViewController:fullScreenItem.viewController
                                       addSubview:^(UIView * _Nonnull parentView, UIView * _Nonnull childView) {
                                           [self.contentView updateContent:fullScreenItem.viewController.view
                                                               contentMode:fullScreenItem.contentMode
                                                               aspectRatio:fullScreenItem.aspectRatio];
                                       }];
             }
             else {
                 [self.contentView updateContent:fullScreenItem.view
                                     contentMode:fullScreenItem.contentMode
                                     aspectRatio:fullScreenItem.aspectRatio];
             }
             return YES;
         }];
    
    [self bjl_kvo:BJLMakeProperty(self.previewsViewController, numberOfItems)
           filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
               // bjl_strongify(self);
               return now.integerValue != old.integerValue;
           }
         observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
             bjl_strongify(self);
             BOOL isHorizontal = BJLIsHorizontalUI(self);
             [self updatePreviewsAndContentConstraintsForHorizontal:isHorizontal];
             return YES;
         }];
    
    // self.previewsViewController.collectionView.contentSize
    [self bjl_kvo:BJLMakeProperty(self.previewsViewController.collectionView, contentSize)
           filter:^BOOL(NSValue * _Nullable old, NSValue * _Nullable now) {
               return !CGSizeEqualToSize(now.CGSizeValue, old.CGSizeValue);
           }
         observer:^BOOL(id _Nullable old, id _Nullable now) {
             bjl_strongify(self);
             BOOL isHorizontal = BJLIsHorizontalUI(self);
             [self updatePreviewsAndContentConstraintsForHorizontal:isHorizontal];
             return YES;
         }];
}

- (void)makeObservingForNotice {
    bjl_weakify(self);
    [self bjl_kvo:BJLMakeProperty(self.room.roomVM, notice)
           filter:^BOOL(BJLNotice * _Nullable old, BJLNotice * _Nullable now) {
               // bjl_strongify(self);
               return ((now.noticeText.length || now.linkURL)
                       && ![now isEqual:old]);
           }
         observer:^BOOL(id _Nullable old, BJLNotice * _Nullable notice) {
             bjl_strongify(self);
             [self.overlayViewController showWithContentViewController:self.noticeViewController];
             return YES;
         }];
}

- (void)makeObservingForQuiz {
    bjl_weakify(self);
    
    [self bjl_observe:BJLMakeMethod(self.room.roomVM, didReceiveQuizMessage:)
             observer:^BOOL(NSDictionary<NSString *, id> *message) {
                 bjl_strongify(self);
                 BJLQuizWebViewController *quizWebViewController = [BJLQuizWebViewController
                                                                    instanceWithQuizMessage:message
                                                                    roomVM:self.room.roomVM];
                 if (quizWebViewController) {
                     quizWebViewController.closeWebViewCallback = ^{
                         bjl_strongify(self);
                         [self.overlayViewController hide];
                         self.quizWebViewController = nil;
                     };
                     quizWebViewController.sendQuizMessageCallback = ^BJLError * _Nullable(NSDictionary<NSString *, id> * _Nonnull message) {
                         bjl_strongify(self);
                         return [self.room.roomVM sendQuizMessage:message];
                     };
                     if (self.quizWebViewController) {
                         [self.overlayViewController hide];
                     }
                     self.quizWebViewController = quizWebViewController;
                     if (bjl_iPhoneX()) {
                         self.overlayViewController.prefersStatusBarHidden = NO;
                         self.overlayViewController.preferredStatusBarStyle = UIStatusBarStyleDefault;
                     }
                     [self.overlayViewController showWithContentViewController:self.quizWebViewController
                                                                      horEdges:UIRectEdgeAll
                                                                       horSize:CGSizeZero
                                                                      verEdges:UIRectEdgeAll
                                                                       verSize:CGSizeZero];
                 }
                 else if (self.quizWebViewController) {
                     [self.quizWebViewController didReceiveQuizMessage:message];
                 }
                 return YES;
             }];
    
    [self.room.roomVM sendQuizMessage:[BJLQuizWebViewController quizReqMessageWithUserNumber:self.room.loginUser.number]];
}

- (void)makeObservingForProgressHUD {
    bjl_weakify(self);
    
    // 上麦失败的提示
    [self bjl_observe:BJLMakeMethod(self.room.recordingVM, recordingDidDeny)
             observer:^BOOL {
                 bjl_strongify(self);
                 [self showProgressHUDWithText:@"服务器拒绝发布音视频，音视频并发已达上限"];
                 return YES;
             }];
    
    //* 暂时没有强制发言逻辑，所以这个用不到
    // 老师强制上麦失败的提示
    if (self.room.loginUser.isTeacher) {
        [self bjl_observe:BJLMakeMethod(self.room.recordingVM, remoteChangeRecordingDidDenyForUser:)
                 observer:^BOOL(BJLUser *user) {
                     bjl_strongify(self);
                     [self showProgressHUDWithText:[NSString stringWithFormat:@"服务器拒绝强制 %@ 发言，音视频并发已达上限", user.name]];
                     return YES;
                 }];
    } // */
    
    // 切换主讲
    [self bjl_kvo:BJLMakeProperty(self.room.onlineUsersVM, currentPresenter)
          options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
           filter:^BOOL(BJLUser * _Nullable old, BJLUser * _Nullable now) {
               // bjl_strongify(self);
               return (old // 默认主讲不提示
                       && now // 老师掉线不提示
                       && old != now
                       && ![now isSameUser:old]);
           }
         observer:^BOOL(id _Nullable old, BJLUser * _Nullable now) {
             bjl_strongify(self);
             NSString *name = self.room.loginUserIsPresenter ? @"你" : now.name;
             [self showProgressHUDWithText:[NSString stringWithFormat:@"%@成为了主讲", name]];
             return YES;
         }];
    
    if (!self.room.loginUser.isTeacher) {
        [self bjl_kvo:BJLMakeProperty(self.room, isSwitching)
               filter:^BOOL(id _Nullable old, NSNumber * _Nullable now) {
                   // bjl_strongify(self);
                   return now.boolValue;
               }
             observer:^BOOL(id _Nullable old, id _Nullable now) {
                 bjl_strongify(self);
                 if (self.room.isSwitching) {
                     [self showProgressHUDWithText:@"切换教室中..."];
                 }
                 return YES;
             }];
        
        [self bjl_kvo:BJLMakeProperty(self.room.onlineUsersVM, activeUsersSynced)
               filter:^BOOL(id _Nullable old, NSNumber * _Nullable now) {
                   // bjl_strongify(self);
                   return now.boolValue;
               }
             observer:^BOOL(id _Nullable old, id _Nullable now) {
                 bjl_strongify(self);
                 if (!self.room.onlineUsersVM.onlineTeacher) {
                     [self showProgressHUDWithText:@"老师未在教室"];
                 }
                 return YES;
             }];
        [self bjl_kvo:BJLMakeProperty(self.room.onlineUsersVM, onlineTeacher)
              options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
               filter:^BOOL(id _Nullable old, id _Nullable now) {
                   bjl_strongify(self);
                   // activeUsersSynced 为 NO 时的变化无意义
                   return self.room.onlineUsersVM.activeUsersSynced && !!old != !!now;
               }
             observer:^BOOL(id _Nullable old, id _Nullable now) {
                 bjl_strongify(self);
                 [self showProgressHUDWithText:now ? @"老师进入教室" : @"老师离开教室"];
                 return YES;
             }];
        
        [self bjl_kvo:BJLMakeProperty(self.room.roomVM, liveStarted)
              options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
               filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
                   // bjl_strongify(self);
                   return old.boolValue != now.boolValue;
               }
             observer:^BOOL(id _Nullable old, NSNumber * _Nullable now) {
                 bjl_strongify(self);
                 [self showProgressHUDWithText:now.boolValue ? @"上课啦" : @"下课啦"];
                 return YES;
             }];
        
        [self bjl_observe:BJLMakeMethod(self.room.playingVM, playingUserDidUpdate:old:)
                 observer:^BOOL(BJLMediaUser * _Nullable now, BJLMediaUser * _Nullable old) {
                     bjl_strongify(self);
                     if (now.isTeacher) {
                         BOOL audioChanged = (now.audioOn != old.audioOn);
                         BOOL videoChanged = (now.videoOn != old.videoOn);
                         
                         if (audioChanged && videoChanged) {
                             if (now.audioOn && now.videoOn) {
                                 [self showProgressHUDWithText:@"老师开启了麦克风和摄像头"];
                             }
                             else if (now.audioOn) {
                                 [self showProgressHUDWithText:@"老师开启了麦克风"];
                             }
                             else if (now.videoOn) {
                                 [self showProgressHUDWithText:@"老师开启了摄像头"];
                             }
                             else {
                                 [self showProgressHUDWithText:@"老师关闭了麦克风和摄像头"];
                             }
                         }
                         else if (audioChanged) {
                             if (now.audioOn) {
                                 [self showProgressHUDWithText:@"老师开启了麦克风"];
                             }
                             else {
                                 [self showProgressHUDWithText:@"老师关闭了麦克风"];
                             }
                         }
                         else { // videoChanged
                             if (now.videoOn) {
                                 [self showProgressHUDWithText:@"老师开启了摄像头"];
                             }
                             else {
                                 [self showProgressHUDWithText:@"老师关闭了摄像头"];
                             }
                         }
                     }
                     return YES;
                 }];
        
        [self bjl_observe:BJLMakeMethod(self.room.speakingRequestVM, speakingRequestDidReplyEnabled:isUserCancelled:user:)
                 observer:(BJLMethodObserver)^BOOL(BOOL speakingEnabled, BOOL isUserCancelled, BJLUser *user) {
                     bjl_strongify(self);
                     if ([user.ID isEqualToString:self.room.loginUser.ID]
                         && !isUserCancelled) {
                         [self showProgressHUDWithText:(speakingEnabled
                                                        ? @"老师同意发言，已进入发言状态"
                                                        : @"老师未同意发言，请稍后再试")];
                     }
                     return YES;
                 }];
        [self bjl_kvo:BJLMakeProperty(self.room.speakingRequestVM, speakingRequestTimeRemaining)
              options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew
               filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable timeRemaining) {
                   // bjl_strongify(self);
                   return old.doubleValue > 0.0 && timeRemaining.doubleValue <= 0.0;
               }
             observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable timeRemaining) {
                 bjl_strongify(self);
                 if (timeRemaining.doubleValue == 0.0) { // reset: - 1.0
                     [self showProgressHUDWithText:@"老师未同意发言，请稍后再试"];
                 }
                 return YES;
             }];
        
        // 举手申请上麦失败的提示
        [self bjl_observe:BJLMakeMethod(self.room.speakingRequestVM, speakingRequestDidDeny)
                 observer:^BOOL {
                     bjl_strongify(self);
                     [self showProgressHUDWithText:@"服务器拒绝申请发言，音视频并发已达上限"];
                     return YES;
                 }];
        
        [self bjl_observe:BJLMakeMethod(self.room.recordingVM, recordingDidRemoteChangedRecordingAudio:recordingVideo:recordingAudioChanged:recordingVideoChanged:)
                 observer:(BJLMethodObserver)^BOOL(BOOL recordingAudio, BOOL recordingVideo, BOOL recordingAudioChanged, BOOL recordingVideoChanged) {
                     bjl_strongify(self);
                     NSString *actionMessage = nil;
                     if (recordingAudioChanged && recordingVideoChanged) {
                         if (recordingAudio == recordingVideo) {
                             actionMessage = recordingAudio ? @"老师开启了你的麦克风和摄像头" : @"老师结束了你的发言"/* @"老师关闭了你的麦克风和摄像头" */;
                         }
                         else {
                             actionMessage = recordingAudio ? @"老师开启了你的麦克风" : @"老师开启了你的摄像头"; // 同时关闭了你的摄像头/麦克风
                         }
                     }
                     else if (recordingAudioChanged) {
                         actionMessage = recordingAudio ? @"老师开启了你的麦克风" : @"老师关闭了你的麦克风";
                     }
                     else if (recordingVideoChanged) {
                         actionMessage = recordingVideo ? @"老师开启了你的摄像头" : @"老师关闭了你的摄像头";
                     }
                     BOOL wasSpeakingEnabled = (recordingAudioChanged ? !recordingAudio : recordingAudio
                                                || recordingVideoChanged ? !recordingVideo : recordingVideo);
                     BOOL isSpeakingEnabled = (recordingAudio || recordingVideo);
                     if (!wasSpeakingEnabled && isSpeakingEnabled) {
                         UIAlertController *alert = [UIAlertController
                                                     alertControllerWithTitle:@"提示"
                                                     message:[NSString stringWithFormat:@"%@，现在可以发言了", actionMessage]
                                                     preferredStyle:UIAlertControllerStyleAlert];
                         [alert bjl_addActionWithTitle:@"知道了"
                                                 style:UIAlertActionStyleCancel
                                               handler:nil];
                         [self presentViewController:alert
                                            animated:YES
                                          completion:nil];
                     }
                     else if (actionMessage) {
                         [self showProgressHUDWithText:actionMessage];
                         if (wasSpeakingEnabled && !isSpeakingEnabled) {
                             [self.room.slideshowViewController updateDrawingEnabled:NO];
                         }
                     }
                     return YES;
                 }];
        
        [self bjl_kvo:BJLMakeProperty(self.room.chatVM, forbidMe)
               filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
                   // bjl_strongify(self);
                   return now.boolValue != old.boolValue;
               }
             observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
                 bjl_strongify(self);
                 [self showProgressHUDWithText:(now.boolValue
                                                ? @"你已被禁言"
                                                : @"你已被解除禁言")];
                 return YES;
             }];
        [self bjl_kvo:BJLMakeProperty(self.room.chatVM, forbidAll)
               filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
                   // bjl_strongify(self);
                   return now.boolValue != old.boolValue;
               }
             observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
                 bjl_strongify(self);
                 [self showProgressHUDWithText:(now.boolValue
                                                ? @"老师开启了全体禁言"
                                                : @"老师关闭了全体禁言")];
                 return YES;
             }];
        
        if (!self.room.loginUser.isTeacherOrAssistant
            && !self.room.featureConfig.disableGrantDrawing) {
            [self bjl_kvo:BJLMakeProperty(self.room.slideshowViewController, drawingGranted)
             // options:NSKeyValueObservingOptionNew | NSKeyValueObservingOptionOld
                   filter:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
                       // bjl_strongify(self);
                       return now.boolValue != old.boolValue;
                   }
                 observer:^BOOL(NSNumber * _Nullable old, NSNumber * _Nullable now) {
                     bjl_strongify(self);
                     [self showProgressHUDWithText:(now.boolValue
                                                    ? @"老师开启了你的画笔权限"
                                                    : @"老师取消了你的画笔权限")];
                     return YES;
                 }];
        }
    }
}

- (void)makeObservingForLoadingVideo {
    bjl_weakify(self);
    [self bjl_observe:BJLMakeMethod(self.previewsViewController, fullScreenDidStartLoadingVideo)
             observer:^BOOL{
                 bjl_strongify(self);
                 [self updateLoadingViewHidden:NO];
                 return YES;
             }];
    [self bjl_observe:BJLMakeMethod(self.previewsViewController, fullScreenDidFinishLoadingVideo)
             observer:^BOOL{
                 bjl_strongify(self);
                 [self updateLoadingViewHidden:YES];
                 return YES;
             }];
}

- (void)updateLoadingViewHidden:(BOOL)hidden {
    if (!self.videoLoadingView) {
        return;
    }
    self.videoLoadingView.hidden = hidden;
    if (!self.videoLoadingView.hidden && !self.videoLoadingImageView.isAnimating) {
        // 显示旋转动画
        [self.videoLoadingView.layer removeAllAnimations];
        [self startAnimation:0];
    }
}

- (void)startAnimation:(CGFloat)angle {
    __block float nextAngle = angle + 10;
    CGAffineTransform endAngle = CGAffineTransformMakeRotation(angle * (M_PI / 180.0f));
    [UIView animateWithDuration:0.02 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        self.videoLoadingImageView.transform = endAngle;
    } completion:^(BOOL finished) {
        if (!self.videoLoadingView.hidden && finished) {
            [self startAnimation:nextAngle];
        }
    }];
}

#pragma mark - 答题器

- (void)makeObservingForAnswerSheet {
    // 老师/助教身份 不监听答题器事件
    if (self.room.loginUser.isTeacherOrAssistant || self.room.loginUser.isGroupTeacherOrAssistant) {
        return;
    }
    
    bjl_weakify(self);
    // 答题开始
    [self bjl_observe:BJLMakeMethod(self.room.roomVM, didReceiveAnswerSheet:)
             observer:^BOOL(BJLAnswerSheet *answerSheet){
                 bjl_strongify(self);
                 [self clearAnswerSheet];
                 self.answerSheetViewController = [[BJLAnswerSheetViewController alloc] initWithAnswerSheet:answerSheet];
                 // 答题结束回调：return YES 表示提交成功，答题器将自动关闭
                 [self.answerSheetViewController setSubmitCallback:^BOOL(BJLAnswerSheet * _Nullable result) {
                     bjl_strongify(self);
                     if (!result) {
                         return NO;
                     }
                     
                     BJLError *error = [self.room.roomVM submitAnswerSheet:result];
                     if (error) {
                         [self showProgressHUDWithText:error.localizedDescription ?: error.localizedFailureReason];
                         return NO;
                     }
                     return YES;
                 }];
                 
                 // 答题器关闭回调
                 [self.answerSheetViewController setCloseCallback:^{
                     bjl_strongify(self);
                     [self clearAnswerSheet];
                 }];
                 
                 [self showProgressHUDWithText:@"答题开始"];
                 [self showAnswerSheet];
                 return YES;
             }];
    
    // 答题结束
    [self bjl_observe:BJLMakeMethod(self.room.roomVM, requireSubmitAnswerSheet)
             observer:^BOOL {
                 bjl_strongify(self);
                 [self showProgressHUDWithText:@"答题已结束"];
                 [self clearAnswerSheet];
                 return YES;
             }];
    
    // 监听到老师不在教室，关闭答题
    [self bjl_kvo:BJLMakeProperty(self.room.onlineUsersVM, onlineTeacher)
         observer:^BOOL(id  _Nullable old, id  _Nullable now) {
             bjl_strongify(self);
             if (!now) {
                 [self clearAnswerSheet];
             }
             return YES;
        }];
}

- (void)showAnswerSheet {
    if (!self.answerSheetViewController) {
        return;
    }
    self.overlayViewController.tapBackgroundToHide = NO;
    [self.overlayViewController showWithContentViewController:self.answerSheetViewController
                                                     horEdges:UIRectEdgeAll
                                                      horSize:CGSizeZero
                                                     verEdges:UIRectEdgeAll
                                                      verSize:CGSizeZero];
}

- (void)clearAnswerSheet {
    if (!self.answerSheetViewController) {
        return;
    }
    [self.overlayViewController hide];
    self.answerSheetViewController = nil;
}

@end

NS_ASSUME_NONNULL_END
