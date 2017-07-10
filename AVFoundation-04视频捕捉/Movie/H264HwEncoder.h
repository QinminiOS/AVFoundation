//
//  H264HwEncoder.h
//  Movie
//
//  Created by qinmin on 2017/7/8.
//  Copyright © 2017年 qinmin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol H264HwEncoderDelegate <NSObject>
- (void)gotSpsPps:(NSData *)sps pps:(NSData *)pps starCode:(BOOL)flag;
- (void)gotEncodedData:(NSData *)data isKeyFrame:(BOOL)isKeyFrame starCode:(BOOL)flag;
@end

@interface H264HwEncoder : NSObject
@property (weak, nonatomic) id<H264HwEncoderDelegate> delegate;

- (void)setupEncoder:(int)width height:(int)height;
- (void)encodeBuffer:(CMSampleBufferRef)sampleBuffer;
- (void)destroy;

- (void)startWithYUVFile:(NSString *)yuvFile width:(int)width height:(int)height;
@end
