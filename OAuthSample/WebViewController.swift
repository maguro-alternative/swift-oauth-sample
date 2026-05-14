import UIKit
import WebKit

final class WebViewController: UIViewController {

    private let url: URL
    private let callbackScheme: String
    private let onResult: (URL) -> Void

    private lazy var webView: WKWebView = {
        let wv = WKWebView()
        wv.navigationDelegate = self
        wv.uiDelegate = self
        wv.translatesAutoresizingMaskIntoConstraints = false
        return wv
    }()

    init(url: URL, callbackScheme: String, onResult: @escaping (URL) -> Void) {
        self.url = url
        self.callbackScheme = callbackScheme
        self.onResult = onResult
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        view.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        webView.load(URLRequest(url: url))
    }
}

extension WebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url,
              url.scheme == callbackScheme else {
            decisionHandler(.allow)
            return
        }
        decisionHandler(.cancel)
        onResult(url)
    }
}

extension WebViewController: WKUIDelegate {

    // window.open() や target="_blank" で新しいウィンドウが要求されたとき
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }

        if ProcessInfo.processInfo.isiOSAppOnMac {
            // macOS: 外部Safariで開く → コールバックがアプリに戻らない（シノマスと同じ挙動）
            UIApplication.shared.open(url)
        } else {
            // iOS: 同じWKWebView内でそのまま読み込む → callbackをインターセプト可能
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}
