//
//  H264Utils.h
//  Movie
//
//  Created by qinmin on 2017/6/30.
//  Copyright © 2017年 qinmin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "x264.h"
#import <AVFoundation/AVFoundation.h>

@protocol X264Delegate <NSObject>
- (void)gotSpsPps:(NSData *)sps pps:(NSData *)pps starCode:(BOOL)flag;
- (void)gotEncodedData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame starCode:(BOOL)flag;
@end

@interface X264Utils : NSObject
@property (weak, nonatomic) id<X264Delegate> delegate;

+ (instancetype)shareUtils;

- (BOOL)setupEncoderWithWidth:(int)width
                       height:(int)height
                    frameRate:(int)fps
                      bitrate:(int)bitrate;

- (void)encodeBuffer:(CMSampleBufferRef)sampler;

- (void)destroy;

@end
