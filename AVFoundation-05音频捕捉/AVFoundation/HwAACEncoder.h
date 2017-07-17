//
//  HwAACEncoder.h
//  AVFoundation
//
//  Created by qinmin on 2017/7/11.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@protocol HwAACEncoderDelegate <NSObject>
- (void)didGetEncodedData:(NSData *)data error:(NSError *)error;
@end

@interface HwAACEncoder : NSObject
@property (nonatomic, weak) id<HwAACEncoderDelegate> delegate;

- (void)setupWithSampleRate:(float)sampleRate
             bitsPerChannel:(int)bitsPerChannel
               channelCount:(int)channelCount
                    bitrate:(int)bitrate;

- (void)encodePCMData:(NSData *)pcmData;

- (void)destroy;

@end
