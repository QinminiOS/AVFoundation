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
    NSDictionary *dict = @{
                           AVVideoWidthKey:@(_videoSize.width),
                           AVVideoHeightKey:@(_videoSize.height),
                           AVVideoCodecKey:AVVideoCodecH264
                           };
    self.assetWriterVideoInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:dict];
    self.assetWriterVideoInput.expectsMediaDataInRealTime = _encodingLiveVideo;
    
    NSDictionary *attributesDictionary = @{
                                           (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
                                           (id)kCVPixelBufferWidthKey : @(_videoSize.width),
                                           (id)kCVPixelBufferHeightKey : @(_videoSize.height)
                                           };
    
    self.assetWriterPixelBufferInput = [AVAssetWriterInputPixelBufferAdaptor assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self.assetWriterVideoInput sourcePixelBufferAttributes:attributesDictionary];
    
    [self.assetWriter addInput:self.assetWriterVideoInput];
}

- (void)buildAudioWriter
{
    NSDictionary *audioOutputSettings = @{
                                          AVFormatIDKey : @(kAudioFormatMPEG4AAC),
                                          AVNumberOfChannelsKey : @(2),
                                          AVSampleRateKey : @(48000),
                                          };
    
    self.assetWriterAudioInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeAudio outputSettings:audioOutputSettings];
    
    [self.assetWriter addInput:self.assetWriterAudioInput];
    self.assetWriterAudioInput.expectsMediaDataInRealTime = _encodingLiveVideo;
}

#pragma mark - AudioBuffer
- (void)processVideoBuffer:(CMSampleBufferRef)videoBuffer
{
    if (!CMSampleBufferIsValid(videoBuffer)) {
        return;
    }
    
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
    
    NSLog(@"video => %ld %@", (long)self.assetWriter.status, [self.assetWriter.error localizedDescription]);
    
    if (!self.assetWriterVideoInput.readyForMoreMediaData) {
        NSLog(@"had to drop a video frame");
        
    } else if(self.assetWriter.status == AVAssetWriterStatusWriting) {
        CVImageBufferRef cvimgRef = CMSampleBufferGetImageBuffer(videoBuffer);
        if (![self.assetWriterPixelBufferInput appendPixelBuffer:cvimgRef withPresentationTime:currentSampleTime]) {
            NSLog(@"appending pixel fail");
        }
    } else {
        NSLog(@"write frame fail");
    }
    
    CFRelease(videoBuffer);
}

- (void)processAudioBuffer:(CMSampleBufferRef)audioBuffer;
{
    if (!CMSampleBufferIsValid(audioBuffer)) {
        return;
    }
    
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
    
    NSLog(@"audio => %ld %@", (long)self.assetWriter.status, [self.assetWriter.error localizedDescription]);
    
    while(!self.assetWriterAudioInput.readyForMoreMediaData && ! _encodingLiveVideo) {
        NSDate *maxDate = [NSDate dateWithTimeIntervalSinceNow:0.5];
        [[NSRunLoop currentRunLoop] runUntilDate:maxDate];
    }
    
    if (!self.assetWriterAudioInput.readyForMoreMediaData) {
        NSLog(@"had to drop an audio frame");
    } else if(self.assetWriter.status == AVAssetWriterStatusWriting) {
        if (![self.assetWriterAudioInput appendSampleBuffer:audioBuffer]) {
           NSLog(@"appending audio buffer fail");
        }
    } else {
        NSLog(@"write audio frame fail");
    }
    
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
