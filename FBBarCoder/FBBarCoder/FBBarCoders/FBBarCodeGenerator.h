//
//  FBBarCodeGenerator.h
//  FBBarCoder
//
//  Created by 123 on 16/1/27.
//  Copyright © 2016年 com.pureLake. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>

@interface FBBarCodeGenerator : NSObject

+ (UIImage*)qrCodeWithContent:(NSString*)content size:(CGFloat)size thumb:(UIImage*)thumbImg color:(UIColor*)color;

@end
