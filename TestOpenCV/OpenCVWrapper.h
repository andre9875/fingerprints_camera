//
//  OpenCVWrapper.h
//  TestOpenCV
//
//  Created by Sandeep Mahajan on 18/09/23.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface OpenCVWrapper : NSObject

+ (NSString *)getOpenCVVersion;
+ (UIImage *)grayscaleImg:(UIImage *)image;
+ (UIImage *)resizeImg:(UIImage *)image :(int)width :(int)height :(int)interpolation;

+ (UIImage *)extractMinutiaeFromUIImage:(UIImage *)image;

//+ (cv::Mat)extractMinutiaeFromImage:(cv::Mat)img;
//+ (cv::Mat)convertUIImageToMat:(UIImage *)image;
//+ (UIImage *)convertMatToUIImage:(cv::Mat)mat;


@end

NS_ASSUME_NONNULL_END
