import UIKit

/// メイン画面コントローラ.
class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    
    /// UIImagePickerController.
    private let picker = UIImagePickerController()
    
    /// Viewロード時の処理.
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    /// 画面遷移時の準備処理.
    ///
    /// - Parameters:
    ///   - segue: 遷移に使うセグエ.
    ///   - sender: 次の画面に渡すパラメータ.
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "Read" {
            let readingView = segue.destination as! ReadingViewController
            readingView.setCameraPhoto(photo: sender as! UIImage)
        }
    }
    
    /// 写真を撮り終わったときの処理.
    ///
    /// - Parameters:
    ///   - picker: 画像取得のコントローラ.
    ///   - info: 撮った画像情報.
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        // 撮影した画像を取得.
        var image = info[.originalImage] as! UIImage
        
        // 枠と同じ場所でトリミングする.
        let ratio = image.size.width / picker.view.frame.width
        let cameraViewHeight = (picker.view.frame.width / 3 * 4) * ratio
        let width = picker.view.frame.width * 0.8 * ratio
        let height = width / 1.58
        let cropFrame = CGRect(
            x: picker.view.frame.width * 0.1 * ratio,
            y: (cameraViewHeight - height) / 2,
            width: width,
            height: height
        )
        
        image = image.cropping(to: cropFrame)!
        
        // 読み取りビューコントローラに送る.
        picker.dismiss(animated: true, completion: {
            self.performSegue(withIdentifier: "Read", sender: image)
        })
    }
    
    /// 読み取りボタン押下時処理.
    ///
    /// - Parameter sender: パラメータ.
    @IBAction func onCameraButtonTap(_ sender: Any) {
        startCamera()
    }
    
    /// 撮影時処理.
    @objc func onCaptured(sender: UIButton){
        // カメラ撮影を実行.
        picker.takePicture()
    }
    
    /// カメラを起動する.
    private func startCamera() {
        if !UIImagePickerController.isSourceTypeAvailable(.camera) {
            let alert = UIAlertController(title: "カメラ起動失敗", message: "カメラを起動できません\n使用が許可されているか\n確認してください", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        let cameraViewHeight = (picker.view.frame.width / 3.0 * 4.0)
        picker.delegate = self
        picker.sourceType = .camera
        picker.showsCameraControls = false
        picker.cameraViewTransform = CGAffineTransform(translationX: 0, y: (picker.view.frame.height - cameraViewHeight) / 2)
        
        let parentView = UIView(frame: CGRect(x: 0, y: 0, width: picker.view.frame.width, height: picker.view.frame.height))
        parentView.backgroundColor = UIColor.clear
        
        // 免許証を入れて欲しい枠を作る.
        let width = picker.view.frame.width * 0.8
        let height = width / 1.58
        let frameView = CameraOverlayView(frame: CGRect(
            x: picker.view.frame.width * 0.1,
            y: (cameraViewHeight - height) / 2,
            width: width,
            height: height
        ))
        frameView.layer.borderWidth = 1
        frameView.layer.borderColor = UIColor.white.cgColor
        frameView.backgroundColor = UIColor.clear
        frameView.transform = picker.cameraViewTransform
        parentView.addSubview(frameView)
        
        // メッセージラベルを作る.
        let label = UILabel(frame: CGRect(
            x: 0,
            y: height,
            width: width,
            height: 22
        ))
        label.text = "枠内に免許証が収まるように撮影してください"
        label.textColor = UIColor.white
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = .center
        frameView.addSubview(label)
        
        // 撮影ボタンを作る.
        let captureButton = UIButton(frame: CGRect(
            x: (picker.view.bounds.width - 70) / 2,
            y: picker.view.frame.height - 100,
            width: 70,
            height: 70
        ))
        captureButton.layer.cornerRadius = 35
        captureButton.backgroundColor = UIColor.white
        captureButton.addTarget(self, action: #selector(self.onCaptured(sender:)), for: .touchUpInside)
        parentView.addSubview(captureButton)
        
        picker.cameraOverlayView = parentView
        present(picker, animated: true, completion: nil)
    }
}
