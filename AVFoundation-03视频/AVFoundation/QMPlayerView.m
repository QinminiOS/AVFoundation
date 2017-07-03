//
//  QMPlayerView.m
//  AVFoundation
//
//  Created by qinmin on 2017/7/3.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "QMPlayerView.h"
#import <AVFoundation/AVFoundation.h>

@implementation QMPlayerView

+ (Class)layerClass
{
    return [AVPlayerLayer class];
}

- (instancetype)init
{
    if (self = [super initWithFrame:[UIScreen mainScreen].bounds]) {
        [self setBackgroundColor:[UIColor blackColor]];
    }

    return self;
}

- (void)setPlayer:(AVPlayer *)player
{
    if (!player) {
        return;
    }
    
    [(AVPlayerLayer *)[self layer] setPlayer:player];
}
@end
