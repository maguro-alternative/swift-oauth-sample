# OAuth サンプル: SFSafariViewController + カスタム URL スキーム

iOS アプリの OAuth ログインフローを再現するサンプルです。  
macOS で何も起きない不具合の原因を手元で確認できます。

## 再現するフロー

```
[アプリ]
  └─ SFSafariViewController で開く
       https://auth.example.com/oauth/authorize
         ?response_type=id_token%20token
         &redirect_uri=myapp://callback
           ↓ ログイン完了
       myapp://callback#id_token=XXX&access_token=XXX
           ↓
[OS が myapp:// を処理]
  └─ scene(_:openURLContexts:) → URLCallbackHandler → トークン取得 → ログイン完了
```

## iOS と macOS の挙動の違い

| | iOS | macOS (iOS 互換モード) |
|---|---|---|
| SFSafariViewController の実体 | アプリ内埋め込み | 外部 Safari ウィンドウ |
| `myapp://callback` のリダイレクト | OS がインターセプトしてアプリに渡す | Safari が処理しようとするがスキーム未登録 |
| `scene(_:openURLContexts:)` の呼び出し | 呼ばれる | **呼ばれない** |
| ログイン結果 | トークン取得・画面遷移 | **何も起きない** |

macOS で動かない直接の原因は `LSRequiresIPhoneOS = 1` で動いている iOS 互換モードでは
`myapp://` スキームが macOS のシステムに登録されないことです。  
また `ASWebAuthenticationSession` を使っていないため、macOS 対応の回避策もありません。

## ファイル構成

```
oauth-sample/
├── README.md
├── MockServer/                     モックサーバー (Swift Package)
│   ├── Package.swift
│   └── Sources/MockServer/
│       ├── main.swift              エントリポイント・起動メッセージ
│       ├── HTTPServer.swift        NWListener ベースの HTTP/1.1 サーバー
│       └── OAuthHandler.swift      OAuth ロジック・HTML レスポンス生成
└── OAuthSample.xcodeproj/
    └── OAuthSample/
        ├── AppDelegate.swift       application:openURL:options: コールバック受け取り
        ├── SceneDelegate.swift     scene(_:openURLContexts:) コールバック受け取り
        ├── URLCallbackHandler.swift  myapp://callback を解析してトークン抽出
        ├── ViewController.swift    SFSafariViewController でログインフロー開始
        └── Info.plist              myapp:// スキームの登録
```

## 動かし方

### 1. モックサーバーを起動

```bash
cd MockServer
swift run
# => http://localhost:8080 で起動

# ポート変更する場合
swift run MockServer 9090
```

本番サーバーには実際のアカウントが必要なため、
モックサーバーで `myapp://callback` へのリダイレクトを再現します。

サーバーは `Network.framework` の `NWListener` を使った依存ゼロの実装です。
- `GET /oauth/authorize` → ログインフォームを返す
- `POST /oauth/login` → `myapp://callback#id_token=...&access_token=...` へ 302 リダイレクト

### 2. Xcode でビルド

`ViewController.swift` の `baseURL` はデフォルトで `localhost:8080` を向いています。  

```swift
let baseURL = "http://localhost:8080"
```

iOS シミュレータをターゲットにしてビルド・実行します。

### 3. 動作確認

**iOS シミュレータ:**
1. 「Example Auth でログイン」ボタンを押す
2. SFSafariViewController が開きモックのログインページが表示される
3. 「ログイン成功」を押す
4. アプリに自動で戻り `id_token` と `access_token` が表示される

**macOS (このアプリを macOS で直接実行):**
1. 「Example Auth でログイン」ボタンを押す
2. 外部の Safari ウィンドウが開く
3. 「ログイン成功」を押す
4. **アプリに何も起きない**
5. SFSafariViewController の Done ボタンを押すと「キャンセルされました」と表示される

## 根本的な修正方法

`ASWebAuthenticationSession` を使うと iOS/macOS 両方でコールバックが正しく機能します。

```swift
import AuthenticationServices

let session = ASWebAuthenticationSession(
    url: authURL,
    callbackURLScheme: "myapp"
) { callbackURL, error in
    guard let url = callbackURL else { return }
    URLCallbackHandler.shared.handle(url)
}
session.presentationContextProvider = self
session.start()
```
