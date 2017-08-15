//
//  ViewController.m
//  AVFoundation
//
//  Created by mac on 17/6/20.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import "OpenGLESView.h"

#define kDocumentPath(path) [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:path]

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureSession *captureSession;

@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureStillImageOutput *stillImageOutput;
@property (nonatomic, strong) AVCaptureDeviceInput *deviceInput;

@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;
@property (nonatomic, strong) OpenGLESView *openGLView;

@property (nonatomic, strong) dispatch_queue_t videoQueue;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    //[self setupOpenGLView];
    [self setupSession];
}

- (void)setupOpenGLView
{
    _openGLView = [[OpenGLESView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:_openGLView];
}

- (void)setupSession
{
    self.captureSession = [[AVCaptureSession alloc] init];
    
    // SessionPreset
    self.captureSession = [[AVCaptureSession alloc] init];
    [self.captureSession setSessionPreset:AVCaptureSessionPreset640x480];
    
    // PreviewLayer
    _previewLayer = [[AVCaptureVideoPreviewLayer alloc] initWithSession:self.captureSession];
    _previewLayer.frame = [UIScreen mainScreen].bounds;
    [self.view.layer addSublayer:_previewLayer];
    
    // Device input
    AVCaptureDevice *device = [self deviceWithPostion:AVCaptureDevicePositionBack];
    NSError *error;
    _deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!_deviceInput) {
        return;
    }
    [self.captureSession addInput:_deviceInput];
    
    // VideoDataOutput
    self.videoQueue = dispatch_queue_create("com.qm.video.queue", NULL);
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.videoQueue];
    self.videoDataOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA] forKey:(id)kCVPixelBufferPixelFormatTypeKey];
    [self.captureSession addOutput:self.videoDataOutput];
    
    // ImageOutput
    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
    self.stillImageOutput.outputSettings = @{AVVideoCodecKey:AVVideoCodecJPEG};
    [self.captureSession addOutput:self.stillImageOutput];
    
    // Start
    [self.captureSession startRunning];
}

#pragma mark - Event
- (IBAction)buttonTapped:(UIButton *)sender
{
    switch (sender.tag) {
        case 1:
            [self setFlashModel:[self currentFlashMode] == AVCaptureTorchModeOn ? AVCaptureFlashModeOff : AVCaptureFlashModeOn];
            break;
        case 2:
            [self setTorchModel:[self currentTorchMode] == AVCaptureTorchModeOn ? AVCaptureTorchModeOff : AVCaptureTorchModeOn];
            break;
        case 3: {
            AVCaptureConnection *conn = [self.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
                [self.stillImageOutput captureStillImageAsynchronouslyFromConnection:conn completionHandler:^(CMSampleBufferRef  _Nullable imageDataSampleBuffer, NSError * _Nullable error) {
                    NSData *data = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageDataSampleBuffer];
                    [self writeImageToPhotosAlbum:[UIImage imageWithData:data]];
                }];
            }
            break;
        case 4:
            [self switchCamera];
            break;
        case 5:
            [self autoFocus];
            break;
        case 6:
            [self exposeAtPoint:CGPointMake(0.5, 0.5)];
            break;
        default:
            break;
    }
}

- (IBAction)sliderValueChange:(UISlider *)sender
{
    [self rampZoomToFactor:sender.value];
}

#pragma mark - 切换摄像头
- (AVCaptureDevice *)deviceWithPostion:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices) {
        if (device.position == position) {
            return device;
        }
    }
    return nil;
}

- (BOOL)canSwitchCamera
{
    return [[AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo] count] > 1;
}

- (void)switchCamera
{
    if (![self canSwitchCamera]) {
        return;
    }
    
    AVCaptureDevicePosition devicePosition;
    if (self.deviceInput.device.position == AVCaptureDevicePositionBack) {
        devicePosition = AVCaptureDevicePositionFront;
    }else {
        devicePosition = AVCaptureDevicePositionBack;
    }
    
    [self.captureSession beginConfiguration];
    [self.captureSession removeInput:_deviceInput];
    NSError *error;
    AVCaptureDevice *device = [self deviceWithPostion:devicePosition];
    self.deviceInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!self.deviceInput) {
        [self.captureSession commitConfiguration];
        return;
    }
    [self.captureSession addInput:self.deviceInput];
    [self.captureSession commitConfiguration];
}

