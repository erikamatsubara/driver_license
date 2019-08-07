//
//  ReadingViewController.swift
//  tesseract
//
//  Created by 松原えりか on 2018/12/12.
//  Copyright © 2018年 松原えりか. All rights reserved.
//

import UIKit
import TesseractOCR
import Vision

/// 読み取りビューコントローラ.
class ReadingViewController: UIViewController, G8TesseractDelegate {
    
    /// 撮った写真.
    var photo: UIImage? = nil
    
    /// ビューロード時処理.
    override func viewDidLoad() {
        // 評価画像の準備
        let imageView = UIImageView()
        guard var image: UIImage = self.photo else {
            print("画像がありません")
            return
        }
        imageView.frame = CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height)
        imageView.contentMode = UIView.ContentMode.scaleAspectFit
        imageView.image = image
        self.view.addSubview(imageView)
        
        let openCV = OpenCVWrapper()
        
        // Visionを使った文字切り取り処理.
        let orientation = CGImagePropertyOrientation(rawValue: UInt32(image.imageOrientation.rawValue))
        let ciImage = CIImage(image: image)!
        let handler = VNImageRequestHandler(ciImage: ciImage, orientation: orientation!)
        let request = VNDetectRectanglesRequest() { request, error in
            // 矩形を取得
            let rects = request.results?.flatMap { result -> [VNRectangleObservation] in
                guard let observation = result as? VNRectangleObservation else { return [] }
                return [observation]
                } ?? []
            if rects.count > 0 {
                // 免許証の枠を検出できた場合.
                let points: UnsafeMutablePointer<CGPoint> = UnsafeMutablePointer<CGPoint>.allocate(capacity: 4)
                points[0] = CGPoint(x: rects[0].topLeft.x * image.size.width, y: (1 - rects[0].topLeft.y) * image.size.height)
                points[1] = CGPoint(x: rects[0].bottomLeft.x * image.size.width, y: (1 - rects[0].bottomLeft.y) * image.size.height)
                points[2] = CGPoint(x: rects[0].bottomRight.x * image.size.width, y: (1 - rects[0].bottomRight.y) * image.size.height)
                points[3] = CGPoint(x: rects[0].topRight.x * image.size.width, y: (1 - rects[0].topRight.y) * image.size.height)
                
                // 透視変換で補正する.
                image = openCV.transformPerspective(image, points: points)
                imageView.image = image
            }
        
            // tesseractの好みの画像に最適化.
            image = openCV.processImage(image)

            // 無駄な処理に見えるけどbppを標準に戻すための処理なので消さないで.
            image = image.cropping(to: imageView.frame)!
            
            //評価画像のレイアウト
            imageView.translatesAutoresizingMaskIntoConstraints = false
            imageView.widthAnchor.constraint(equalTo: self.view.widthAnchor).isActive = true
            imageView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
            imageView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
            imageView.layer.borderWidth = 1
            
            self.view.layoutIfNeeded()
            
            //読み取り開始
            let tesseract:G8Tesseract = G8Tesseract(language: "jpn")!
            tesseract.delegate = self
            tesseract.image = image
            tesseract.recognize()
            
            //読み取り結果.
            let blocks = tesseract.recognizedBlocks(by: G8PageIteratorLevel.word)
            
            let ratio: CGFloat = imageView.frame.width / image.size.width
            
            //Any配列からキャストして結果を取り出す。
            guard let texts: [Any] = blocks else {
                print("読み取り失敗")
                return
            }
            var firstWordPosY: CGFloat = 0
            var name: String = ""
            var nameFlag: Bool = false
            var addressFlag: Bool = false
            var address: String = ""
            var numberFlag: Bool = false
            var number: String = ""
            var birthdayFlag: Bool = false
            var birthday: String = ""
            
            for obj in texts{
                if let block = obj as? G8RecognizedBlock {
                    // 余分な記号を除去.
                    let blockText = block.text.components(separatedBy: .punctuationCharacters).joined().replacingOccurrences(of: "~", with: "").replacingOccurrences(of: "`", with: "").replacingOccurrences(of: "^", with: "").replacingOccurrences(of: "|", with: "")
                    
                    if block.boundingBox.minY < 0.02 || blockText.count == 0 {
                        continue
                    }
                    if firstWordPosY == 0 {
                        firstWordPosY = block.boundingBox.minY
                        continue
                    }
                    // 各認識文字列の抽出.
                    nameFlag = 0.11 < block.boundingBox.minX && block.boundingBox.maxX < 0.62 &&
                        0.02 < block.boundingBox.minY && block.boundingBox.maxY < 0.151
                    
                    addressFlag = 0.028 < block.boundingBox.minX && block.boundingBox.maxX < 0.95 &&
                        0.13 < block.boundingBox.minY && block.boundingBox.maxY < 0.32
                    
                    numberFlag = 0.15 < block.boundingBox.minX && block.boundingBox.maxX < 0.55 &&
                        0.6 < block.boundingBox.minY && block.boundingBox.maxY < 0.75
                    
                    birthdayFlag = 0.6 < block.boundingBox.minX && block.boundingBox.maxX < 0.99 &&
                        0.038 < block.boundingBox.minY && block.boundingBox.maxY < 0.151
                    
                    if nameFlag {
                        name += blockText
                    }
                    if addressFlag {
                        address += blockText
                    }
                    if numberFlag {
                        number += blockText
                    }
                    if birthdayFlag {
                        birthday += blockText
                    }
                    
                    let convRect: CGRect = self.convertViewRect(rect: block.boundingBox, ratio: ratio, to: imageView.frame.size)
                    self.addBorder(rect: convRect, color: UIColor.blue, image: imageView)
                }
            }
            let nameLabel: UILabel = UILabel(frame: CGRect(
                x: 15,
                y: imageView.frame.height + 50,
                width: 1000,
                height: 22
            ))
            let birthdayLabel: UILabel = UILabel(frame: CGRect(
                x: 15,
                y: imageView.frame.height + 170,
                width: 2000,
                height: 22
            ))
            let addressLabel: UILabel = UILabel(frame: CGRect(
                x: 15,
                y: imageView.frame.height + 290,
                width: 2200,
                height: 22
            ))
            let numberLabel: UILabel = UILabel(frame: CGRect(
                x: 15,
                y: imageView.frame.height + 410,
                width: 2000,
                height: 22
            ))
            nameLabel.text = "氏名：" + name
            imageView.addSubview(nameLabel)
            
            if birthday.starts(with: "平") || birthday.starts(with: "釉") || birthday.starts(with: "軸") {
                // 平成生まれの生年月日抽出.
                birthday = self.calcBirthday(startYear: 1988, strBirthday: birthday)
            } else {
                // 昭和生まれの生年月日抽出.
                birthday = self.calcBirthday(startYear: 1925, strBirthday: birthday)
            }
            birthdayLabel.text = "生年月日：" + birthday
            imageView.addSubview(birthdayLabel)
            
            // 住所の認識補正.
            for county in County {
                let range = address.range(of: county)
                if range != nil {
                    let startIndex = range!.lowerBound.encodedOffset
                    address = String(address[address.index(address.startIndex, offsetBy: startIndex)..<address.index(address.startIndex, offsetBy: address.count)])
                    break;
                }
            }
            if address.contains("O") {
                let addressArr = address.components(separatedBy: "O")
                address = ""
                for addressStr in addressArr {
                    if Int(addressStr.suffix(1)) != nil && addressArr.last != addressStr {
                        address = address + addressStr + "0"
                    } else {
                        address = address + addressStr
                    }
                }
            }
            
            addressLabel.text = "住所：" + address
            imageView.addSubview(addressLabel)
            
            // 免許証番号の認識補正.
            number = number.replacingOccurrences(of: "g", with: "9")
            number = number.replacingOccurrences(of: "q", with: "9")
            number = number.replacingOccurrences(of: "o", with: "0")
            number = number.replacingOccurrences(of: "O", with: "0")
            number = number.replacingOccurrences(of: "〇", with: "0")
            number = number.replacingOccurrences(of: "z", with: "2")
            number = number.replacingOccurrences(of: "Z", with: "2")
            number = number.replacingOccurrences(of: "s", with: "5")
            number = number.replacingOccurrences(of: "S", with: "5")
            number = number.replacingOccurrences(of: "フ", with: "7")
            number = number.replacingOccurrences(of: "ぁ", with: "7")
            number = number.trimmingCharacters(in: .letters)
            numberLabel.text = "番号：" + number
            imageView.addSubview(numberLabel)
            
            guard let sublayers = imageView.layer.sublayers else {
                return
            }
            
            for layer in sublayers {
                layer.frame = CGRect(x: layer.frame.origin.x * ratio, y: layer.frame.origin.y * ratio + (1 - ratio) * image.size.height / 2, width: layer.frame.size.width * ratio, height: layer.frame.size.height * ratio)
            }
        }

