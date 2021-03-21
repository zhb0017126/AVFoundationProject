//
//  SystomCaptureForDecode.m
//  AVFoundationProject
//
//  Created by 赵泓博 on 2021/3/21.
//

#import "SystomCaptureForDecode.h"
@interface SystomCaptureForDecode()<AVCaptureAudioDataOutputSampleBufferDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>
/********************控制相关**********/
//是否进行
@property (nonatomic, assign) BOOL isRunning;
/********************公共*************/
//音视频信息捕获session会话
@property (nonatomic, strong) AVCaptureSession *captureSession;
//音视频信息捕捉代理代理队列
@property (nonatomic, strong) dispatch_queue_t captureQueue;

/********************音频相关**********/
//音频设备
@property (nonatomic, strong) AVCaptureDeviceInput *audioInputDevice;
//输出数据接收
@property (nonatomic, strong) AVCaptureAudioDataOutput *audioDataOutput;
//
@property (nonatomic, strong) AVCaptureConnection *audioConnection;


///***/
//@property (nonatomic,strong) AVCapturePhotoOutput *photoOutPut;
////
//@property (nonatomic, strong) AVCaptureConnection *photoConnection;

/********************视频相关**********/
//当前使用的视频设备
@property (nonatomic, weak) AVCaptureDeviceInput *videoInputDevice;
//前后摄像头
@property (nonatomic, strong) AVCaptureDeviceInput *frontCamera;
@property (nonatomic, strong) AVCaptureDeviceInput *backCamera;
//输出数据接收
@property (nonatomic, strong) AVCaptureVideoDataOutput *videoDataOutput;
@property (nonatomic, strong) AVCaptureConnection *videoConnection;
//预览层
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *preLayer;
@property (nonatomic, assign) CGSize prelayerSize;


/**视频输出分辨率*/
@property (nonatomic,assign) CGSize videoPresetSize;

@end

@implementation SystomCaptureForDecode{
    SystemCaptureType captureType;
}
#pragma mark -入口函数
- (instancetype)initWithType:(SystemCaptureType)type {
    self = [super init];
    if (self) {
        captureType = type;
    }
    return self;
}
//准备捕获
- (void)prepare {
    [self prepareWithPreviewSize:CGSizeZero];
}

//准备捕获(视频/音频)
- (void)prepareWithPreviewSize:(CGSize)size {
    _prelayerSize = size;
    if (captureType == SystemCaptureTypeAudio) {
        [self setupAudio];
    }else if (captureType == SystemCaptureTypeVideo) {
        [self setupVideo];
    }else if (captureType == SystemCaptureTypeAll) {
        [self setupAudio];
        [self setupVideo];
    }
}
#pragma mark-init Audio/video  音频 视频信息初始化
/* PS: 在苹果Avcapture 的架构设计中
  session 为整体配置。也就是完整流水线。但是一个流水线生产多种产品。
  输入信息（intput class）、输出信息(outPut class)，分别为不同的信息入口和信息出口
  
 AVCaptureConnection 可以理解为标识符
 
 原则上，流水线出口只有一条（output 代理方法）。通过 AVCaptureConnection 标识出口数据为谁工作的。

 session 会话为完整载体。
 在载体中装配
 1. 输入信息 （input calss）
 2. 输出信息  (output calss )
 3. 标识符信息 （AVCaptureConnection）
 就可以获取指定类型的数据了
 */
