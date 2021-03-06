//
//  AudioDecoder.m
//  AVFoundationProject
//
//  Created by 赵泓博 on 2021/4/4.
//

#import "AudioDecoder.h"

typedef struct {
    char * data;
    UInt32 size;
    UInt32 channelCount;
    AudioStreamPacketDescription packetDesc;
} AudioUserData;
@interface AudioDecoder()
@property (strong, nonatomic) NSCondition *converterCond;
@property (nonatomic, strong) dispatch_queue_t decoderQueue;
@property (nonatomic, strong) dispatch_queue_t callbackQueue;

@property (nonatomic) AudioConverterRef audioConverter; // 音频解码器文件

@property (nonatomic) char *aacBuffer;  // aac缓存指针
@property (nonatomic) UInt32 aacBufferSize; // aac缓存大小
@property (nonatomic) AudioStreamPacketDescription *packetDesc; // 视频包描述信息
@end
@implementation AudioDecoder
//解码器回调函数
static OSStatus AudioDecoderConverterComplexInputDataProc(  AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData,  AudioStreamPacketDescription **outDataPacketDescription,  void *inUserData) {
    
    
    AudioUserData *audioDecoder = (AudioUserData *)(inUserData);
    if (audioDecoder->size <= 0) {
        ioNumberDataPackets = 0;
        return -1;
    }
   
    //填充数据
    *outDataPacketDescription = &audioDecoder->packetDesc;
    (*outDataPacketDescription)[0].mStartOffset = 0;
    (*outDataPacketDescription)[0].mDataByteSize = audioDecoder->size;
    (*outDataPacketDescription)[0].mVariableFramesInPacket = 0;
    
    ioData->mBuffers[0].mData = audioDecoder->data;
    ioData->mBuffers[0].mDataByteSize = audioDecoder->size;
    ioData->mBuffers[0].mNumberChannels = audioDecoder->channelCount;
    
    return noErr;
}

//初始化
- (instancetype)initWithConfig:(AudioConfig *)config {
    self = [super init];
    if (self) {
        _decoderQueue = dispatch_queue_create("aac hard decoder queue", DISPATCH_QUEUE_SERIAL);
        _callbackQueue = dispatch_queue_create("aac hard decoder callback queue", DISPATCH_QUEUE_SERIAL);
        _audioConverter = NULL;
        _aacBufferSize = 0;
        _aacBuffer = NULL;
        _config = config;
        if (_config == nil) {
            _config = [[AudioConfig alloc] init];
        }
        AudioStreamPacketDescription desc = {0};
        _packetDesc = &desc;
        [self setupEncoder];
    }
    return self;
}
#pragma mark 创建音频解码器
- (void)setupEncoder {
    
    //输出参数pcm
    AudioStreamBasicDescription outputAudioDes = {0};
    outputAudioDes.mSampleRate = (Float64)_config.sampleRate;       //采样率
    outputAudioDes.mChannelsPerFrame = (UInt32)_config.channelCount; //输出声道数
    outputAudioDes.mFormatID = kAudioFormatLinearPCM;                //输出格式
    outputAudioDes.mFormatFlags = (kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked); //编码 12
    outputAudioDes.mFramesPerPacket = 1;                            //每一个packet帧数 ；
    outputAudioDes.mBitsPerChannel = 16;                             //数据帧中每个通道的采样位数。
    outputAudioDes.mBytesPerFrame = outputAudioDes.mBitsPerChannel / 8 *outputAudioDes.mChannelsPerFrame;                              //每一帧大小（采样位数 / 8 *声道数）
    outputAudioDes.mBytesPerPacket = outputAudioDes.mBytesPerFrame * outputAudioDes.mFramesPerPacket;                             //每个packet大小（帧大小 * 帧数）
    outputAudioDes.mReserved =  0;                                  //对其方式 0(8字节对齐)
    
    //输入参数aac
    AudioStreamBasicDescription inputAduioDes = {0};
    inputAduioDes.mSampleRate = (Float64)_config.sampleRate;
    inputAduioDes.mFormatID = kAudioFormatMPEG4AAC;
    inputAduioDes.mFormatFlags = kMPEG4Object_AAC_LC;
    inputAduioDes.mFramesPerPacket = 1024;
    inputAduioDes.mChannelsPerFrame = (UInt32)_config.channelCount;
    
    //填充输出相关信息
    UInt32 inDesSize = sizeof(inputAduioDes);
    AudioFormatGetProperty(kAudioFormatProperty_FormatInfo, 0, NULL, &inDesSize, &inputAduioDes);
    
    //获取解码器的描述信息(只能传入software)
    AudioClassDescription *audioClassDesc = [self getAudioCalssDescriptionWithType:outputAudioDes.mFormatID fromManufacture:kAppleSoftwareAudioCodecManufacturer];
    /** 创建converter  根据解码器描述信息创建解码类
     参数1：输入音频格式描述
     参数2：输出音频格式描述
     参数3：class desc的数量
     参数4：class desc
     参数5：创建的解码器
     */
    OSStatus status = AudioConverterNewSpecific(&inputAduioDes, &outputAudioDes, 1, audioClassDesc, &_audioConverter);
    if (status != noErr) {
        NSLog(@"Error！：硬解码AAC创建失败, status= %d", (int)status);
        return;
    }
}

