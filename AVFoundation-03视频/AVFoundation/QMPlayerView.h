//
//  QMPlayerView.h
//  AVFoundation
//
//  Created by qinmin on 2017/7/3.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface QMPlayerView : UIView

- (instancetype)init;

- (void)setPlayer:(AVPlayer *)player;

@end
