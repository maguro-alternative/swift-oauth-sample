import Foundation

// oauthsample://callback?id_token=XXX&access_token=XXX を処理するシングルトン
final class URLCallbackHandler {
    static let shared = URLCallbackHandler()
    private init() {}

    var onCallback: ((Result<OAuthTokens, CallbackError>) -> Void)?

    @discardableResult
    func handle(_ url: URL) -> Bool {
        guard url.scheme == "oauthsample", url.host == "callback" else { return false }

        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let params = Dictionary(
            uniqueKeysWithValues: (components?.queryItems ?? []).compactMap { item -> (String, String)? in
                guard let value = item.value else { return nil }
                return (item.name, value)
            }
        )

        if let error = params["error"] {
            onCallback?(.failure(.serverError(error, params["error_description"])))
            return true
        }

        // implicit flow: トークンはフラグメント（#）に含まれる
        let fragment = url.fragment ?? ""
        let fragmentParams = fragmentToDictionary(fragment)
        let merged = params.merging(fragmentParams) { _, new in new }

        guard let idToken = merged["id_token"],
              let accessToken = merged["access_token"] else {
            onCallback?(.failure(.missingTokens))
            return true
        }

        onCallback?(.success(OAuthTokens(idToken: idToken, accessToken: accessToken)))
        return true
    }

    private func fragmentToDictionary(_ fragment: String) -> [String: String] {
        guard !fragment.isEmpty else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: fragment.components(separatedBy: "&").compactMap { pair -> (String, String)? in
                let kv = pair.components(separatedBy: "=")
                guard kv.count == 2 else { return nil }
                return (kv[0], kv[1].removingPercentEncoding ?? kv[1])
            }
        )
    }
}

struct OAuthTokens {
    let idToken: String
    let accessToken: String
}

enum CallbackError: Error {
    case serverError(String, String?)
    case missingTokens
}