- (void)setupAudio{
    //麦克风设备
    AVCaptureDevice *audioDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeAudio];
    //将audioDevice ->AVCaptureDeviceInput 对象
    self.audioInputDevice = [AVCaptureDeviceInput deviceInputWithDevice:audioDevice error:nil];
    //设置音频输出音
    self.audioDataOutput = [[AVCaptureAudioDataOutput alloc] init];
    // 配置输出回调代理 和输出工作队列
    [self.audioDataOutput setSampleBufferDelegate:self queue:self.captureQueue];
    //配置
    // 添加输入信息
    [self.captureSession beginConfiguration];
    if ([self.captureSession canAddInput:self.audioInputDevice]) {
        [self.captureSession addInput:self.audioInputDevice];
    }
    //添加输出信息
    if([self.captureSession canAddOutput:self.audioDataOutput]){
        [self.captureSession addOutput:self.audioDataOutput];
    }
    [self.captureSession commitConfiguration]; // commit 提交上下文
    
    self.audioConnection = [self.audioDataOutput connectionWithMediaType:AVMediaTypeAudio];
}
- (void)setupVideo{
    //所有video设备
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    //前置摄像头
    self.frontCamera = [AVCaptureDeviceInput deviceInputWithDevice:videoDevices.lastObject error:nil];
    self.backCamera = [AVCaptureDeviceInput deviceInputWithDevice:videoDevices.firstObject error:nil];
    //设置当前设备为前置
    self.videoInputDevice = self.backCamera;
    //视频输出
    self.videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [self.videoDataOutput setSampleBufferDelegate:self queue:self.captureQueue];
    [self.videoDataOutput setAlwaysDiscardsLateVideoFrames:YES]; // 捕获帧后不做处理，马上丢弃。（通常不知道美颜是不是需要设置为NO）
    //配置视频参数
    /*
     kCVPixelBufferPixelFormatTypeKey它指定像素的输出格式，这个参数直接影响到生成图像的成功与否
     kCVPixelFormatType_420YpCbCr8BiPlanarFullRange  YUV420格式.
     */
    
    [self.videoDataOutput setVideoSettings:@{
                                             (__bridge NSString *)kCVPixelBufferPixelFormatTypeKey:@(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
                                             }];
    //配置  添加输入
    [self.captureSession beginConfiguration];
    if ([self.captureSession canAddInput:self.videoInputDevice]) {
        [self.captureSession addInput:self.videoInputDevice];
    }
    // 添加输出
    if([self.captureSession canAddOutput:self.videoDataOutput]){
        [self.captureSession addOutput:self.videoDataOutput];
    }
    //分辨率
    [self setVideoPreset];
    [self.captureSession commitConfiguration];
    // 添加 Connection
    self.videoConnection = [self.videoDataOutput connectionWithMediaType:AVMediaTypeVideo];
    
    //****commit后下面的代码才会有效*** ？ 为啥
    
   
    //设置视频输出方向
    self.videoConnection.videoOrientation = AVCaptureVideoOrientationPortrait;
    
    //fps
    /*
     FPS是图像领域中的定义，是指画面每秒传输帧数，通俗来讲就是指动画或视频的画面数。
     FPS是测量用于保存、显示动态视频的信息数量。每秒钟帧数愈多，所显示的动作就会越流畅。
     通常，要避免动作不流畅的最低是30。某些计算机视频格式，每秒只能提供15帧。
     */
    [self updateFps:25]; // 视频捕捉设置选项
    //设置预览
    [self setupPreviewLayer];
    // 有个 想法，如果不设置预览图层。直接使用捕捉的数据渲染。就可以实现预览过程中的效果捕捉了
}

/**设置分辨率**/
- (void)setVideoPreset{
    if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1920x1080])  {
        self.captureSession.sessionPreset = AVCaptureSessionPreset1920x1080;
        self.videoPresetSize = CGSizeMake(1080, 1920);
//        self.videoPresetSize.width = 1080; self.videoPresetSize.height = 1920;
    }else if ([self.captureSession canSetSessionPreset:AVCaptureSessionPreset1280x720]) {
        self.captureSession.sessionPreset = AVCaptureSessionPreset1280x720;
        self.videoPresetSize = CGSizeMake(720, 1280);
//        self.videoPresetSize.witdh = 720; self.videoPresetSize.height = 1280;
    }else{
        self.captureSession.sessionPreset = AVCaptureSessionPreset640x480;
        self.videoPresetSize = CGSizeMake(480, 640);
//        self.videoPresetSize.witdh = 480; self.videoPresetSize.height = 640;
    }
    
}
-(void)updateFps:(NSInteger) fps{
    //获取当前capture设备
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    //遍历所有设备（前后摄像头）
    for (AVCaptureDevice *vDevice in videoDevices) {
        //获取当前支持的最大fps
        float maxRate = [(AVFrameRateRange *)[vDevice.activeFormat.videoSupportedFrameRateRanges objectAtIndex:0] maxFrameRate];
        //如果想要设置的fps小于或等于做大fps，就进行修改
        if (maxRate >= fps) {
            //实际修改fps的代码
            if ([vDevice lockForConfiguration:NULL]) {
                vDevice.activeVideoMinFrameDuration = CMTimeMake(10, (int)(fps * 10));
                vDevice.activeVideoMaxFrameDuration = vDevice.activeVideoMinFrameDuration;
                [vDevice unlockForConfiguration];
            }
        }
    }
}
/**设置预览层**/
- (void)setupPreviewLayer{
    self.preLayer = [AVCaptureVideoPreviewLayer layerWithSession:self.captureSession];
    self.preLayer.frame =  CGRectMake(0, 0, self.prelayerSize.width, self.prelayerSize.height);
    //设置满屏
    self.preLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.preview.layer addSublayer:self.preLayer];
}
#pragma mark-销毁会话
- (void)dealloc{
    NSLog(@"capture销毁。。。。");
    [self destroyCaptureSession];
}
-(void) destroyCaptureSession{
    if (self.captureSession) {
        if (captureType == SystemCaptureTypeAudio) {
            [self.captureSession removeInput:self.audioInputDevice];
            [self.captureSession removeOutput:self.audioDataOutput];
        }else if (captureType == SystemCaptureTypeVideo) {
            [self.captureSession removeInput:self.videoInputDevice];
            [self.captureSession removeOutput:self.videoDataOutput];
        }else if (captureType == SystemCaptureTypeAll) {
            [self.captureSession removeInput:self.audioInputDevice];
            [self.captureSession removeOutput:self.audioDataOutput];
            [self.captureSession removeInput:self.videoInputDevice];
            [self.captureSession removeOutput:self.videoDataOutput];
        }
    }
    self.captureSession = nil;
}

