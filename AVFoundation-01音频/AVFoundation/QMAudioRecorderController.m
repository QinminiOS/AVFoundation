//
//  QMAudioRecorderController.m
//  AVFoundation
//
//  Created by mac on 17/6/21.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "QMAudioRecorderController.h"
#import "QMMeterTable.h"

@interface QMAudioRecorderController()
@property (nonatomic, strong) QMMeterTable *meterTable;
@end

@implementation QMAudioRecorderController

- (instancetype)initWithContentsOfURL:(NSURL *)url
{
    if (url && (self = [super init])) {
        NSDictionary *setting = @{
                               AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                               AVSampleRateKey : @(44100),
                               AVNumberOfChannelsKey : @(1),
                               AVLinearPCMBitDepthKey : @(16),
                               AVEncoderAudioQualityKey : @(AVAudioQualityMedium)
                               };
        
        NSError *error;
        _audioRecorder = [[AVAudioRecorder alloc] initWithURL:url settings:setting error:&error];
        if (error) {
            NSLog(@"%@", [error localizedDescription]);
            return nil;
        }
        
        _meterTable = [[QMMeterTable alloc] init];
        _audioRecorder.meteringEnabled = YES;
        _audioRecorder.delegate = self;
        [_audioRecorder prepareToRecord];
        
        return self;
    }
    
    return nil;
}

- (BOOL)isRecording
{
    return [_audioRecorder isRecording];
}

- (BOOL)record
{
    NSError *error;
    if (![[AVAudioSession sharedInstance] setCategory:AVAudioSessionCategoryPlayAndRecord error:&error]) {
        NSLog(@"setCategory error: %@", [error localizedDescription]);
        return NO;
    }
    
    if (![[AVAudioSession sharedInstance] setActive:YES error:&error]) {
        NSLog(@"setActive error: %@", [error localizedDescription]);
        return NO;
    }
    
    return [_audioRecorder record];
}

- (BOOL)recordAtTime:(NSTimeInterval)time
{
    return [_audioRecorder recordAtTime:time];
}

- (BOOL)recordForDuration:(NSTimeInterval) duration
{
    return [_audioRecorder recordForDuration:duration];
}

- (BOOL)recordAtTime:(NSTimeInterval)time forDuration:(NSTimeInterval) duration
{
    return [_audioRecorder recordAtTime:time forDuration:duration];
}

- (void)pause
{
    [_audioRecorder pause];
}

- (void)stop
{
    [_audioRecorder stop];
}

- (BOOL)deleteRecording
{
    return [_audioRecorder deleteRecording];
}

- (void)updateMeters
{
    [_audioRecorder updateMeters];
}

- (float)peakValueForChannel:(NSUInteger)channelNumber
{
    return [_meterTable valueForPower:[_audioRecorder peakPowerForChannel:channelNumber]];
}

- (float)averageValueForChannel:(NSUInteger)channelNumber
{
    return [_meterTable valueForPower:[_audioRecorder averagePowerForChannel:channelNumber]];
}

#pragma mark - AVAudioRecorderDelegate
- (void)audioRecorderDidFinishRecording:(AVAudioRecorder *)recorder successfully:(BOOL)flag
{
    if (self.finishCallback) {
        self.finishCallback(flag, nil);
    }
}

- (void)audioRecorderEncodeErrorDidOccur:(AVAudioRecorder *)recorder error:(NSError * __nullable)error;
{
    NSLog(@"RecorderEncodeError error:%@", [error localizedDescription]);
    
    if (self.finishCallback) {
        self.finishCallback(NO, error);
    }
}

@end
