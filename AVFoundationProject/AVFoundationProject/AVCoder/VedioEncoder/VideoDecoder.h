//
//  VideoEncoder.h
//  AVFoundationProject
//  解码
//  Created by 赵泓博 on 2021/3/30.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import "AVConfig.h"

NS_ASSUME_NONNULL_BEGIN
/**h264解码回调代理*/
@protocol VideoDecoderDelegate <NSObject>
//解码后H264数据回调
- (void)videoDecodeCallback:(CVPixelBufferRef)imageBuffer;
@end

/*
 生成session ,对接收的数据 先转换为 CMBlockBufferRef
 
 
 再转换为 CMSampleBufferRef
 
 
 再转换为 CVPixelBufferRef
 同时将 CMSampleBufferRef 填充到session 中 代理返回
 
 CVPixelBufferRef 会从代理里返回
 
 
 并且从代理中返回  CVImageBufferRef
 CVImageBufferRef 可以转换为UIImage
 
另外 CVPixelBufferRef 也可以转换成 opengl 的纹理数据
 
 这块可以研究一下。
 
 
 解码可以解码成各种各样的类型。
 
 
 */
@interface VideoDecoder : NSObject
@property (nonatomic, strong) VedioConfig *config;
@property (nonatomic, weak) id<VideoDecoderDelegate> delegate;
/**初始化解码器**/
- (instancetype)initWithConfig:(VedioConfig*)config;
/**解码h264数据*/
- (void)decodeNaluData:(NSData *)frame;
@end

NS_ASSUME_NONNULL_END
