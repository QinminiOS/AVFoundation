//
//  QMMediaWriter.h
//  AVFoundation
//
//  Created by mac on 17/8/28.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface QMMediaWriter : NSObject
- (instancetype)initWithOutputURL:(NSURL *)URL size:(CGSize)newSize;
- (instancetype)initWithOutputURL:(NSURL *)URL size:(CGSize)newSize fileType:(NSString *)newFileType;

- (void)processVideoBuffer:(CMSampleBufferRef)videoBuffer;
- (void)processAudioBuffer:(CMSampleBufferRef)audioBuffer;

- (void)finishWriting;
@end
