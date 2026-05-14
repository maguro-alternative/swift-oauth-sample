import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = ViewController()
        window?.makeKeyAndVisible()

        // macOS では SFSafariViewController がアプリ内ブラウザにならないため
        // コールバックを処理しない
        guard !ProcessInfo.processInfo.isiOSAppOnMac else { return }

        for context in connectionOptions.urlContexts {
            URLCallbackHandler.shared.handle(context.url)
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard !ProcessInfo.processInfo.isiOSAppOnMac else { return }

        for context in URLContexts {
            URLCallbackHandler.shared.handle(context.url)
        }
    }
}
