//
//  BankCardRecogPro.h
//  BankCardRecogPro
//
//  Created by wintone on 15/3/17.
//  Copyright (c) 2015年 wintone. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "BankSlideLine.h"
#import <UIKit/UIKit.h>

@interface BankCardRecogPro : NSObject

//授权
@property (nonatomic ,copy) NSString *nsResult;
@property (nonatomic ,copy) NSString *devcode;
@property (nonatomic ,copy) NSString *lpDirectory;

//识别结果
@property(copy, nonatomic) NSString *resultStr;
@property(strong, nonatomic) UIImage *resultImg;
@property(copy, nonatomic) NSString *bankName;
@property(copy, nonatomic) NSString *bankCode;
@property(copy, nonatomic) NSString *cardName;
@property(copy, nonatomic) NSString *cardType;

/*
 初始化核心,调用其他方法之前，必须调用此初始化，否则，其他函数调用无效
 devcode:开发码
 返回值：0-核心初始化成功；其他失败，具体失败原因参照开发手册
 */
-(int)InitBankCardWithDevcode:(NSString *)devcode;

/*
 设置感兴区域
 参数：检边区域在实际图像中到整张图片上、下、左、右的距离，与图像分辨率和检边区域frame有关，详见demo设置
 */
- (void) setRoiWithLeft:(int)nLeft Top:(int)nTop Right:(int)nRight Bottom:(int)nBottom;

/*
 检边识别接口
 参数：图像帧数据以及其宽高
 返回值：BankSlideLine有5个属性；leftLine、rightLine、topLine、bottomLine的值为1时检测到边，为0时未检测到边线；
        allLine-0表示识别成功，allLine-1表示检测到边未识别，allLine-2表示未检测到边线
 */
- (BankSlideLine *) RecognizeStreamNV21Ex:(UInt8 *)buffer Width:(int)width Height:(int)height;

/*
    根据银行卡号获取银行信息,cardNumber参数是内容为银行卡号的字符串；
    获取失败返回值为null，获取成功后银行信息保存在字典中；
    字典格式key值如下：
        bankCode = 机构代码;
        bankName = 银行名字
        cardNumber = 银行卡号
        cardType = 卡种
        cradName = 卡名
 */
- (NSDictionary *)getBankInfoWithCardNO:(NSString *)cardNumber;

/*释放核心*/
- (void) recogFree;
@end
