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


@interface AudioEncoder : NSObject
/**编码器配置*/
@property (nonatomic, strong) AudioConfig *config;
/**初始化传入编码器配置*/
- (instancetype)initWithConfig:(AudioConfig*)config;
/**编码*/
- (void)encodeAudioSamepleBuffer: (CMSampleBufferRef)sampleBuffer;
@end
NS_ASSUME_NONNULL_END
