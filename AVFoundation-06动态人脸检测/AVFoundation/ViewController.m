//
//  ViewController.m
//  AVFoundation
//
//  Created by mac on 17/6/20.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "QMPreviewView.h"

#define kDocumentPath(path) [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:path]

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate,AVCaptureMetadataOutputObjectsDelegate>
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureMetadataOutput *metaDataOutput;
@property (nonatomic, assign) QMPreviewView *previewView;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self setupView];
    [self setupSession];
}

- (void)setupView
{
    QMPreviewView *previewView = [[QMPreviewView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:previewView];
    _previewView = previewView;
}

- (void)setupSession
{
    self.captureSession = [[AVCaptureSession alloc] init];
    
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession setSessionPreset:AVCaptureSessionPreset640x480];
    [self.previewView setSession:self.captureSession];
    
    // Create a device input with the device and add it to the session.
    AVCaptureDevice *device = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    NSError *error;
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input) {
        return;
    }
    [self.captureSession addInput:input];
    
    // Create a VideoDataOutput and add it to the session
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoDataOutput setSampleBufferDelegate:self queue:dispatch_get_global_queue(0, 0)];
    self.videoDataOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [self.captureSession addOutput:self.videoDataOutput];
    
    // Output
    self.metaDataOutput = [[AVCaptureMetadataOutput alloc] init];

    [self.metaDataOutput setMetadataObjectsDelegate:self queue:dispatch_get_global_queue(0, 0)];
    if ([self.captureSession canAddOutput:self.metaDataOutput]) {
        [self.captureSession addOutput:self.metaDataOutput];
    }

    for (NSString *metaType in self.metaDataOutput.availableMetadataObjectTypes) {
        NSLog(@"%@", metaType);
    }

    self.metaDataOutput.metadataObjectTypes = @[AVMetadataObjectTypeFace];
    
    [self.captureSession startRunning];
}

#pragma mark - AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
   
}

- (void)captureOutput:(AVCaptureOutput *)output didOutputMetadataObjects:(NSArray<__kindof AVMetadataObject *> *)metadataObjects fromConnection:(AVCaptureConnection *)connection
{
//    for (AVMetadataFaceObject *face in metadataObjects) {
//        NSLog(@"face = %ld, bounds = %@", face.faceID, NSStringFromCGRect(face.bounds));
//    }
    
    [self.previewView onDetectFaces:metadataObjects];
}

@end
