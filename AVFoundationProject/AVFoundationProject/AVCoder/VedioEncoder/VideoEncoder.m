//
//  VideoEncoder.m
//  AVFoundationProject
//
//  Created by 赵泓博 on 2021/4/1.
//

#import "VideoEncoder.h"
#import <VideoToolbox/VideoToolbox.h>
@interface VideoEncoder()
//编码队列
@property (nonatomic, strong) dispatch_queue_t encodeQueue;
//回调队列
@property (nonatomic, strong) dispatch_queue_t callbackQueue;
/**编码会话*/
@property (nonatomic) VTCompressionSessionRef encodeSesion;
@end
@implementation VideoEncoder{
    long frameID;   //帧的递增序标识
    BOOL hasSpsPps;//判断是否已经获取到pps和sps  类似锁，适配只在 I帧中添加功能
}
- (instancetype)initWithConfig:(VedioConfig*)config;
{
    self = [super init];
    if (self) {
        _config = config;
        _encodeQueue = dispatch_queue_create("h264 hard encode queue", DISPATCH_QUEUE_SERIAL);
        _callbackQueue = dispatch_queue_create("h264 hard encode callback queue", DISPATCH_QUEUE_SERIAL);
        
        /**编码设置*/
        
        //创建编码会话 编码session
        OSStatus status = VTCompressionSessionCreate(kCFAllocatorDefault, (int32_t)_config.width, (int32_t)_config.height, kCMVideoCodecType_H264, NULL, NULL, NULL, VideoEncodeCallback, (__bridge void * _Nullable)(self), &_encodeSesion);
        if (status != noErr) {
            NSLog(@"VTCompressionSession create failed. status=%d", (int)status);
            return self;
        }
        /*设置编码器属性*/
        //1. 设置是否实时执行
        status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
        NSLog(@"VTSessionSetProperty: set RealTime return: %d", (int)status);
        
        //2.指定编码比特流的配置文件和级别。直播一般使用baseline，可减少由于b帧带来的延时
        status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_ProfileLevel, kVTProfileLevel_H264_Baseline_AutoLevel);
        NSLog(@"VTSessionSetProperty: set profile return: %d", (int)status);
        
        //3.设置码率均值(比特率可以高于此。默认比特率为零，表示视频编码器。应该确定压缩数据的大小。注意，比特率设置只在定时时有效）
        CFNumberRef bit = (__bridge CFNumberRef)@(_config.bitrate);
        status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_AverageBitRate, bit);
        NSLog(@"VTSessionSetProperty: set AverageBitRate return: %d", (int)status);
        
        
        //4. 码率限制(只在定时时起作用)*待确认
        CFArrayRef limits = (__bridge CFArrayRef)@[@(_config.bitrate / 4), @(_config.bitrate * 4)];
        status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_DataRateLimits,limits);
        NSLog(@"VTSessionSetProperty: set DataRateLimits return: %d", (int)status);
        
        //5. 设置关键帧间隔(GOPSize)GOP太大图像会模糊
        CFNumberRef maxKeyFrameInterval = (__bridge CFNumberRef)@(_config.fps * 2);
        status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_MaxKeyFrameInterval, maxKeyFrameInterval);
        NSLog(@"VTSessionSetProperty: set MaxKeyFrameInterval return: %d", (int)status);
        
        //6.设置fps(预期)
        CFNumberRef expectedFrameRate = (__bridge CFNumberRef)@(_config.fps);
        status = VTSessionSetProperty(_encodeSesion, kVTCompressionPropertyKey_ExpectedFrameRate, expectedFrameRate);
        NSLog(@"VTSessionSetProperty: set ExpectedFrameRate return: %d", (int)status);
        
        //准备编码
        status = VTCompressionSessionPrepareToEncodeFrames(_encodeSesion);
        NSLog(@"VTSessionSetProperty: set PrepareToEncodeFrames return: %d", (int)status);
        
        
    }
    return self;
}
// startCode 长度 4
const Byte startCode[] = "\x00\x00\x00\x01"; // h264起始码

