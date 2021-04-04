//
//  VideoEncoder.m
//  AVFoundationProject
//
//  Created by 赵泓博 on 2021/3/30.
//

#import "VideoDecoder.h"
#import <VideoToolbox/VideoToolbox.h>
@interface VideoDecoder ()
@property (nonatomic, strong) dispatch_queue_t decodeQueue; // 编码队列
@property (nonatomic, strong) dispatch_queue_t callbackQueue; // 回调队列

/**VideoToolbox解码会话   */
@property (nonatomic) VTDecompressionSessionRef decodeSesion; //解码器对象数据结构
@end
@implementation VideoDecoder{
    // h254 sps  pps  相关数据
    uint8_t *_sps;
    NSUInteger _spsSize;
    uint8_t *_pps;
    NSUInteger _ppsSize;
    CMVideoFormatDescriptionRef _decodeDesc; //图形解码相关格式及描述 视频输出格式
}

/**解码回调函数*/
void videoDecompressionOutputCallback(void * CM_NULLABLE decompressionOutputRefCon,
                                      void * CM_NULLABLE sourceFrameRefCon,
                                      OSStatus status,
                                      VTDecodeInfoFlags infoFlags,
                                      CM_NULLABLE CVImageBufferRef imageBuffer,
                                      CMTime presentationTimeStamp,
                                      CMTime presentationDuration ) {
    if (status != noErr) {
        NSLog(@"Video hard decode callback error status=%d", (int)status);
        return;
    }
    //解码后的数据sourceFrameRefCon -> CVPixelBufferRef
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(imageBuffer);
    
    //获取self
    VideoDecoder *decoder = (__bridge VideoDecoder *)(decompressionOutputRefCon);
    
    //调用回调队列
    dispatch_async(decoder.callbackQueue, ^{
        
        //将解码后的数据给decoder代理.viewController
        [decoder.delegate videoDecodeCallback:imageBuffer];
        //释放数据
        CVPixelBufferRelease(imageBuffer);
    });
    
}

