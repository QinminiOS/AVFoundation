//
//  SwAACEncoder.h
//  AVFoundation
//
//  Created by qinmin on 2017/7/12.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol SwAACEncoder <NSObject>
- (void)didGetEncodedData:(NSData *)data error:(NSError *)error;
@end

@interface SwAACEncoder : NSObject
@property (nonatomic, weak) id<SwAACEncoder> delegate;
@property (nonatomic, assign) unsigned long maxOutputBytes;
@property (nonatomic, assign) unsigned long maxInputBytes;

- (void)setupWithSampleRate:(int)sampleRate
                numChannels:(int)numChannels
                 pcmBitSize:(int)pcmBitSize;

- (void)encodeBuffer:(char *)buffer size:(uint)samplesInput;

- (void)destroy;

@end
