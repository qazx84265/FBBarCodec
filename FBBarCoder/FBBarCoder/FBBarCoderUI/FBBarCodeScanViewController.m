//
//  FBBarCodeScanViewController.m
//  FBBarCoder
//
//  Created by 123 on 16/1/27.
//  Copyright © 2016年 com.pureLake. All rights reserved.
//

#import "FBBarCodeScanViewController.h"
#import "UIView+Extension.h"
#import "FBBarCodeScanner.h"
@import AVFoundation;

#define ALERT_VIEW(m) dispatch_async(dispatch_get_main_queue(), ^{do {UIAlertView *al = [[UIAlertView alloc] initWithTitle:@"" message:m delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];\
[al show];\
}while(0);});

#define SCREEN_WIDTH CGRectGetWidth([UIScreen mainScreen].bounds)
#define SCREEN_HEIGHT CGRectGetHeight([UIScreen mainScreen].bounds)

static const CGFloat kBorderW = 100;
static const CGFloat kMargin = 30;


@interface FBBarCodeScanViewController ()<UIImagePickerControllerDelegate, UINavigationControllerDelegate> {
    NSTimer *_animTimer;
}
@property (nonatomic, weak)   UIView *maskView;
@property (nonatomic, strong) UIView *scanWindow;
@property (nonatomic, strong) UIImageView *scanNetImageView;

@property (nonatomic, strong) NSBundle* imgBundle;
@property (nonatomic, strong) FBBarCodeScanner *scanner;
@end

@implementation FBBarCodeScanViewController

-(void)viewWillAppear:(BOOL)animated {
    
//    self.navigationController.navigationBar.hidden=YES;
    [self resumeAnimation];
    
}
-(void)viewDidDisappear:(BOOL)animated {
    
//    self.navigationController.navigationBar.hidden=NO;
    [super viewDidDisappear:animated];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    //这个属性必须打开否则返回的时候会出现黑边
    self.view.clipsToBounds=YES;
    
    // Default animation
    self.scanAnimationType = ScanAnimationTypeGrid;
    
    NSBundle* bundle = [NSBundle bundleForClass:[FBBarCodeScanViewController class]];
    NSURL* url = [bundle URLForResource:@"FBBarCodec" withExtension:@"bundle"];
    self.imgBundle = [NSBundle bundleWithURL:url];

    //遮罩
    [self setupMaskView];
    //扫描区域
    [self setupScanWindowView];
    //下边栏
    [self setupBottomBar];


    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(resumeAnimation) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    //开始扫描
    [self startScanning];
    
}


- (void)setupMaskView {
    UIView *mask = [[UIView alloc] init];
    _maskView = mask;
    mask.layer.borderColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.7].CGColor;
    mask.layer.borderWidth = kBorderW;
    mask.bounds = CGRectMake(0, 0, SCREEN_WIDTH + kBorderW + kMargin , SCREEN_WIDTH + kBorderW + kMargin);
    mask.center = CGPointMake(self.view.width * 0.5, self.view.height * 0.5);
    mask.originY = 0;
    [self.view addSubview:mask];
    
    
    CALayer *bottomMaskLayer = [[CALayer alloc] init];
    bottomMaskLayer.bounds = CGRectMake(0, 0, SCREEN_WIDTH, SCREEN_HEIGHT-_maskView.originY-_maskView.height);
    bottomMaskLayer.position = CGPointMake(SCREEN_WIDTH/2, (SCREEN_HEIGHT+_maskView.originY+_maskView.height)/2);
    bottomMaskLayer.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.7].CGColor;
    [self.view.layer addSublayer:bottomMaskLayer];
}




