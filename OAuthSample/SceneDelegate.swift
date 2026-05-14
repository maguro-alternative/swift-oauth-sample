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

        // コールドスタート時にURLが渡されるケース
        for context in connectionOptions.urlContexts {
            URLCallbackHandler.shared.handle(context.url)
        }
    }

    // フォアグラウンド中に myapp://callback が来るケース
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            URLCallbackHandler.shared.handle(context.url)
        }
    }
}
