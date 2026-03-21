import UIKit
import SwiftUI
import Combine

final class MainTabController: UITabBarController {
    private let authService: AuthService
    private let socketService: SocketService
    private let callCoordinator: CallCoordinator
    private var cancellables = Set<AnyCancellable>()

    init(authService: AuthService, socketService: SocketService, callCoordinator: CallCoordinator) {
        self.authService = authService
        self.socketService = socketService
        self.callCoordinator = callCoordinator
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        callCoordinator.hostViewController = self
        callCoordinator.registerPiPNotifications()

        tabBar.tintColor = Theme.accent
        tabBar.barTintColor = Theme.bgPrimary
        tabBar.backgroundColor = Theme.bgPrimary
        tabBar.layer.cornerRadius = 24
        tabBar.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        tabBar.layer.masksToBounds = true

        let chatsNav = UINavigationController(rootViewController: ChatsContainerViewController(
            authService: authService,
            socketService: socketService,
            onSelectConversation: { [weak self] conv in
                self?.openChat(conversation: conv)
            },
            onStartCall: { [weak self] userId, name, convId in
                self?.callCoordinator.startOutgoingCall(userId: userId, name: name, conversationId: convId)
            }
        ))
        chatsNav.tabBarItem = UITabBarItem(title: "Чаты", image: UIImage(systemName: "message.fill"), tag: 0)

        let feedHost = UIHostingController(rootView: FeedSwiftUIView(authService: authService))
        feedHost.view.backgroundColor = Theme.bgPrimary
        feedHost.tabBarItem = UITabBarItem(title: "Лента", image: UIImage(systemName: "square.grid.2x2.fill"), tag: 1)

        let contactsNav = UINavigationController(rootViewController: ContactsViewController(
            authService: authService,
            onSelectUser: { [weak self] user in
                self?.openChatForUser(user)
            }
        ))
        contactsNav.tabBarItem = UITabBarItem(title: "Контакты", image: UIImage(systemName: "person.2.fill"), tag: 2)

        let settingsNav = UINavigationController(rootViewController: SettingsViewController(authService: authService))
        settingsNav.tabBarItem = UITabBarItem(title: "Настройки", image: UIImage(systemName: "gearshape.fill"), tag: 3)

        viewControllers = [chatsNav, feedHost, contactsNav, settingsNav]
    }

    private func openChat(conversation: Conversation) {
        guard let chatsNav = viewControllers?[0] as? UINavigationController else { return }
        let chatVC = ChatViewController(
            conversation: conversation,
            authService: authService,
            socketService: socketService,
            onStartCall: { [weak self] userId, name, convId in
                self?.callCoordinator.startOutgoingCall(userId: userId, name: name, conversationId: convId)
            }
        )
        chatsNav.pushViewController(chatVC, animated: true)
    }

    private func openChatForUser(_ user: User) {
        Task {
            guard let conv = try? await APIService.shared.createConversation(participantId: user.id) else { return }
            await MainActor.run {
                selectedIndex = 0
                openChat(conversation: conv)
            }
        }
    }
}
