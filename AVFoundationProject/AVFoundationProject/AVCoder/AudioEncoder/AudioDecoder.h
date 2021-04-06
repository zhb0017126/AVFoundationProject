//
//  AudioDecoder.h
//  AVFoundationProject
//
//  Created by 赵泓博 on 2021/4/4.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "AVConfig.h"
NS_ASSUME_NONNULL_BEGIN

/**AAC解码回调代理*/
@protocol AudioDecoderDelegate <NSObject>
- (void)audioDecodeCallback:(NSData *)pcmData;
@end
@interface AudioDecoder : NSObject
@property (nonatomic, strong) AudioConfig *config;


@property (nonatomic, weak) id<AudioDecoderDelegate> delegate;
//初始化 传入解码配置
- (instancetype)initWithConfig:(AudioConfig *)config;

/**解码aac*/
- (void)decodeAudioAACData: (NSData *)aacData;

@end

NS_ASSUME_NONNULL_END
