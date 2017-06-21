//
//  QMAudioRecorderController.h
//  AVFoundation
//
//  Created by mac on 17/6/21.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface QMAudioRecorderController : NSObject <AVAudioRecorderDelegate>
@property (nonatomic, strong) AVAudioRecorder *audioRecorder;
@property (nonatomic, strong) void(^finishCallback)(BOOL success, NSError * _Nullable error);
@property(readonly, getter=isRecording) BOOL recording;

- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithContentsOfURL:(NSURL *)url;

- (BOOL)record;
- (BOOL)recordAtTime:(NSTimeInterval)time;
- (BOOL)recordForDuration:(NSTimeInterval) duration;
- (BOOL)recordAtTime:(NSTimeInterval)time forDuration:(NSTimeInterval) duration;

- (void)pause;
- (void)stop;

- (BOOL)deleteRecording;

- (void)updateMeters;

- (float)peakValueForChannel:(NSUInteger)channelNumber;
- (float)averageValueForChannel:(NSUInteger)channelNumber;

@end


NS_ASSUME_NONNULL_END
