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
    
    // Check if we have got a key frame first
    bool keyframe = !CFDictionaryContainsKey( (CFArrayGetValueAtIndex(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true), 0)), kCMSampleAttachmentKey_NotSync);
    
    if (keyframe)
    {
        CMFormatDescriptionRef format = CMSampleBufferGetFormatDescription(sampleBuffer);
        // CFDictionaryRef extensionDict = CMFormatDescriptionGetExtensions(format);
        // Get the extensions
        // From the extensions get the dictionary with key "SampleDescriptionExtensionAtoms"
        // From the dict, get the value for the key "avcC"
        
        size_t sparameterSetSize, sparameterSetCount;
        const uint8_t *sparameterSet;
        OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 0, &sparameterSet, &sparameterSetSize, &sparameterSetCount, 0 );
        if (statusCode == noErr)
        {
            // Found sps and now check for pps
            size_t pparameterSetSize, pparameterSetCount;
            const uint8_t *pparameterSet;
            OSStatus statusCode = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(format, 1, &pparameterSet, &pparameterSetSize, &pparameterSetCount, 0 );
            if (statusCode == noErr)
            {
                // Found pps
                NSData *sps = [NSData dataWithBytes:sparameterSet length:sparameterSetSize];
                NSData *pps = [NSData dataWithBytes:pparameterSet length:pparameterSetSize];
                if (encoder->_delegate)
                {
                    [encoder->_delegate gotSpsPps:sps pps:pps starCode:NO];
                }
            }
        }
    }
    
    CMBlockBufferRef dataBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    size_t length, totalLength;
    char *dataPointer;
    OSStatus statusCodeRet = CMBlockBufferGetDataPointer(dataBuffer, 0, &length, &totalLength, &dataPointer);
    if (statusCodeRet == noErr) {
        
        size_t bufferOffset = 0;
        static const int AVCCHeaderLength = 4;
        while (bufferOffset < totalLength - AVCCHeaderLength) {
            
            // Read the NAL unit length
            uint32_t NALUnitLength = 0;
            memcpy(&NALUnitLength, dataPointer + bufferOffset, AVCCHeaderLength);
            
            // Convert the length value from Big-endian to Little-endian
            NALUnitLength = CFSwapInt32BigToHost(NALUnitLength);
            
            NSData* data = [[NSData alloc] initWithBytes:(dataPointer + bufferOffset + AVCCHeaderLength) length:NALUnitLength];
            [encoder->_delegate gotEncodedData:data isKeyFrame:keyframe starCode:NO];
            
            // Move to the next NAL unit in the block buffer
            bufferOffset += AVCCHeaderLength + NALUnitLength;
        }
        
    }
    
}

- (void)setupEncoder:(int)width height:(int)height
{
    _videoQueue = dispatch_queue_create("com.qm.video.encode", NULL);
    
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
        VTSessionSetProperty(EncodingSession, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Main_AutoLevel);
        
        
        // Tell the encoder to start encoding
        VTCompressionSessionPrepareToEncodeFrames(EncodingSession);
    });
}

- (void)encodeBuffer:(CMSampleBufferRef )sampleBuffer
{
    dispatch_sync(_videoQueue, ^{
        
        _frameCount++;
        // Get the CV Image buffer
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        
        // Create properties
        CMTime presentationTimeStamp = CMTimeMake(_frameCount, 1000);
        //CMTime duration = CMTimeMake(1, DURATION);
        VTEncodeInfoFlags flags;
        
        // Pass it to the encoder
        OSStatus statusCode = VTCompressionSessionEncodeFrame(EncodingSession,
                                                              imageBuffer,
                                                              presentationTimeStamp,
                                                              kCMTimeInvalid,
                                                              NULL, NULL, &flags);
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
    });
    
}

- (void)finish
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
