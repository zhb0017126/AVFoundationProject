//
//  AudioEncoder.h
//  AVFoundationProject
//
//  Created by 赵泓博 on 2021/4/2.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "AVConfig.h"
NS_ASSUME_NONNULL_BEGIN

/**AAC编码器代理*/
@protocol AudioEncoderDelegate <NSObject>
- (void)audioEncodeCallback:(NSData *)aacData;
@end
@interface AudioEncoder : NSObject
/**编码器配置*/
@property (nonatomic, strong) AudioConfig *config;
@property (nonatomic, weak) id<AudioEncoderDelegate> delegate;
/**初始化传入编码器配置*/
- (instancetype)initWithConfig:(AudioConfig*)config;
/**编码*/
- (void)encodeAudioSamepleBuffer: (CMSampleBufferRef)sampleBuffer;
// 音频处理，在代理回调中不断的填充数据
@end
NS_ASSUME_NONNULL_END
