//
//  CameraViewController.m
//  BankCardRecog
//
//  Created by wintone on 15/1/22.
//  Copyright (c) 2015年 wintone. All rights reserved.
//

#import "CameraViewController.h"
#import "OverView.h"
#import "SlideLine.h"
#import "UIViewExt.h"
//#import "DriPhotoConfirmViewController.h"
//#import "ConfirmIDViewController.h" //确认身份证信息
//#import "ConfirmIDBackViewController.h"
#if TARGET_IPHONE_SIMULATOR//模拟器
#elif TARGET_OS_IPHONE//真机
#import "WintoneCardOCR.h"
#endif


//屏幕的宽、高
#define kScreenWidth  [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

@interface CameraViewController ()<UIAlertViewDelegate>{
    
    OverView *_overView;//预览界面覆盖层,显示是否找到边
    BOOL _on;//闪光灯是否打开
    
    NSTimer *_timer;//定时器，实现实时对焦
    CAShapeLayer *_maskWithHole;//预览界面覆盖的半透明层
    AVCaptureDevice *_device;//当前摄像设备
    BOOL _isFoucePixel;//是否开启对焦
    int _mrzType;//机读码类型
    int _confimCount;//找到边的次数
    int _maxCount;//找边最大次数
    float _isIOS8AndFoucePixelLensPosition;//相位聚焦下镜头位置
    float _aLensPosition;//默认镜头位置
}

@property (assign, nonatomic) BOOL adjustingFocus;//是否正在对焦
#if TARGET_IPHONE_SIMULATOR//模拟器

#elif TARGET_OS_IPHONE//真机

@property (strong, nonatomic) WintoneCardOCR *cardRecog;//核心

#endif
@property (strong, nonatomic) UILabel *middleLabel;

@end

@implementation CameraViewController


- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    _confimCount = 0;
    _maxCount = 2;//最大连续检边次数
#if TARGET_IPHONE_SIMULATOR//模拟器
    
#elif TARGET_OS_IPHONE//真机
    
    //初始化识别核心
    [self initRecog];
    //初始化相机
    [self initialize];
    //创建相机界面控件
    [self createCameraView];
    
#endif
    
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    //隐藏navigationBar
    self.navigationController.navigationBarHidden = YES;
    if(!_isFoucePixel){//如果不支持相位对焦，开启自定义对焦
        //定时器 开启连续对焦
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.3 target:self selector:@selector(fouceMode) userInfo:nil repeats:YES];
    }
    
    AVCaptureDevice*camDevice =[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    int flags = NSKeyValueObservingOptionNew;
    //注册反差对焦通知（5s以下机型）
    [camDevice addObserver:self forKeyPath:@"adjustingFocus" options:flags context:nil];
    if (_isFoucePixel) {
        [camDevice addObserver:self forKeyPath:@"lensPosition" options:flags context:nil];
    }
    [self.session startRunning];
    
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    self.view.backgroundColor = [UIColor clearColor];
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    //移除聚焦监听
    AVCaptureDevice*camDevice =[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [camDevice removeObserver:self forKeyPath:@"adjustingFocus"];
    if (_isFoucePixel) {
        [camDevice removeObserver:self forKeyPath:@"lensPosition"];
    }
    [self.session stopRunning];
    [[AVAudioSession sharedInstance] setActive:false error:nil];
    
}
- (void) viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    
  
    //关闭定时器
    if(!_isFoucePixel){
        [_timer invalidate];
    }
}

//监听对焦
-(void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    if([keyPath isEqualToString:@"adjustingFocus"]){
        self.adjustingFocus =[[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1]];
        //对焦中
    }
    if([keyPath isEqualToString:@"lensPosition"]){
        _isIOS8AndFoucePixelLensPosition =[[change objectForKey:NSKeyValueChangeNewKey] floatValue];
    }
}

#pragma mark - 初始化识别核心
- (void) initRecog
{
#if TARGET_IPHONE_SIMULATOR//模拟器
    
#elif TARGET_OS_IPHONE//真机
    
    
    NSDate *before = [NSDate date];
    self.cardRecog = [[WintoneCardOCR alloc] init];
    
    /*提示：该开发码和项目中的授权仅为演示用，客户开发时请替换该开发码及项目中Copy Bundle Resources 中的.lsc授权文件*/
    int intRecog = [self.cardRecog InitIDCardWithDevcode:@""];
    NSLog(@"ingRecog = %d",intRecog);
    
    //设置识别方式和证件类型
    [_cardRecog setParameterWithMode:1 CardType:self.recogType];
    
    //设置检边参数,根据识别的图像在整张图上的位置设置,建议不要改动
    //    [_cardRecog setROIWithLeft:225 Top:100 Right:1024 Bottom:618];//图像分辨率1280*720
    
    //设置二代证识别类型（0-正反面 1-正面 2-背面），在调用IsDetectRegionValid之后调用
    [self.cardRecog SetDetectIDCardType:0];
    
    NSTimeInterval time = [[NSDate date] timeIntervalSinceDate:before];
    NSLog(@"初始化核心时间：%f", time);
#endif
}