#pragma mark - 自动对焦
- (void)autoFocus
{
    if (!self.deviceInput.device) {
        return;
    }
    
    if ([self.deviceInput.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([self.deviceInput.device lockForConfiguration:&error]) {
            self.deviceInput.device.focusMode = AVCaptureFocusModeAutoFocus;
            [self.deviceInput.device unlockForConfiguration];
        }
    }
}

#pragma mark - 调整焦距
- (BOOL)canTapFoucus
{
    return [self.deviceInput.device isFocusPointOfInterestSupported];
}

- (void)focusAtPoint:(CGPoint)point
{
    if (![self canTapFoucus]) {
        return;
    }
    
    if ([self.deviceInput.device isFocusModeSupported:AVCaptureFocusModeAutoFocus]) {
        NSError *error;
        if ([self.deviceInput.device lockForConfiguration:&error]) {
            self.deviceInput.device.focusPointOfInterest = point;
            self.deviceInput.device.focusMode = AVCaptureFocusModeAutoFocus;
            [self.deviceInput.device unlockForConfiguration];
        }
    }
}

#pragma mark - 曝光
- (BOOL)canTapExpose
{
    return [self.deviceInput.device isExposurePointOfInterestSupported];
}

- (void)exposeAtPoint:(CGPoint)point
{
    if (![self canTapExpose]) {
        return;
    }
    
    if ([self.deviceInput.device isExposureModeSupported:AVCaptureExposureModeAutoExpose]) {
        NSError *error;
        if ([self.deviceInput.device lockForConfiguration:&error]) {
            self.deviceInput.device.exposurePointOfInterest = point;
            self.deviceInput.device.exposureMode = AVCaptureExposureModeAutoExpose;
            [self.deviceInput.device unlockForConfiguration];
        }
    }
}

#pragma mark - 闪光灯
- (BOOL)haveFlash
{
    return [self.deviceInput.device hasFlash];
}

- (AVCaptureFlashMode)currentFlashMode
{
    return self.deviceInput.device.flashMode;
}

- (void)setFlashModel:(AVCaptureFlashMode)flashModel
{
    if (self.deviceInput.device.flashMode == flashModel) {
        return;
    }
    
    if ([self.deviceInput.device isFlashModeSupported:flashModel]) {
        NSError *error;
        if ([self.deviceInput.device lockForConfiguration:&error]) {
            self.deviceInput.device.flashMode = flashModel;
            [self.deviceInput.device unlockForConfiguration];
        }
    }
}

#pragma mark - 手电筒
- (BOOL)haveTorch
{
    return [self.deviceInput.device hasTorch];
}

- (AVCaptureTorchMode)currentTorchMode
{
    return self.deviceInput.device.torchMode;
}

- (void)setTorchModel:(AVCaptureTorchMode)torchModel
{
    if (self.deviceInput.device.torchMode == torchModel) {
        return;
    }
    
    if ([self.deviceInput.device isTorchModeSupported:torchModel]) {
        NSError *error;
        if ([self.deviceInput.device lockForConfiguration:&error]) {
            self.deviceInput.device.torchMode = torchModel;
            [self.deviceInput.device unlockForConfiguration];
        }
    }
}

- (void)setTorchLevel:(float)torchLevel
{
    if ([self.deviceInput.device isTorchActive]) {
        NSError *error;
        if ([self.deviceInput.device lockForConfiguration:&error]) {
            [self.deviceInput.device setTorchModeOnWithLevel:torchLevel error:&error];
            [self.deviceInput.device unlockForConfiguration];
        }
    }
}

#pragma mark - 保存图片
- (void)writeImageToPhotosAlbum:(UIImage *)image
{
    ALAssetsLibrary *assetsLib = [[ALAssetsLibrary alloc] init];
    [assetsLib writeImageToSavedPhotosAlbum:image.CGImage
                                orientation:(NSInteger)image.imageOrientation
                            completionBlock:^(NSURL *assetURL, NSError *error) {
        NSLog(@"%@", assetURL);
    }];
}

#pragma mark - 视频缩放
- (BOOL)videoCanZoom
{
    return self.deviceInput.device.activeFormat.videoMaxZoomFactor > 1.0f;
}

- (float)videoMaxZoomFactor
{
    return MIN(self.deviceInput.device.activeFormat.videoMaxZoomFactor, 4.0f);
}

- (void)setVideoZoomFactor:(float)factor
{
    if (self.deviceInput.device.isRampingVideoZoom) {
        return;
    }
    
    NSError *error;
    if ([self.deviceInput.device lockForConfiguration:&error]) {
        self.deviceInput.device.videoZoomFactor = pow([self videoMaxZoomFactor], factor);
        [self.deviceInput.device unlockForConfiguration];
    }
}

- (void)rampZoomToFactor:(float)factor
{
    if (self.deviceInput.device.isRampingVideoZoom) {
        return;
    }

    NSError *error;
    if ([self.deviceInput.device lockForConfiguration:&error]) {
        [self.deviceInput.device rampToVideoZoomFactor:pow([self videoMaxZoomFactor], factor) withRate:1.0f];
        [self.deviceInput.device unlockForConfiguration];
    }
}

#pragma mark - AVCaptureAudioDataOutputSampleBufferDelegate
- (void)captureOutput:(AVCaptureOutput *)output
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        [_openGLView renderImage:CMSampleBufferGetImageBuffer(sampleBuffer)];
    });
}

@end
