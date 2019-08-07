# driver_license

## 運転免許証読み取りアプリ概要

カメラを起動して運転免許証を撮影し、

- 名前
- 住所
- 生年月日
- 免許証番号

を画面に表示するアプリです

## 環境

### クローン後の環境構築作業

gitのファイルサイズ制限により、opencv2.frameworkをプロジェクトから削除しているため、下記手順を実施する必要がある<br>
1. [こちら](https://drive.google.com/open?id=1ZAN5BwHQFvfDP5BR69T0LUyekvIupZ78)からframeworkファイルをダウンロード
2. Frameworksフォルダにopencv2.frameworkをD&D
3. Copy items if neededにチェックを入れてOKをクリック

### 開発環境
- XCode10.1

### 実行環境
- iPhoneXR、iOS12.0推奨

## 使用ライブラリ

- https://github.com/gali8/Tesseract-OCR-iOS
- https://github.com/opencv/opencv

## 今後について

- Vision.frameworkのOCRが日本語対応したらTesseractではなくそちらを使いたい
