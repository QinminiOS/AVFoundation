//
//  QMPreviewView.m
//  AVFoundation
//
//  Created by qinmin on 2017/7/24.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "QMPreviewView.h"
#import <AVFoundation/AVFoundation.h>

// 角度转弧度
#define DegreeToRadius(degree) (((degree)/(180.0f)) * (M_PI))

@interface QMPreviewView()
@property (nonatomic, strong) NSMutableDictionary *faceLayerDict;
@property (nonatomic, strong) CALayer *overlayLayer;
@end

@implementation QMPreviewView

// 透视投影
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

- (instancetype)initWithCoder:(NSCoder *)aDecoder
{
    if (self = [super initWithCoder:aDecoder]) {
        [self setupView];
    }
    return self;
}

- (void)setupView
{
    _faceLayerDict = [NSMutableDictionary dictionary];
    
    AVCaptureVideoPreviewLayer *previewLayer = (id)self.layer;
    previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    
    self.overlayLayer = [CALayer layer];
    self.overlayLayer.frame = self.bounds;
    self.overlayLayer.sublayerTransform = PerspectiveTransformMake(1000);
    [previewLayer addSublayer:self.overlayLayer];
}

- (NSArray *)transformFacesToLayerFromFaces:(NSArray *)faces
{
    NSMutableArray *transformFaces = [NSMutableArray array];
    for (AVMetadataFaceObject *face in faces) {
        AVMetadataObject *transFace = [(AVCaptureVideoPreviewLayer *)self.layer transformedMetadataObjectForMetadataObject:face]
        [transformFaces addObject:transFace];
        
    }
    return transformFaces;
}

- (CALayer *)makeLayer
{
    CALayer *layer = [CALayer layer];
    layer.borderWidth = 5.0f;
    layer.borderColor = [UIColor colorWithRed:0.0f green:255.0f blue:0.0f alpha:255.0f].CGColor;
    return layer;
}

- (CATransform3D)transformFromYawAngle:(CGFloat)angle
{
    CATransform3D t = CATransform3DMakeRotation(DegreeToRadius(angle), 0.0f, -1.0f, 0.0f);
    return CATransform3DConcat(t, [self orientationTransform]);
}

- (CATransform3D)orientationTransform
{
    CGFloat angle  = 0.0f;
    switch ([UIDevice currentDevice].orientation) {
        case UIDeviceOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
        case UIDeviceOrientationLandscapeRight:
            angle = -M_PI/2.0;
            break;
        case UIDeviceOrientationLandscapeLeft:
            angle = M_PI/2.0;
            break;
        default:
            angle  = 0.0f;
            break;
    }
    return CATransform3DMakeRotation(angle, 0.0f, 0.0f, 1.0f);
}

#pragma mark - Public
- (void)setSession:(AVCaptureSession *)session
{
    ((AVCaptureVideoPreviewLayer *)self.layer).session = session;
}

- (void)onDetectFaces:(NSArray *)faces
{
    // 坐标变换
    NSArray *transFaces = [self transformFacesToLayerFromFaces:faces];
    NSMutableArray *missFaces = [[self.faceLayerDict allKeys] mutableCopy];
    
    for (AVMetadataFaceObject *face in transFaces) {
        NSNumber *faceID = @(face.faceID);
        // 如果当前人脸还在镜头里，则不用移除
        [missFaces removeObject:faceID];
        
        CALayer *layer = self.faceLayerDict[faceID];
        if (!layer) {  // 生成新的人脸矩形
            layer = [self makeLayer];
            self.faceLayerDict[faceID] = layer;
            [self.overlayLayer addSublayer:layer];
        }
        
        layer.transform = CATransform3DIdentity;
        layer.frame = face.bounds;
        
        // 根据偏转角，对矩形进行旋转
        if (face.hasRollAngle) {
            CATransform3D t = CATransform3DMakeRotation(DegreeToRadius(face.rollAngle), 0, 0, 1.0);
            layer.transform = CATransform3DConcat(layer.transform, t);
        }
        // 根据斜倾角，对矩形进行旋转变换
        if (face.hasYawAngle) {
            CATransform3D t = [self transformFromYawAngle:face.yawAngle];
            layer.transform = CATransform3DConcat(layer.transform, t);
        }
        
    }
    // 去除离开屏幕的人脸和矩形视图变换
    for (NSNumber *faceID in missFaces) {
        CALayer *layer = self.faceLayerDict[faceID];
        [layer removeFromSuperlayer];
        [self.faceLayerDict removeObjectForKey:faceID];
    }
}

@end
