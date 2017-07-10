//
//  H264HwEncoder.m
//  Movie
//
//  Created by qinmin on 2017/7/8.
//  Copyright © 2017年 qinmin. All rights reserved.
//

#import "H264HwEncoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface H264HwEncoder ()
{
    dispatch_queue_t         _videoQueue;
    VTCompressionSessionRef  EncodingSession;
    int64_t                 _frameCount;
}
@end

@implementation H264HwEncoder

static void didCompressH264(void *outputCallbackRefCon,
                            void *sourceFrameRefCon,
                            OSStatus status,
                            VTEncodeInfoFlags infoFlags,
                            CMSampleBufferRef sampleBuffer )
{
    NSLog(@"didCompressH264 called with status %d infoFlags %d", (int)status, (int)infoFlags);
    if (status != 0) return;
    
    if (!CMSampleBufferDataIsReady(sampleBuffer))
    {
        NSLog(@"didCompressH264 data is not ready ");
        return;
    }
    H264HwEncoder* encoder = (__bridge H264HwEncoder*)outputCallbackRefCon;
    
    // 检查是否为关键帧
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    if (keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr)
        {
            // 获取 sps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                // 获取 pps
                NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if (encoder->_delegate)
                {
                    [encoder->_delegate gotSpsPps:sps pps:pps starCode:NO];
                }
            }
        }
    }
    
    // 获取其它视频帧
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        // 一般情况下都是只有1帧，在最开始编码的时候有2帧，取最后一帧
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            // 获取 NAL unit 数据长度
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // Convert the length value from Big-endian to Little-endian
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            
            // 如果保存到文件中，需要将此数据前加上 [0 0 0 1] 4个字节，按顺序写入到h264文件中。
            [encoder->_delegate gotEncodedData:data isKeyFrame:keyframe starCode:NO];
            
            // 转到下一个 NAL unit
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
        
    }
    
}

- (void)setupEncoder:(int)width height:(int)height
{
    _videoQueue = dispatch_queue_create("com.qm.video.encode", NULL);
    
    dispatch_sync(_videoQueue, ^{
        
        // 编码类型：kCMVideoCodecType_H264
        // 编码回调：didCompressH264，这个回调函数为编码结果回调，编码成功后，会将数据传入此回调中。
        OSStatus status = VTCompressionSessionCreate(NULL,
                                                     width,
                                                     height,
                                                     kCMVideoCodecType_H264,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     didCompressH264,
                                                     (__bridge void *)(self),
                                                     &EncodingSession);
        
        NSLog(@"H264: VTCompressionSessionCreate %d", (int)status);
        
        if (status != noErr)
        {
            NSLog(@"H264: Unable to create a H264 session");
            return ;
            
        }
        
        // 设置实时编码
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        
        // ProfileLevel，h264的协议等级，不同的清晰度使用不同的ProfileLevel。
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
        
        // 设置码率
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_AverageBitRate, (__bridge CFTypeRef)@(width * height * 3));
        
        // 关闭重排Frame，因为有了B帧（双向预测帧，根据前后的图像计算出本帧）后，编码顺序可能跟显示顺序不同。此参数可以关闭B帧
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        
        // 关键帧最大间隔，关键帧也就是I帧。此处表示关键帧最大间隔为2s。
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (__bridge CFTypeRef)@(25 * 2));
        
        // Tell the encoder to start encoding
        VTCompressionSessionPrepareToEncodeFrames(EncodingSession);
    });
}

- (void)encodeBuffer:(CMSampleBufferRef )sampleBuffer
{
    dispatch_sync(_videoQueue, ^{
        
        _frameCount++;
        // 获取 CVImageBufferRef
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        
        // 设置 pts
        CMTime presentationTimeStamp = CMTimeMake(_frameCount, 1000);
        
        VTEncodeInfoFlags flags;
        // 编码
        OSStatus statusCode = VTCompressionSessionEncodeFrame(EncodingSession,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              kCMTimeInvalid,
                                                              NULL, NULL, &flags);
        // 错误处理
        if (statusCode != noErr) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            
            // End the session
            VTCompressionSessionInvalidate(EncodingSession);
            CFRelease(EncodingSession);
            EncodingSession = NULL;
            return;
        }
        NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
    });
    
}

- (void)destroy
{
    // Mark the completion
    VTCompressionSessionCompleteFrames(EncodingSession, kCMTimeInvalid);
    
    // End the session
    VTCompressionSessionInvalidate(EncodingSession);
    CFRelease(EncodingSession);
    EncodingSession = NULL;
}