#if TARGET_IPHONE_SIMULATOR//模拟器

#elif TARGET_OS_IPHONE//真机

//初始化相机
- (void) initialize
{
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 7.0) {
        //判断摄像头授权
        NSString *mediaType = AVMediaTypeVideo;
        AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
        if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied){
            
            UIAlertView * alt = [[UIAlertView alloc] initWithTitle:@"请在手机'设置'-'隐私'-'相机'里打开权限" message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alt show];
            return;
        }
    }
    //1.创建会话层
    self.session = [[AVCaptureSession alloc] init];
    //设置图片品质，此分辨率为最佳识别分辨率，建议不要改动
    [self.session setSessionPreset:AVCaptureSessionPreset1280x720];
    
    //2.创建、配置输入设备
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices)
    {
        if (device.position == AVCaptureDevicePositionBack)
        {
            _device = device;
            self.captureInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
        }
    }
    [self.session addInput:self.captureInput];
    
    ///创建、配置预览输出设备
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc] init];
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    
    dispatch_queue_t queue;
    queue = dispatch_queue_create("cameraQueue", NULL);
    [captureOutput setSampleBufferDelegate:self queue:queue];
    
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary dictionaryWithObject:value forKey:key];
    [captureOutput setVideoSettings:videoSettings];
    
    [self.session addOutput:captureOutput];
    
    //3.创建、配置输出
    self.captureOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
    [self.captureOutput setOutputSettings:outputSettings];
    [self.session addOutput:self.captureOutput];
    
    //判断对焦方式
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
        AVCaptureDeviceFormat *deviceFormat = _device.activeFormat;
        if (deviceFormat.autoFocusSystem == AVCaptureAutoFocusSystemPhaseDetection){
            _isFoucePixel = YES;
            _maxCount = 2;//最大连续检边次数
        }
    }
    
    //设置预览
    self.preview = [AVCaptureVideoPreviewLayer layerWithSession: self.session];
    self.preview.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    self.preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:self.preview];
    
    [self.session startRunning];
}

