//
//  ViewController.m
//  AVFoundation
//
//  Created by mac on 17/6/20.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "ViewController.h"
#import "QMAudioController.h"
#import "QMAudioRecorderController.h"

#define kDocumentPath(path) [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:path]

@interface ViewController ()
@property (nonatomic, strong) QMAudioController *musicPlayer;
@property (nonatomic, strong) QMAudioRecorderController *audioRecorder;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (weak, nonatomic) IBOutlet UISlider *slider;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _slider.transform = CGAffineTransformMakeRotation(-M_PI_2);
    
    NSURL *musicURL = [[NSBundle mainBundle] URLForResource:@"1" withExtension:@"mp3"];
    _musicPlayer = [[QMAudioController alloc] initWithContentsOfURL:musicURL];

    NSURL *recordFileURL = [NSURL fileURLWithPath:kDocumentPath(@"1.aac")];
    _audioRecorder = [[QMAudioRecorderController alloc] initWithContentsOfURL:recordFileURL];
    
    self.displayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateMeter:)];
    self.displayLink.frameInterval = 5;
    [self.displayLink addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
}

#pragma mark - Timer
- (void)updateMeter:(CADisplayLink *)link
{
    if ([_musicPlayer isPlaying]) {
        [_musicPlayer updateMeters];
        _slider.value = [_musicPlayer averageValueForChannel:0];
    }else if ([_audioRecorder isRecording]) {
        [_audioRecorder updateMeters];
        _slider.value = [_audioRecorder averageValueForChannel:0];
    }
}

#pragma mark - Events
- (IBAction)playButtonTapped:(UIButton *)sender
{
    if ([_musicPlayer isPlaying]) {
        [self.displayLink setPaused:YES];
        [_musicPlayer pause];
        [sender setTitle:@"音乐播放" forState:UIControlStateNormal];
    }else {
        [self.displayLink setPaused:NO];
        [_musicPlayer play];
        [sender setTitle:@"音乐暂停" forState:UIControlStateNormal];
    }
}

- (IBAction)recordButtonTapped:(UIButton *)sender
{
    if ([_audioRecorder isRecording]) {
        [self.displayLink setPaused:YES];
        [_audioRecorder stop];
        [sender setTitle:@"录音开始" forState:UIControlStateNormal];
    }else {
        [self.displayLink setPaused:NO];
        [_audioRecorder record];
        [sender setTitle:@"录音结束" forState:UIControlStateNormal];
    }
}

@end
