//
//  ViewController.m
//  AVFoundation
//
//  Created by mac on 17/6/20.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "HwAACEncoder.h"
#import "SwAACEncoder.h"

#define kDocumentPath(path) [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:path]

@interface ViewController () <AVCaptureAudioDataOutputSampleBufferDelegate,HwAACEncoderDelegate,SwAACEncoder>
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) HwAACEncoder *hwAACEncoder;
@property (nonatomic, assign) FILE *fileHandle;
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioDataOutput;
@property (nonatomic, strong) SwAACEncoder *swAACEncoder;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupEncoder1];
    [self setupFilehandle];
    [self setupSession];
}

- (void)setupSession
{
    self.captureSession = [[AVCaptureSession alloc] init];
    
    // Input
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    NSError *error;
    AVCaptureInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!error && [self.captureSession canAddInput:input]) {
        [self.captureSession addInput:input];
    }

    // Output
    self.audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    [self.audioDataOutput setSampleBufferDelegate:self queue:dispatch_get_global_queue(0, 0)];
    if ([self.captureSession canAddOutput:self.audioDataOutput]) {
        [self.captureSession addOutput:self.audioDataOutput];
    }
    
    [self.captureSession startRunning];
}

- (void)setupEncoder
{
    self.hwAACEncoder = [[HwAACEncoder alloc] init];
    [self.hwAACEncoder setupWithSampleRate:44100
                            bitsPerChannel:16
                              channelCount:1
                                   bitrate:100000];
    
    self.hwAACEncoder.delegate = self;
}

- (void)setupEncoder1
{
    self.swAACEncoder = [[SwAACEncoder alloc] init];
    [self.swAACEncoder setupWithSampleRate:44100 numChannels:1 pcmBitSize:16];
    
    self.swAACEncoder.delegate = self;
}

- (void)setupFilehandle
{
    [[NSFileManager defaultManager] removeItemAtPath:kDocumentPath(@"out.aac") error:nil];
    _fileHandle = fopen(kDocumentPath(@"out.aac").UTF8String, "ab+");
}

#pragma mark - AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    if (self.captureSession.isRunning) {
        if (output == _audioDataOutput) {
            //获取pcm数据大小
            NSInteger audioDataSize = CMSampleBufferGetTotalSampleSize(sampleBuffer);
            
            //分配空间
            int8_t *audioData = malloc(audioDataSize);
            
            //获取CMBlockBufferRef, 这个结构里面就保存了 PCM数据
            CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
            
            //直接将数据copy至我们自己分配的内存中
            CMBlockBufferCopyDataBytes(dataBuffer, 0, audioDataSize, audioData);
            
            // 转为NSData
            NSData *data = [NSData dataWithBytesNoCopy:audioData length:audioDataSize];
            
            //[self.hwAACEncoder encodePCMData:data];
            
            [self.swAACEncoder encodeBuffer:(char *)data.bytes size:(uint)data.length];
        }
    }
}

#pragma mark - HwAACEncoderDelegate
- (void)didGetEncodedData:(NSData *)data error:(NSError *)error
{
    if (!error) {
        fwrite(data.bytes, 1, data.length, _fileHandle);
    }
}

@end
