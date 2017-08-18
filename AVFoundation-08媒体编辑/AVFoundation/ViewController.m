//
//  ViewController.m
//  AVFoundation
//
//  Created by mac on 17/6/20.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <AssetsLibrary/AssetsLibrary.h>
#import <AVKit/AVKit.h>

#define kDocumentPath(path) [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:path]
#define kOutputFile kDocumentPath(@"out.mp4")

static void *ExportContext;

@interface ViewController ()
@property (nonatomic, strong) dispatch_queue_t videoQueue;
@property (nonatomic, strong) AVMutableComposition *composition;
@property (nonatomic, strong) AVMutableCompositionTrack *videoTrack;
@property (nonatomic, strong) AVMutableCompositionTrack *audioTrack;
@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _videoQueue = dispatch_queue_create("com.qm.video", NULL);
    dispatch_async(_videoQueue, ^{
        [self buildComposition];
    });
}

- (IBAction)buttonTapped:(UIButton *)sender
{
    if (sender.tag == 1) {
        dispatch_async(_videoQueue, ^{
            [[NSFileManager defaultManager] removeItemAtPath:kOutputFile error:nil];
            [self loadAssets];
        });
    }else if (sender.tag == 2) {
        dispatch_async(_videoQueue, ^{
            [self export];
        });
    }else if (sender.tag == 3) {
        [self play];
    }
}

- (void)loadAssets
{
    AVAsset *video = [AVAsset assetWithURL:[[NSBundle mainBundle] URLForResource:@"1" withExtension:@"mp4"]];
    AVAsset *audio = [AVAsset assetWithURL:[[NSBundle mainBundle] URLForResource:@"许嵩-素颜" withExtension:@"mp3"]];
    
    [video loadValuesAsynchronouslyForKeys:@[@"tracks", @"duration", @"commonMetadata"] completionHandler:^{
        dispatch_async(_videoQueue, ^{
            [self addVideo:video toTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMake(10.0, 1.0)) atTime:kCMTimeZero];
        });
    }];
    
    [audio loadValuesAsynchronouslyForKeys:@[@"tracks", @"duration", @"commonMetadata"] completionHandler:^{
        dispatch_async(_videoQueue, ^{
            [self addAudio:audio toTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMake(5.0, 1.0)) atTime:kCMTimeZero];
            [self addAudio:audio toTimeRange:CMTimeRangeMake(kCMTimeZero, CMTimeMake(5.0, 1.0)) atTime:CMTimeMake(5.0, 1.0)];
        });
    }];
}

- (void)buildComposition
{
    self.composition = [AVMutableComposition composition];
    self.videoTrack = [_composition addMutableTrackWithMediaType:AVMediaTypeVideo preferredTrackID:kCMPersistentTrackID_Invalid];
    self.audioTrack = [_composition addMutableTrackWithMediaType:AVMediaTypeAudio preferredTrackID:kCMPersistentTrackID_Invalid];
}

- (void)addVideo:(AVAsset *)videoAssets toTimeRange:(CMTimeRange)range atTime:(CMTime)time
{
    AVAssetTrack *vidoTrack = [[videoAssets tracksWithMediaType:AVMediaTypeVideo] firstObject];
    [self.videoTrack insertTimeRange:range ofTrack:vidoTrack atTime:time error:nil];
    
    NSLog(@"%@", @"add video finish");
}

- (void)addAudio:(AVAsset *)audioAssets toTimeRange:(CMTimeRange)range atTime:(CMTime)time
{
    AVAssetTrack *audioTrack = [[audioAssets tracksWithMediaType:AVMediaTypeAudio] firstObject];
    [self.audioTrack insertTimeRange:range ofTrack:audioTrack atTime:time error:nil];
    
    NSLog(@"%@", @"add audio finish");
}

- (void)export
{
    AVAssetExportSession *session = [AVAssetExportSession exportSessionWithAsset:[self.composition copy] presetName:AVAssetExportPresetHighestQuality];
    session.outputURL = [NSURL fileURLWithPath:kOutputFile];
    session.outputFileType = AVFileTypeMPEG4;
    NSLog(@"%@", kOutputFile);
    
    [session addObserver:self forKeyPath:@"progress" options:NSKeyValueObservingOptionNew context:&ExportContext];
    
    [session exportAsynchronouslyWithCompletionHandler:^{
        if (!session.error) {
            NSLog(@"%@", @"finish export");
        }else {
            NSLog(@"error : %@", [session.error localizedDescription]);
        }
    }];
}

- (void)play
{
    NSURL * videoURL = [NSURL fileURLWithPath:kOutputFile];
    AVPlayerViewController *avPlayer = [[AVPlayerViewController alloc] init];
    avPlayer.player = [[AVPlayer alloc] initWithURL:videoURL];
    avPlayer.videoGravity = AVLayerVideoGravityResizeAspect;
    [self presentViewController:avPlayer animated:YES completion:nil];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if (context == &ExportContext) {
        NSLog(@"%@", change);
    }
}

@end