#pragma mark-输出代理
-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    if (connection == self.audioConnection) { // 音频
        [_delegate captureSampleBuffer:sampleBuffer type:SystemCaptureTypeAudio];
    }else if (connection == self.videoConnection) { // 视频
        [_delegate captureSampleBuffer:sampleBuffer type:SystemCaptureTypeVideo];
    }
}

#pragma mark-授权相关
/**
 *  麦克风授权
 *  0 ：未授权 1:已授权 -1：拒绝
 */
+ (int)checkMicrophoneAuthor{
    int result = 0;
    //麦克风
    AVAudioSessionRecordPermission permissionStatus = [[AVAudioSession sharedInstance] recordPermission];
    switch (permissionStatus) {
        case AVAudioSessionRecordPermissionUndetermined:
            //    请求授权
            [[AVAudioSession sharedInstance] requestRecordPermission:^(BOOL granted) {
            }];
            result = 0;
            break;
        case AVAudioSessionRecordPermissionDenied://拒绝
            result = -1;
            break;
        case AVAudioSessionRecordPermissionGranted://允许
            result = 1;
            break;
        default:
            break;
    }
    return result;
    
    
}
/**
 *  摄像头授权
 *  0 ：未授权 1:已授权 -1：拒绝
 */
+ (int)checkCameraAuthor{
    int result = 0;
    AVAuthorizationStatus videoStatus = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    switch (videoStatus) {
        case AVAuthorizationStatusNotDetermined://第一次
            //    请求授权
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                
            }];
            break;
        case AVAuthorizationStatusAuthorized://已授权
            result = 1;
            break;
        default:
            result = -1;
            break;
    }
    return result;
    
}

#pragma mark-懒加载
- (AVCaptureSession *)captureSession{
    if (!_captureSession) {
        _captureSession = [[AVCaptureSession alloc] init];
    }
    return _captureSession;
}
- (dispatch_queue_t)captureQueue{
    if (!_captureQueue) {
        _captureQueue = dispatch_queue_create("TMCapture Queue", NULL);
    }
    return _captureQueue;
}
#pragma mark - Control start/stop capture or change camera
- (void)start{
    if (!self.isRunning) {
        self.isRunning = YES;
        [self.captureSession startRunning];
    }
}
- (void)stop{
    if (self.isRunning) {
        self.isRunning = NO;
        [self.captureSession stopRunning];
    }
    
}

- (void)changeCamera{
    [self switchCamera];
}
// 切换摄像头
-(void)switchCamera{
    [self.captureSession beginConfiguration];
    [self.captureSession removeInput:self.videoInputDevice];
    if ([self.videoInputDevice isEqual: self.frontCamera]) {
        self.videoInputDevice = self.backCamera;
    }else{
        self.videoInputDevice = self.frontCamera;
    }
    [self.captureSession addInput:self.videoInputDevice];
    [self.captureSession commitConfiguration];
}
@end