- (void)startWithYUVFile:(NSString *)yuvFile width:(int)width height:(int)height
{
    int frameSize = (width * height * 1.5);
    
    if (frameSize <= 0)
    {
        NSLog(@"H264: Not initialized");
        return;
    }
    dispatch_sync(_videoQueue, ^{
        
        // For testing out the logic, lets read from a file and then send it to encoder to create h264 stream
        
        // Create the compression session
        OSStatus status = VTCompressionSessionCreate(NULL,
                                                     width,
                                                     height,
                                                     kCMVideoCodecType_H264,
                                                     NULL,
                                                     NULL,
                                                     NULL,
                                                     didCompressH264,
                                                     (__bridge void *)(self),
                                                     &EncodingSession);
        
        NSLog(@"H264: VTCompressionSessionCreate %d", (int)status);
        
        if (status != 0)
        {
            NSLog(@"H264: Unable to create a H264 session");
          
            return ;
            
        }
        
        // Set the properties
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_AllowFrameReordering, kCFBooleanFalse);
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_MaxKeyFrameInterval, (void *)240);
        
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_High_AutoLevel);
        
        
        // Tell the encoder to start encoding
        VTCompressionSessionPrepareToEncodeFrames(EncodingSession);
        
        // Start reading from the file and copy it to the buffer
        
        // Open the file using POSIX as this is anyway a test application
        int fd = open([yuvFile UTF8String], O_RDONLY);
        if (fd == -1)
        {
            NSLog(@"H264: Unable to open the file");
            return ;
        }
        
        NSMutableData* theData = [[NSMutableData alloc] initWithLength:frameSize] ;
        NSUInteger actualBytes = frameSize;
        while (actualBytes > 0)
        {
            void* buffer = [theData mutableBytes];
            NSUInteger bufferSize = [theData length];
            
            actualBytes = read(fd, buffer, bufferSize);
            if (actualBytes < frameSize)
                [theData setLength:actualBytes];
            
            _frameCount++;
            
            // Create a CM Block buffer out of this data
            CMBlockBufferRef BlockBuffer = NULL;
            OSStatus status = CMBlockBufferCreateWithMemoryBlock(NULL,
                                                                 buffer,
                                                                 actualBytes,
                                                                 kCFAllocatorNull,
                                                                 NULL,
                                                                 0,
                                                                 actualBytes,
                                                                 kCMBlockBufferAlwaysCopyDataFlag,
                                                                 &BlockBuffer);
            
            // Check for error
            if (status != noErr) {
                NSLog(@"H264: CMBlockBufferCreateWithMemoryBlock failed with %d", (int)status);
                return ;
            }
            
            // Create a CM Sample Buffer
            CMFormatDescriptionRef formatDescription;
            CMFormatDescriptionCreate(kCFAllocatorDefault, // Allocator
                                      kCMMediaType_Video,
                                      'I420',
                                       NULL,
                                       &formatDescription );
            
            CMSampleTimingInfo sampleTimingInfo = {CMTimeMake(1, 300)};
            
            CMSampleBufferRef sampleBuffer = NULL;
            OSStatus statusCode = CMSampleBufferCreate(kCFAllocatorDefault,
                                                       BlockBuffer,
                                                       YES,
                                                       NULL,
                                                       NULL,
                                                       formatDescription,
                                                       1,
                                                       1,
                                                       &sampleTimingInfo,
                                                       0,
                                                       NULL,
                                                       &sampleBuffer);
            
            // Check for error
            if (statusCode != noErr) {
                NSLog(@"H264: CMSampleBufferCreate failed with %d", (int)statusCode);
                CFRelease(BlockBuffer);
                return;
            }
            
            CFRelease(BlockBuffer);
            BlockBuffer = NULL;
            
            // Get the CV Image buffer
            CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
            
            // Create properties
            CMTime presentationTimeStamp = CMTimeMake(_frameCount, 300);
            //CMTime duration = CMTimeMake(1, DURATION);
            VTEncodeInfoFlags flags;
            
            // Pass it to the encoder
            statusCode = VTCompressionSessionEncodeFrame(EncodingSession,
                                                         imageBuffer,
                                                         presentationTimeStamp,
                                                         kCMTimeInvalid,
                                                         NULL,
                                                         NULL,
                                                         &flags);
            // Check for error
            if (statusCode != noErr) {
                NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
              
                // End the session
                VTCompressionSessionInvalidate(EncodingSession);
                CFRelease(EncodingSession);
                EncodingSession = NULL;

                return;
            }
            NSLog(@"H264: VTCompressionSessionEncodeFrame Success");
            
        }
        
        // Mark the completion
        VTCompressionSessionCompleteFrames(EncodingSession, kCMTimeInvalid);
        
        // End the session
        VTCompressionSessionInvalidate(EncodingSession);
        CFRelease(EncodingSession);
        EncodingSession = NULL;
        
        close(fd);
    });
}

@end