/**
 获取编码器类型描述  （音频解码器支持多种，获取支持当前格式的音频捡起）
 参数1：类型
 */
- (AudioClassDescription *)getAudioCalssDescriptionWithType: (AudioFormatID)type fromManufacture: (uint32_t)manufacture {
    
    static AudioClassDescription desc;
    UInt32 encoderSpecific = type;
    
    //获取满足AAC编码器的总大小
    UInt32 size;
    
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
    //将满足aac编码的编码器的信息写入数组
    status = AudioFormatGetProperty(kAudioFormatProperty_Encoders, sizeof(encoderSpecific), &encoderSpecific, &size, &description);
    if (status != noErr) {
        NSLog(@"Error！：硬编码AAC get propery 失败, status= %d", (int)status);
        return nil;
    }
    for (unsigned int i = 0; i < count; i++) {
        if (type == description[i].mSubType && manufacture == description[i].mManufacturer) {
            desc = description[i];
            return &desc;
        }
    }
    return nil;
}

- (void)decodeAudioAACData:(NSData *)aacData {
   
    if (!_audioConverter) { return; }
    
    dispatch_async(_decoderQueue, ^{
     
        //记录aac 作为参数参入解码回调函数  pack 解码描述信息
        AudioUserData userData = {0};
        userData.channelCount = (UInt32)self.config.channelCount;
        userData.data = (char *)[aacData bytes];
        userData.size = (UInt32)aacData.length;
        userData.packetDesc.mDataByteSize = (UInt32)aacData.length;
        userData.packetDesc.mStartOffset = 0;
        userData.packetDesc.mVariableFramesInPacket = 0;
        
        //输出大小和packet个数
        UInt32 pcmBufferSize = (UInt32)(2048 * self.config.channelCount);
        UInt32 pcmDataPacketSize = 1024;
        
        //创建临时容器pcm
        uint8_t *pcmBuffer = malloc(pcmBufferSize);
        memset(pcmBuffer, 0, pcmBufferSize);
        
        //输出buffer ? AudioBufferList 可以设置为多个吗
        AudioBufferList outAudioBufferList = {0};
        outAudioBufferList.mNumberBuffers = 1;
        outAudioBufferList.mBuffers[0].mNumberChannels = (uint32_t)self.config.channelCount;
        outAudioBufferList.mBuffers[0].mDataByteSize = (UInt32)pcmBufferSize;
        outAudioBufferList.mBuffers[0].mData = pcmBuffer;
        
        //输出描述
        AudioStreamPacketDescription outputPacketDesc = {0};
        
        //配置填充函数，获取输出数据
        OSStatus status = AudioConverterFillComplexBuffer(self.audioConverter, &AudioDecoderConverterComplexInputDataProc, &userData, &pcmDataPacketSize, &outAudioBufferList, &outputPacketDesc);
        if (status != noErr) {
            NSLog(@"Error: AAC Decoder error, status=%d",(int)status);
            return;
        }
        //如果获取到数据
        if (outAudioBufferList.mBuffers[0].mDataByteSize > 0) {
            NSData *rawData = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
            dispatch_async(self.callbackQueue, ^{
                [self.delegate audioDecodeCallback:rawData];
            });
        }
        free(pcmBuffer);
    });
    
}
- (void)dealloc {
    if (_audioConverter) {
        AudioConverterDispose(_audioConverter);
        _audioConverter = NULL;
    }
}

@end

