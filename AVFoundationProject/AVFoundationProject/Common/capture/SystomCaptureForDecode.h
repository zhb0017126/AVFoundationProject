//
//  SystomCaptureForDecode.h
//  AVFoundationProject
//
//  Created by 赵泓博 on 2021/3/21.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef NS_ENUM(int,SystemCaptureType){
    SystemCaptureTypeVideo = 0,
    SystemCaptureTypeAudio,
    SystemCaptureTypeAll
};

@protocol SystemCaptureDelegate <NSObject>
@optional
- (void)captureSampleBuffer:(CMSampleBufferRef)sampleBuffer type: (SystemCaptureType)type;

@end

@interface SystomCaptureForDecode : NSObject
-(instancetype)initWithType:(SystemCaptureType)type;

/***/
@property (nonatomic,strong) UIView *preview;

@property (nonatomic, weak) id<SystemCaptureDelegate> delegate;
#pragma mark-授权相关
/**
 *  麦克风授权
 *  0 ：未授权 1:已授权 -1：拒绝
 */
+ (int)checkMicrophoneAuthor;
/**
 *  摄像头授权
 *  0 ：未授权 1:已授权 -1：拒绝
 */
+ (int)checkCameraAuthor;
@end

NS_ASSUME_NONNULL_END
