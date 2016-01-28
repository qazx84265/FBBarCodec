//
//  FBBarCodeScanViewController.h
//  FBBarCoder
//
//  Created by 123 on 16/1/27.
//  Copyright © 2016年 com.pureLake. All rights reserved.
//

#import <UIKit/UIKit.h>


typedef NS_ENUM(NSUInteger, ScanAnimationType) {
    ScanAnimationTypeLine = 1,
    ScanAnimationTypeGrid
};

@interface FBBarCodeScanViewController : UIViewController

@property (nonatomic, assign) ScanAnimationType scanAnimationType;

@end
