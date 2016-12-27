//
//  WTCameraViewController.m
//  WTCardRecogDemo
//
//  Created by wintone on 15/1/22.
//  Copyright (c) 2015年 wintone. All rights reserved.
//

#import "WTCameraViewController.h"
#import "WTOverView.h"
#import "BankSlideLine.h"
#import "BankCardRecogPro.h"
//#import "ConfirmBankViewController.h"
//屏幕的宽、高
#define kScreenWidth  [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height
#define kAutoSizeScale ([UIScreen mainScreen].bounds.size.height/568.0)

@interface WTCameraViewController ()<UIAlertViewDelegate,AVCaptureVideoDataOutputSampleBufferDelegate>{
    AVCaptureSession *_session;
    AVCaptureDeviceInput *_captureInput;
    AVCaptureStillImageOutput *_captureOutput;
    AVCaptureVideoPreviewLayer *_preview;
    AVCaptureDevice *_device;
    UIView* m_highlitView[100];
    CGAffineTransform m_transform[100];
    
    BankCardRecogPro *_cardRecog;
    WTOverView *_overView; //检边视图
    NSTimer *_timer; //定时器
    BOOL _on; //闪光灯状态
    BOOL _isAlertShow;//是否弹出提示
    BOOL _capture;//导航栏动画是否完成
    BOOL _isFoucePixel;//是否相位对焦
    CGRect _imgRect;//拍照裁剪
    int _count;//每几帧识别
    CGFloat _isLensChanged;//镜头位置
    
    /*相位聚焦下镜头位置 镜头晃动 值不停的改变 */
    CGFloat _isIOS8AndFoucePixelLensPosition;

    /*
     控制识别速度，最小值为1！数值越大识别越慢。
     相机初始化时，设置默认值为1（不要改动），判断设备若为相位对焦时，设置此值为2（可以修改，最小为1，越大越慢）
     此值的功能是为了减小相位对焦下，因识别速度过快，在银行卡放入检边框移动过程中识别，导致出现识别后裁剪出的图片模糊的概率
     此值在相机初始化中设置，在相机代理中使用，用户若无特殊需求不用修改。
     */
    int _MaxFR;
    
    
}
@property (assign, nonatomic) BOOL adjustingFocus;
@property (nonatomic, retain) CALayer *customLayer;
@property (nonatomic,assign) BOOL isProcessingImage;
@end

@implementation WTCameraViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.view.backgroundColor = [UIColor clearColor];
    
    //初始化识别核心
    [self performSelectorInBackground:@selector(initRecog) withObject:nil];
    
    //初始化相机
    [self initialize];
    
    //创建相机界面控件
    [self createCameraView];
}