- (void)setupBottomBar {

    UIView *bottomView = [[UIView alloc] initWithFrame:CGRectMake(0, SCREEN_HEIGHT-50-20, SCREEN_WIDTH, 50)];
    bottomView.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.9];
    [self.view addSubview:bottomView];
    
    //1.返回
    UIButton *backBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    backBtn.frame = CGRectMake(20, 13, 24, 24);
    [backBtn setBackgroundImage:[UIImage imageNamed:[self.imgBundle pathForResource:@"qrcode_scan_titlebar_back_nor@2x" ofType:@"png"]] forState:UIControlStateNormal];
    backBtn.contentMode=UIViewContentModeScaleAspectFit;
    [backBtn addTarget:self action:@selector(disMiss) forControlEvents:UIControlEventTouchUpInside];
    [bottomView addSubview:backBtn];
    
    //2.相册
    UIButton * albumBtn=[UIButton buttonWithType:UIButtonTypeCustom];
    albumBtn.frame = CGRectMake(100, 0, 35, 49);
    [albumBtn setBackgroundImage:[UIImage imageNamed:[self.imgBundle pathForResource:@"qrcode_scan_btn_photo_down@2x" ofType:@"png"]] forState:UIControlStateNormal];
    albumBtn.contentMode=UIViewContentModeScaleAspectFit;
    [albumBtn addTarget:self action:@selector(myAlbum) forControlEvents:UIControlEventTouchUpInside];
    [bottomView addSubview:albumBtn];
    
    //3.闪光灯
    if ([self.scanner hasTorch]) {
        UIButton * flashBtn=[UIButton buttonWithType:UIButtonTypeCustom];
        flashBtn.frame = CGRectMake(CGRectGetMaxX(albumBtn.frame)+20,0, 35, 49);
        [flashBtn setBackgroundImage:[UIImage imageNamed:[self.imgBundle pathForResource:@"qrcode_scan_btn_flash_down@2x" ofType:@"png"]] forState:UIControlStateNormal];
        flashBtn.contentMode=UIViewContentModeScaleAspectFit;
        [flashBtn addTarget:self action:@selector(openFlash:) forControlEvents:UIControlEventTouchUpInside];
        [bottomView addSubview:flashBtn];
    }
    
    //4.摄像头切换
    if ([UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceRear] && [UIImagePickerController isCameraDeviceAvailable:UIImagePickerControllerCameraDeviceFront]) {
        
        UIButton *cameraFlipBtn=[UIButton buttonWithType:UIButtonTypeCustom];
        cameraFlipBtn.frame = CGRectMake(CGRectGetMaxX(albumBtn.frame)+20+35+20,0, 40, 32);
        [cameraFlipBtn setBackgroundImage:[UIImage imageNamed:[self.imgBundle pathForResource:@"qrcode_scan_btn_flip_camera@2x" ofType:@"png"]] forState:UIControlStateNormal];
        cameraFlipBtn.contentMode=UIViewContentModeScaleAspectFit;
        [cameraFlipBtn addTarget:self action:@selector(flipCamera:) forControlEvents:UIControlEventTouchUpInside];
        [bottomView addSubview:cameraFlipBtn];
    }
}


- (void)setupScanWindowView {
    
    CGFloat scanWindowH = SCREEN_WIDTH - kMargin * 2;
    CGFloat scanWindowW = SCREEN_WIDTH - kMargin * 2;
    _scanWindow = [[UIView alloc] initWithFrame:CGRectMake(kMargin, kBorderW, scanWindowW, scanWindowH)];
    _scanWindow.clipsToBounds = YES;
    _scanWindow.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_scanWindow];
    
    
    CGFloat buttonWH = 19;
    
    UIButton *topLeft = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, buttonWH, buttonWH)];
    [topLeft setImage:[UIImage imageNamed:[self.imgBundle pathForResource:@"scan_1@2x" ofType:@"png"]] forState:UIControlStateNormal];
    [_scanWindow addSubview:topLeft];
    
    UIButton *topRight = [[UIButton alloc] initWithFrame:CGRectMake(scanWindowW - buttonWH, 0, buttonWH, buttonWH)];
    [topRight setImage:[UIImage imageNamed:[self.imgBundle pathForResource:@"scan_2@2x" ofType:@"png"]] forState:UIControlStateNormal];
    [_scanWindow addSubview:topRight];
    
    UIButton *bottomLeft = [[UIButton alloc] initWithFrame:CGRectMake(0, scanWindowH - buttonWH, buttonWH, buttonWH)];
    [bottomLeft setImage:[UIImage imageNamed:[self.imgBundle pathForResource:@"scan_3@2x" ofType:@"png"]] forState:UIControlStateNormal];
    [_scanWindow addSubview:bottomLeft];
    
    UIButton *bottomRight = [[UIButton alloc] initWithFrame:CGRectMake(topRight.originX, bottomLeft.originY, buttonWH, buttonWH)];
    [bottomRight setImage:[UIImage imageNamed:[self.imgBundle pathForResource:@"scan_4@2x" ofType:@"png"]] forState:UIControlStateNormal];
    [_scanWindow addSubview:bottomRight];
    
    
    //2.操作提示
    UILabel * tipLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(_scanWindow.frame)+10, SCREEN_WIDTH, 21)];
    tipLabel.text = @"将取景框对准二维码，即可自动扫描";
    tipLabel.textColor = [UIColor whiteColor];
    tipLabel.textAlignment = NSTextAlignmentCenter;
    tipLabel.lineBreakMode = NSLineBreakByWordWrapping;
    tipLabel.numberOfLines = 2;
    tipLabel.font=[UIFont systemFontOfSize:12];
    tipLabel.backgroundColor = [UIColor clearColor];
    [self.view addSubview:tipLabel];
    
    
}



