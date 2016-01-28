//
//  FBBarCodeGenerator.m
//  FBBarCoder
//
//  Created by 123 on 16/1/27.
//  Copyright © 2016年 com.pureLake. All rights reserved.
//

#import "FBBarCodeGenerator.h"
#import "qrencode.h"

typedef enum {
    QRPointRect = 0,
    QRPointRound
}QRPointType;

typedef enum {
    QRPositionNormal = 0,
    QRPositionRound
}QRPositionType;


enum {
    qr_margin = 3
};

@implementation FBBarCodeGenerator

+ (UIImage*)qrCodeWithContent:(NSString *)content size:(CGFloat)size thumb:(UIImage *)thumbImg color:(UIColor *)color {
    if (content.length == 0) {
        return nil;
    }
    
    QRcode *code = QRcode_encodeString([content UTF8String], 0, QR_ECLEVEL_L, QR_MODE_8, 1);
    if (!code) {
        return nil;
    }
    
    // create context
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(0, size, size, 8, size * 4, colorSpace, kCGImageAlphaPremultipliedLast);
    
    CGAffineTransform translateTransform = CGAffineTransformMakeTranslation(0, -size);
    CGAffineTransform scaleTransform = CGAffineTransformMakeScale(1, -1);
    CGContextConcatCTM(ctx, CGAffineTransformConcat(translateTransform, scaleTransform));
    
    // draw QR on this context
    [[self class] drawQRCode:code context:ctx size:size withPointType:0 withPositionType:0 withColor:color];
    
    // get image
    CGImageRef qrCGImage = CGBitmapContextCreateImage(ctx);
    UIImage * qrImage = [UIImage imageWithCGImage:qrCGImage];
    
    if(thumbImg)
    {
        UIGraphicsBeginImageContext(qrImage.size);
        
        //Draw image2
        [qrImage drawInRect:CGRectMake(0, 0, qrImage.size.width, qrImage.size.height)];
        
        //Draw image1
        float r=qrImage.size.width*35/240;
        [thumbImg drawInRect:CGRectMake((qrImage.size.width-r)/2, (qrImage.size.height-r)/2 ,r, r)];
        
        qrImage=UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
    }
    
    // some releases
    CGContextRelease(ctx);
    CGImageRelease(qrCGImage);
    CGColorSpaceRelease(colorSpace);
    QRcode_free(code);
    
    return qrImage;
}


+ (void)drawQRCode:(QRcode *)code context:(CGContextRef)ctx size:(CGFloat)size withPointType:(QRPointType)pointType withPositionType:(QRPositionType)positionType withColor:(UIColor *)color {
    unsigned char *data = 0;
    int width;
    data = code->data;
    width = code->width;
    float zoom = (double)size / (code->width + 2.0 * qr_margin);
    CGRect rectDraw = CGRectMake(0, 0, zoom, zoom);
    
    // draw
    const CGFloat *components;
    if (color) {
        components = CGColorGetComponents(color.CGColor);
    }else {
        components = CGColorGetComponents([UIColor blackColor].CGColor);
    }
    CGContextSetRGBFillColor(ctx, components[0], components[1], components[2], 1.0);
//    NSLog(@"aad :%f  bbd :%f   ccd:%f",components[0],components[1],components[2]);
    
    for(int i = 0; i < width; ++i) {
        for(int j = 0; j < width; ++j) {
            if(*data & 1) {
                rectDraw.origin = CGPointMake((j + qr_margin) * zoom,(i + qr_margin) * zoom);
                if (positionType == QRPositionNormal) {
                    switch (pointType) {
                        case QRPointRect:
                            CGContextAddRect(ctx, rectDraw);
                            break;
                        case QRPointRound:
                            CGContextAddEllipseInRect(ctx, rectDraw);
                            break;
                        default:
                            break;
                    }
                }else if(positionType == QRPositionRound) {
                    switch (pointType) {
                        case QRPointRect:
                            CGContextAddRect(ctx, rectDraw);
                            break;
                        case QRPointRound:
                            if ((i>=0 && i<=6 && j>=0 && j<=6) || (i>=0 && i<=6 && j>=width-7-1 && j<=width-1) || (i>=width-7-1 && i<=width-1 && j>=0 && j<=6)) {
                                CGContextAddRect(ctx, rectDraw);
                            }else {
                                CGContextAddEllipseInRect(ctx, rectDraw);
                            }
                            break;
                        default:
                            break;
                    }
                }
            }
            ++data;
        }
    }
    CGContextFillPath(ctx);
}


@end