- (void) viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
     self.navigationController.navigationBarHidden = YES;
    _cardRecog.resultStr = @"";
    _cardRecog.bankCode = @"";
    _cardRecog.bankName = @"";
    _cardRecog.cardType = @"";
    _cardRecog.cardName = @"";
    
    _capture = NO;
    [self performSelector:@selector(changeCapture) withObject:nil afterDelay:0.4];
    //反差对焦 定时器 开启连续对焦
    if (!_isFoucePixel) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.2 target:self selector:@selector(fouceMode) userInfo:nil repeats:YES];
        //NSLog(@"非相位对焦");
    }
    
    AVCaptureDevice*camDevice =[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    int flags =NSKeyValueObservingOptionNew;
    //注册通知
    [camDevice addObserver:self forKeyPath:@"adjustingFocus" options:flags context:nil];
    if (_isFoucePixel) {
        [camDevice addObserver:self forKeyPath:@"lensPosition" options:flags context:nil];
    }
    [_session startRunning];
    
    //初始化识别核心 代理对象返回初始化参数
    int init = [_cardRecog InitBankCardWithDevcode:self.devcode];
    if ([self.delegate respondsToSelector:@selector(initBankCardRecWithResult:)]) {
        [self.delegate initBankCardRecWithResult:init];
    }
    if (init != 0) {
        if (_isAlertShow == NO) {
            [_session stopRunning];
            NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
            NSArray * allLanguages = [defaults objectForKey:@"AppleLanguages"];
            NSString * preferredLang = [allLanguages objectAtIndex:0];
            if (![preferredLang isEqualToString:@"zh-Hans"] && ![preferredLang isEqualToString:@"zh-Hans-CN"]) {
                NSString *initStr = [NSString stringWithFormat:@"Error code:%d",init];
                UIAlertView *alertV = [[UIAlertView alloc]initWithTitle:@"Tips" message:initStr delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [alertV show];
            }else{
                NSString *initStr = [NSString stringWithFormat:@"初始化失败错误编码:%d",init];
                UIAlertView *alertV = [[UIAlertView alloc]initWithTitle:@"提示" message:initStr delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
                [alertV show];
            }
        }
    }
    
    UIButton *upBtn = (UIButton *)[self.view viewWithTag:1001];
    upBtn.hidden = NO;
    
    //代理对象事项协议返回相机控制器
    if ([self.delegate respondsToSelector:@selector(viewWillAppearWithCameraViewController:)]) {
        [self.delegate viewWillAppearWithCameraViewController:self];
    }
}

- (void) viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    //代理对象事项协议返回相机控制器
    if ([self.delegate respondsToSelector:@selector(viewDidAppearWithCameraViewController:)]) {
        [self.delegate viewDidAppearWithCameraViewController:self];
    }
}

- (void) viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    //代理对象事项协议返回相机控制器
    if ([self.delegate respondsToSelector:@selector(viewWillDisappearWithCameraViewController:)]) {
        [self.delegate viewWillDisappearWithCameraViewController:self];
    }
}

