//
//  HwAACEncoder.m
//  AVFoundation
//
//  Created by qinmin on 2017/7/11.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "HwAACEncoder.h"

@interface HwAACEncoder()
@property (nonatomic, assign) Float64 sampleRate;
@property (nonatomic, assign) uint32_t sampleSize;
@property (nonatomic, assign) uint32_t bitrate;
@property (nonatomic, assign) int channelCount;
@property (nonatomic, assign) uint32_t aMaxOutputFrameSize;
@property (nonatomic, assign) AudioConverterRef outAudioConverter;
@property (nonatomic, strong) NSData *curFramePcmData;
@property (nonatomic, strong) dispatch_queue_t audioQueue;
@end

@implementation HwAACEncoder

- (void)setupWithSampleRate:(float)sampleRate
             bitsPerChannel:(int)bitsPerChannel
               channelCount:(int)channelCount
                    bitrate:(int)bitrate
{
    _audioQueue = dispatch_queue_create("com.qm.audio.queue", NULL);
    
    self.sampleRate = sampleRate;
    self.sampleSize = bitsPerChannel;
    self.channelCount = channelCount;
    self.bitrate = bitrate;
    
    //创建audio encode converter也就是AAC编码器
    //初始化一系列参数
    AudioStreamBasicDescription inputAudioDes = {
        .mFormatID = kAudioFormatLinearPCM,
        .mSampleRate = self.sampleRate,
        .mBitsPerChannel = self.sampleSize,
        .mFramesPerPacket = 1,//每个包1帧
        .mBytesPerFrame = 2,//每帧2字节
        .mBytesPerPacket = 2,//每个包1帧也是2字节
        .mChannelsPerFrame = self.channelCount,//声道数，推流一般使用单声道
        //下面这个flags的设置参照此文：http://www.mamicode.com/info-detail-986202.html
        .mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsNonInterleaved,
        .mReserved = 0
    };
    
    //设置输出格式，声道数
    AudioStreamBasicDescription outputAudioDes = {
        .mChannelsPerFrame = self.channelCount,
        .mFormatID = kAudioFormatMPEG4AAC,
        0
    };
    
    //初始化_aConverter
    UInt32 outDesSize = sizeof(outputAudioDes);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                           0,
                           NULL,
                           &outDesSize,
                           &outputAudioDes);
    
    OSStatus status = AudioConverterNew(&inputAudioDes, &outputAudioDes, &_outAudioConverter);
    if (status != noErr) {
        NSLog(@"%@", @"硬编码AAC创建失败");
    }
    
    //设置码率
    UInt32 aBitrate = self.bitrate;
    UInt32 aBitrateSize = sizeof(aBitrate);
    status = AudioConverterSetProperty(_outAudioConverter,
                                       kAudioConverterEncodeBitRate,
                                       aBitrateSize,
                                       &aBitrate);
    
    //查询最大输出
    UInt32 aMaxOutput = 0;
    UInt32 aMaxOutputSize = sizeof(aMaxOutput);
    AudioConverterGetProperty(_outAudioConverter,
                              kAudioConverterPropertyMaximumOutputPacketSize,
                              &aMaxOutputSize,
                              &aMaxOutput);
    
    self.aMaxOutputFrameSize = aMaxOutput;
    
    if (aMaxOutput == 0) {
        NSLog(@"%@", @"AAC 获取最大frame size失败");
    }
}

- (void)encodePCMData:(NSData *)pcmData
{
    dispatch_async(_audioQueue, ^{
        self.curFramePcmData = pcmData;
    
        //构造输出结构体，编码器需要
        AudioBufferList outAudioBufferList = {0};
        outAudioBufferList.mNumberBuffers = 1;
        outAudioBufferList.mBuffers[0].mNumberChannels = (uint32_t)self.channelCount;
        outAudioBufferList.mBuffers[0].mDataByteSize = self.aMaxOutputFrameSize;
        outAudioBufferList.mBuffers[0].mData = malloc(self.aMaxOutputFrameSize);
    
        UInt32 outputDataPacketSize = 1;
    
        //执行编码，此处需要传一个回调函数aacEncodeInputDataProc，以同步的方式，在回调中填充pcm数据。
        OSStatus status = AudioConverterFillComplexBuffer(_outAudioConverter,
                                                          aacEncodeInputDataProc,
                                                          (__bridge void * _Nullable)(self),
                                                          &outputDataPacketSize,
                                                          &outAudioBufferList,
                                                          NULL);
    
        if (status == noErr) {
            //编码成功，获取数据
            NSData *rawAAC = [NSData dataWithBytes: outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
            NSData *adtsData = [self adtsDataForPacketLength:rawAAC.length];
            
            // AAC完整范围
            NSMutableData *resultData = [NSMutableData dataWithBytes:adtsData.bytes length:adtsData.length];
            [resultData appendBytes:rawAAC.bytes length:rawAAC.length];
            
            // CallBack
            [_delegate didGetEncodedData:resultData error:nil];
            
            //时间戳(ms) = 1000 * 每秒采样数 / 采样率;
            // self.timestamp += 1024 * 1000 / self.sampleRate;
            //获取到aac数据，转成flv audio tag，发送给服务端。
            
        }else{
            //编码错误
            NSLog(@"%@", @"aac 编码错误");
        }
    });
}

//回调函数，系统指定格式
static OSStatus aacEncodeInputDataProc(AudioConverterRef inAudioConverter,
                                       UInt32 *ioNumberDataPackets,
                                       AudioBufferList *ioData,
                                       AudioStreamPacketDescription **outDataPacketDescription,
                                       void *inUserData)
{
    HwAACEncoder *hwAacEncoder = (__bridge HwAACEncoder *)inUserData;
    //将pcm数据交给编码器
    if (hwAacEncoder.curFramePcmData) {
        ioData->mBuffers[0].mData = (void *)hwAacEncoder.curFramePcmData.bytes;
        ioData->mBuffers[0].mDataByteSize = (uint32_t)hwAacEncoder.curFramePcmData.length;
        ioData->mNumberBuffers = 1;
        ioData->mBuffers[0].mNumberChannels = (uint32_t)hwAacEncoder.channelCount;
        return noErr;
    }
    
    return -1;
}

- (void)destroy
{
    AudioConverterDispose(_outAudioConverter);
    _outAudioConverter = nil;
    self.curFramePcmData = nil;
    self.aMaxOutputFrameSize = 0;
}

/**
 *  Add ADTS header at the beginning of each and every AAC packet.
 *  This is needed as MediaCodec encoder generates a packet of raw
 *  AAC data.
 *
 *  Note the packetLen must count in the ADTS header itself.
 *  See: http://wiki.multimedia.cx/index.php?title=ADTS
 *  Also: http://wiki.multimedia.cx/index.php?title=MPEG-4_Audio#Channel_Configurations
 **/
- (NSData *)adtsDataForPacketLength:(NSUInteger)packetLength
{
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;  //44.1KHz
    int chanCfg = 1;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF; // 11111111     = syncword
    packet[1] = (char)0xF9; // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}

@end

