//
//  OverView.m
//  TestCamera
//
//  Created by wintone on 14/11/25.
//  Copyright (c) 2014年 zzzili. All rights reserved.
//

#import "WTOverView.h"
#import <CoreText/CoreText.h>

//屏幕的宽、高
#define kScreenWidth  [UIScreen mainScreen].bounds.size.width
#define kScreenHeight [UIScreen mainScreen].bounds.size.height

@implementation WTOverView{
    
    /*以下坐标点为横屏时，检边框四个顶点位置命名*/
    CGPoint ldown; //检边框左下角点
    CGPoint rdown; //检边框右下角点
    CGPoint lup; //检边框左上角点
    CGPoint rup; //检边框右上角点
    
    CGRect pointRect; //提示文字frame
    CGRect logoRect; //文通logo文字frame
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
        /*
         sRect 为检边框的frame，检边框的位置和大小都可以随意设置，不需其他设置均可识别
         注意：检边框的宽高比例要符合银行卡实际宽高比，银行卡的 高/宽 = 1.58
         以下是demo对检边框frame的设置，仅供参考.
         */
        CGRect sRect = CGRectMake(45, 100, 230, 230*1.55);//以苹果5屏幕大小为模板设置sRect
        CGFloat fValue = 15.0;
        if (kScreenHeight == 480)
        {//苹果4屏幕上sRect
            sRect = CGRectMake(CGRectGetMinX(sRect), CGRectGetMinY(sRect)-44, CGRectGetWidth(sRect), CGRectGetHeight(sRect));
        }else
        {//大屏幕在苹果5屏幕基础上等比例放大sRect
            CGFloat scale = kScreenWidth/320;
            sRect = CGRectMake(CGRectGetMinX(sRect)*scale, CGRectGetMinY(sRect)*scale, CGRectGetWidth(sRect)*scale, CGRectGetHeight(sRect)*scale);
            fValue = 17.0;
        }
        
        ldown = CGPointMake(CGRectGetMinX(sRect), CGRectGetMinY(sRect));
        lup  = CGPointMake(CGRectGetMaxX(sRect), CGRectGetMinY(sRect));
        rdown = CGPointMake(CGRectGetMinX(sRect), CGRectGetMaxY(sRect));
        rup = CGPointMake(CGRectGetMaxX(sRect), CGRectGetMaxY(sRect));
        self.smallrect = sRect;
        
        UILabel *pointL = [[UILabel alloc]initWithFrame:CGRectMake(0, 0, CGRectGetHeight(sRect), CGRectGetWidth(sRect))];
        pointL.text = @"请将银行卡正面置于此区域,尝试对齐边缘";
        pointL.font = [UIFont boldSystemFontOfSize:fValue];
        pointL.textColor = [UIColor whiteColor];
        pointL.textAlignment = NSTextAlignmentCenter;
        pointL.transform = CGAffineTransformMakeRotation(M_PI_2);
        pointL.center = CGPointMake(CGRectGetMidX(sRect), CGRectGetMidY(sRect));
        [self addSubview:pointL];
    }
    return self;
}


- (void) drawRect:(CGRect)rect
{
    [super drawRect:rect];
    
    [[UIColor greenColor] set];
    //获得当前画布区域
    CGContextRef currentContext = UIGraphicsGetCurrentContext();
    //设置线的宽度
    CGContextSetLineWidth(currentContext, 2.0f);
    
    //检边框四角宽度
    int s = 25;
    /*画线*/
    //起点--左下角
    CGContextMoveToPoint(currentContext,ldown.x, ldown.y+s);
    CGContextAddLineToPoint(currentContext, ldown.x, ldown.y);
    CGContextAddLineToPoint(currentContext, ldown.x+s, ldown.y);
    
    //右下角
    CGContextMoveToPoint(currentContext, rdown.x,rdown.y-s);
    CGContextAddLineToPoint(currentContext, rdown.x,rdown.y);
    CGContextAddLineToPoint(currentContext, rdown.x+s,rdown.y);
    
    //左上角
    CGContextMoveToPoint(currentContext, lup.x-s,lup.y);
    CGContextAddLineToPoint(currentContext, lup.x,lup.y);
    CGContextAddLineToPoint(currentContext, lup.x,lup.y+s);
    
    //右上角
    CGContextMoveToPoint(currentContext, rup.x, rup.y-s);
    CGContextAddLineToPoint(currentContext, rup.x, rup.y);
    CGContextAddLineToPoint(currentContext, rup.x-s, rup.y);
    
    //四条线
    if (!_leftHidden) {
        CGContextMoveToPoint(currentContext, ldown.x+s, ldown.y);
        CGContextAddLineToPoint(currentContext, lup.x-s,lup.y);
    }
    if (!_rightHidden) {
        CGContextMoveToPoint(currentContext, rdown.x+s,rdown.y);
        CGContextAddLineToPoint(currentContext, rup.x-s, rup.y);
    }
    
    if (!_topHidden) {
        CGContextMoveToPoint(currentContext, lup.x,lup.y+s);
        CGContextAddLineToPoint(currentContext, rup.x, rup.y-s);
    }
    if (!_bottomHidden) {
        CGContextMoveToPoint(currentContext, ldown.x, ldown.y+s);
        CGContextAddLineToPoint(currentContext, rdown.x,rdown.y-s);
    }
    CGContextStrokePath(currentContext);
}

/*
 设置四条线的显隐
 */
- (void) setTopHidden:(BOOL)topHidden
{
    if (_topHidden == topHidden) {
        return;
    }
    _topHidden = topHidden;
    [self setNeedsDisplay];
}

- (void) setLeftHidden:(BOOL)leftHidden
{
    if (_leftHidden == leftHidden) {
        return;
    }
    _leftHidden = leftHidden;
    [self setNeedsDisplay];
}

- (void) setBottomHidden:(BOOL)bottomHidden
{
    if (_bottomHidden == bottomHidden) {
        return;
    }
    _bottomHidden = bottomHidden;
    [self setNeedsDisplay];
}

- (void) setRightHidden:(BOOL)rightHidden
{
    if (_rightHidden == rightHidden) {
        return;
    }
    _rightHidden = rightHidden;
    [self setNeedsDisplay];
}

/*
 // Only override drawRect: if you perform custom drawing.
 // An empty implementation adversely affects performance during animation.
 - (void)drawRect:(CGRect)rect {
 // Drawing code
 }
 */

@end