- (void) viewDidDisappear:(BOOL)animated{
    [super viewDidDisappear:animated];
    
    //关闭定时器
    if (!_isFoucePixel) {
        [_timer invalidate];
        _timer = nil;
    }
    AVCaptureDevice*camDevice =[AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [camDevice removeObserver:self forKeyPath:@"adjustingFocus"];
    if (_isFoucePixel) {
        [camDevice removeObserver:self forKeyPath:@"lensPosition"];
    }
    [_session stopRunning];
    [[AVAudioSession sharedInstance] setActive:false error:nil];
    //隐藏四条边框
    [_overView setLeftHidden:YES];
    [_overView setRightHidden:YES];
    [_overView setBottomHidden:YES];
    [_overView setTopHidden:YES];
    _capture = NO;
    [_cardRecog recogFree];
    
    UIButton *photoBtn = (UIButton *)[self.view viewWithTag:1000];
    photoBtn.hidden = YES;
    //代理对象事项协议返回相机控制器
    if ([self.delegate respondsToSelector:@selector(viewDidDisappearWithCameraViewController:)]) {
        [self.delegate viewDidDisappearWithCameraViewController:self];
    }
}

//设置延迟。4秒  防止导航栏动画未完成时识别成功push下一控制器引起崩溃
- (void) changeCapture
{
    _capture = YES;
}

//初始化识别核心
- (void) initRecog
{
    _cardRecog = [[BankCardRecogPro alloc] init];
}

//监听对焦
-(void)observeValueForKeyPath:(NSString*)keyPath ofObject:(id)object change:(NSDictionary*)change context:(void*)context {
    
    /*反差对焦 监听反差对焦此*/
    if([keyPath isEqualToString:@"adjustingFocus"]){
        self.adjustingFocus =[[change objectForKey:NSKeyValueChangeNewKey] isEqualToNumber:[NSNumber numberWithInt:1]];
    }
    /*监听相位对焦此*/
    if([keyPath isEqualToString:@"lensPosition"]){
        _isIOS8AndFoucePixelLensPosition =[[change objectForKey:NSKeyValueChangeNewKey] floatValue];
        //NSLog(@"监听_isIOS8AndFoucePixelLensPosition == %f",_isIOS8AndFoucePixelLensPosition);
    }
}

//初始化
- (void) initialize
{
    //判断摄像头授权
    _isAlertShow = NO;
    NSString *mediaType = AVMediaTypeVideo;
    AVAuthorizationStatus authStatus = [AVCaptureDevice authorizationStatusForMediaType:mediaType];
    if(authStatus == AVAuthorizationStatusRestricted || authStatus == AVAuthorizationStatusDenied){
        NSUserDefaults * defaults = [NSUserDefaults standardUserDefaults];
        NSArray * allLanguages = [defaults objectForKey:@"AppleLanguages"];
        NSString * preferredLang = [allLanguages objectAtIndex:0];
        NSLog(@"%@",preferredLang);
        if (![preferredLang isEqualToString:@"zh-Hans"] && ![preferredLang isEqualToString:@"zh-Hans-CN"]) {
            UIAlertView * alt = [[UIAlertView alloc] initWithTitle:@"Please allow to access your device’s camera in “Settings”-“Privacy”-“Camera”" message:@"" delegate:self cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
            [alt show];
        }else{
            UIAlertView * alt = [[UIAlertView alloc] initWithTitle:@"未获得授权使用摄像头" message:@"请在iOS '设置中-隐私-相机' 中打开" delegate:self cancelButtonTitle:nil otherButtonTitles:@"知道了", nil];
            [alt show];
        }
        _isAlertShow = YES;
        return;
    }
    
    _MaxFR = 1;
    //1.创建会话层
    _session = [[AVCaptureSession alloc] init];
    [_session setSessionPreset:AVCaptureSessionPreset1280x720];
    
    //2.创建、配置输入设备
    NSArray *devices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    
    for (AVCaptureDevice *device in devices)
    {
        if (device.position == AVCaptureDevicePositionBack){
            _device = device;
            _captureInput = [AVCaptureDeviceInput deviceInputWithDevice:device error:nil];
        }
    }
    [_session addInput:_captureInput];
    
    ///out put
    AVCaptureVideoDataOutput *captureOutput = [[AVCaptureVideoDataOutput alloc]
                                               init];
    captureOutput.alwaysDiscardsLateVideoFrames = YES;
    
    dispatch_queue_t queue;
    queue = dispatch_queue_create("cameraQueue", NULL);
    [captureOutput setSampleBufferDelegate:self queue:queue];
    NSString* key = (NSString*)kCVPixelBufferPixelFormatTypeKey;
    NSNumber* value = [NSNumber
                       numberWithUnsignedInt:kCVPixelFormatType_32BGRA];
    NSDictionary* videoSettings = [NSDictionary
                                   dictionaryWithObject:value forKey:key];
    [captureOutput setVideoSettings:videoSettings];
    [_session addOutput:captureOutput];
    
    //3.创建、配置输出
    _captureOutput = [[AVCaptureStillImageOutput alloc] init];
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
    [_captureOutput setOutputSettings:outputSettings];
    [_session addOutput:_captureOutput];
    
    _preview = [AVCaptureVideoPreviewLayer layerWithSession: _session];
    _preview.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    _preview.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [self.view.layer addSublayer:_preview];
    [_session startRunning];
    
    //设置覆盖层
    CAShapeLayer *maskWithHole = [CAShapeLayer layer];
    // Both frames are defined in the same coordinate system
    CGRect biggerRect = self.view.bounds;
    CGFloat offset = 1.0f;
    if ([[UIScreen mainScreen] scale] >= 2) {
        offset = 0.5;
    }
    
    //设置检边视图层
    if (!_overView) {
        _overView = [[WTOverView alloc] initWithFrame:self.view.bounds];
    }
    CGRect smallFrame = _overView.smallrect;
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
    [maskWithHole setPath:[maskPath CGPath]];
    [maskWithHole setFillRule:kCAFillRuleEvenOdd];
    [maskWithHole setFillColor:[[UIColor colorWithWhite:0 alpha:0.35] CGColor]];
    [self.view.layer addSublayer:maskWithHole];
    [self.view.layer setMasksToBounds:YES];
    _overView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_overView];
    
    //判断是否相位对焦
    if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8.0) {
        AVCaptureDeviceFormat *deviceFormat = _device.activeFormat;
        if (deviceFormat.autoFocusSystem == AVCaptureAutoFocusSystemPhaseDetection){
            _isFoucePixel = YES;
            _MaxFR = 2;
        }
    }
    
    //隐藏四条边框
    [_overView setLeftHidden:YES];
    [_overView setRightHidden:YES];
    [_overView setBottomHidden:YES];
    [_overView setTopHidden:YES];
    
    CGRect rect = _overView.smallrect;
    if (kScreenHeight == 480) {
        rect = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect)+44, CGRectGetWidth(rect), CGRectGetHeight(rect));
    }
    //720为当前分辨率(1280*720)中的宽
    CGFloat scale = 720/kScreenWidth;
    int sTop = (kScreenWidth - CGRectGetMaxX(rect))*scale;
    int sBottom = (kScreenWidth - CGRectGetMinX(rect))*scale;
    int sLeft = CGRectGetMinY(rect)*scale;
    int sRight = (CGRectGetMinY(rect) + CGRectGetHeight(rect))*scale;
    //设置扫描检边参数
    [_cardRecog setRoiWithLeft:sLeft Top:sTop Right:sRight Bottom:sBottom];//图像分辨率1280*720
    
    //设置拍照裁切frame
    CGFloat x = CGRectGetMinY(rect)*scale;
    CGFloat y = (kScreenWidth - CGRectGetMaxX(rect))*scale;
    CGFloat w = rect.size.height*scale;
    CGFloat h = rect.size.width*scale;
    _imgRect = CGRectMake(x, y, w, h);
}
//手动拍照
-(void)captureimage
{
    //将处理图片状态值置为YES
    self.isProcessingImage = YES;
    //get connection
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in _captureOutput.connections) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) { break; }
    }
    
    //get UIImage
    [_captureOutput captureStillImageAsynchronouslyFromConnection:videoConnection completionHandler:
     ^(CMSampleBufferRef imageSampleBuffer, NSError *error) {
         if (imageSampleBuffer != NULL) {
             //停止取景
             [_session stopRunning];
             
             NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
             //NSLog(@"开始生成图片");
             UIImage *tempImage = [[UIImage alloc] initWithData:imageData];
             UIImage *finalImage = [UIImage imageWithCGImage:tempImage.CGImage scale:0.5 orientation:UIImageOrientationUp];
             
             //裁剪图片
             CGImageRef imageRef = finalImage.CGImage;
             CGImageRef subImageRef = CGImageCreateWithImageInRect(imageRef, _imgRect);
             UIGraphicsBeginImageContext(_imgRect.size);
             CGContextRef context = UIGraphicsGetCurrentContext();
             CGContextDrawImage(context, _imgRect, subImageRef);
             UIImage *thumbScale = [UIImage imageWithCGImage:subImageRef];
             UIGraphicsEndImageContext();
             CGImageRelease(subImageRef);
             
             [self performSelectorOnMainThread:@selector(readyToGetImage:) withObject:thumbScale waitUntilDone:NO];
             //将处理图片状态值置为NO
             self.isProcessingImage = NO;
         }
     }];
}

