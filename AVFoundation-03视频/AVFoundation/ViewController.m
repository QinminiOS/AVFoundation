//
//  ViewController.m
//  AVFoundation
//
//  Created by mac on 17/6/20.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "ViewController.h"
#import <AVFoundation/AVFoundation.h>
#import "QMPlayer.h"

#define kDocumentPath(path) [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:path]

@interface ViewController ()
@property (nonatomic, strong) QMPlayer *player;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURL *fileURL = [[NSBundle mainBundle] URLForResource:@"1" withExtension:@"mp4"];
    _player = [[QMPlayer alloc] initWithURL:fileURL];

    _player.previewView.frame = self.view.bounds;
    [self.view addSubview:_player.previewView];
}

@end
