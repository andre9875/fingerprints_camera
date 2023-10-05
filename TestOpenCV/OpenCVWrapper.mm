//
//  OpenCVWrapper.m
//  TestOpenCV
//
//  Created by Sandeep Mahajan on 18/09/23.
//

#import <opencv2/opencv.hpp>
#import <opencv2/Core.h>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/imgproc/imgproc.hpp>
#import <opencv2/imgproc/types_c.h>
#import <opencv2/ximgproc.hpp>
#import "OpenCVWrapper.h"
#import <CoreGraphics/CoreGraphics.h>


@interface UIImage (OpenCVWrapper)

- (void)convertToMat: (cv::Mat *)pMat: (bool)alphaExists;
- (cv::Mat)convertUIImageToMat:(UIImage *)image;

@end

@implementation UIImage (OpenCVWrapper)

int GetCGImageHeight(CGImageRef cgImage) {
  return CGImageGetHeight(cgImage);
}

int GetCGImageWidth(CGImageRef cgImage) {
  return CGImageGetWidth(cgImage);
}

- (void)convertToMat: (cv::Mat *)pMat: (bool)alphaExists {
    if (self.imageOrientation == UIImageOrientationRight) {
        /*
         * When taking picture in portrait orientation,
         * convert UIImage to OpenCV Matrix in landscape right-side-up orientation,
         * and then rotate OpenCV Matrix to portrait orientation
         */
        UIImageToMat([UIImage imageWithCGImage:self.CGImage scale:1.0 orientation:UIImageOrientationUp], *pMat, alphaExists);
        cv::rotate(*pMat, *pMat, cv::ROTATE_90_CLOCKWISE);
    } else if (self.imageOrientation == UIImageOrientationLeft) {
        /*
         * When taking picture in portrait upside-down orientation,
         * convert UIImage to OpenCV Matrix in landscape right-side-up orientation,
         * and then rotate OpenCV Matrix to portrait upside-down orientation
         */
        UIImageToMat([UIImage imageWithCGImage:self.CGImage scale:1.0 orientation:UIImageOrientationUp], *pMat, alphaExists);
        cv::rotate(*pMat, *pMat, cv::ROTATE_90_COUNTERCLOCKWISE);
    } else {
        /*
         * When taking picture in landscape orientation,
         * convert UIImage to OpenCV Matrix directly,
         * and then ONLY rotate OpenCV Matrix for landscape left-side-up orientation
         */
        UIImageToMat(self, *pMat, alphaExists);
        if (self.imageOrientation == UIImageOrientationDown) {
            cv::rotate(*pMat, *pMat, cv::ROTATE_180);
        }
    }
}

- (cv::Mat)toCvMatGray:(UIImage *)image {
    // Convert the UIImage to a CGImage
       CGImageRef cgImage = image.CGImage;

       // Get the height and width of the CGImage
       int height = GetCGImageHeight(cgImage);
       int width = GetCGImageWidth(cgImage);

       // Create a grayscale Mat
       //cv::Mat cvMat(height, width, CV_8UC1);
        cv::Mat cvMat(height, width, CV_32FC1);
    
       // Copy the pixel data from the CGImage to the cvMat
       CGContextRef context = CGBitmapContextCreate(cvMat.data, cvMat.cols, cvMat.rows, 8, cvMat.step[0], CGColorSpaceCreateDeviceGray(), kCGBitmapByteOrderDefault);
       CGContextDrawImage(context, CGRectMake(0, 0, cvMat.cols, cvMat.rows), cgImage);
       CGContextRelease(context);

       return cvMat;
}

@end

@implementation OpenCVWrapper

+ (NSString *)getOpenCVVersion {
    return [NSString stringWithFormat:@"OpenCV Version %s",  CV_VERSION];
}

+ (UIImage *)grayscaleImg:(UIImage *)image {
    cv::Mat mat;
    [image convertToMat: &mat :false];
    
    cv::Mat gray;
    
    NSLog(@"channels = %d", mat.channels());

    if (mat.channels() > 1) {
        cv::cvtColor(mat, gray, cv::COLOR_RGB2GRAY);
    } else {
        mat.copyTo(gray);
    }
    
    UIImage *grayImg = MatToUIImage(gray);
    return grayImg;
}

