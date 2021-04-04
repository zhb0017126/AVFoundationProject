//
//  AudioEncoder.m
//  AVFoundationProject
//
//  Created by 赵泓博 on 2021/4/2.
//

#import "AudioEncoder.h"
@interface AudioEncoder ()
@property (nonatomic, strong) dispatch_queue_t encoderQueue;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;

//对音频转换器对象
@property (nonatomic, unsafe_unretained) AudioConverterRef audioConverter;

//PCM缓存区
@property (nonatomic) char *pcmBuffer;
//PCM缓存区大小
@property (nonatomic) size_t pcmBufferSize;

@end
@implementation AudioEncoder
/**初始化传入编码器配置*/
- (instancetype)initWithConfig:(AudioConfig*)config;
{
    self = [super init];
    if (self) {
        //音频编码队列
        _encoderQueue = dispatch_queue_create("aac hard encoder queue", DISPATCH_QUEUE_SERIAL);
        //音频回调队列
        _callbackQueue = dispatch_queue_create("aac hard encoder callback queue", DISPATCH_QUEUE_SERIAL);
        //音频转换器
        _audioConverter = NULL;
        _pcmBufferSize = 0;
        _pcmBuffer = NULL;
        _config = config;
        if (config == nil) {
            _config = [[AudioConfig alloc] init];
        }
        
    }
    return self;
}
/**编码*/
- (void)encodeAudioSamepleBuffer: (CMSampleBufferRef)sampleBuffer;
{
    //1.判断音频转换器是否创建成功.如果未创建成功.则配置音频编码参数且创建转码器
    // ? 问题，如果过程中，音频数据发生了变化，这块貌似没有兼容 。貌似iOS 不会变化。如果有变化的情况需要考虑兼容
    if (!_audioConverter) {
        [self setupEncoderWithSampleBuffer:sampleBuffer];
    }
}

//配置音频编码参数
- (void)setupEncoderWithSampleBuffer: (CMSampleBufferRef)sampleBuffer {
    
    //1.获取输入参数
    AudioStreamBasicDescription inputAduioDes = *CMAudioFormatDescriptionGetStreamBasicDescription( CMSampleBufferGetFormatDescription(sampleBuffer));
    
    //2.设置输出参数
    AudioStreamBasicDescription outputAudioDes = {0};
    outputAudioDes.mSampleRate = (Float64)_config.sampleRate;       //采样率
    outputAudioDes.mFormatID = kAudioFormatMPEG4AAC;                //输出格式
    outputAudioDes.mFormatFlags = kMPEG4Object_AAC_LC;              // 如果设为0 代表无损编码
    outputAudioDes.mBytesPerPacket = 0;                             //自己确定每个packet 大小
    outputAudioDes.mFramesPerPacket = 1024;                         //每一个packet帧数 AAC-1024；
    outputAudioDes.mBytesPerFrame = 0;                              //每一帧大小
    outputAudioDes.mChannelsPerFrame = (uint32_t)_config.channelCount; //输出声道数
    outputAudioDes.mBitsPerChannel = 0;                             //数据帧中每个通道的采样位数。
    outputAudioDes.mReserved =  0;                                  //对其方式 0(8字节对齐)
    
    //填充输出相关信息
    UInt32 outDesSize = sizeof(outputAudioDes);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &outDesSize, &outputAudioDes);
    
    
    //3.获取编码器的描述信息(只能传入software)
    AudioClassDescription *audioClassDesc = [self getAudioCalssDescriptionWithType:outputAudioDes.mFormatID fromManufacture:kAppleSoftwareAudioCodecManufacturer];
    
    // 4. 创建音频转换器对象
    /** 创建converter 音频转换器对象
     参数1：输入音频格式描述
     参数2：输出音频格式描述
     参数3：class desc的数量
     参数4：class desc  编码器描述信息
     参数5：创建的解码器  需要填充的音频转换器对象
     */
    OSStatus status = AudioConverterNewSpecific(&inputAduioDes, &outputAudioDes, 1, audioClassDesc, &_audioConverter);
    if (status != noErr) {
        NSLog(@"Error！：硬编码AAC创建失败, status= %d", (int)status);
        return;
    }
    
    //5. 设置编解码质量
    /*
     kAudioConverterQuality_Max                              = 0x7F,
     kAudioConverterQuality_High                             = 0x60,
     kAudioConverterQuality_Medium                           = 0x40,
     kAudioConverterQuality_Low                              = 0x20,
     kAudioConverterQuality_Min                              = 0
     */
    UInt32 temp = kAudioConverterQuality_High;
    //编解码器的呈现质量
    AudioConverterSetProperty(_audioConverter, kAudioConverterCodecQuality, sizeof(temp), &temp);
    
    
    //6.设置比特率
    uint32_t audioBitrate = (uint32_t)self.config.bitrate;
    uint32_t audioBitrateSize = sizeof(audioBitrate);
    status = AudioConverterSetProperty(_audioConverter, kAudioConverterEncodeBitRate, audioBitrateSize, &audioBitrate);
    if (status != noErr) {
        NSLog(@"Error！：硬编码AAC 设置比特率失败");
    }
    
    //    //获取最大输出(用于填充数据时检查是否填满)
    //    UInt32 audioMaxOutput = 0;
    //    UInt32 audioMaxOutputSize = sizeof(audioMaxOutput);
    //    self.audioMaxOutputFrameSize = audioMaxOutputSize;
    //    status = AudioConverterGetProperty(_audioConverter, kAudioConverterPropertyMaximumOutputPacketSize, &audioMaxOutputSize, &audioBitrate);
    //
    //    if (audioMaxOutputSize == 0) {
    //        NSLog(@"Error!: 硬编码AAC 获取最大frame size失败");
    //    }
    
   /* 整个过程的意义，就是创建并且填充 _audioConverter*/
    
}

/**
 
 检测 AAC编码支持情况  获取编码器类型描述
 参数1：类型
 */
- (AudioClassDescription *)getAudioCalssDescriptionWithType: (AudioFormatID)type fromManufacture: (uint32_t)manufacture {
    
    static AudioClassDescription desc;
    UInt32 encoderSpecific = type;
    
    //获取满足AAC编码器的总大小
    UInt32 size;
    
    // 1. 获取编码器相关参数
    /**
     参数1：编码器类型
     参数2：类型描述大小
     参数3：类型描述
     参数4：大小
     */
    OSStatus status = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders, sizeof(encoderSpecific), &encoderSpecific, &size);
    if (status != noErr) {
        NSLog(@"Error！：硬编码AAC get info 失败, status= %d", (int)status);
        return nil;
    }
    //计算aac编码器的个数
    unsigned int count = size / sizeof(AudioClassDescription);
    //创建一个包含count个编码器的数组
    AudioClassDescription description[count];
    //  获取满足aac编码器的信息
    //将满足aac编码的编码器的信息写入数组
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(encoderSpecific), &encoderSpecific, &size, &description);
    if (status != noErr) {
        NSLog(@"Error！：硬编码AAC get propery 失败, status= %d", (int)status);
        return nil;
    }
    // 遍历编码器数组，获取满足入参 type 和 manufacture 的编码器，并且返回该编码器的描述信息
    for (unsigned int i = 0; i < count; i++) {
        if (type == description[i].mSubType && manufacture == description[i].mManufacturer) {
            desc = description[i];
            return &desc;
        }
    }
    return nil;
}


@end
