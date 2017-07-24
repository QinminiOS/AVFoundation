//
//  QMPreviewView.m
//  AVFoundation
//
//  Created by qinmin on 2017/7/24.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "QMPreviewView.h"
#import <AVFoundation/AVFoundation.h>

@interface QMPreviewView()
@property (nonatomic, strong) NSMutableDictionary *faceLayerDict;
@property (nonatomic, strong) CALayer *overlayLayer;
@end

@implementation QMPreviewView

static CATransform3D PerspectiveTransformMake(CGFloat eyePosition)
{
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = -1.0 / eyePosition;
    return transform;
}

+ (Class)layerClass
{
    return [AVCaptureVideoPreviewLayer class];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    if (self = [super initWithFrame:frame]) {
        [self setupView];
    }
    return self;
}

- (void)setupView
{
    _faceLayerDict = [NSMutableDictionary dictionary];
    
    AVCaptureVideoPreviewLayer *previewLayer = (id)self.layer;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
                                 
    
}

@end
