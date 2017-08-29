//
//  QMMediaReader.m
//  AVFoundation
//
//  Created by mac on 17/8/28.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "QMMediaReader.h"
#import <CoreVideo/CoreVideo.h>
#import <AVFoundation/AVFoundation.h>

@interface QMMediaReader ()
@property (nonatomic, strong) NSURL *url;
@property (nonatomic, strong) AVAsset *asset;
@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, assign) CMTime previousFrameTime;
@property (nonatomic, assign) CFAbsoluteTime previousActualFrameTime;
@end

@implementation QMMediaReader

- (id)initWithURL:(NSURL *)url;
{
    if (self = [super init])
    {
        self.url = url;
        self.asset = nil;
    }
    
    return self;
}

- (id)initWithAsset:(AVAsset *)asset;
{
    if (self = [super init])
    {
        self.url = nil;
        self.asset = asset;
    }
    
    return self;
}

#pragma mark - cancelProcessing
- (void)cancelProcessing
{
    if (self.reader) {
        [self.reader cancelReading];
    }
}

#pragma mark - startProcessing
- (void)startProcessing
{
    _previousFrameTime = kCMTimeZero;
    _previousActualFrameTime = CFAbsoluteTimeGetCurrent();
    
    NSDictionary *inputOptions = @{AVURLAssetPreferPreciseDurationAndTimingKey : @(YES)};
    self.asset = [[AVURLAsset alloc] initWithURL:self.url options:inputOptions];
    
    __weak typeof(self) weakSelf = self;
    [self.asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler: ^{
        dispatch_async(dispatch_get_global_queue(0, 0), ^{
            NSError *error = nil;
            AVKeyValueStatus tracksStatus = [weakSelf.asset statusOfValueForKey:@"tracks" error:&error];
            if (tracksStatus != AVKeyValueStatusLoaded) {
                return;
            }
            [weakSelf processAsset];
        });
    }];
}

- (AVAssetReader *)createAssetReader
{
    NSError *error = nil;
    AVAssetReader *assetReader = [AVAssetReader assetReaderWithAsset:self.asset error:&error];
    
    // Video
    NSArray *videoTracks = [self.asset tracksWithMediaType:AVMediaTypeVideo];
    BOOL shouldRecordVideoTrack = [videoTracks count] > 0;
    AVAssetReaderTrackOutput *readerVideoTrackOutput = nil;
    if (shouldRecordVideoTrack) {
        AVAssetTrack* videoTrack = [videoTracks firstObject];
        NSDictionary *outputSettings = @{
                                         (id)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_32BGRA)
                                         };
        readerVideoTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:outputSettings];
        readerVideoTrackOutput.alwaysCopiesSampleData = NO;
        [assetReader addOutput:readerVideoTrackOutput];
    }
    
    // Audio
    NSArray *audioTracks = [self.asset tracksWithMediaType:AVMediaTypeAudio];
    BOOL shouldRecordAudioTrack = [audioTracks count] > 0;
    AVAssetReaderTrackOutput *readerAudioTrackOutput = nil;
    
    if (shouldRecordAudioTrack)
    {
        AVAssetTrack* audioTrack = [audioTracks firstObject];
        NSDictionary *audioOutputSetting = @{
                                             AVFormatIDKey : @(kAudioFormatLinearPCM),
                                             AVNumberOfChannelsKey : @(2),
                                             };

        readerAudioTrackOutput = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:audioTrack outputSettings:audioOutputSetting];
        readerAudioTrackOutput.alwaysCopiesSampleData = NO;
        [assetReader addOutput:readerAudioTrackOutput];
    }
    
    return assetReader;
}

- (void)processAsset
{
    self.reader = [self createAssetReader];
    
    AVAssetReaderOutput *readerVideoTrackOutput = nil;
    AVAssetReaderOutput *readerAudioTrackOutput = nil;
    
    for( AVAssetReaderOutput *output in self.reader.outputs ) {
        if( [output.mediaType isEqualToString:AVMediaTypeAudio] ) {
            readerAudioTrackOutput = output;
        }else if( [output.mediaType isEqualToString:AVMediaTypeVideo] ) {
            readerVideoTrackOutput = output;
        }
    }
    
    if ([self.reader startReading] == NO) {
        NSLog(@"Error reading from file at URL: %@", self.url);
        return;
    }
    
    while (self.reader.status == AVAssetReaderStatusReading ) {
        if (readerVideoTrackOutput) {
            [self readNextVideoFrameFromOutput:readerVideoTrackOutput];
        }
        
        if (readerAudioTrackOutput) {
            [self readNextAudioSampleFromOutput:readerAudioTrackOutput];
        }
    }
    
    if (self.reader.status == AVAssetReaderStatusCompleted) {
        [self.reader cancelReading];
        if (self.readerCompleteCallback) {
            self.readerCompleteCallback();
        }
    }
    
}

- (void)readNextVideoFrameFromOutput:(AVAssetReaderOutput *)readerVideoTrackOutput;
{
    if (self.reader.status == AVAssetReaderStatusReading)
    {
        CMSampleBufferRef sampleBufferRef = [readerVideoTrackOutput copyNextSampleBuffer];
        if (sampleBufferRef)
        {
            //NSLog(@"read a video frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, CMSampleBufferGetOutputPresentationTimeStamp(sampleBufferRef))));
            
            BOOL playAtActualSpeed = YES;
            if (playAtActualSpeed) {
                // Do this outside of the video processing queue to not slow that down while waiting
                CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(sampleBufferRef);
                CMTime differenceFromLastFrame = CMTimeSubtract(currentSampleTime, _previousFrameTime);
                CFAbsoluteTime currentActualTime = CFAbsoluteTimeGetCurrent();
                
                CGFloat frameTimeDifference = CMTimeGetSeconds(differenceFromLastFrame);
                CGFloat actualTimeDifference = currentActualTime - _previousActualFrameTime;
                
                if (frameTimeDifference > actualTimeDifference)
                {
                    usleep(1000000.0 * (frameTimeDifference - actualTimeDifference));
                }
                
                _previousFrameTime = currentSampleTime;
                _previousActualFrameTime = CFAbsoluteTimeGetCurrent();
            }
            
            if (self.videoReaderCallback) {
                self.videoReaderCallback(sampleBufferRef);
            }
            CMSampleBufferInvalidate(sampleBufferRef);
            CFRelease(sampleBufferRef);
        }
    }
}

- (void)readNextAudioSampleFromOutput:(AVAssetReaderOutput *)readerAudioTrackOutput;
{
    if (self.reader.status == AVAssetReaderStatusReading)
    {
        CMSampleBufferRef audioSampleBufferRef = [readerAudioTrackOutput copyNextSampleBuffer];
        if (audioSampleBufferRef)
        {
            //NSLog(@"read an audio frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, CMSampleBufferGetOutputPresentationTimeStamp(audioSampleBufferRef))));
            if (self.audioReaderCallback) {
                self.audioReaderCallback(audioSampleBufferRef);
            }
            CFRelease(audioSampleBufferRef);
        }
    }
}

@end
