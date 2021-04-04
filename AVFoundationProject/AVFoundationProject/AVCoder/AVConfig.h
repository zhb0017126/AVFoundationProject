//
//  AVConfig.h
//  AVFoundationProject
//
//  Created by 赵泓博 on 2021/3/30.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**音频配置*/
@interface AudioConfig : NSObject
/**码率*/
@property (nonatomic, assign) NSInteger bitrate;//96000）
/**声道*/
@property (nonatomic, assign) NSInteger channelCount;//（1）
/**采样率*/
@property (nonatomic, assign) NSInteger sampleRate;//(默认44100)
/**采样点量化*/
@property (nonatomic, assign) NSInteger sampleSize;//(16)

+ (instancetype)defaultConifg;
@end



@interface VedioConfig : NSObject
@property (nonatomic, assign) NSInteger width;//可选，系统支持的分辨率，采集分辨率的宽
@property (nonatomic, assign) NSInteger height;//可选，系统支持的分辨率，采集分辨率的高
@property (nonatomic, assign) NSInteger bitrate;//自由设置  比特率 每秒传输的bit数量
/*
 比特率约高，视频约清晰
 */
@property (nonatomic, assign) NSInteger fps;//自由设置 25  fps 画面每秒传输帧数
/*
 每秒钟帧数越多，所显示的动作就会越流畅。
 */
+ (instancetype)defaultConifg;
@end

NS_ASSUME_NONNULL_END