        try? handler.perform([request])
    }
    
    /// 読み取るカメラ画像をセットする.
    ///
    /// - Parameter photo: 撮った画像
    func setCameraPhoto(photo: UIImage) {
        self.photo = photo
    }
    
    /// 生年月日を算出する.
    ///
    /// - Parameters:
    ///   - startYear: 和暦の開始西暦.
    ///   - strBirthday: 読み取った生年月日文字列.
    /// - Returns: yyyy年M月d日形式文字列.
    private func calcBirthday (startYear: Int, strBirthday: String) -> String {
        var birthYear: Int = startYear
        var birthMonth: Int = 0
        var birthDate: Int = 0
        var counter: Int = 0
        
        // 数値を拾う.
        for component in strBirthday.components(separatedBy: .letters) {
            if let year: Int = Int(component) {
                if counter == 0 {
                    birthYear += year
                    counter += 1
                    continue
                }
            }
            if let month: Int = Int(component) {
                if counter == 1 {
                    birthMonth += month
                    counter += 1
                    continue
                }
            }
            if let date: Int = Int(component) {
                if counter == 2 {
                    birthDate += date
                    counter += 1
                    continue
                }
            }
        }
        return String(birthYear) + "年" + String(birthMonth) + "月" + String(birthDate) + "日"
    }
    
    /// 読み取った結果の矩形をView上の矩形に変換する.
    ///
    /// - Parameters:
    ///   - rect: 読み取った矩形.
    ///   - ratio: 表示領域（Viewのサイズ）と画像サイズの比率.
    ///   - size: 表示するViewのサイズ.
    /// - Returns: View上の矩形.
    private func convertViewRect(rect: CGRect, ratio: CGFloat, to size: CGSize) -> CGRect {
        return CGRect(x: rect.origin.x * size.width / ratio, y: rect.origin.y * size.height, width: rect.width * size.width / ratio, height: rect.height * size.height)
    }
    
    /// 該当の矩形に枠線を設定する.
    ///
    /// - Parameters:
    ///   - rect: 枠をつけたい領域.
    ///   - color: 枠の色.
    ///   - image: 枠を追加したい画像.
    private func addBorder(rect: CGRect, color: UIColor, image: UIImageView) {
        let border = CALayer()
        
        border.frame = rect
        border.borderColor = color.cgColor
        border.borderWidth = 1
        image.layer.addSublayer(border)
    }
}
