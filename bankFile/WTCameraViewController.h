//
//  CameraViewController.h
//  BankCardRecog
//
//  Created by wintone on 15/1/22.
//  Copyright (c) 2015年 wintone. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMedia/CoreMedia.h>

@class WTCameraViewController;
@protocol WTCameraDelegate <NSObject>

@required
//银行卡识别核心初始化结果，判断核心是否初始化成功
- (void)initBankCardRecWithResult:(int)nInit;

//拍照和识别成功后返回结果图片、识别结果
- (void)cameraViewController:(WTCameraViewController *)cameraVC resultImage:(UIImage *)image resultDictionary:(NSDictionary *)resultDic;

//返回按钮被点击时回调此方法，返回相机视图控制器
- (void)backWithCameraViewController:(WTCameraViewController *)cameraVC;

//点击UIAlertView时返回相机视图控制器
- (void)clickAlertViewWithCameraViewController:(WTCameraViewController *)cameraVC;

@optional
//相机视图将要显示时回调此方法，返回相机视图控制器
- (void)viewWillAppearWithCameraViewController:(WTCameraViewController *)cameraVC;

//相机视图已经显示时回调此方法，返回相机视图控制器
- (void)viewDidAppearWithCameraViewController:(WTCameraViewController *)cameraVC;

//相机视图将要消失时回调此方法，返回相机视图控制器
- (void)viewWillDisappearWithCameraViewController:(WTCameraViewController *)cameraVC;

//相机视图已经消失时回调此方法，返回相机视图控制器
- (void)viewDidDisappearWithCameraViewController:(WTCameraViewController *)cameraVC;

@end

@interface WTCameraViewController : UIViewController
@property (weak, nonatomic) id<WTCameraDelegate>delegate;
@property (copy, nonatomic) NSString *devcode; //开发码

//@property (nonatomic,weak) PayeInfo * bankInfo; //银行卡信息
@end
