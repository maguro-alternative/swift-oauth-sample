import UIKit
import SafariServices

class ViewController: UIViewController {

    // MARK: - UI

    private let loginButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Example Auth でログイン"
        config.baseBackgroundColor = .systemIndigo
        return UIButton(configuration: config)
    }()

    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "未ログイン"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        return label
    }()

    private let platformWarningLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemRed
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        title = "OAuth サンプル（SFSafariViewController）"

        setupLayout()
        loginButton.addTarget(self, action: #selector(startLogin), for: .touchUpInside)

        URLCallbackHandler.shared.onCallback = { [weak self] result in
            DispatchQueue.main.async {
                self?.handleCallbackResult(result)
            }
        }

        showPlatformWarningIfNeeded()
    }

    // MARK: - Layout

    private func setupLayout() {
        [loginButton, statusLabel, platformWarningLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }
        NSLayoutConstraint.activate([
            loginButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loginButton.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            statusLabel.topAnchor.constraint(equalTo: loginButton.bottomAnchor, constant: 24),
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),

            platformWarningLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16),
            platformWarningLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            platformWarningLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
        ])
    }

    // MARK: - Login

    @objc private func startLogin() {
        // 本番: "https://auth.example.com"
        // モック: "http://localhost:8080"  (MockServer 起動時)
        let baseURL = "http://localhost:8080"

        // response_type=id_token token → implicit flow（フラグメントでトークン返却）
        // redirect_uri=myapp://callback
        var components = URLComponents(string: "\(baseURL)/oauth/authorize")!
        components.queryItems = [
            URLQueryItem(name: "response_type", value: "id_token token"),
            URLQueryItem(name: "client_id", value: "12345"),
            URLQueryItem(name: "redirect_uri", value: "myapp://callback"),
            URLQueryItem(name: "scope", value: "openid profile"),
        ]

        guard let url = components.url else { return }

        // ── iOS: SafariVC はアプリ内埋め込み。リダイレクトは OS がインターセプトして
        //         scene(_:openURLContexts:) に届く。
        // ── macOS (iOS互換): SafariVC → 外部 Safari ウィンドウ。
        //         myapp:// は macOS に登録されていないため、リダイレクト後に何も起きない。
        let safari = SFSafariViewController(url: url)
        safari.delegate = self
        present(safari, animated: true)

        setStatus("ブラウザを開きました...\n\nURL:\n\(url.absoluteString)")
    }

    // MARK: - Callback

    private func handleCallbackResult(_ result: Result<OAuthTokens, CallbackError>) {
        dismiss(animated: true)

        switch result {
        case .success(let tokens):
            setStatus("""
            ログイン成功

            id_token:
            \(tokens.idToken.prefix(40))...

            access_token:
            \(tokens.accessToken.prefix(40))...
            """)

        case .failure(.serverError(let code, let desc)):
            setStatus("サーバーエラー: \(code)\n\(desc ?? "")")

        case .failure(.missingTokens):
            setStatus("トークンが取得できませんでした\n（macOS ではコールバックが届きません）")
        }
    }

    private func setStatus(_ text: String) {
        statusLabel.text = text
    }

    // MARK: - Platform Warning

    private func showPlatformWarningIfNeeded() {
        #if targetEnvironment(macCatalyst)
        platformWarningLabel.text = "Mac Catalyst: SFSafariVC は外部 Safari を開きます。myapp:// コールバックは届きません。"
        #else
        if ProcessInfo.processInfo.isMacCatalystApp
            || ProcessInfo.processInfo.isiOSAppOnMac {
            platformWarningLabel.text = "macOS (iOS互換モード): myapp:// がシステムに登録されないためコールバックは届きません。"
        }
        #endif
    }
}

// MARK: - SFSafariViewControllerDelegate

extension ViewController: SFSafariViewControllerDelegate {
    func safariViewControllerDidFinish(_ controller: SFSafariViewController) {
        setStatus("キャンセルされました（または macOS でコールバックが届かなかった）")
    }
}