//从摄像头缓冲区获取图像
#pragma mark -
#pragma mark AVCaptureSession delegate
- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(imageBuffer,0);
    uint8_t *baseAddress = (uint8_t *)CVPixelBufferGetBaseAddress(imageBuffer);
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    //NSLog(@"每一帧 == %f",_isIOS8AndFoucePixelLensPosition);
    //检边识别
    if (_capture == YES) { //导航栏动画完成
        if (self.isProcessingImage==NO) {  //点击拍照后 不去识别
            if (!self.adjustingFocus) {  //反差对焦下 非正在对焦状态（相位对焦下self.adjustingFocus此值不会改变）
                if (_isLensChanged == _isIOS8AndFoucePixelLensPosition) {
                    _count++;
                    if (_count == _MaxFR) {
                        BankSlideLine *sliderLine = [_cardRecog RecognizeStreamNV21Ex:baseAddress Width:(int)width Height:(int)height];
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [_overView setLeftHidden:!sliderLine.leftLine];
                            [_overView setRightHidden:!sliderLine.rightLine];
                            [_overView setBottomHidden:!sliderLine.bottomLine];
                            [_overView setTopHidden:!sliderLine.topLine];
                        });
                        if (sliderLine.allLine == 0 ) //检到边 识别成功
                        {
                            _count = 0;
                            
                            // 停止取景
                            [_session stopRunning];
                            
                            //设置震动
                            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                            UIImage * bankImage = [self imageFromSampleBuffer:sampleBuffer];
                            
                            [self performSelectorOnMainThread:@selector(readyToGetImage:) withObject:bankImage waitUntilDone:NO];
                      
                        
                        }else if (sliderLine.allLine == 1 ){ //检到边 未识别
                            _count--;
                        }else{
                            _count = 0;
                        }
                    }
                }else{
                    _isLensChanged = _isIOS8AndFoucePixelLensPosition;
                    _count = 0;
                }
            }
        }
    }
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
}

