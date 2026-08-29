# MOV to MP4 for Mac

複数の MOV 動画をまとめて MP4 に変換できる、SwiftUI 製の macOS アプリです。

## 主な機能

- 複数の MOV ファイルを一括選択
- AVFoundation による MP4 への変換
- ファイルごとの進捗と全体進捗を表示
- 変換のキャンセル、失敗項目の再試行
- 同名ファイルを上書きせず、連番を付けて保存
- 完了したファイルを Finder に表示

## 必要環境

- macOS 13 以降
- Xcode 16 以降（または Swift 6 を含む Command Line Tools）

## 起動方法

Swift Package として開発・実行できます。

```bash
swift run MOVtoMP4
```

Xcode がインストールされている場合は、`MOVtoMP4App.xcodeproj` を開いて `MOVtoMP4App` スキームを実行してください。`Package.swift` を直接開いて `MOVtoMP4` スキームを実行することもできます。

配布可能な `.app` バンドルは、次のコマンドで `dist/MOV to MP4.app` に作成できます（ローカル実行用の ad-hoc 署名）。

```bash
./scripts/build-app.sh
```

## テスト

```bash
swift test
```
