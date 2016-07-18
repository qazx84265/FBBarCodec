//
//  ViewController.m
//  FBBarCoder
//
//  Created by 123 on 16/1/27.
//  Copyright © 2016年 com.pureLake. All rights reserved.
//

#import "ViewController.h"
#import "FBBarCodeScanViewController.h"
#import "FBBarCodeGenerator.h"



#define RandomColor [UIColor colorWithRed:arc4random_uniform(256)/255.0 green:arc4random_uniform(256)/255.0 blue:arc4random_uniform(256)/255.0 alpha:1]


@interface ViewController () {
    NSTimer *_timer;
}
@property (weak, nonatomic) IBOutlet UITextField *barCodeContentTf;
@property (weak, nonatomic) IBOutlet UIImageView *qrCodeImg;


- (IBAction)scan:(id)sender;
- (IBAction)create:(id)sender;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    UILongPressGestureRecognizer*longPress=[[UILongPressGestureRecognizer alloc]initWithTarget:self action:@selector(dealLongPress:)];
    longPress.minimumPressDuration = 1.0;
    [self.qrCodeImg addGestureRecognizer:longPress];
    [self.qrCodeImg  setUserInteractionEnabled:YES];
    
//    //定时器
//    if (!_timer) {
//        _timer=[NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(createQRCode) userInfo:nil repeats:YES];
//        [[NSRunLoop mainRunLoop]addTimer:_timer forMode:NSRunLoopCommonModes];
//    }
//    [self createQRCode];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


/**
 *  code scanning
 *
 *  @param sender
 */
- (IBAction)scan:(id)sender {
    FBBarCodeScanViewController *scVC = [[FBBarCodeScanViewController alloc] init];
    [scVC setScanComplete:^(NSString* result){
        NSLog(@"------>>>>>>> %@", result);
        dispatch_async(dispatch_get_main_queue(), ^{
            UIAlertView *al = [[UIAlertView alloc] initWithTitle:@"" message:result delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil, nil];\
            [al show];
        });
    }];
    [self presentViewController:scVC animated:YES completion:^{
        
    }];
}


/**
 *  QRCode creating
 *
 *  @param sender 
 */
- (IBAction)create:(id)sender {
    [self createQRCode];
}

- (void)createQRCode {
    UIImage *image=[UIImage imageNamed:@"thumb.jpg"];
    
    NSString*tempStr;
    if(self.barCodeContentTf.text.length==0){
        tempStr=@"ddddddddd";
    }else{
        tempStr=self.barCodeContentTf.text;
    }
    UIImage*tempImage=[FBBarCodeGenerator qrCodeWithContent:tempStr size:self.qrCodeImg.frame.size.width thumb:nil color:RandomColor];
    
    self.qrCodeImg.image=tempImage;
}


#pragma mark-> 长按识别二维码
-(void)dealLongPress:(UIGestureRecognizer*)gesture{
    
    NSLog(@"------->>>>>>>>>> detect long press");
    if(gesture.state == UIGestureRecognizerStateBegan){
        
        _timer.fireDate=[NSDate distantFuture];
        
        UIImageView* tempImageView = (UIImageView*)gesture.view;
        if(tempImageView.image){
            //1. 初始化扫描仪，设置设别类型和识别质量
            CIDetector* detector = [CIDetector detectorOfType:CIDetectorTypeQRCode context:nil options:@{ CIDetectorAccuracy : CIDetectorAccuracyHigh }];
            //2. 扫描获取的特征组
            NSArray *features = [detector featuresInImage:[CIImage imageWithCGImage:tempImageView.image.CGImage]];
            //3. 获取扫描结果
            CIQRCodeFeature *feature = [features objectAtIndex:0];
            NSString *scannedResult = feature.messageString;
            UIAlertView * alertView = [[UIAlertView alloc]initWithTitle:@"扫描结果" message:scannedResult delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
            [alertView show];
        }else {
            
            UIAlertView * alertView = [[UIAlertView alloc]initWithTitle:@"扫描结果" message:@"您还没有生成二维码" delegate:nil cancelButtonTitle:@"确定" otherButtonTitles:nil, nil];
            [alertView show];
        }
        
    }else if (gesture.state==UIGestureRecognizerStateEnded){
        _timer.fireDate=[NSDate distantPast];
    }
}



- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self.view endEditing:YES];
}

- (BOOL)shouldAutorotate {
    return NO;
}


@end
