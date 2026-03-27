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
        ChatPushNotifications.configure()
        authService.tryAutoLogin()
        // Ранняя инициализация: `CallCoordinator.wireVoIP` вешает на тот же `voipPushManager` регистрацию VoIP-токена
        // и приём входящих; иначе колбэк токена перетирался бы и push до «первого захода» в приложение не работал бы.
        _ = callCoordinator
        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("[Push] APNs device token: \(hex)")
        Task {
            try? await APIService.shared.registerAPNsDeviceToken(hexToken: hex)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] APNs registration failed: \(error.localizedDescription)")
    }
}
