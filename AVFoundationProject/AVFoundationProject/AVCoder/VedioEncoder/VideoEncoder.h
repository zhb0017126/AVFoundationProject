//
//  VideoEncoder.h
//  AVFoundationProject
//
//  Created by 赵泓博 on 2021/4/1.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "AVConfig.h"
NS_ASSUME_NONNULL_BEGIN
/**h264编码回调代理*/
@protocol VideoEncoderDelegate <NSObject>
//Video-H264数据编码完成回调
- (void)videoEncodeCallback:(NSData *)h264Data;
//Video-SPS&PPS数据编码回调
- (void)videoEncodeCallbacksps:(NSData *)sps pps:(NSData *)pps;
@end
@interface VideoEncoder : NSObject
@property (nonatomic, weak) id<VideoEncoderDelegate> delegate;
@property (nonatomic, strong) VedioConfig *config;
- (instancetype)initWithConfig:(VedioConfig*)config;
@end

NS_ASSUME_NONNULL_END
