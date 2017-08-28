//
//  QMMediaWriter.m
//  AVFoundation
//
//  Created by mac on 17/8/28.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "QMMediaWriter.h"
#import <CoreVideo/CoreVideo.h>

@interface QMMediaWriter ()
@property (nonatomic, strong) AVAssetWriter *assetWriter;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterAudioInput;
@property (nonatomic, strong) AVAssetWriterInput *assetWriterVideoInput;
@property (nonatomic, strong) AVAssetWriterInputPixelBufferAdaptor *assetWriterPixelBufferInput;
@property (nonatomic, assign) BOOL encodingLiveVideo;
@property (nonatomic, assign) CGFloat frameRate;
@property (nonatomic, assign) CGSize videoSize;
@property (nonatomic, assign) CMTime startTime;
@end

@implementation QMMediaWriter

- (instancetype)initWithOutputURL:(NSURL *)URL size:(CGSize)newSize
{
    return [self initWithOutputURL:URL size:newSize fileType:AVFileTypeQuickTimeMovie];
}

- (instancetype)initWithOutputURL:(NSURL *)URL size:(CGSize)newSize fileType:(NSString *)newFileType
{
    if (self = [super init]) {
        _videoSize = newSize;
        _frameRate = 25.0f;
        _startTime = kCMTimeInvalid;
        _encodingLiveVideo = YES;
        
        [self buildAssetWriterWithURL:URL fileType:newFileType];
        [self buildVideoWriter];
        [self buildAudioWriter];
    }
    return self;
}

#pragma mark - AVAssetWriter
- (void)buildAssetWriterWithURL:(NSURL *)url fileType:(NSString *)fileType
{
    NSError *error;
    self.assetWriter = [AVAssetWriter assetWriterWithURL:url fileType:fileType error:&error];
    if (error) {
        NSLog(@"%@", [error localizedDescription]);
        exit(0);
    }
    self.assetWriter.movieFragmentInterval = CMTimeMakeWithSeconds(1.0, 1000);
}

- (void)buildVideoWriter
{
    NSDictionary *dict = @{ AVVideoWidthKey:@(_videoSize.width),
                            AVVideoHeightKey:@(_videoSize.height),
                            AVVideoCodecKey:AVVideoCodecH264,
//                            AVVideoProfileLevelKey:AVVideoProfileLevelH264BaselineAutoLevel,
//                            AVVideoExpectedSourceFrameRateKey:@(_frameRate),
//                            AVVideoAverageBitRateKey:@(2000000)
                            };
    self.assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:dict];
    self.assetWriterVideoInput.expectsMediaDataInRealTime = _encodingLiveVideo;
    
    NSDictionary *attributesDictionary = @{
                                           (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange),
                                           (id)kCVPixelBufferWidthKey : @(_videoSize.width),
                                           (id)kCVPixelBufferHeightKey : @(_videoSize.height)
                                           };
    
    self.assetWriterPixelBufferInput = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.assetWriterVideoInput sourcePixelBufferAttributes:attributesDictionary];
    
    [self.assetWriter addInput:self.assetWriterVideoInput];
}

- (void)buildAudioWriter
{
    AudioChannelLayout acl;
    bzero( &acl, sizeof(acl));
    acl.mChannelLayoutTag = kAudioChannelLayoutTag_Mono;
    
    NSDictionary *audioOutputSettings = @{
                                          AVChannelLayoutKey : [NSData dataWithBytes:&acl length:sizeof(acl)],
                                          AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                          AVNumberOfChannelsKey : @(1),
                                          AVSampleRateKey : @(48000),
                                          AVEncoderBitRateKey : @(640000)
                                          };
    
    self.assetWriterAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings];
    
    [self.assetWriter addInput:self.assetWriterAudioInput];
    self.assetWriterAudioInput.expectsMediaDataInRealTime = _encodingLiveVideo;
}

#pragma mark - AudioBuffer
- (void)processVideoBuffer:(CMSampleBufferRef)videoBuffer
{
    CFRetain(videoBuffer);
    CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(videoBuffer);
    
    if (CMTIME_IS_INVALID(_startTime))
    {
        if (self.assetWriter.status != AVAssetWriterStatusWriting)
        {
            [self.assetWriter startWriting];
        }
        
        [self.assetWriter startSessionAtSourceTime:currentSampleTime];
        _startTime = currentSampleTime;
    }

    while(!self.assetWriterVideoInput.readyForMoreMediaData && !_encodingLiveVideo) {
        NSDate *maxDate = [NSDate dateWithTimeIntervalSinceNow:0.1];
        [[NSRunLoop currentRunLoop] runUntilDate:maxDate];
    }
    
    NSLog(@"-------> %d %@", self.assetWriter.status, [self.assetWriter.error localizedDescription]);
    
    if (!self.assetWriterVideoInput.readyForMoreMediaData) {
        NSLog(@"2: Had to drop a video frame %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
        
    } else if(self.assetWriter.status == AVAssetWriterStatusWriting) {
        CVPixelBufferRef pixel_buffer = NULL;
        CVPixelBufferLockBaseAddress(pixel_buffer, 0);
        if (![self.assetWriterPixelBufferInput appendPixelBuffer:pixel_buffer withPresentationTime:currentSampleTime])
            
            NSLog(@"Problem appending pixel buffer at time: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
    } else {
        NSLog(@"Couldn't write a frame");
        //NSLog(@"Wrote a video frame: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
    }
    
    CFRelease(videoBuffer);
}

- (void)processAudioBuffer:(CMSampleBufferRef)audioBuffer;
{
    CFRetain(audioBuffer);
    
    CMTime currentSampleTime = CMSampleBufferGetOutputPresentationTimeStamp(audioBuffer);
    if (CMTIME_IS_INVALID(_startTime))
    {
        if (self.assetWriter.status != AVAssetWriterStatusWriting)
        {
            [self.assetWriter startWriting];
        }
        
        [self.assetWriter startSessionAtSourceTime:currentSampleTime];
        _startTime = currentSampleTime;
    }
    
    
    while(!self.assetWriterAudioInput.readyForMoreMediaData && ! _encodingLiveVideo) {
        NSDate *maxDate = [NSDate dateWithTimeIntervalSinceNow:0.5];
        [[NSRunLoop currentRunLoop] runUntilDate:maxDate];
    }
    
    if (!self.assetWriterAudioInput.readyForMoreMediaData) {
        NSLog(@"2: Had to drop an audio frame %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
    
    } else if(self.assetWriter.status == AVAssetWriterStatusWriting) {
        if (![self.assetWriterAudioInput appendSampleBuffer:audioBuffer])
            NSLog(@"Problem appending audio buffer at time: %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
    
    } else {
        NSLog(@"Wrote an audio frame %@", CFBridgingRelease(CMTimeCopyDescription(kCFAllocatorDefault, currentSampleTime)));
    }
    
    CMSampleBufferInvalidate(audioBuffer);
    CFRelease(audioBuffer);
}

- (void)finishWriting
{
    if (self.assetWriter.status == AVAssetWriterStatusCompleted || self.assetWriter.status == AVAssetWriterStatusCancelled || self.assetWriter.status == AVAssetWriterStatusUnknown) {
        return;
    }
    
    if(self.assetWriter.status == AVAssetWriterStatusWriting) {
        [self.assetWriterVideoInput markAsFinished];
    }
    
    if(self.assetWriter.status == AVAssetWriterStatusWriting) {
        [self.assetWriterAudioInput markAsFinished];
    }
    
    [self.assetWriter finishWritingWithCompletionHandler:^{
        
    }];
    
}
@end