+ (UIImage *)resizeImg:(UIImage *)image :(int)width :(int)height :(int)interpolation {
    cv::Mat mat;
    [image convertToMat: &mat :false];
    
    if (mat.channels() == 4) {
        [image convertToMat: &mat :true];
    }
    
    NSLog(@"source shape = (%d, %d)", mat.cols, mat.rows);
    
    cv::Mat resized;
    
//    cv::INTER_NEAREST = 0,
//    cv::INTER_LINEAR = 1,
//    cv::INTER_CUBIC = 2,
//    cv::INTER_AREA = 3,
//    cv::INTER_LANCZOS4 = 4,
//    cv::INTER_LINEAR_EXACT = 5,
//    cv::INTER_NEAREST_EXACT = 6,
//    cv::INTER_MAX = 7,
//    cv::WARP_FILL_OUTLIERS = 8,
//    cv::WARP_INVERSE_MAP = 16
    
    cv::Size size = {width, height};
    
    cv::resize(mat, resized, size, 0, 0, interpolation);
    
    NSLog(@"dst shape = (%d, %d)", resized.cols, resized.rows);
    
    UIImage *resizedImg = MatToUIImage(resized);
    
    return resizedImg;

}

+ (UIImage *)extractMinutiaeFromUIImage:(UIImage *)image {
    // Convert the image into Mat
    cv::Mat img;
    //[image convertToMat: &img :false];
    img = [image toCvMatGray:image];
    
    cv::Mat resultImage;
    img.copyTo(resultImage);
    
    cv::Mat finalImg;
    finalImg = [self performOperations:img];
    
    for (int i = 1; i < img.rows - 1; i++) {
        for (int j = 1; j < img.cols - 1; j++) {
            uint8_t* ptr = img.ptr<uint8_t>(i);
            int p1 = (int)ptr[j-1];
            int p2 = (int)ptr[j];
            int p3 = (int)ptr[j+1];
        
            int p4 = (int)img.ptr<uint8_t>(i-1)[j];
            int p5 = (int)img.ptr<uint8_t>(i+1)[j];

            int p6 = (int)img.ptr<uint8_t>(i-1)[j-1];
            int p7 = (int)img.ptr<uint8_t>(i+1)[j+1];

            int p8 = (int)img.ptr<uint8_t>(i-1)[j+1];
            int p9 = (int)img.ptr<uint8_t>(i+1)[j-1];

            // Calculate the summation of neighbor pixels
            int summation = p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9;

            // If the pixel is a minutiae point
            if (summation == 7) {
                resultImage.ptr<uint8_t>(i)[j] = 255;
            } else {
                resultImage.ptr<uint8_t>(i)[j] = 0;
            }
        }
    }
    
    cv::cvtColor(resultImage, resultImage, cv::COLOR_GRAY2RGB);
    UIImage *finalImage = MatToUIImage(resultImage);
    //UIImage *finalImage = [self imageFromCVMat:resultImage];
    return finalImage;
}

+ (UIImage *)imageFromCVMat:(cv::Mat)cvMat {
    // Add an alpha channel to the cv::Mat.
    cv::Mat cvMatInCV_8UC4;
    cv::cvtColor(cvMat, cvMatInCV_8UC4, cv::COLOR_BGR2BGRA);

    // Create a data provider object from the cv::Mat.
    CGDataProviderRef dataProvider = CGDataProviderCreateWithData(NULL, cvMatInCV_8UC4.data, cvMatInCV_8UC4.cols * cvMatInCV_8UC4.rows * 4, NULL);

    // Create a CGImage from the data provider object.
    CGImageRef cgImage = CGImageCreate(cvMatInCV_8UC4.cols, cvMatInCV_8UC4.rows, 8, 32, cvMatInCV_8UC4.step[0], CGColorSpaceCreateDeviceRGB(), kCGBitmapByteOrderDefault, dataProvider, NULL, false, kCGRenderingIntentDefault);

    // Release the data provider object.
    CGDataProviderRelease(dataProvider);

    // Create a UIImage from the CGImage.
    UIImage *image = [UIImage imageWithCGImage:cgImage];

    // Release the CGImage.
    CGImageRelease(cgImage);

    return image;
}