#pragma mark-> 我的相册
-(void)myAlbum{
    
    NSLog(@"我的相册");
    if([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]){
        //1.初始化相册拾取器
        UIImagePickerController *controller = [[UIImagePickerController alloc] init];
        //2.设置代理
        controller.delegate = self;
        //3.设置资源：
        /**
         UIImagePickerControllerSourceTypePhotoLibrary,相册
         UIImagePickerControllerSourceTypeCamera,相机
         UIImagePickerControllerSourceTypeSavedPhotosAlbum,照片库
         */
        controller.sourceType = UIImagePickerControllerSourceTypeSavedPhotosAlbum;
        //4.随便给他一个转场动画
        controller.modalTransitionStyle=UIModalTransitionStyleFlipHorizontal;
        [self presentViewController:controller animated:YES completion:nil];
        
    }else{
        ALERT_VIEW(@"设备不支持访问相册，请在设置->隐私->照片中进行设置！");
    }
    
}
#pragma mark-> imagePickerController delegate
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    //获取选择的图片
    UIImage *image = info[UIImagePickerControllerOriginalImage];

    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        
        [weakSelf scanBarCodeFromImage:image];
    }];
}


- (void)scanBarCodeFromImage:(UIImage*)image {
    //初始化一个监测器
    CIDetector*detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
    //监测到的结果数组
    NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:image.CGImage]];
    if (features.count >=1) {
        /**结果对象 */
        CIQRCodeFeature *feature = [features objectAtIndex:0];
        NSString *scannedResult = feature.messageString;
        ALERT_VIEW(scannedResult);
    }
    else{
        ALERT_VIEW(@"该图片不包含二维码！");
    }
}


#pragma mark-> 闪光灯
-(void)openFlash:(UIButton*)button{
    if (![self.scanner hasTorch]) {
        ALERT_VIEW(@"此设备不支持手电筒/闪光灯");
    } else {
        [self.scanner toggleTorch];
    }
}

/**
 *  switch camera
 *
 *  @param sender
 */
- (void)flipCamera:(id)sender {
    [self.scanner flipCamera];
}



#pragma mark 恢复动画
- (void)resumeAnimation {
  
    if (!_scanNetImageView) {
        
        //扫描条
        _scanNetImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:self.scanAnimationType==ScanAnimationTypeLine? [self.imgBundle pathForResource:@"qrcode_scan_light_green@2x" ofType:@"png"]:[self.imgBundle pathForResource:@"scan_net@2x" ofType:@"png"]]];
        
        CGFloat scanNetImageViewH = 241;
        CGFloat scanWindowH = SCREEN_WIDTH - kMargin * 2;
        CGFloat scanNetImageViewW = scanWindowH;
        _scanNetImageView.frame = CGRectMake(0, self.scanAnimationType==ScanAnimationTypeLine? -5:-scanNetImageViewH, scanNetImageViewW, self.scanAnimationType==ScanAnimationTypeLine?5:scanNetImageViewH);
        [_scanWindow addSubview:_scanNetImageView];
    }
    
    //
    [self scanAnimation];
}




- (void)scanAnimation {
    
    CGFloat scanNetImageViewH = 241;
    __weak typeof(self) weakSelf = self;
    [UIView animateWithDuration:1 animations:^{
        CGRect tmp = _scanNetImageView.frame;
        tmp.origin.y += SCREEN_WIDTH - kMargin * 2;
        _scanNetImageView.frame = tmp;
    } completion:^(BOOL finished) {
        _scanNetImageView.frame = CGRectMake(0, self.scanAnimationType==ScanAnimationTypeLine? 0:-scanNetImageViewH, _scanWindow.width, self.scanAnimationType==ScanAnimationTypeLine?5:scanNetImageViewH);
        
        [weakSelf scanAnimation];
        
    }];
}



#pragma mark -- scanning

- (void)startScanning {
    if (![FBBarCodeScanner hasCamera]) {
        ALERT_VIEW(@"此设备不支持摄像头");
        
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    [FBBarCodeScanner requestCameraPermissionWithBlock:^(BOOL grant) {
        if (!grant) {
            ALERT_VIEW(@"无使用权限，请在设置->隐私->相机中允许");
        }
        else {
            [weakSelf.scanner startScanningWithBlock:^(NSArray *results) {
                if (results && results.count>0) {
                    AVMetadataMachineReadableCodeObject *obj = [results objectAtIndex:0];
                    //ALERT_VIEW(obj.stringValue);
                    
                    if (self.scanComplete) {
                        self.scanComplete(obj.stringValue);
                    }
                    [weakSelf disMiss];
                }
            }];
        }
    }];
}


- (void)stopScanning {
    if (_scanner) {
        [_scanner stopScanning];
    }
}




- (FBBarCodeScanner*)scanner {
    if (!_scanner) {
        _scanner = [[FBBarCodeScanner alloc] initWithPreviewView:self.view];
    }
    
    return _scanner;
}



#pragma mark-> 返回
- (void)disMiss
{
    [self stopScanning];
//    [self.navigationController popViewControllerAnimated:YES];
    [self dismissViewControllerAnimated:YES completion:^{
        
    }];
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/


- (void)setScanComplete:(scanComplete)scanComplete {
    if (scanComplete) {
        _scanComplete = [scanComplete copy];
    }
}

- (void)setScanAnimationType:(ScanAnimationType)scanAnimationType {
    _scanAnimationType = scanAnimationType;
}


- (BOOL)shouldAutorotate {
    return NO;
}


@end
