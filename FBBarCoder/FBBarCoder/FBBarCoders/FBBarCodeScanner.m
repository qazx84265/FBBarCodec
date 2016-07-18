//
//  FBBarCodeScanner.m
//  FBBarCoder
//
//  Created by 123 on 16/1/27.
//  Copyright © 2016年 com.pureLake. All rights reserved.
//

#import "FBBarCodeScanner.h"
@import AVFoundation;


@interface FBBarCodeScanner()<AVCaptureMetadataOutputObjectsDelegate>

/*!
 @property session
 @abstract
 The capture session used for scanning barcodes.
 */
@property (nonatomic, strong) AVCaptureSession *session;

/*!
 @property captureDevice
 @abstract
 Represents the physical device that is used for scanning barcodes.
 */
@property (nonatomic, strong) AVCaptureDevice *captureDevice;

/*!
 @property capturePreviewLayer
 @abstract
 The layer used to view the camera input. This layer is added to the
 previewView when scanning starts.
 */
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *capturePreviewLayer;

/*!
 @property currentCaptureDeviceInput
 @abstract
 The current capture device input for capturing video. This is used
 to reset the camera to its initial properties when scanning stops.
 */
@property (nonatomic, strong) AVCaptureDeviceInput *currentCaptureDeviceInput;

/*
 @property captureDeviceOnput
 @abstract
 The capture device output for capturing video.
 */
@property (nonatomic, strong) AVCaptureMetadataOutput *captureMetadataOutput;

/*!
 @property metaDataObjectTypes
 @abstract
 The MetaDataObjectTypes to look for in the scanning session.
 
 @discussion
 Only objects with a MetaDataObjectType found in this array will be
 reported to the result block.
 */
@property (nonatomic, strong) NSArray *metadataObjs;

/*!
 @property gestureRecognizer
 @abstract
 If allowTapToFocus is set to YES, this gesture recognizer is added to the `previewView`
 when scanning starts. When the user taps the view, the `focusPointOfInterest` will change
 to the location the user tapped.
 */
@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;


@property (nonatomic, assign) UIImagePickerControllerCameraDevice camera;

@property (nonatomic, assign) AVCaptureTorchMode torchMode;


@property (nonatomic, assign) BOOL isScanning;

@property (nonatomic, weak) UIView *preview;
@end




@implementation FBBarCodeScanner

@synthesize session = _session;
@synthesize captureDevice =_captureDevice;
@synthesize capturePreviewLayer = _capturePreviewLayer;
@synthesize captureMetadataOutput = _captureMetadataOutput;
@synthesize currentCaptureDeviceInput = _currentCaptureDeviceInput;
@synthesize metadataObjs = _metadataObjs;
@synthesize camera = _camera;
@synthesize torchMode = _torchMode;
@synthesize isScanning = _isScanning;



#pragma mark -- init

- (instancetype)initWithPreviewView:(UIView *)previewView {
    return [self initWithMetadataObjectTypes:[self defaultMetaDataObjectTypes] previewView:previewView];
}

- (instancetype)initWithMetadataObjectTypes:(NSArray *)metaDataObjectTypes previewView:(UIView *)previewView {
    if (!previewView) {
        return nil;
    }
    
    self  = [super init];
    if (self) {
        self.metadataObjs = [NSArray arrayWithArray:metaDataObjectTypes];
        self.allowTapToFocus = YES;
        self.preview = previewView;
        
        self.scanRect = CGRectZero;
        self.camera = UIImagePickerControllerCameraDeviceRear;
        self.torchMode = AVCaptureFlashModeOff;
        
        
        [self addRotationObserver];
    }
    
    return self;
}


- (void)addRotationObserver {
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(handleDeviceOrientationDidChangeNotification:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}


#pragma mark -- permission 

+ (void)requestCameraPermissionWithBlock:(authoResult)authResultBlock {
    switch ([AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo]) {
        case AVAuthorizationStatusAuthorized:
            authResultBlock(YES);
            break;
        case AVAuthorizationStatusDenied:
        case AVAuthorizationStatusRestricted:
            authResultBlock(NO);
            break;
        case AVAuthorizationStatusNotDetermined:{
            [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    authResultBlock(granted);
                });
            }];
        } break;
        default:
            authResultBlock(NO);
            break;
    }
}


+ (BOOL)hasCamera {
    return [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear|UIImagePickerControllerCameraDeviceFront];
}


