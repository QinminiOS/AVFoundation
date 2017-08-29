//
//  ViewController.m
//  AVFoundation
//
//  Created by mac on 17/6/20.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "ViewController.h"
#import "QMMediaReader.h"
#import "QMMediaWriter.h"

#define kDocumentPath(path) [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:path]


@interface ViewController ()
@property (nonatomic, strong) QMMediaReader *mediaReader;
@property (nonatomic, strong) QMMediaWriter *mediaWriter;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSLog(@"%@", kDocumentPath(@""));
    [[NSFileManager defaultManager] removeItemAtPath:kDocumentPath(@"1.mp4") error:nil];
    
    _mediaWriter = [[QMMediaWriter alloc] initWithOutputURL:[NSURL fileURLWithPath:kDocumentPath(@"1.mp4")] size:CGSizeMake(640, 360)];
    _mediaReader = [[QMMediaReader alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"1" withExtension:@"mp4"]];

    __weak typeof(self) weakSelf = self;
    [_mediaReader setVideoReaderCallback:^(CMSampleBufferRef videoBuffer) {
        [weakSelf.mediaWriter processVideoBuffer:videoBuffer];
    }];

    [_mediaReader setAudioReaderCallback:^(CMSampleBufferRef audioBuffer) {
        [weakSelf.mediaWriter processAudioBuffer:audioBuffer];
    }];

    [_mediaReader setReaderCompleteCallback:^{
        NSLog(@"==finish===");
        [weakSelf.mediaWriter finishWriting];
    }];

    [_mediaReader startProcessing];
}

@end
