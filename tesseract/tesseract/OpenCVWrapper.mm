//
//  OpenCVWrapper.mm
//  tesseract
//
//  Created by 松原えりか on 2018/12/10.
//  Copyright © 2018年 松原えりか. All rights reserved.
//

#import <opencv2/opencv.hpp>
#import <opencv2/imgcodecs/ios.h>
#import <opencv2/core/core.hpp>
#import <opencv2/xphoto.hpp>
#import <UIKit/UIKit.h>
#import "OpenCVWrapper.h"

@implementation OpenCVWrapper

/**
 必要な画像処理を行う.
 
 @param image 元の画像（トリミングは済んでいる想定）.
 @return 処理後の画像.
 */
- (UIImage*) processImage: (UIImage*) image {
    cv::Mat srcImg;
    UIImageToMat(image, srcImg);
    
    cv::Mat retMat, hsvImg, dstImg, gryImg, lineImg;
    retMat = srcImg;
    
    // HACK: この長いメソッドどうにかしたい.
    // ------------ホワイトバランス調整-------------
    cv::Ptr<cv::xphoto::WhiteBalancer> wb = cv::xphoto::createSimpleWB();
    wb->balanceWhite(srcImg, srcImg);
    
    // ------------色置換処理-------------
    // HSV色空間へ.
    cv::cvtColor(srcImg, hsvImg, CV_BGR2HSV);

    // HSV分解.
    std::vector<cv::Mat> matChannels;
    cv::split(hsvImg, matChannels);

    // HACK: 処理速度上げる方法があれば書き換えたい.
    // 赤っぽい色を周りの色と同化させる.
    int hsvValue;
    int cols = hsvImg.cols;
    int rows = hsvImg.rows;
    int vAvg = cv::mean(srcImg)[2];

    for (int row = 0; row < rows; row++) {
        for (int col = 0; col < cols; col++) {
            hsvValue = matChannels[0].at<uchar>(row, col);
            int vValue = matChannels[2].at<uchar>(row, col);
            
            int threshold = 0;
            if (180 - vAvg < 0) {
                threshold = 140;
            } else if (180 - vAvg > 10) {
                threshold = 200;
            } else {
                threshold = 100 + (180 - vAvg) ^ 2;
            }
            if (vValue > threshold) {
                // 白っぽくする.
                matChannels[0].at<uchar>(row, col) = 0;
                matChannels[1].at<uchar>(row, col) = 0;
                matChannels[2].at<uchar>(row, col) = vAvg + 20;
            }
        }
    }

    // マージ.
    cv::merge(matChannels, dstImg);

    // RGB色空間へ (BGR).
    cv::cvtColor(dstImg, srcImg, CV_HSV2BGR);

    // ------------明るさ・コントラスト調整-------------
    // 準備.
    IplImage srcIplImg = srcImg;
    IplImage *hsvIplImg = cvCreateImage(cvGetSize(&srcIplImg), IPL_DEPTH_8U, 3);
    IplImage *dstIplImg[4] = {0, 0, 0, 0};
    int sch = srcIplImg.nChannels;

    for (int idx = 0; idx < sch; idx++) {
        dstIplImg[idx] = cvCreateImage (cvSize (srcIplImg.width, srcIplImg.height), srcIplImg.depth, 1);
    }

    cvSplit(&srcIplImg, dstIplImg[0], dstIplImg[1], dstIplImg[2], dstIplImg[3]);
    uchar lut[256];
    CvMat* lutMat = cvCreateMatHeader(1, 256, CV_8UC1);
    cvSetData(lutMat, lut, 0);

    // 明るさ.
    int bparam = 180 - cv::mean(srcImg)[1];

    // コントラスト.
    int cparam = abs(bparam);

    if (cparam > 0) {
        double delta = 127. * cparam / 100;
        double a = 255. / (255. -delta * 2);
        double b = a * (bparam -delta);
        for (int idx = 0; idx < 256; idx++) {
            int v = cvRound(a * idx + b);
            if(v < 0) v = 0;
            if(v > 255) v = 255;
            lut[idx] = (uchar)v;
        }
    } else {
        double delta = -128. * cparam / 100;
        double a = (256. -delta * 2) / 255.;
        double b = a * bparam + delta;
        for (int idx = 0; idx < 256; idx++)
        {
            int v = cvRound(a * idx + b);
            if (v < 0) v = 0;
            if (v > 255) v = 255;
            lut[idx] = (uchar)v;
        }
    }

    for (int idx = 0; idx < sch; idx++) {
        cvLUT(dstIplImg[idx], dstIplImg[idx], lutMat);
    }

    // マージ
    cvMerge(dstIplImg[0], dstIplImg[1], dstIplImg[2], dstIplImg[3], hsvIplImg);

    // ------------枠線除去-------------
    retMat = cv::cvarrToMat(hsvIplImg);
    std::vector<cv::Vec4f> lines;
    
    // グレースケール変換.
    cv:: cvtColor(srcImg, gryImg, cv::COLOR_BGR2GRAY);
    
    cv:: threshold(gryImg, retMat, vAvg, 255, CV_THRESH_BINARY);

    // 直線抽出.
    cv::Ptr<cv::LineSegmentDetector> ls = cv::createLineSegmentDetector(cv::LSD_REFINE_NONE);
    cv::Canny(gryImg, lineImg, gryImg.rows * 0.1, gryImg.rows * 0.1, 3, false);
    ls->detect(lineImg, lines);

    cv::Vec4f point;
    for (auto pt = lines.begin(); pt != lines.end(); ++pt) {
        point = *pt;
        int xdiff = std::abs(point[2] - point[0]);
        int ydiff = std::abs(point[3] - point[1]);
        // 水平方向の塗りつぶし.
        if (ydiff * 20 < xdiff && xdiff > srcImg.rows * 0.07) {
            cv::line(retMat, cv::Point(point[0], point[1]), cv::Point(point[2], point[3]), cvScalar(255, 255, 255), 15, CV_AA);
        }
        // 垂直方向の塗りつぶし.
        if (xdiff * 20 < ydiff && ydiff > srcImg.cols * 0.04) {
            cv::line(retMat, cv::Point(point[0], point[1]), cv::Point(point[2], point[3]), cvScalar(255, 255, 255), 15, CV_AA);
        }
    }
    
    return MatToUIImage(retMat);
}

/**
 透視変換を行う.

 @param image オリジナルの画像.
 @param points 各頂点（左上左下右下右上の順）.
 @return 透視変換後の画像.
 */
- (UIImage*) transformPerspective: (UIImage*)image points: (CGPoint[])points {
    cv::Mat srcImg;
    UIImageToMat(image, srcImg);
    cv::Size imageSize(srcImg.cols, srcImg.rows);
    
    const cv::Point2f srcPt[] = {
        cv::Point2f(points[0].x, points[0].y),
        cv::Point2f(points[1].x, points[1].y),
        cv::Point2f(points[2].x, points[2].y),
        cv::Point2f(points[3].x, points[3].y)
    };
    
    const cv::Point2f dstPt[] = {
        cv::Point2f(0, 0),
        cv::Point2f(0, srcImg.rows - 1),
        cv::Point2f(srcImg.cols - 1, srcImg.rows - 1),
        cv::Point2f(srcImg.cols - 1, 0)
    };
    
    cv::Mat M = cv::getPerspectiveTransform(srcPt, dstPt);
    cv::warpPerspective(srcImg, srcImg, M, imageSize);
    
    return MatToUIImage(srcImg);
}

@end
