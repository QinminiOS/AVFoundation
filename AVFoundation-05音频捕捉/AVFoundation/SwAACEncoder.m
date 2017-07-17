//
//  SwAACEncoder.m
//  AVFoundation
//
//  Created by qinmin on 2017/7/12.
//  Copyright © 2017年 Qinmin. All rights reserved.
//

#import "SwAACEncoder.h"
#import "faac.h"

@interface SwAACEncoder ()
@property (nonatomic, assign) faacEncHandle aacHandle;
@property (nonatomic, assign) unsigned long inputSamples;
@property (nonatomic, assign) unsigned char *outputBuffer;
@property (nonatomic, assign) int pcmBitSize;
@end

@implementation SwAACEncoder

- (void)setupWithSampleRate:(int)sampleRate
                numChannels:(int)numChannels
                 pcmBitSize:(int)pcmBitSize
{
    _maxOutputBytes = 0;
    _aacHandle = faacEncOpen(sampleRate, numChannels, &_inputSamples, &_maxOutputBytes);
    
    if (_aacHandle) {
        faacEncConfigurationPtr config = faacEncGetCurrentConfiguration(_aacHandle);
        config->bitRate = 100000;
        _pcmBitSize = pcmBitSize;
        switch (_pcmBitSize) {
            case 16:
                config->inputFormat = FAAC_INPUT_16BIT;
                break;
            case 24:
                config->inputFormat = FAAC_INPUT_24BIT;
                break;
            case 32:
                config->inputFormat = FAAC_INPUT_32BIT;
                break;
            default:
                config->inputFormat = FAAC_INPUT_FLOAT;
                break;
        }
        config->aacObjectType = MAIN;
        config->mpegVersion = MPEG2;
        config->outputFormat = 0;
        config->useTns = 1;
        config->allowMidside = 0;
        faacEncSetConfiguration(_aacHandle, config);
        
        _maxInputBytes = _inputSamples * _pcmBitSize / 8;
        _outputBuffer = malloc(sizeof(char) * _maxOutputBytes);
    }
}

- (void)encodeBuffer:(char *)buffer size:(uint)samplesInput
{
    memset(_outputBuffer, 0x00, _maxOutputBytes);

    // 输入样本数，用实际读入字节数计算，一般只有读到文件尾时才不是nPCMBufferSize/(nPCMBitSize/8);
    unsigned int bufferSize = samplesInput / (_pcmBitSize / 8);
    
    int len = faacEncEncode(_aacHandle,
                            (int *)buffer,
                            bufferSize,
                            _outputBuffer,
                            (unsigned int)_maxOutputBytes);
    if (len > 0) {
        NSData *rawAAC = [NSData dataWithBytes:_outputBuffer length:len];
        NSData *adtsData = [self adtsDataForPacketLength:rawAAC.length];
        
        // AAC完整范围
        NSMutableData *resultData = [NSMutableData dataWithBytes:adtsData.bytes length:adtsData.length];
        [resultData appendBytes:rawAAC.bytes length:rawAAC.length];
        [_delegate didGetEncodedData:resultData error:nil];
    }
}

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

- (void)destroy
{
    faacEncClose(_aacHandle);
    free(_outputBuffer);
    _aacHandle = NULL;
    _outputBuffer = NULL;
}

@end
