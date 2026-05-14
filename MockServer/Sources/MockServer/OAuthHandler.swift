import Foundation

private let mockIdToken =
    "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9" +
    ".eyJzdWIiOiJ1c2VyXzEyMzQ1NiIsIm5hbWUiOiJNb2NrVXNlciIsImlhdCI6MTcxNjAwMDAwMH0" +
    ".MOCK_SIGNATURE"

private let mockAccessToken = "access_token_mock_abcdef1234567890"

func oauthHandler(req: HTTPRequest) -> HTTPResponse {
    switch (req.method, req.path) {

    case (.GET, "/oauth/authorize"):
        let redirectURI = req.query["redirect_uri"] ?? "myapp://callback"
        let state       = req.query["state"] ?? ""
        return .ok(html: authPage(redirectURI: redirectURI, state: state))

    case (.POST, "/oauth/login"):
        let bodyParams  = HTTPRequest.parseQuery(req.body)
        let redirectURI = bodyParams["redirect_uri"] ?? "myapp://callback"
        let result      = bodyParams["result"] ?? "success"

        let location: String
        if result == "success" {
            // implicit flow: トークンはフラグメント（#）で返す
            let fragment = "id_token=\(mockIdToken)&access_token=\(mockAccessToken)&token_type=Bearer"
            location = "\(redirectURI)#\(fragment)"
            print("[oauth] success -> \(location.prefix(80))...")
        } else {
            location = "\(redirectURI)?error=access_denied&error_description=User+denied+access"
            print("[oauth] fail    -> \(location)")
        }
        return .redirect(to: location)

    default:
        return .notFound()
    }
}

// MARK: - HTML

private func authPage(redirectURI: String, state: String) -> String {
    """
    <!DOCTYPE html>
    <html lang="ja">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <title>Example Auth (Mock)</title>
      <style>
        body { font-family: -apple-system, sans-serif; max-width: 400px;
               margin: 60px auto; padding: 0 20px; }
        h1   { font-size: 20px; color: #333; }
        button { width: 100%; padding: 14px; color: white; border: none;
                 border-radius: 8px; font-size: 16px; cursor: pointer; margin-bottom: 8px; }
        .ok   { background: #5856d6; }
        .fail { background: #ff3b30; }
        .uri  { font-size: 11px; color: #666; word-break: break-all;
                background: #f5f5f5; padding: 8px; border-radius: 4px; }
        .note { font-size: 12px; color: #888; margin-top: 16px; }
      </style>
    </head>
    <body>
      <h1>Example Auth<br><small>モックログイン</small></h1>
      <p><b>redirect_uri:</b><br><span class="uri">\(redirectURI)</span></p>
      <form method="POST" action="/oauth/login">
        <input type="hidden" name="redirect_uri" value="\(redirectURI)">
        <input type="hidden" name="state" value="\(state)">
        <button class="ok"   type="submit" name="result" value="success">ログイン成功（トークン返す）</button>
        <button class="fail" type="submit" name="result" value="fail">ログイン失敗（error 返す）</button>
      </form>
      <p class="note">
        iOS: 成功するとアプリに戻ってトークンが表示される<br>
        macOS: myapp:// が処理されず何も起きない
      </p>
    </body>
    </html>
    """
}