//找边成功开始拍照
-(void)readyToGetImage:(UIImage *)image
{
    //添加水印
    NSMutableDictionary *dic = [[NSMutableDictionary alloc]init];
//    [dic setValue:[CommonFun getDateStringWithType:DateTypeNormal] forKey:@"time"];
//    [dic setValue:ApplicationDelegate.caseLocation forKey:@"place"];
//    image = [CommonFun addWaterMarkDic:dic toImage:image];
    
    //代理对象实现协议方法返回结果
    NSDictionary *resultDic = @{
                                @"cardNumber":_cardRecog.resultStr,
                                @"bankName":_cardRecog.bankName,
                                @"bankCode":_cardRecog.bankCode,
                                @"cardName":_cardRecog.cardName,
                                @"cardType":_cardRecog.cardType,
                                @"bankImage": image
                                };
//    if ([self.delegate respondsToSelector:@selector(cameraViewController:resultImage:resultDictionary:)]) {
//        [self.delegate cameraViewController:self resultImage:image resultDictionary:resultDic];
//    }


   
//    
//    ConfirmBankViewController * page = [[ConfirmBankViewController alloc] initWithDic:resultDic];
//    
//    
//    
//    page.info = _bankInfo;
//    [self.navigationController pushViewController:page animated:YES];
    
    if (_cardRecog.resultImg) {
        _cardRecog.resultImg = nil;
    }
}

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

- (void)createCameraView{
    
    //设置检边视图层
    if (!_overView) {
        _overView = [[WTOverView alloc] initWithFrame:self.view.bounds];
        //_overView.backgroundColor = [UIColor clearColor];
        [self.view addSubview:_overView];
        //隐藏四条边框
        [_overView setLeftHidden:YES];
        [_overView setRightHidden:YES];
        [_overView setBottomHidden:YES];
        [_overView setTopHidden:YES];
    }
    
    //返回、闪光灯按钮
    UIButton *backBtn = [[UIButton alloc]initWithFrame:CGRectMakeBack(23,30, 35, 35)];
    [backBtn addTarget:self action:@selector(backAction) forControlEvents:UIControlEventTouchUpInside];
    [backBtn setImage:[UIImage imageNamed:@"BundleForBankCard.bundle/back_camera_btn"] forState:UIControlStateNormal];
    backBtn.titleLabel.textAlignment = NSTextAlignmentLeft;
    [self.view addSubview:backBtn];
    
    UIButton *flashBtn = [[UIButton alloc]initWithFrame:CGRectMakeFlash(255+5+2,30, 35, 35)];
    [flashBtn setImage:[UIImage imageNamed:@"BundleForBankCard.bundle/flash_camera_btn"] forState:UIControlStateNormal];
    [flashBtn addTarget:self action:@selector(modeBtn) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:flashBtn];
    
    //拍照视图 上拉按钮 拍照按钮
    UIButton *upBtn = [[UIButton alloc]initWithFrame:CGRectMakeUp(100, 553, 120, 20)];
    upBtn.tag = 1001;
    [upBtn addTarget:self action:@selector(upBtn:) forControlEvents:UIControlEventTouchUpInside];
    [upBtn setImage:[UIImage imageNamed:@"BundleForBankCard.bundle/locker_btn_def"] forState:UIControlStateNormal];
    
    [self.view addSubview:upBtn];
    UIButton *photoBtn = [[UIButton alloc]initWithFrame:CGRectMakePhoto(130,495,60, 60)];
    photoBtn.tag = 1000;
    photoBtn.hidden = YES;
    [photoBtn setImage:[UIImage imageNamed:@"BundleForBankCard.bundle/take_pic_btn"] forState:UIControlStateNormal];
    [photoBtn addTarget:self action:@selector(photoBtn) forControlEvents:UIControlEventTouchUpInside];
    [photoBtn setTitleColor:[UIColor grayColor] forState:UIControlStateHighlighted];
    [self.view addSubview:photoBtn];
    
}