// 编码格式  //编码回调
void VideoEncodeCallback(void * CM_NULLABLE outputCallbackRefCon, void * CM_NULLABLE sourceFrameRefCon,OSStatus status, VTEncodeInfoFlags infoFlags,  CMSampleBufferRef sampleBuffer ) {
    
    if (status != noErr) {
        NSLog(@"VideoEncodeCallback: encode error, status = %d", (int)status);
        return;
    }
    if (!CMSampleBufferDataIsReady(sampleBuffer)) {
        NSLog(@"VideoEncodeCallback: data is not ready");
        return;
    }
    VideoEncoder *encoder = (__bridge VideoEncoder *)(outputCallbackRefCon);
    
    //判断是否为关键帧
    BOOL keyFrame = NO;
    CFArrayRef attachArray = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, true);
    keyFrame = !CFDictionaryContainsKey(CFArrayGetValueAtIndex(attachArray, 0), kCMSampleAttachmentKey_NotSync);//(注意取反符号)
    
    //获取sps & pps 数据 ，只需获取一次，保存在h264文件开头即可
    if (keyFrame && !encoder->hasSpsPps) { // 关键帧，并且无sps  这个 是不是 只设置了一次，貌似是不是每个关键帧都要加sps pps
        size_t spsSize, spsCount;
        size_t ppsSize, ppsCount;
        const uint8_t *spsData, *ppsData;
        //获取图像源格式
        CMFormatDescriptionRef formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer);
        // 获取sps/pps
        OSStatus status1 = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, 0, &spsData, &spsSize, &spsCount, 0);
        OSStatus status2 = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(formatDesc, 1, &ppsData, &ppsSize, &ppsCount, 0);
        
        //判断sps/pps获取成功
        if (status1 == noErr & status2 == noErr) {
            
            NSLog(@"VideoEncodeCallback： get sps, pps success");
            encoder->hasSpsPps = true;
            //sps data  初始值 +4  +sps
            NSMutableData *sps = [NSMutableData dataWithCapacity:4 + spsSize];
            [sps appendBytes:startCode length:4];
            [sps appendBytes:spsData length:spsSize];
            //pps data 初始值 +4  +pps
            NSMutableData *pps = [NSMutableData dataWithCapacity:4 + ppsSize];
            [pps appendBytes:startCode length:4];
            [pps appendBytes:ppsData length:ppsSize];
            
            dispatch_async(encoder.callbackQueue, ^{
                //回调方法传递sps/pps
                [encoder.delegate videoEncodeCallbacksps:sps pps:pps];
            });
            
        } else {
            NSLog(@"VideoEncodeCallback： get sps/pps failed spsStatus=%d, ppsStatus=%d", (int)status1, (int)status2);
        }
    }
    
    //获取NALU数据
    size_t lengthAtOffset, totalLength;
    char *dataPoint;
    
    //将数据复制到dataPoint
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    OSStatus error = CMBlockBufferGetDataPointer(blockBuffer, 0, &lengthAtOffset, &totalLength, &dataPoint);
    // 根据blockBuffer 获取 整个长度。
    
    if (error != kCMBlockBufferNoErr) {
        NSLog(@"VideoEncodeCallback: get datapoint failed, status = %d", (int)error);
        return;
    }
    
    //循环获取nalu数据
    size_t offet = 0;
    //返回的nalu数据前四个字节不是0001的startcode(不是系统端的0001)，而是大端模式的帧长度length
    const int lengthInfoSize = 4;
    
    while (offet < totalLength - lengthInfoSize) {
        uint32_t naluLength = 0;
        //获取nalu 数据长度
        memcpy(&naluLength, dataPoint + offet, lengthInfoSize);
        //大端转系统端
        naluLength = CFSwapInt32BigToHost(naluLength);
        //获取到编码好的视频数据
        NSMutableData *data = [NSMutableData dataWithCapacity:4 + naluLength];
        [data appendBytes:startCode length:4];
        [data appendBytes:dataPoint + offet + lengthInfoSize length:naluLength];
        
        //将NALU数据回调到代理中
        dispatch_async(encoder.callbackQueue, ^{
            [encoder.delegate videoEncodeCallback:data];
        });
        
        //移动下标，继续读取下一个数据
        offet += lengthInfoSize + naluLength;
    }
    // 编码数据需要更多理解
  
}

//2.获取到sampleBuffer 数据 进行H264硬编码
- (void)VideoEncodeCallback:(CMSampleBufferRef)sampleBuffer {
    CFRetain(sampleBuffer);
    dispatch_async(_encodeQueue, ^{
        //帧数据
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        //该帧的时间戳
        self->frameID++;
        CMTime timeStamp = CMTimeMake(self->frameID, 1000);
        //持续时间
        CMTime duration = kCMTimeInvalid;
        //编码
        VTEncodeInfoFlags flags;
        // 开启编码
        OSStatus status = VTCompressionSessionEncodeFrame(self.encodeSesion, imageBuffer, timeStamp, duration, NULL, NULL, &flags);
        // 编码后会在sesseion 的回调代理中，获取数据
        if (status != noErr) {
            NSLog(@"VTCompression: encode failed: status=%d",(int)status);
        }
        CFRelease(sampleBuffer);
    });
    
}

@end
