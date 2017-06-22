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

#define kDocumentPath(path) [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:path]

@interface ViewController ()
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (weak, nonatomic) IBOutlet UISlider *slider;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateMeter:)];
    self.displayLink.frameInterval = 5;
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)setupAsset
{
    NSURL *mp3URL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp3"]];
    AVURLAsset *asset = [AVURLAsset assetWithURL:mp3URL];
}

- (void)setupAssetWithSettings
{
    NSDictionary *dict = @{
                           AVURLAssetPreferPreciseDurationAndTimingKey : @(YES)
                           };
    NSURL *mp3URL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp3"]];
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:mp3URL options:dict];
    
}

- (void)setupFromPhotoLib
{
    ALAssetsLibrary *assetLib = [[ALAssetsLibrary alloc] init];
    [assetLib enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos
                            usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
                                [group setAssetsFilter:[ALAssetsFilter allVideos]];
                                
                                [group enumerateAssetsAtIndexes:[NSIndexSet indexSetWithIndex:0]
                                                        options:0
                                                     usingBlock:^(ALAsset *result, NSUInteger index, BOOL *stop) {
                                                         if (result) {
                                                             NSURL *url = [[result defaultRepresentation] url];
                                                             AVAsset *asset = [AVAsset assetWithURL:url];
                                                             
                                                         }
                                }];
                                
                            } failureBlock:^(NSError *error) {
                              NSLog(@"%@", [error localizedDescription]);
                          }];
    
}

- (void)loadMediaAsyn
{
    NSURL *mp3URL = [NSURL fileURLWithPath:[[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp3"]];
    AVURLAsset *asset = [AVURLAsset assetWithURL:mp3URL];

    [asset loadValuesAsynchronouslyForKeys:@[@"tracks"] completionHandler:^{
        
        NSError *error;
        AVKeyValueStatus status = [asset statusOfValueForKey:@"tracks" error:&error];
        
        switch (status) {
            case AVKeyValueStatusLoaded:
                
                break;
            case AVKeyValueStatusLoading:
                
                break;
            case AVKeyValueStatusUnknown:
                
                break;
            case AVKeyValueStatusFailed:
                
                break;
            case AVKeyValueStatusCancelled:
                
                break;
            default:
                break;
        }
    }];
}

#pragma mark - Timer
- (void)updateMeter:(CADisplayLink *)link
{
   
}

#pragma mark - Events
- (IBAction)playButtonTapped:(UIButton *)sender
{
//    [self.displayLink setPaused:YES];
//    [sender setTitle:@"音乐播放" forState:UIControlStateNormal];
//    [self.displayLink setPaused:NO];
//    [sender setTitle:@"音乐暂停" forState:UIControlStateNormal];

}

- (IBAction)recordButtonTapped:(UIButton *)sender
{
//    [self.displayLink setPaused:YES];
//    [sender setTitle:@"录音开始" forState:UIControlStateNormal];
//
//    [self.displayLink setPaused:NO];
//    [sender setTitle:@"录音结束" forState:UIControlStateNormal];

}

@end
