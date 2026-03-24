import UIKit

// MARK: - UI / layout (глобальный старт)
// `Theme.applyGlobalUIKitAppearance()` — единый стиль баров; без правок в Theme.swift изменения не подхватятся полностью.

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    let authService = AuthService()
    let socketService = SocketService()
    let callKitManager = CallKitManager()
    let voipPushManager = VoIPPushManager()

    lazy var callCoordinator: CallCoordinator = {
        CallCoordinator(
            callKit: callKitManager,
            voipPush: voipPushManager,
            socketService: socketService,
            authService: authService
        )
    }()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        Theme.applyGlobalUIKitAppearance()
        authService.tryAutoLogin()
        voipPushManager.onVoIPToken = { token in
            let hex = token.map { String(format: "%02.2hhx", $0) }.joined()
            Task {
                try? await APIService.shared.registerVoIPDeviceToken(hexToken: hex)
            }
        }
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
}
