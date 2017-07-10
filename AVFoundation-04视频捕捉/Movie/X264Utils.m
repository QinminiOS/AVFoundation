//
//  H264Utils.m
//  Movie
//
//  Created by qinmin on 2017/6/30.
//  Copyright © 2017年 qinmin. All rights reserved.
//

#import "X264Utils.h"

@interface X264Utils ()
{
    x264_t          *_x264Handle;
    x264_picture_t  *_pPicIn;
    x264_picture_t  *_pPicOut;
    
    int _width;
    int _height;
}
@end

@implementation X264Utils

+ (instancetype)shareUtils
{
    static X264Utils *instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[[self class] alloc] init];
    });
    return instance;
}

- (BOOL)setupEncoderWithWidth:(int)width height:(int)height frameRate:(int)fps bitrate:(int)bitrate
{
    _width = width;
    _height = height;
    
    x264_param_t param;
    //x264_param_default_preset 设置
    x264_param_default_preset(&param,"ultrafast","zerolatency");
    //编码输入的像素格式YUV420P
    param.i_csp = X264_CSP_NV12;
    param.i_width  = width;
    param.i_height = height;
    
    //参数i_rc_method表示码率控制，CQP(恒定质量)，CRF(恒定码率)，ABR(平均码率)
    //恒定码率，会尽量控制在固定码率
    param.rc.i_rc_method = X264_RC_CRF;
    param.rc.i_bitrate = bitrate / 1000; //* 码率(比特率,单位Kbps)
    param.rc.i_vbv_max_bitrate = bitrate / 1000 * 1.2; //瞬时最大码率
    
    //码率控制不通过timebase和timestamp，而是fps
    param.b_vfr_input = 0;
    param.i_fps_num = fps; //* 帧率分子
    param.i_fps_den = 1; //* 帧率分母
    param.i_timebase_den = param.i_fps_num;
    param.i_timebase_num = param.i_fps_den;
    param.i_threads = 1;//并行编码线程数量，0默认为多线程
    
    //是否把SPS和PPS放入每一个关键帧
    //SPS Sequence Parameter Set 序列参数集，PPS Picture Parameter Set 图像参数集
    //为了提高图像的纠错能力
    param.b_repeat_headers = 1;
    //设置Level级别
    param.i_level_idc = 51;
    //设置Profile档次
    //baseline级别，没有B帧
    x264_param_apply_profile(&param,"baseline");
    
    _x264Handle = x264_encoder_open(&param);
    
    if(_x264Handle == NULL) {
        return NO;
    }
    
    _pPicIn = malloc(sizeof(x264_picture_t));
    x264_picture_alloc(_pPicIn, X264_CSP_NV12, _width, _height);
    _pPicIn->img.i_csp = X264_CSP_NV12;
    _pPicIn->img.i_plane = 2;
    
    _pPicOut = malloc(sizeof(x264_picture_t));
    x264_picture_init(_pPicOut);
    
    return YES;
}

- (void)encodeBuffer:(CMSampleBufferRef)sampler
{
    CVImageBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampler);
  
    //表示开始操作数据
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    
    //Y数据
    uint8_t *yFrame = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    
    // UV数据
    uint8_t *uvFrame = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    
    //* 编码需要的辅助变量
    int iNal = 0;
    x264_nal_t *pNals = NULL;
    
    _pPicIn->img.i_csp = X264_CSP_NV12;
    _pPicIn->img.i_plane = 2;
   
    _pPicIn->img.plane[0] = yFrame;
    _pPicIn->img.plane[1] = uvFrame;
    
    int frame_size = x264_encoder_encode(_x264Handle,
                                         &pNals,
                                         &iNal,
                                         _pPicIn,
                                         _pPicOut);
    
    _pPicIn->i_pts += 1;
    _pPicIn->i_dts += 1;
    
    if(frame_size > 0) {
        for (int i = 0; i < iNal; i++) {
            NSLog(@"%d", pNals[i].i_type);
            
            // SPS
            if (pNals[i].i_type == NAL_SPS) {
                NSData *sps = [NSData dataWithBytes:pNals[i].p_payload length:pNals[i].i_payload];
                [_delegate gotSpsPps:sps pps:nil starCode:YES];
                
            // PPS
            }else if(pNals[i].i_type == NAL_PPS) {
                NSData *pps = [NSData dataWithBytes:pNals[i].p_payload length:pNals[i].i_payload];
                [_delegate gotSpsPps:nil pps:pps starCode:YES];
                
            }else {
                NSData *data = [NSData dataWithBytes:pNals[i].p_payload length:pNals[i].i_payload];
                [_delegate gotEncodedData:data isKeyFrame:NO starCode:YES];
            }
        }
    }
    
    // Unlock
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
}

- (void)destroy
{
    //* 清除图像区域
    x264_picture_clean(_pPicIn);
    x264_picture_clean(_pPicOut);
    
    //* 关闭编码器句柄
    x264_encoder_close(_x264Handle);
    _x264Handle = NULL;
}
@end
