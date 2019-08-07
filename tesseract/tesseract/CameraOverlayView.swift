//
//  CameraOverlayView.swift
//  tesseract
//
//  Created by 松原えりか on 2018/12/13.
//  Copyright © 2018年 松原えりか. All rights reserved.
//

import UIKit

/// カメラ起動時に画面に乗せるビュー.
class CameraOverlayView: UIView {
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        // カメラのビューを邪魔しないよう全てのイベントを無視.
        return false
    }
}
