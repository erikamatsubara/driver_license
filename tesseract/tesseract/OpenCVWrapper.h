//
//  OpenCVWrapper.h
//  tesseract
//
//  Created by 松原えりか on 2018/12/10.
//  Copyright © 2018年 松原えりか. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject

- (UIImage*) processImage: (UIImage*)image;
- (UIImage*) transformPerspective: (UIImage*)image points: (CGPoint[])points;

@end

NS_ASSUME_NONNULL_END