+ (BOOL)cameraAvaliable {
    return [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
}



#pragma mark -- scanning

- (BOOL)isScanning {
    return [self.session isRunning];
}


- (void)startScanningWithBlock:(scanResult)resultResultBlock {
    if (![FBBarCodeScanner hasCamera]) {
        resultResultBlock(nil);
        return;
    }
    
    
    if (!self.session) {
        self.captureDevice = [self newCaptureDeviceWithCamera:self.camera];
        self.session = [self newSessionWithCaptureDevice:self.captureDevice];
    }
    
    // Configure the rect of interest
    self.captureMetadataOutput.rectOfInterest = [self rectOfInterestFromScanRect:self.scanRect];
    
    // Configure the preview layer
    self.capturePreviewLayer.cornerRadius = self.preview.layer.cornerRadius;
    [self.preview.layer insertSublayer:self.capturePreviewLayer atIndex:0]; // Insert below all other views
    [self refreshVideoOrientation];
    
    // Configure 'tap to focus' functionality
    [self configureTapToFocus];
    
    self.scanResultBlock = resultResultBlock;
    
    // Start the session after all configurations
    [self.session startRunning];
    
}


- (void)stopScanning {
    if (self.session) {
        
        // Turn the torch off
        self.torchMode = AVCaptureTorchModeOff;
        
        // Remove the preview layer
        [self.capturePreviewLayer removeFromSuperlayer];
        
        // Stop recognizing taps for the 'Tap to Focus' feature
        [self stopRecognizingTaps];
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            
            // When we're finished scanning, reset the settings for the camera
            // to their original states
            [self removeDeviceInput];
            
            for (AVCaptureOutput *output in self.session.outputs) {
                [self.session removeOutput:output];
            }
            
            [self.session stopRunning];
            self.session = nil;
            self.scanResultBlock = nil;
            self.capturePreviewLayer = nil;
        });
    }
}



#pragma mark - AVCaptureMetadataOutputObjects Delegate

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputMetadataObjects:(NSArray *)metadataObjects fromConnection:(AVCaptureConnection *)connection {
    
    NSMutableArray *codes = [[NSMutableArray alloc] init];
    
    for (AVMetadataObject *metaData in metadataObjects) {
        AVMetadataMachineReadableCodeObject *barCodeObject = (AVMetadataMachineReadableCodeObject *)[self.capturePreviewLayer transformedMetadataObjectForMetadataObject:(AVMetadataMachineReadableCodeObject *)metaData];
        if (barCodeObject) {
            [codes addObject:barCodeObject];
        }
    }
    
    if (self.scanResultBlock) {
        self.scanResultBlock(codes);
    }
}



#pragma mark - Tap to Focus

- (void)configureTapToFocus {
    if (self.allowTapToFocus) {
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusTapped:)];
        [self.preview addGestureRecognizer:tapGesture];
        self.tapGestureRecognizer = tapGesture;
    }
}

- (void)focusTapped:(UITapGestureRecognizer *)tapGesture {
    CGPoint tapPoint = [self.tapGestureRecognizer locationInView:self.tapGestureRecognizer.view];
    CGPoint devicePoint = [self.capturePreviewLayer captureDevicePointOfInterestForPoint:tapPoint];
    
    AVCaptureDevice *device = self.captureDevice;
    NSError *error = nil;
    
    if ([device lockForConfiguration:&error]) {
        if (device.isFocusPointOfInterestSupported &&
            [device isFocusModeSupported:AVCaptureFocusModeContinuousAutoFocus]) {
            
            device.focusPointOfInterest = devicePoint;
            device.focusMode = AVCaptureFocusModeContinuousAutoFocus;
        }
        [device unlockForConfiguration];
    }
}

- (void)stopRecognizingTaps {
    if (self.tapGestureRecognizer) {
        [self.preview removeGestureRecognizer:self.tapGestureRecognizer];
    }
}




#pragma mark -- flip camera || toggle torch

- (void)flipCamera {
    if (!([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear] && [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront])) {
        return;
    }
    
    if ([self isScanning]) {
        if (self.camera == UIImagePickerControllerCameraDeviceFront) {
            self.camera = UIImagePickerControllerCameraDeviceRear;
        } else {
            self.camera = UIImagePickerControllerCameraDeviceFront;
        }
    }
}



- (BOOL)hasTorch {
    AVCaptureDevice *device = [self newCaptureDeviceWithCamera:self.camera];
    if (device) {
        return [device hasTorch];
    }
    
    return NO;
}

- (void)toggleTorch {
    if (self.torchMode == AVCaptureTorchModeOn) {
        self.torchMode = AVCaptureTorchModeOff;
    } else {
        self.torchMode = AVCaptureTorchModeOn;
    }
    
//    [self updateTorchModeForCurrentSettings];
}


- (void)updateTorchModeForCurrentSettings {
    
    AVCaptureDevice *backCamera = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    if ([backCamera isTorchAvailable] && [backCamera isTorchModeSupported:AVCaptureTorchModeOn]) {
        
        BOOL success = [backCamera lockForConfiguration:nil];
        if (success) {
            [backCamera setTorchMode:_torchMode];
            [backCamera unlockForConfiguration];
        }
    }
}



