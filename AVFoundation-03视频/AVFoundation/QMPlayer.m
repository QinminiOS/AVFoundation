//
//  QMPlayer.m
//  AVFoundation
//
//  Created by qinmin on 2017/7/3.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "QMPlayer.h"
#import "QMPlayerView.h"

static NSString *QMPlayerItemContext;

@interface QMPlayer ()
@property (nonatomic, strong) AVPlayer *player;
@property (nonatomic, strong) AVPlayerItem *playerItem;
@property (nonatomic, strong) AVAsset *asset;
@end

@implementation QMPlayer

- (instancetype)initWithURL:(NSURL *)assetURL
{
    if (assetURL && (self = [super init])) {
        _asset = [AVAsset assetWithURL:assetURL];
        _previewView = [[QMPlayerView alloc] init];
        
        [self prepare];
    }
    
    return self;
}

- (void)prepare
{
    NSArray *requestedKeys = @[@"playable"];
    
    [_asset loadValuesAsynchronouslyForKeys:requestedKeys
                         completionHandler:^{
                             dispatch_async( dispatch_get_main_queue(), ^{
                                 [self didPrepareToPlayAsset:_asset withKeys:requestedKeys];
                             });
                         }];

    
}

- (void)didPrepareToPlayAsset:(AVAsset *)asset withKeys:(NSArray *)requestedKeys
{
    NSArray *keys = @[@"tracks", @"duration", @"commonMetadata"];
    _playerItem = [AVPlayerItem playerItemWithAsset:_asset automaticallyLoadedAssetKeys:keys];
    
    [_playerItem addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:&QMPlayerItemContext];
    
    _player = [AVPlayer playerWithPlayerItem:_playerItem];
    
    [(QMPlayerView *)_previewView setPlayer:_player];
    
}

#pragma mark - PublicMethod
- (void)play
{
    [_player play];
    [UIApplication sharedApplication].idleTimerDisabled = YES;
}

- (void)pause
{
    [_player pause];
}

- (void)stop
{
    [_player pause];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setVideoFillMode:(NSString *)fillMode
{
    AVPlayerLayer *playerLayer = (AVPlayerLayer *)[_previewView layer];
    playerLayer.videoGravity = fillMode;
}

- (NSTimeInterval)currentPlaybackTime
{
    if (!_player)
        return 0.0f;
    
    return CMTimeGetSeconds([_player currentTime]);
}

- (void)setCurrentPlaybackTime:(NSTimeInterval)aCurrentPlaybackTime
{
    if (!_player)
        return;
    
    [_player seekToTime:CMTimeMakeWithSeconds(aCurrentPlaybackTime, NSEC_PER_SEC)
      completionHandler:^(BOOL finished) {
          if (!finished)
              return;
          
          dispatch_async(dispatch_get_main_queue(), ^{
              [_player play];
          });
      }];
}

- (void)setPlaybackVolume:(float)playbackVolume
{
    _playbackVolume = playbackVolume;
    if (_player != nil && _player.volume != playbackVolume) {
        _player.volume = playbackVolume;
    }
}

- (NSArray<AVMediaSelectionGroup *> *)mediaSelectionGroups
{
    NSMutableArray *mediaSelectionGroups = [NSMutableArray array];
    NSArray *mediaCharacteristics = [self.asset availableMediaCharacteristicsWithMediaSelectionOptions];
    for (NSString *mediaCharacteristic in mediaCharacteristics) {
        [mediaSelectionGroups addObject:[self.asset mediaSelectionGroupForMediaCharacteristic:mediaCharacteristic]];
    }
    return [mediaSelectionGroups copy];
}

- (void)selectMediaOption:(AVMediaSelectionOption *)mediaSelectionOption
    inMediaSelectionGroup:(AVMediaSelectionGroup *)mediaSelectionGroup
{
    [self.playerItem selectMediaOption:mediaSelectionOption inMediaSelectionGroup:mediaSelectionGroup];
}

- (UIImage *)thumbnailImageAtCurrentTime
{
    AVAssetImageGenerator *imageGenerator = [AVAssetImageGenerator assetImageGeneratorWithAsset:_asset];
    NSError *error = nil;
    CMTime time = CMTimeMakeWithSeconds(self.currentPlaybackTime, 1);
    CMTime actualTime;
    CGImageRef cgImage = [imageGenerator copyCGImageAtTime:time actualTime:&actualTime error:&error];
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    return image;
}

#pragma mark - Observe
- (void)observeValueForKeyPath:(NSString *)keyPath
                      ofObject:(id)object
                        change:(NSDictionary<NSKeyValueChangeKey,id> *)change
                       context:(void *)context
{
    if (context == &QMPlayerItemContext) {
        AVPlayerItemStatus status = [[change objectForKey:NSKeyValueChangeNewKey] integerValue];
        
        switch (status) {
            case AVPlayerItemStatusUnknown:
                 NSLog(@"%@ : error:%@", @"AVPlayerItemStatusUnknown", [_playerItem.error localizedDescription]);
                break;
                
            case AVPlayerItemStatusReadyToPlay:
                NSLog(@"%@", @"AVPlayerItemStatusReadyToPlay");
                [_player play];
                break;
                
            case AVPlayerItemStatusFailed:
                NSLog(@"%@ : error:%@", @"AVPlayerItemStatusFailed", [_playerItem.error localizedDescription]);
                break;
        }
    }
}

@end
