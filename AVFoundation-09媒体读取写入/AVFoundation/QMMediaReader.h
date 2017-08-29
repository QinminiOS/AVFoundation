//
//  QMMediaReader.h
//  AVFoundation
//
//  Created by mac on 17/8/28.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import <AVFoundation/AVFoundation.h>

@interface QMMediaReader : NSObject
@property (nonatomic, strong) void(^videoReaderCallback)(CMSampleBufferRef videoBuffer);
@property (nonatomic, strong) void(^audioReaderCallback)(CMSampleBufferRef audioBuffer);
@property (nonatomic, strong) void(^readerCompleteCallback)(void);

- (instancetype)initWithAsset:(AVAsset *)asset;
- (instancetype)initWithURL:(NSURL *)url;

- (void)startProcessing;
- (void)cancelProcessing;
@end
