//
//  ViewController.m
//  Movie
//
//  Created by qinmin on 2017/6/30.
//  Copyright © 2017年 qinmin. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "H264HwEncoder.h"
#import "X264Utils.h"


#define kDocumentPath(path) [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:path]

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate,H264HwEncoderDelegate,X264Delegate>
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;

@property (nonatomic, strong) H264HwEncoder *h264HwEncoder;
@property (nonatomic, strong) X264Utils *x264Encoder;

@property (nonatomic, assign) FILE *fileHandle;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupEncoder1];
    [self setupOutputFile];
    [self setupCaptureSession];
}

- (void)setupOutputFile
{
    [[NSFileManager defaultManager] removeItemAtPath:kDocumentPath(@"output.h264") error:nil];
    _fileHandle = fopen([kDocumentPath(@"output.h264") UTF8String], "ab+");
}

- (void)setupEncoder
{
    self.h264HwEncoder = [[H264HwEncoder alloc] init];
    [self.h264HwEncoder setupEncoder:640 height:480];
    [self.h264HwEncoder setDelegate:self];
}

- (void)setupEncoder1
{
    self.x264Encoder = [[X264Utils alloc] init];
    [self.x264Encoder setupEncoderWithWidth:640 height:480 frameRate:25 bitrate:640*480*3];
    [self.x264Encoder setDelegate:self];
}

- (void)setupCaptureSession
{
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession setSessionPreset:AVCaptureSessionPreset640x480];
    
    // Create a device input with the device and add it to the session.
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        return;
    }
    [self.captureSession addInput:input];
    
    // Create a VideoDataOutput and add it to the session
    _videoOutput = [[AVCaptureVideoDataOutput alloc] init];
    [_videoOutput setSampleBufferDelegate:self queue:dispatch_get_global_queue(0, 0)];
    _videoOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [self.captureSession addOutput:_videoOutput];
    
    AVCaptureVideoPreviewLayer *previewLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    previewLayer.frame = [UIScreen mainScreen].bounds;
    [self.view.layer addSublayer:previewLayer];
    
    // Start the session running to start the flow of data
    [self.captureSession startRunning];
}

#pragma mark - AVCaptureVideoDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    if (!self.captureSession.isRunning) {
        return;
    }else if (captureOutput == _videoOutput) {
        //CVImageBufferRef cameraFrame = CMSampleBufferGetImageBuffer(sampleBuffer);
        //int bufferWidth = (int) CVPixelBufferGetWidth(cameraFrame);
        //int bufferHeight = (int) CVPixelBufferGetHeight(cameraFrame);
    
        [self.h264HwEncoder encodeBuffer:sampleBuffer];
        [self.x264Encoder encodeBuffer:sampleBuffer];
    }
}

- (void)gotSpsPps:(NSData *)sps pps:(NSData *)pps starCode:(BOOL)flag
{
    char slide[] = "\x00\x00\x00\x01";
    if (sps) {
        if (!flag) {
            fwrite(slide, 1, 4, _fileHandle);
        }
        fwrite(sps.bytes, 1, sps.length, _fileHandle);
    }
    
    if (pps) {
        if (!flag) {
            fwrite(slide, 1, 4, _fileHandle);
        }
        fwrite(pps.bytes, 1, pps.length, _fileHandle);
    }
}

- (void)gotEncodedData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame starCode:(BOOL)flag
{
    if (!flag) {
        char slide[] = "\x00\x00\x00\x01";
        fwrite(slide, 1, 4, _fileHandle);
    }
    
    fwrite(data.bytes, 1, data.length, _fileHandle);
}

@end
