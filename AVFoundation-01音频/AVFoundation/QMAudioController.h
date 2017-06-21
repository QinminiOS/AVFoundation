//
//  QMAudioController.h
//  AVFoundation
//
//  Created by mac on 17/6/20.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QMAudioController : NSObject

@property (nonatomic, strong, readonly) AVAudioPlayer *musicPlayer;
@property (nonatomic, assign, readonly, getter=isPlaying) BOOL playing;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url;

- (void)play;
- (BOOL)playAtTime:(NSTimeInterval)time;
- (void)pause;
- (void)stop;

- (void)updateMeters;

- (float)peakValueForChannel:(NSUInteger)channelNumber;
- (float)averageValueForChannel:(NSUInteger)channelNumber;

@end

NS_ASSUME_NONNULL_END