+ (cv::Mat)performOperations:(cv::Mat)img {
    // Calculate the DFT of the image
    cv::Mat dftMat;
    cv::dft(img, dftMat, cv::DftFlags::DFT_COMPLEX_OUTPUT + cv::DftFlags::DFT_ROWS, 0);

    // Get the real and imaginary parts of the DFT
    std::vector<cv::Mat> channels;
    cv::split(dftMat, channels);
    cv::Mat realDftMat = channels[0];
    cv::Mat imaginaryDftMat = channels[1];

    // Calculate the magnitude of the DFT
    cv::Mat magnitudeMat;
    cv::magnitude(realDftMat, imaginaryDftMat, magnitudeMat);

    // Convert the magnitude of the DFT to a single-channel image
    cv::Mat singleChannelMagnitudeMat;
    magnitudeMat.copyTo(singleChannelMagnitudeMat);
    
    // Perform histogram equalization on the single-channel magnitude of the DFT
    cv::Mat equalizedMagnitudeMat;
    cv::Mat singleChannelMagnitudeMat_Converted;
    singleChannelMagnitudeMat.convertTo(singleChannelMagnitudeMat_Converted, CV_8UC1);
    cv::equalizeHist(singleChannelMagnitudeMat_Converted, equalizedMagnitudeMat);

    // Calculate the inverse DFT of the equalized magnitude of the DFT
    cv::Mat equalizedMat;
    cv::Mat equalizedMat_Converted;
    equalizedMagnitudeMat.convertTo(equalizedMat_Converted, CV_32FC1);
    cv::idft(equalizedMat_Converted, equalizedMat, cv::DFT_COMPLEX_OUTPUT);

    // Perform binarization on the single-channel image
    cv::threshold(equalizedMat, equalizedMat, 128, 255, cv::THRESH_BINARY);
    
    // Perform thinning using THINNING_ZHANGSUEN algorithm
    cv::Mat equalizedMat_8UC;
    equalizedMat.convertTo(equalizedMat_8UC, CV_8UC1);
    cv::ximgproc::thinning(equalizedMat_8UC, equalizedMat_8UC, cv::ximgproc::THINNING_ZHANGSUEN);
    
    return equalizedMat_8UC;
}

- (cv::Mat)extractMinutiaeFromImage:(cv::Mat)img {
    cv::Mat resultImage;
    img.copyTo(resultImage);
    
    for (int i = 1; i < img.rows - 1; i++) {
        for (int j = 1; j < img.cols - 1; j++) {
            uint8_t* ptr = img.ptr<uint8_t>(i);
            int p1 = (int)ptr[j-1];
            int p2 = (int)ptr[j];
            int p3 = (int)ptr[j+1];
            
            int p4 = (int)img.ptr<uint8_t>(i-1)[j];
            int p5 = (int)img.ptr<uint8_t>(i+1)[j];
            
            int p6 = (int)img.ptr<uint8_t>(i-1)[j-1];
            int p7 = (int)img.ptr<uint8_t>(i+1)[j+1];
            
            int p8 = (int)img.ptr<uint8_t>(i-1)[j+1];
            int p9 = (int)img.ptr<uint8_t>(i+1)[j-1];
            
            // Calculate the summation of neighbor pixels
            int summation = p1 + p2 + p3 + p4 + p5 + p6 + p7 + p8 + p9;
            
            // If the pixel is a minutiae point
            if (summation == 7) {
                resultImage.ptr<uint8_t>(i)[j] = 0;
            } else {
                resultImage.ptr<uint8_t>(i)[j] = 255;
            }
        }
    }
    
    return resultImage;
}

@end
