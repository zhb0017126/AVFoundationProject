//
//  AVConfig.m
//  AVFoundationProject
//
//  Created by 赵泓博 on 2021/3/30.
//

#import "AVConfig.h"


@implementation AudioConfig

+ (instancetype)defaultConifg {
    return  [[AudioConfig alloc] init];
}
- (instancetype)init
{
    self = [super init];
    if (self) {
        self.bitrate = 96000;
        self.channelCount = 1;
        self.sampleSize = 16;
        self.sampleRate = 44100;
    }
    return self;
}
@end


@implementation VedioConfig
+ (instancetype)defaultConifg;
{
    return [[self alloc]init];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.width = 480;
        self.height = 640;
        self.bitrate = 640*1000;
        self.fps = 25;
    }
    return self;
}
@end
