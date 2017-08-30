//
//  ViewController.m
//  AVFoundation
//
//  Created by mac on 17/6/20.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "ViewController.h"
#import "QMImageHelper.h"

#define kDocumentPath(path) [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:path]

@interface ViewController () <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (nonatomic, strong) AVCaptureSession *captureSession;
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoOutput;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIImage *image = [UIImage imageNamed:@"1.jpg"];
    CVPixelBufferRef pixelBuffer = [QMImageHelper convertToCVPixelBufferRefFromImage:image.CGImage withSize:CGSizeMake(CGImageGetWidth(image.CGImage), CGImageGetHeight(image.CGImage))];
    
    CGImageRef imgRef = [QMImageHelper imageFromPixelBuffer:pixelBuffer];
    self.imageView.image = [UIImage imageWithCGImage:imgRef];
    
    
}

@end
