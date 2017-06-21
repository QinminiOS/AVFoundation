//
//  QMAudioController.m
//  AVFoundation
//
//  Created by mac on 17/6/20.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "QMAudioController.h"
#import "QMMeterTable.h"

@interface QMAudioController ()
@property (nonatomic, strong) QMMeterTable *meterTable;
@end

@implementation QMAudioController

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)initWithContentsOfURL:(NSURL *)url
{
    if (url && (self = [super init])) {
        NSError *error = nil;
        _musicPlayer = [[AVAudioPlayer alloc] initWithContentsOfURL:url error:&error];
        if (error) {
            NSLog(@"%@", [error localizedDescription]);
            return nil;
        }
       
        _musicPlayer.volume = 0.5f;
        _musicPlayer.pan = 0.0f;
        _musicPlayer.rate = 1.0f;
        _musicPlayer.numberOfLoops = -1;
        _musicPlayer.meteringEnabled = YES;
        [_musicPlayer prepareToPlay];
        
        _meterTable = [[QMMeterTable alloc] init];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleInterruption:)
                                                     name:AVAudioSessionInterruptionNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(handleRouteChange:)
                                                     name:AVAudioSessionRouteChangeNotification
                                                   object:nil];
        
        return self;
    }
    
    return nil;
}

- (void)play
{
    NSError *error;
    if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayback error:&error]) {
        NSLog(@"setCategory error: %@", [error localizedDescription]);
        return;
    }

    if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
        NSLog(@"setActive error: %@", [error localizedDescription]);
        return;
    }
    
    if (![_musicPlayer isPlaying]) {
        [_musicPlayer play];
    }
}

- (BOOL)playAtTime:(NSTimeInterval)time
{
    return [_musicPlayer playAtTime:time];
}

- (void)pause
{
    [_musicPlayer pause];
}

- (void)stop
{
    if ([_musicPlayer isPlaying]) {
        [_musicPlayer stop];
    }
}

- (BOOL)isPlaying
{
    return [_musicPlayer isPlaying];
}

- (void)updateMeters
{
    [_musicPlayer updateMeters];
}

- (float)peakValueForChannel:(NSUInteger)channelNumber
{
    return [_meterTable valueForPower:[_musicPlayer peakPowerForChannel:channelNumber]];
}

- (float)averageValueForChannel:(NSUInteger)channelNumber
{
    return [_meterTable valueForPower:[_musicPlayer averagePowerForChannel:channelNumber]];
}

#pragma mark - Notification
- (void)handleInterruption:(NSNotification *)notice
{
    AVAudioSessionInterruptionType type = [notice.userInfo[AVAudioSessionInterruptionTypeKey] unsignedIntegerValue];
    if (type == AVAudioSessionInterruptionTypeBegan) {
        [_musicPlayer pause];
    }else if (type == AVAudioSessionInterruptionTypeEnded) {
        [_musicPlayer play];
    }
}

- (void)handleRouteChange:(NSNotification *)notice
{
    AVAudioSessionRouteChangeReason reason = [notice.userInfo[AVAudioSessionRouteChangeReasonKey] unsignedIntegerValue];
    if (reason == AVAudioSessionRouteChangeReasonOldDeviceUnavailable) {
        AVAudioSessionRouteDescription *preRoute = notice.userInfo[AVAudioSessionRouteChangePreviousRouteKey];
        NSString *portType = [[preRoute.outputs firstObject] portType];
        if ([portType isEqualToString:AVAudioSessionPortHeadphones]) {
            [_musicPlayer pause];
        }
    }
}

@end
