//
//  QMPlayer.h
//  AVFoundation
//
//  Created by qinmin on 2017/7/3.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface QMPlayer : NSObject
@property (nonatomic, strong) UIView *previewView;
@property (nonatomic, assign) float playbackVolume;

- (instancetype)initWithURL:(NSURL *)assetURL;

- (void)setVideoFillMode:(NSString *)fillMode;

- (void)play;
- (void)pause;
- (void)stop;

// 字幕
- (NSArray<AVMediaSelectionGroup *> *)mediaSelectionGroups;
- (void)selectMediaOption:(AVMediaSelectionOption *)mediaSelectionOption
    inMediaSelectionGroup:(AVMediaSelectionGroup *)mediaSelectionGroup;

- (NSTimeInterval)currentPlaybackTime;
- (void)setCurrentPlaybackTime:(NSTimeInterval)aCurrentPlaybackTime;

- (UIImage *)thumbnailImageAtCurrentTime;

@end