/**初始化解码器  配置**/
- (instancetype)initWithConfig:(VedioConfig*)config;
{
    self = [super init];
    if (self) {
        //初始化VideoConfig 信息
        _config = config;
        //创建解码队列与回调队列
        _decodeQueue = dispatch_queue_create("h264 hard decode queue", DISPATCH_QUEUE_SERIAL);
        _callbackQueue = dispatch_queue_create("h264 hard decode callback queue", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}


// public
- (void)decodeNaluData:(NSData *)frame {
    //将解码放在异步队列.
    dispatch_async(_decodeQueue, ^{
        //获取frame 二进制数据
        uint8_t *nalu = (uint8_t *)frame.bytes;
        //调用解码Nalu数据方法,参数1:数据 参数2:数据长度
        [self decodeNaluData:nalu size:(uint32_t)frame.length];
    });
}

// private
- (void)decodeNaluData:(uint8_t *)frame size:(uint32_t)size {
    //H264数据类型:frame的前4个字节是NALU数据的开始码，也就是00 00 00 01，
    // 第5个字节是表示数据类型，转为10进制后，7是sps, 8是pps, 5是IDR（I帧）信息
    int type = (frame[4] & 0x1F); // 获取第五个字节
    
    // 将NALU的开始码转为4字节大端NALU的长度信息
    uint32_t naluSize = size - 4;
    uint8_t *pNaluSize = (uint8_t *)(&naluSize);
    
    frame[0] = *(pNaluSize + 3);
    frame[1] = *(pNaluSize + 2);
    frame[2] = *(pNaluSize + 1);
    frame[3] = *(pNaluSize);
    
    CVPixelBufferRef pixelBuffer = NULL;
    
    switch (type) {
        case 0x05: //关键帧 i帧
            if ([self initDecoder]) {
                pixelBuffer= [self decode:frame withSize:size];
            }
            break;
        case 0x06:
            //NSLog(@"SEI");//增强信息
            break;
        case 0x07: //sps
            _spsSize = naluSize;
            _sps = malloc(_spsSize);
            memcpy(_sps, &frame[4], _spsSize);
            break;
        case 0x08: //pps
            _ppsSize = naluSize;
            _pps = malloc(_ppsSize);
            memcpy(_pps, &frame[4], _ppsSize);
            break;
        default: //其他帧（1-5）
            if ([self initDecoder]) {
                pixelBuffer = [self decode:frame withSize:size];
            }
            break;
    }
    
}

/*初始化解码器**/
- (BOOL)initDecoder {
    
    if (_decodeSesion) return true;
    const uint8_t * const parameterSetPointers[2] = {_sps, _pps};
    const size_t parameterSetSizes[2] = {_spsSize, _ppsSize};
    int naluHeaderLen = 4;
    
    /**
     根据sps pps设置解码参数
     param kCFAllocatorDefault 分配器
     param 2 参数个数
     param parameterSetPointers 参数集指针
     param parameterSetSizes 参数集大小
     param naluHeaderLen nalu nalu start code 的长度 4
     param _decodeDesc 解码器描述
     return 状态
     */
    // 设置 解码
    OSStatus status = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetSizes, naluHeaderLen, &_decodeDesc);
    if (status != noErr) {
        NSLog(@"Video hard DecodeSession create H264ParameterSets(sps, pps) failed status= %d", (int)status);
        return false;
    }
    
    /*
     解码参数:
    * kCVPixelBufferPixelFormatTypeKey:摄像头的输出数据格式
     kCVPixelBufferPixelFormatTypeKey，已测可用值为
        kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange，即420v
        kCVPixelFormatType_420YpCbCr8BiPlanarFullRange，即420f
        kCVPixelFormatType_32BGRA，iOS在内部进行YUV至BGRA格式转换
     YUV420一般用于标清视频，YUV422用于高清视频，这里的限制让人感到意外。但是，在相同条件下，YUV420计算耗时和传输压力比YUV422都小。
     
    * kCVPixelBufferWidthKey/kCVPixelBufferHeightKey: 视频源的分辨率 width*height
     * kCVPixelBufferOpenGLCompatibilityKey : 它允许在 OpenGL 的上下文中直接绘制解码后的图像，而不是从总线和 CPU 之间复制数据。这有时候被称为零拷贝通道，因为在绘制过程中没有解码的图像被拷贝.
     
     */
    NSDictionary *destinationPixBufferAttrs =
    @{
      (id)kCVPixelBufferPixelFormatTypeKey: [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange], //iOS上 nv12(uvuv排布) 而不是nv21（vuvu排布）
      (id)kCVPixelBufferWidthKey: [NSNumber numberWithInteger:_config.width],
      (id)kCVPixelBufferHeightKey: [NSNumber numberWithInteger:_config.height],
      (id)kCVPixelBufferOpenGLCompatibilityKey: [NSNumber numberWithBool:true]
      };
    
    
    //解码回调设置
    /*
     VTDecompressionOutputCallbackRecord 是一个简单的结构体，它带有一个指针 (decompressionOutputCallback)，指向帧解压完成后的回调方法。你需要提供可以找到这个回调方法的实例 (decompressionOutputRefCon)。VTDecompressionOutputCallback 回调方法包括七个参数：
            参数1: 回调的引用
            参数2: 帧的引用
            参数3: 一个状态标识 (包含未定义的代码)
            参数4: 指示同步/异步解码，或者解码器是否打算丢帧的标识
            参数5: 实际图像的缓冲
            参数6: 出现的时间戳
            参数7: 出现的持续时间
     */
    VTDecompressionOutputCallbackRecord callbackRecord;
    callbackRecord.decompressionOutputCallback = videoDecompressionOutputCallback;
    callbackRecord.decompressionOutputRefCon = (__bridge void * _Nullable)(self);
    
    
    //创建session
    
    /*!
     @function    VTDecompressionSessionCreate
     @abstract    创建用于解压缩视频帧的会话。
     @discussion  解压后的帧将通过调用OutputCallback发出
     @param    allocator  内存的会话。通过使用默认的kCFAllocatorDefault的分配器。
     @param    videoFormatDescription 描述源视频帧
     @param    videoDecoderSpecification 指定必须使用的特定视频解码器.NULL
     @param    destinationImageBufferAttributes 描述源像素缓冲区的要求 NULL
     @param    outputCallback 使用已解压缩的帧调用的回调
     @param    decompressionSessionOut 指向一个变量以接收新的解压会话
     */
    status = VTDecompressionSessionCreate(kCFAllocatorDefault, _decodeDesc, NULL, (__bridge CFDictionaryRef _Nullable)(destinationPixBufferAttrs), &callbackRecord, &_decodeSesion);
    
    //判断一下status
    if (status != noErr) {
        NSLog(@"Video hard DecodeSession create failed status= %d", (int)status);
        return false;
    }
    
    //设置解码会话属性(实时编码)
    status = VTSessionSetProperty(_decodeSesion, kVTDecompressionPropertyKey_RealTime,kCFBooleanTrue);
    
    NSLog(@"Vidoe hard decodeSession set property RealTime status = %d", (int)status);
    
    return true;
}
/**解码函数（private）*/
- (CVPixelBufferRef)decode:(uint8_t *)frame withSize:(uint32_t)frameSize {
    
    CVPixelBufferRef outputPixelBuffer = NULL;
    CMBlockBufferRef blockBuffer = NULL;
    CMBlockBufferFlags flag0 = 0;
    
    //创建blockBuffer
    /*!
     参数1: structureAllocator kCFAllocatorDefault  内存分配器
     参数2: memoryBlock  frame  数据帧指针
     参数3: frame size  数据帧大小
     参数4: blockAllocator: Pass NULL   KCFAllocatorDefault 内存分配方式默认
     参数5: customBlockSource Pass NULL KCFAllocatorDefault 内存分配方式默认
     参数6: offsetToData  数据偏移  ？ 这是什么
     参数7: dataLength 数据长度  数据长度
     参数8: flags 功能和控制标志
     参数9: newBBufOut blockBuffer地址,不能为空  填充blockButter地址
     */
    // 根据frame 信息创建 CMBlockBufferRef 数据
    /*
     CMBlockBuffer对象包含H264基本流,
     
    A。 CMBlockBuffer中的数据以AVCC格式存储 附件B格式
     
    B。 单个CMBlockBuffer有时会包含多个NAL单元
     
    C. 必须读取AVCC标题中包含的长度值以找到下一个NAL单元
     
     4个第一个字节包含NAL单元的长度(H264数据包的另一个字)
     .您需要使用4字节起始码替换此标头：0x00 0x00 0x00 0x01,用作附件B基本流中的NAL单元之间的分隔符(3字节版本0x00 0x00 0x01也可以正常工作).


    D。AVCC头是以Big-Endian（大端）格式存储的,而iOS是本机的Little-Endian.（小端）因此,当您读取AVCC头文件中包含的长度值时。首先要进行大小端转换
     
    E。 CMBlockBuffer内的数据不包含参数NAL单元SPS和PPS。所以在发送之前拼接sps pps 。通常在I帧之前拼接
     
     如配置文件,级别,分辨率,帧速率.这些作为元数据存储在样本缓冲区的格式描述中,可以通过CMVideoFormatDescriptionGetH264ParameterSetAtIndex函数进行访问
     
     
     */
    OSStatus status = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, frame, frameSize, kCFAllocatorNull, NULL, 0, frameSize, flag0, &blockBuffer);
    
    if (status != kCMBlockBufferNoErr) {
        NSLog(@"Video hard decode create blockBuffer error code=%d", (int)status);
        return outputPixelBuffer;
    }
    
    
    CMSampleBufferRef sampleBuffer = NULL;
    const size_t sampleSizeArray[] = {frameSize};
    
    //创建sampleBuffer
    /*
     参数1: allocator 分配器,使用默认内存分配, kCFAllocatorDefault
     参数2: blockBuffer.需要编码的数据blockBuffer.不能为NULL
     参数3: formatDescription,视频输出格式
     参数4: numSamples.CMSampleBuffer 个数.
     参数5: numSampleTimingEntries 必须为0,1,numSamples
     参数6: sampleTimingArray.  数组.为空
     参数7: numSampleSizeEntries 默认为1
     参数8: sampleSizeArray
     参数9: sampleBuffer对象
     */
    // 根据blockBuffer 生成 CMSampleBufferRef
    status = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, _decodeDesc, 1, 0, NULL, 1, sampleSizeArray, &sampleBuffer);
    
    if (status != noErr || !sampleBuffer) {
        NSLog(@"Video hard decode create sampleBuffer failed status=%d", (int)status);
        CFRelease(blockBuffer);
        return outputPixelBuffer;
    }
    
    //解码
    //向视频解码器提示使用低功耗模式是可以的
    VTDecodeFrameFlags flag1 = kVTDecodeFrame_1xRealTimePlayback;
    //异步解码
    VTDecodeInfoFlags  infoFlag = kVTDecodeInfo_Asynchronous;
    //解码数据
    /*
     参数1: 解码session
     参数2: 源数据 包含一个或多个视频帧的CMsampleBuffer
     参数3: 解码标志
     参数4: 解码后数据outputPixelBuffer
     参数5: 同步/异步解码标识
     */
    status = VTDecompressionSessionDecodeFrame(_decodeSesion, sampleBuffer, flag1, &outputPixelBuffer, &infoFlag);
    
    if (status == kVTInvalidSessionErr) {
        NSLog(@"Video hard decode  InvalidSessionErr status =%d", (int)status);
    } else if (status == kVTVideoDecoderBadDataErr) {
        NSLog(@"Video hard decode  BadData status =%d", (int)status);
    } else if (status != noErr) {
        NSLog(@"Video hard decode failed status =%d", (int)status);
    }
    CFRelease(sampleBuffer);
    CFRelease(blockBuffer);
    
    return outputPixelBuffer;
}
@end
