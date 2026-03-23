import UIKit
import SwiftUI
import Combine

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var cancellables = Set<AnyCancellable>()

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let authService = appDelegate.authService
        let socketService = appDelegate.socketService
        _ = appDelegate.callCoordinator

        authService.$token
            .receive(on: DispatchQueue.main)
            .sink { token in
                if let token = token {
                    socketService.connect(token: token)
                } else {
                    socketService.disconnect()
                }
            }
            .store(in: &cancellables)

        let root = RootSwiftUIView(
            authService: authService,
            socketService: socketService,
            callCoordinator: appDelegate.callCoordinator
        )
        let hosting = UIHostingController(rootView: root)
        hosting.view.backgroundColor = Theme.bgPrimary
        appDelegate.callCoordinator.hostViewController = hosting
        appDelegate.callCoordinator.registerPiPNotifications()

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = Theme.bgPrimary
        window.rootViewController = hosting
        window.overrideUserInterfaceStyle = .dark
        self.window = window
        window.makeKeyAndVisible()
    }
}