#pragma mark -- setters && getters

//- (UIImagePickerControllerCameraDevice)camera {
//    
//}


- (void)setTorchMode:(AVCaptureTorchMode)torchMode {
    _torchMode = torchMode;
    [self updateTorchModeForCurrentSettings];
}


- (void)setCamera:(UIImagePickerControllerCameraDevice)camera {
    if (self.isScanning && camera != _camera) {
        AVCaptureDevice *captureDevice = [self newCaptureDeviceWithCamera:camera];
        AVCaptureDeviceInput *input = [self deviceInputForCaptureDevice:captureDevice];
        if (input) {
            [self setDeviceInput:input session:self.session];
        }
        
        _camera = camera;
    }
}

- (void)setScanRect:(CGRect)scanRect {
    
    [self refreshVideoOrientation];
    
    _scanRect = scanRect;
    self.captureMetadataOutput.rectOfInterest = [self.capturePreviewLayer metadataOutputRectOfInterestForRect:_scanRect];
}



- (CALayer *)previewLayer {
    return self.capturePreviewLayer;
}


#pragma mark -- AVCapture methods

- (AVCaptureSession *)newSessionWithCaptureDevice:(AVCaptureDevice *)captureDevice {
    AVCaptureSession *newSession = [[AVCaptureSession alloc] init];
    
    AVCaptureDeviceInput *input = [self deviceInputForCaptureDevice:captureDevice];
    [self setDeviceInput:input session:newSession];
    
    // Set an optimized preset for barcode scanning
    [newSession setSessionPreset:AVCaptureSessionPresetHigh];
    
    self.captureMetadataOutput = [[AVCaptureMetadataOutput alloc] init];
    [self.captureMetadataOutput setMetadataObjectsDelegate:self queue:dispatch_get_main_queue()];
    
    [newSession addOutput:self.captureMetadataOutput];
    self.captureMetadataOutput.metadataObjectTypes = self.metadataObjs;
    
//    // Still image capture configuration
//    self.stillImageOutput = [[AVCaptureStillImageOutput alloc] init];
//    self.stillImageOutput.outputSettings = @{AVVideoCodecKey: AVVideoCodecJPEG};
//    
//    if ([self.stillImageOutput isStillImageStabilizationSupported]) {
//        self.stillImageOutput.automaticallyEnablesStillImageStabilizationWhenAvailable = YES;
//    }
//    
//    if ([self.stillImageOutput respondsToSelector:@selector(isHighResolutionStillImageOutputEnabled)]) {
//        self.stillImageOutput.highResolutionStillImageOutputEnabled = YES;
//    }
//    [newSession addOutput:self.stillImageOutput];
    
    self.captureMetadataOutput.rectOfInterest = [self rectOfInterestFromScanRect:self.scanRect];
    
    self.capturePreviewLayer = nil;
    self.capturePreviewLayer = [AVCaptureVideoPreviewLayer layerWithSession:newSession];
    self.capturePreviewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    self.capturePreviewLayer.frame = self.preview.bounds;
    
    [newSession commitConfiguration];
    
    return newSession;
}

- (void)setDeviceInput:(AVCaptureDeviceInput *)deviceInput session:(AVCaptureSession *)session {
    [self removeDeviceInput];
    
    self.currentCaptureDeviceInput = deviceInput;
    
    if ([deviceInput.device lockForConfiguration:nil] == YES) {
        
//        // Prioritize the focus on objects near to the device
//        if ([deviceInput.device respondsToSelector:@selector(isAutoFocusRangeRestrictionSupported)] &&
//            deviceInput.device.isAutoFocusRangeRestrictionSupported) {
//            
//            self.initialAutoFocusRangeRestriction = deviceInput.device.autoFocusRangeRestriction;
//            deviceInput.device.autoFocusRangeRestriction = AVCaptureAutoFocusRangeRestrictionNear;
//        }
//        
//        // Focus on the center of the image
//        if ([deviceInput.device respondsToSelector:@selector(isFocusPointOfInterestSupported)] &&
//            deviceInput.device.isFocusPointOfInterestSupported) {
//            
//            self.initialFocusPoint = deviceInput.device.focusPointOfInterest;
//            deviceInput.device.focusPointOfInterest = CGPointMake(kFocalPointOfInterestX, kFocalPointOfInterestY);
//        }
        
        [self updateTorchModeForCurrentSettings];
        
        [deviceInput.device unlockForConfiguration];
    }
    
    [session addInput:deviceInput];
}