#pragma mark - ButtonAction
//返回按钮按钮点击事件
- (void)backAction{
    
    //代理对象实现协议返回相机控制器
    if ([self.delegate respondsToSelector:@selector(backWithCameraViewController:)]) {
        [self.delegate backWithCameraViewController:self];
    }
}

//闪光灯按钮点击事件
- (void)modeBtn{
    
    if (![_device hasTorch]) {
        //NSLog(@"no torch");
    }else{
        [_device lockForConfiguration:nil];
        if (!_on) {
            [_device setTorchMode: AVCaptureTorchModeOn];
            _on = YES;
        }
        else
        {
            [_device setTorchMode: AVCaptureTorchModeOff];
            _on = NO;
        }
        [_device unlockForConfiguration];
    }
    
}

//上拉按钮点击事件
- (void)upBtn:(UIButton *)upBtn{
    
    UIButton *photoBtn = (UIButton *)[self.view viewWithTag:1000];
    photoBtn.hidden = NO;
    upBtn.hidden = YES;
    
}

//拍照按钮点击事件
- (void)photoBtn{
    
    //识别后 不进行拍照
    if (!_cardRecog.resultImg) {
        [self captureimage];
    }
}

#pragma mark - UIAlertViewDelegate
- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    
    //代理对象事项协议返回相机控制器
    if ([self.delegate respondsToSelector:@selector(clickAlertViewWithCameraViewController:)]) {
        [self.delegate clickAlertViewWithCameraViewController:self];
    }
}

//隐藏状态栏
- (UIStatusBarStyle)preferredStatusBarStyle{
    
    return UIStatusBarStyleDefault;
}
- (BOOL)prefersStatusBarHidden{
    return YES;
}

//对焦
- (void)fouceMode{
    
    NSError *error;
    AVCaptureDevice *device = [self cameraWithPosition:AVCaptureDevicePositionBack];
    if ([device isFocusModeSupported:AVCaptureFocusModeAutoFocus])
    {
        if ([device lockForConfiguration:&error]) {
            CGPoint cameraPoint = [_preview captureDevicePointOfInterestForPoint:self.view.center];
            [device setFocusPointOfInterest:cameraPoint];
            [device setFocusMode:AVCaptureFocusModeAutoFocus];
            [device unlockForConfiguration];
        } else {
            //NSLog(@"Error: %@", error);
        }
    }
}

#pragma mark - 内联函数适配屏幕
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
        rect.origin.x = x * kAutoSizeScale;
        rect.origin.y = y * kAutoSizeScale;
        rect.size.width = width * kAutoSizeScale;
        rect.size.height = height * kAutoSizeScale;
        
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
        rect.origin.x = x * kAutoSizeScale;
        rect.origin.y = y * kAutoSizeScale;
        rect.size.width = width * kAutoSizeScale;
        rect.size.height = height * kAutoSizeScale;
        
    }
    return rect;
}
CG_INLINE CGRect
CGRectMakePhoto(CGFloat x, CGFloat y, CGFloat width, CGFloat height)
{
    CGRect rect;
    
    if (kScreenHeight==480) {
        rect.origin.y = y-(568-480)+10;
        rect.origin.x = x;
        rect.size.width = width;
        rect.size.height = height;
    }else{
        rect.origin.x = x * kAutoSizeScale;
        rect.origin.y = y * kAutoSizeScale;
        rect.size.width = width * kAutoSizeScale;
        rect.size.height = height * kAutoSizeScale;
        
    }
    return rect;
}

