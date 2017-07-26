//
//  QMPreviewView.h
//  AVFoundation
//
//  Created by qinmin on 2017/7/24.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface QMPreviewView : UIView

- (void)setSession:(AVCaptureSession *)session;

- (void)onDetectFaces:(NSArray *)faces;

@end
