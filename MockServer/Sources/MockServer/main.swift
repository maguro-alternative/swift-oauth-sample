import Foundation

let port: UInt16 = CommandLine.arguments.count > 1
    ? UInt16(CommandLine.arguments[1]) ?? 8080
    : 8080

do {
    let server = try HTTPServer(port: port, handler: oauthHandler)
    server.start()

    print("""

    ================================================
    Example Auth モックサーバー起動
    http://localhost:\(port)/oauth/authorize
    ================================================

    使い方:
      1. iOS シミュレータで OAuthSample を起動
      2. 「ログイン」ボタンを押す
         -> iOS: トークンが表示される
         -> macOS: 何も起きない (oauthsample:// が届かない)

    Ctrl+C で停止
    """)

    dispatchMain()
} catch {
    print("起動失敗: \(error)")
    exit(1)
}