CG_INLINE CGRect
CGRectMakeUp(CGFloat x, CGFloat y, CGFloat width, CGFloat height)
{
    CGRect rect;
    
    if (kScreenHeight==480) {
        rect.origin.y = y-(568-480);
        rect.origin.x = x;
        rect.size.width = width;
        rect.size.height = height;
    }else{
        rect.origin.x = x * kAutoSizeScale;
        rect.origin.y = y * kAutoSizeScale;
        rect.size.width = width * kAutoSizeScale;
        rect.size.height = height * kAutoSizeScale;
        
    }
    return rect;
}
//数据帧转图片
- (UIImage *) imageFromSampleBuffer:(CMSampleBufferRef) sampleBuffer
{
    // Get a CMSampleBuffer's Core Video image buffer for the media data
    CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    // Lock the base address of the pixel buffer
    CVPixelBufferLockBaseAddress(imageBuffer, 0);
    
    // Get the number of bytes per row for the pixel buffer
    void *baseAddress = CVPixelBufferGetBaseAddress(imageBuffer);
    
    // Get the number of bytes per row for the pixel buffer
    size_t bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer);
    // Get the pixel buffer width and height
    size_t width = CVPixelBufferGetWidth(imageBuffer);
    size_t height = CVPixelBufferGetHeight(imageBuffer);
    
    // Create a device-dependent RGB color space
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    // Create a bitmap graphics context with the sample buffer data
    CGContextRef context = CGBitmapContextCreate(baseAddress, width, height, 8,
                                                 bytesPerRow, colorSpace, kCGBitmapByteOrder32Little | kCGImageAlphaPremultipliedFirst);
    // Create a Quartz image from the pixel data in the bitmap graphics context
    CGImageRef quartzImage = CGBitmapContextCreateImage(context);
    // Unlock the pixel buffer
    CVPixelBufferUnlockBaseAddress(imageBuffer,0);
    
    // Free up the context and color space
    CGContextRelease(context);
    CGColorSpaceRelease(colorSpace);
    
    // Create an image object from the Quartz image
    //UIImage *image = [UIImage imageWithCGImage:quartzImage];
    UIImage *image = [UIImage imageWithCGImage:quartzImage scale:1.0f orientation:UIImageOrientationUp];
    
    // Release the Quartz image
    CGImageRelease(quartzImage);
    
    //裁剪图片
    CGRect tempRect = _overView.smallrect;
    CGFloat scale = 720.0/kScreenWidth;
    CGFloat dValue = (kScreenWidth/720*1280-kScreenHeight)*scale*0.5;
    
    CGFloat y = (kScreenWidth - CGRectGetMaxX(tempRect))*scale;
    CGFloat x = CGRectGetMinY (tempRect)*scale+dValue;
    CGFloat w = tempRect.size.height*scale;
    CGFloat h = tempRect.size.width*scale;
    CGRect rect = CGRectMake(x, y, w, h);
    
    CGImageRef imageRef = image.CGImage;
    CGImageRef subImageRef = CGImageCreateWithImageInRect(imageRef, rect);
    UIGraphicsBeginImageContext(rect.size);
    CGContextRef context1 = UIGraphicsGetCurrentContext();
    CGContextDrawImage(context1, rect, subImageRef);
    UIImage *image1 = [UIImage imageWithCGImage:subImageRef];
    UIGraphicsEndImageContext();
    CGImageRelease(subImageRef);
    
    return (image1);
    
}



- (BOOL)shouldAutorotate{
    return NO;
}
/*
 #pragma mark - Navigation
 
 // In a storyboard-based application, you will often want to do a little preparation before navigation
 - (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
 // Get the new view controller using [segue destinationViewController].
 // Pass the selected object to the new view controller.
 }
 */


@end