- (void)removeDeviceInput {
    
    AVCaptureDeviceInput *deviceInput = self.currentCaptureDeviceInput;
    
    // Restore focus settings to the previously saved state
    if ([deviceInput.device lockForConfiguration:nil] == YES) {
//        if ([deviceInput.device respondsToSelector:@selector(isAutoFocusRangeRestrictionSupported)] &&
//            deviceInput.device.isAutoFocusRangeRestrictionSupported) {
//            deviceInput.device.autoFocusRangeRestriction = self.initialAutoFocusRangeRestriction;
//        }
//        
//        if ([deviceInput.device respondsToSelector:@selector(isFocusPointOfInterestSupported)] &&
//            deviceInput.device.isFocusPointOfInterestSupported) {
//            deviceInput.device.focusPointOfInterest = self.initialFocusPoint;
//        }
        
        [deviceInput.device unlockForConfiguration];
    }
    
    [self.session removeInput:deviceInput];
    self.currentCaptureDeviceInput = nil;
}


- (AVCaptureDevice *)newCaptureDeviceWithCamera:(UIImagePickerControllerCameraDevice)camera {
    AVCaptureDevice *newCaptureDevice = nil;
    
    AVCaptureDevicePosition position = [self devicePositionForCamera:camera];
    NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    for (AVCaptureDevice *device in videoDevices) {
        if (device.position == position) {
            newCaptureDevice = device;
            break;
        }
    }
    
    // If the front camera is not available, use the back camera
    if (!newCaptureDevice) {
        newCaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    
    return newCaptureDevice;
}


- (AVCaptureDevicePosition)devicePositionForCamera:(UIImagePickerControllerCameraDevice)camera {
    AVCaptureDevicePosition position = AVCaptureDevicePositionUnspecified;
    
    switch (camera) {
        case UIImagePickerControllerCameraDeviceRear:
            position = AVCaptureDevicePositionBack;
            break;
        case UIImagePickerControllerCameraDeviceFront:
            position = AVCaptureDevicePositionFront;
        default:
            break;
    }
    
    return position;
}



- (AVCaptureDeviceInput *)deviceInputForCaptureDevice:(AVCaptureDevice *)captureDevice {
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:captureDevice
                                                                        error:nil];
    return input;
}




- (CGRect)rectOfInterestFromScanRect:(CGRect)scanRect {
    CGRect rect = CGRectZero;
    if (!CGRectIsEmpty(self.scanRect)) {
        rect = [self.capturePreviewLayer metadataOutputRectOfInterestForRect:self.scanRect];
    } else {
        rect = CGRectMake(0, 0, 1, 1); // Default rectOfInterest for AVCaptureMetadataOutput
    }
    return rect;
}




#pragma mark - Default Values

- (NSArray *)defaultMetaDataObjectTypes {
    NSMutableArray *types = [@[AVMetadataObjectTypeQRCode,
                               AVMetadataObjectTypeUPCECode,
                               AVMetadataObjectTypeCode39Code,
                               AVMetadataObjectTypeCode39Mod43Code,
                               AVMetadataObjectTypeEAN13Code,
                               AVMetadataObjectTypeEAN8Code,
                               AVMetadataObjectTypeCode93Code,
                               AVMetadataObjectTypeCode128Code,
                               AVMetadataObjectTypePDF417Code,
                               AVMetadataObjectTypeAztecCode] mutableCopy];
    
    if (__IPHONE_OS_VERSION_MAX_ALLOWED >= __IPHONE_8_0) {
        [types addObjectsFromArray:@[AVMetadataObjectTypeInterleaved2of5Code,
                                     AVMetadataObjectTypeITF14Code,
                                     AVMetadataObjectTypeDataMatrixCode
                                     ]];
    }
    
    return types;
}






#pragma mark -- rotation
- (void)handleDeviceOrientationDidChangeNotification:(NSNotification*)notification {
    [self refreshVideoOrientation];
}

- (void)refreshVideoOrientation {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    self.capturePreviewLayer.frame = self.preview.bounds;
    if ([self.capturePreviewLayer.connection isVideoOrientationSupported]) {
        self.capturePreviewLayer.connection.videoOrientation = [self captureOrientationForInterfaceOrientation:orientation];
    }
}

- (AVCaptureVideoOrientation)captureOrientationForInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    switch (interfaceOrientation) {
        case UIInterfaceOrientationPortrait:
            return AVCaptureVideoOrientationPortrait;
        case UIInterfaceOrientationPortraitUpsideDown:
            return AVCaptureVideoOrientationPortraitUpsideDown;
        case UIInterfaceOrientationLandscapeLeft:
            return AVCaptureVideoOrientationLandscapeLeft;
        case UIInterfaceOrientationLandscapeRight:
            return AVCaptureVideoOrientationLandscapeRight;
        default:
            return AVCaptureVideoOrientationPortrait;
    }
}





#pragma mark -- dealloc
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
