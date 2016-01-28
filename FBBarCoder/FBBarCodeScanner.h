//
//  FBBarCodeScanner.h
//  FBBarCoder
//
//  Created by 123 on 16/1/27.
//  Copyright © 2016年 com.pureLake. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>


typedef void (^scanResult)(NSArray* results);

typedef void (^authoResult)(BOOL grant);


@interface FBBarCodeScanner : NSObject


@property (nonatomic, assign) BOOL allowTapToFocus;


/**
 *  If set, only barcodes inside this area will be scanned.
 */
@property (nonatomic, assign) CGRect scanRect;

//
@property (nonatomic, copy) scanResult scanResultBlock;

@property (nonatomic, copy) authoResult authResult;






+ (void)requestCameraPermissionWithBlock:(authoResult)authResultBlock;


/**
 *  Initialize a scanner that will feed the camera input
 *  into the given UIView.
 *
 *  @param previewView View that will be overlayed with the live feed from the camera input.
 *
 *  @return An instance of MTBBarcodeScanner
 */
- (instancetype)initWithPreviewView:(UIView *)previewView;

/**
 *  Initialize a scanner that will feed the camera input
 *  into the given UIView. Only codes with a type given in
 *  the metaDataObjectTypes array will be reported to the result
 *  block when scanning is started using startScanningWithResultBlock:
 *
 *  @see startScanningWithResultBlock:
 *
 *  @param metaDataObjectTypes Array of AVMetadataObjectTypes to scan for. Only codes with types given in this array will be reported to the resultBlock.
 *  @param previewView View that will be overlayed with the live feed from the camera input.
 *
 *  @return An instance of MTBBarcodeScanner
 */
- (instancetype)initWithMetadataObjectTypes:(NSArray *)metaDataObjectTypes
                                previewView:(UIView *)previewView;





- (void)startScanningWithBlock:(scanResult)resultResultBlock;


- (void)stopScanning;

+ (BOOL)hasCamera;
+ (BOOL)cameraAvaliable;
- (void)flipCamera;


- (BOOL)hasTorch;
- (void)toggleTorch;



@end
