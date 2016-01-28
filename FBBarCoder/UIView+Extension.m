//
//  UIView+Extension.m
//  FBBarCoder
//
//  Created by 123 on 16/1/28.
//  Copyright © 2016年 com.pureLake. All rights reserved.
//

#import "UIView+Extension.h"

@implementation UIView(UIViewRectCategory)

- (CGFloat)originX {
    return self.frame.origin.x;
}

- (void)setOriginX:(CGFloat)originX {
    CGRect tmp = self.frame;
    tmp.origin.x = originX;
    
    self.frame = tmp;
}

- (CGFloat)originY {
    return self.frame.origin.y;
}

- (void)setOriginY:(CGFloat)originY {
    CGRect tmp = self.frame;
    tmp.origin.y = originY;
    
    self.frame = tmp;
}


- (CGFloat)width {
    return self.frame.size.width;
}

- (void)setWidth:(CGFloat)width {
    CGRect tmp = self.frame;
    tmp.size.width = width;
    
    self.frame = tmp;
}

- (CGFloat)height {
    return self.frame.size.height;
}

- (void)setHeight:(CGFloat)height {
    CGRect tmp = self.frame;
    tmp.size.height = height;
    
    self.frame = tmp;
}

@end