//重绘透明部分
- (void) drawShapeLayer
{
    //设置覆盖层
    _maskWithHole = [CAShapeLayer layer];
    
    // Both frames are defined in the same coordinate system
    CGRect biggerRect = self.view.bounds;
    CGFloat offset = 1.0f;
    if ([[UIScreen mainScreen] scale] >= 2) {
        offset = 0.5;
    }
    
    //设置检边视图层
    CGRect smallFrame;
    if (self.recogType == 3000) {
        _overView.mrz = YES;
        smallFrame = _overView.mrzSmallRect;
    }else{
        _overView.mrz = NO;
        smallFrame  = _overView.smallrect;
    }
    CGRect smallerRect = CGRectInset(smallFrame, -offset, -offset) ;
    
    UIBezierPath *maskPath = [UIBezierPath bezierPath];
    [maskPath moveToPoint:CGPointMake(CGRectGetMinX(biggerRect), CGRectGetMinY(biggerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMinX(biggerRect), CGRectGetMaxY(biggerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMaxX(biggerRect), CGRectGetMaxY(biggerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMaxX(biggerRect), CGRectGetMinY(biggerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMinX(biggerRect), CGRectGetMinY(biggerRect))];
    
    [maskPath moveToPoint:CGPointMake(CGRectGetMinX(smallerRect), CGRectGetMinY(smallerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMinX(smallerRect), CGRectGetMaxY(smallerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMaxX(smallerRect), CGRectGetMaxY(smallerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMaxX(smallerRect), CGRectGetMinY(smallerRect))];
    [maskPath addLineToPoint:CGPointMake(CGRectGetMinX(smallerRect), CGRectGetMinY(smallerRect))];
    
    [_maskWithHole setPath:[maskPath CGPath]];
    [_maskWithHole setFillRule:kCAFillRuleEvenOdd];
    [_maskWithHole setFillColor:[[UIColor colorWithWhite:0 alpha:0.35] CGColor]];
    [self.view.layer addSublayer:_maskWithHole];
    [self.view.layer setMasksToBounds:YES];
    
}

//创建相机界面
- (void)createCameraView{
    //设置检边视图层
    _overView = [[OverView alloc] initWithFrame:self.view.bounds];
    _overView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_overView];
    if (self.recogType == 3000) {
        _overView.mrz = YES;
        [_overView setNeedsDisplay];
    }else{
        _overView.mrz = NO;
        //隐藏四条边框
        [_overView setLeftHidden:YES];
        [_overView setRightHidden:YES];
        [_overView setBottomHidden:YES];
        [_overView setTopHidden:YES];
    }
    
    CGRect rect = _overView.smallrect;
    
    CGFloat aWidth, aHeight;
    if (kScreenHeight > kScreenWidth) {
        aWidth = kScreenWidth;
        aHeight = kScreenHeight;
    }else{
        aWidth = kScreenHeight;
        aHeight = kScreenWidth;
    }
    
    CGFloat scale = 720.0/aWidth; //720 is the width of current resolution
    NSLog(@"kScreenWidth%f", aWidth);
    CGFloat sTop = CGRectGetMinX(rect)*scale;
    CGFloat sBottom = CGRectGetMaxX(rect)*scale;
    CGFloat sLeft = CGRectGetMinY(rect)*scale;
    CGFloat sRight = CGRectGetMaxY(rect)*scale;
    CGFloat imageScale = 1280.0/720.0;
    CGFloat chazhi = (imageScale*aWidth-aHeight)*scale/2;
    
    //设置检边参数,根据识别的图像在整张图上的位置设置,建议不要改动
    int a = [_cardRecog setROIWithLeft:(int)sLeft+chazhi Top:(int)sTop Right:(int)sRight+chazhi Bottom:(int)sBottom];// Image resolution 1280*720
    NSLog(@"roi%d", a);
    
    //设置覆盖层
    [self drawShapeLayer];
    
    //显示当前识别卡种
    self.middleLabel = [[UILabel alloc] init];
    self.middleLabel.frame = CGRectMake(0, 0, 300, 30);
    self.middleLabel.transform = CGAffineTransformMakeRotation(M_PI/2);
    self.middleLabel.center = self.view.center;
    self.middleLabel.backgroundColor = [UIColor clearColor];
    self.middleLabel.textColor = [UIColor orangeColor];
    self.middleLabel.textAlignment = NSTextAlignmentCenter;
    self.middleLabel.text = NSLocalizedString(self.typeName, nil) ;
    [self.view addSubview:self.middleLabel];
    
    //返回、闪光灯按钮
    UIButton *backBtn = [[UIButton alloc]initWithFrame:CGRectMakeBack(25,30, 35, 35)];
    [backBtn addTarget:self action:@selector(backAction) forControlEvents:UIControlEventTouchUpInside];
    [backBtn setImage:[UIImage imageNamed:@"back_camera_btn"] forState:UIControlStateNormal];
    backBtn.titleLabel.textAlignment = NSTextAlignmentLeft;
    
    [self.view addSubview:backBtn];
    
    UIButton *flashBtn = [[UIButton alloc]initWithFrame:CGRectMakeFlash(255+5,30, 35, 35)];
    [flashBtn setImage:[UIImage imageNamed:@"flash_camera_btn"] forState:UIControlStateNormal];
    [flashBtn addTarget:self action:@selector(flashBtn) forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:flashBtn];
    
}

//从摄像头缓冲区获取图像
#pragma mark - AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    //获取当前帧数据
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    
    int width = (int)CVPixelBufferGetWidth(imageBuffer);
    int height = (int)CVPixelBufferGetHeight(imageBuffer);
    
    //检测证件边
    if (self.recogType == 3000) {
        //判断MRZ类型
        int mrzType = [self.cardRecog GetAcquireMRZSignal:baseAddress Width:width Height:height Left:178 Right:1025 Top:253 Bottom:464 RotateType:0];
        if (mrzType == 1) {
            _mrzType = 1034;
        }
        else if (mrzType == 2) {
            _mrzType = 1036;
        }
        else if (mrzType == 3) {
            _mrzType = 1033;
        }
        if (_mrzType != 0) {
            //加载图片
            int loadMRZ = [self.cardRecog loadMRZImageWithBuffer:baseAddress Width:width Height:height];
            NSLog(@"%d, loadMRZ = %d", mrzType, loadMRZ);
            // 马上停止取景
            [_session stopRunning];
            //识别图片
            [self performSelectorOnMainThread:@selector(readyToRecog) withObject:nil waitUntilDone:YES];
        }
    }else{
        
        if (_aLensPosition == _isIOS8AndFoucePixelLensPosition) {
            
            if ([self.cardRecog newLoadImageWithBuffer:baseAddress Width:width Height:height] == 0) {
                //找边
                SlideLine *sliderLine = [self.cardRecog newConfirmSlideLine];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [_overView setLeftHidden:!sliderLine.allLine];
                    [_overView setRightHidden:!sliderLine.allLine];
                    [_overView setBottomHidden:!sliderLine.allLine];
                    [_overView setTopHidden:!sliderLine.allLine];
                });
                //找边成功
                if (sliderLine.allLine == 1)
                {
                    if ([self.cardRecog newCheckPicIsClear] == 0)//图像清晰
                    {
                        _confimCount++;
                        NSLog(@"_confimCount = %d", _confimCount);
                        //连续找到边_maxCount次，再进行识别
                        if (_confimCount == _maxCount) {
                            //停止取景
                            [_session stopRunning];
                            _confimCount = 0;
                            
                            //开始识别
                            [self performSelectorOnMainThread:@selector(readyToRecog) withObject:nil waitUntilDone:NO];
                        }
                    }
                }else{
                    if (_isFoucePixel) {
                        _confimCount = 0;
                    }
                }
            }
        }else{
            _confimCount = 0;
            _aLensPosition = _isIOS8AndFoucePixelLensPosition;
            
        }
    }
    
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}

#pragma mark - 识别
// 找边成功开始识别
-(void)readyToRecog
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
    NSString *caches = paths[0];
    NSString *imagepath = [caches stringByAppendingPathComponent:@"image.jpg"];
    NSString *headImagePath = [caches stringByAppendingPathComponent:@"head.jpg"];
    
    if (self.recogType == 3000) {
        //识别机读码
        int recog = [self.cardRecog recogIDCardWithMainID:_mrzType];
        NSLog(@"recog:%d",recog);
    }else if(self.recogType == 2){
        
        //自动判断二代证正反面
        int sum = [self.cardRecog autoRecogChineseID];
        NSLog(@"sum = %d", sum);
    }else{
        //识别非机读码证件
        int recog = [self.cardRecog recogIDCardWithMainID:self.recogType];
        NSLog(@"recog:%d",recog);
    }
    
    //获取识别结果
    NSString *allResult = @"";
    NSMutableDictionary * resultDic = [NSMutableDictionary dictionary];
    if (self.recogType != 3000) {
        //将裁切好的头像保存到headImagePath
        int save =[self. cardRecog saveHeaderImage:headImagePath];
        NSLog(@"save头像 = %d", save);
        for (int i = 1; i < 12; i++) {
            //获取字段值
            NSString *field = [self.cardRecog GetFieldNameWithIndex:i];
            //获取字段结果
            NSString *result = [self.cardRecog GetRecogResultWithIndex:i];
            if (result.length) {
                [resultDic setObject:result forKey:field];
                NSLog(@"%@:%@\n",field, result);
            }
            
            
            if(field != NULL){
                allResult = [allResult stringByAppendingString:[NSString stringWithFormat:@"%@:%@\n", field, result]];
            }
        }
    }else{
        int mrzCount = _mrzType == 1033 ?4:3;
        for (int i=1; i<mrzCount; i++) {
            NSString *result = [self.cardRecog GetRecogResultWithIndex:i];
            if (result!= nil || result != NULL) {
                allResult = [allResult stringByAppendingString:[NSString stringWithFormat:@"%@\n", result]];
                
            }else{
                break;
            }
        }
        _mrzType = 0;
    }
    
    if (![allResult isEqualToString:@""]) {
        
        //将裁切好的全幅面保存到imagepath里
        int save = [self.cardRecog saveImage:imagepath];
        NSLog(@"save裁切图 = %d", save);
        
//        NSData * imageData = [NSData dataWithContentsOfFile:imagepath];
//        UIImage * resultImage = [UIImage imageWithData:imageData];
//        //添加水印
//        NSMutableDictionary *dic = [[NSMutableDictionary alloc]init];
//        [dic setValue:[CommonFun getDateStringWithType:DateTypeNormal] forKey:@"time"];
//        [dic setValue:ApplicationDelegate.caseLocation forKey:@"place"];
//        resultImage = [CommonFun addWaterMarkDic:dic toImage:resultImage];
//
//        [resultImage setValue:resultImage forKey:@"resultImage"];
        
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
        //识别结果不为空，跳转到结果展示页面
//        ResultViewController *rvc = [[ResultViewController alloc] initWithNibName:@"ResultViewController" bundle:nil];
        NSLog(@"allresult = %@", allResult);
        
         NSLog(@"resultDic = %@", resultDic);
//        rvc.resultString = allResult;
//        [self.navigationController pushViewController:rvc animated:YES];
        
//        [resultDic yy_modelSetWithJSON:[allResult yy_modelToJSONObject]];
//        
//        if ([self.typeName isEqualToString:@"身份证OCR识别"]) {
//            ConfirmIDViewController * page = [[ConfirmIDViewController alloc] initWithDictionary:resultDic];
//            page.info = _PayInfo;
//            
//            [self.navigationController pushViewController:page animated:YES];
//        }else if ([self.typeName isEqualToString:@"中国驾照"]){
//            DriPhotoConfirmViewController *vc = [[DriPhotoConfirmViewController alloc] initWithDictionary:resultDic];
//
//            vc.photoType = @"确认驾驶证信息";
//            vc.info = _info;
//            [self.navigationController pushViewController:vc animated:NO];
//
//        }else if ([self.typeName isEqualToString:@"中国行驶证"]){
//            DriPhotoConfirmViewController *vc = [[DriPhotoConfirmViewController alloc] initWithDictionary:resultDic];
//            
//            vc.photoType = @"确认行驶证信息";
//            vc.info = _info;
//            [self.navigationController pushViewController:vc animated:NO];
//
//        }else if ([self.typeName isEqualToString:@"身份证背面扫描"]){
//            ConfirmIDBackViewController * page1 = [[ConfirmIDBackViewController alloc] init];
//            [self.navigationController pushViewController:page1 animated:YES];
//        }
        
    }else{
        //识别结果为空，重新识别
        [_session startRunning];
    }
}

//获取摄像头位置
- (AVCaptureDevice *)cameraWithPosition:(AVCaptureDevicePosition)position
{
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in devices)
    {
        if (device.position == position)
        {
            return device;
        }
    }
    return nil;
}

//对焦
- (void)fouceMode{
    NSError *error;
    AVCaptureDevice *device = [self cameraWithPosition:AVCaptureDevicePositionBack];
    if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
    {
        if ([device lockForConfiguration:&error]) {
            CGPoint cameraPoint = [self.preview captureDevicePointOfInterestForPoint:self.view.center];
            [device setFocusPointOfInterest:cameraPoint];
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
            [device unlockForConfiguration];
        } else {
            NSLog(@"Error: %@", error);
        }
    }
}

#pragma mark - ButtonAction
//返回按钮按钮点击事件
- (void)backAction{
    [self.navigationController popViewControllerAnimated:YES];
}

//闪光灯按钮点击事件
- (void)flashBtn{
    
    AVCaptureDevice *device = [self cameraWithPosition:AVCaptureDevicePositionBack];
    if (![device hasTorch]) {
        //        NSLog(@"no torch");
    }else{
        [device lockForConfiguration:nil];
        if (!_on) {
            [device setTorchMode: AVCaptureTorchModeOn];
            _on = YES;
        }
        else
        {
            [device setTorchMode: AVCaptureTorchModeOff];
            _on = NO;
        }
        [device unlockForConfiguration];
    }
}

//隐藏状态栏
- (UIStatusBarStyle)preferredStatusBarStyle{
    
    return UIStatusBarStyleDefault;
}

- (BOOL)prefersStatusBarHidden{
    
    return YES;
}

CG_INLINE CGRect
CGRectMakeBack(CGFloat x, CGFloat y, CGFloat width, CGFloat height)
{
    CGRect rect;
    
    if (kScreenHeight==480) {
        rect.origin.y = y-20;
        rect.origin.x = x;
        rect.size.width = width;
        rect.size.height = height;
    }else{
        rect.origin.x = x * kScreenWidth/320;
        rect.origin.y = y * kScreenHeight/568;
        rect.size.width = width * kScreenWidth/320;
        rect.size.height = height * kScreenHeight/568;
        
    }
    return rect;
}

CG_INLINE CGRect
CGRectMakeFlash(CGFloat x, CGFloat y, CGFloat width, CGFloat height)
{
    CGRect rect;
    
    if (kScreenHeight==480) {
        rect.origin.y = y-20;
        rect.origin.x = x;
        rect.size.width = width;
        rect.size.height = height;
    }else{
        rect.origin.x = x * kScreenWidth/320;
        rect.origin.y = y * kScreenHeight/568;
        rect.size.width = width * kScreenWidth/320;
        rect.size.height = height * kScreenHeight/568;
        
    }
    return rect;
}
#endif


/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */

- (BOOL)shouldAutorotate{
    return NO;
}




@end
