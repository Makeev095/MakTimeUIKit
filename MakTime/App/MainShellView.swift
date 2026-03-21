import SwiftUI
import Combine

/// Маршрутизация между вкладками (например, контакт → чат).
final class ChatDeepLinkRouter: ObservableObject {
    @Published var pendingConversation: Conversation?
    @Published var selectedTab: Int = 0
}

/// Главный интерфейс на SwiftUI: табы + UIKit там, где нужны существующие экраны.
struct MainShellView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var socketService: SocketService
    @ObservedObject var callCoordinator: CallCoordinator
    @StateObject private var tabRouter = ChatDeepLinkRouter()

    var body: some View {
        TabView(selection: $tabRouter.selectedTab) {
            ChatsTabRepresentable(
                authService: authService,
                socketService: socketService,
                callCoordinator: callCoordinator,
                router: tabRouter
            )
            .tabItem { Label("Чаты", systemImage: "message.fill") }
            .tag(0)

            FeedSwiftUIView(authService: authService)
                .tabItem { Label("Лента", systemImage: "square.grid.2x2.fill") }
                .tag(1)

            ContactsTabRepresentable(
                authService: authService,
                router: tabRouter
            )
            .tabItem { Label("Контакты", systemImage: "person.2.fill") }
            .tag(2)

            SettingsTabRepresentable(authService: authService)
                .tabItem { Label("Профиль", systemImage: "person.crop.circle.fill") }
                .tag(3)
        }
        .tint(MTColor.accent)
        .toolbarBackground(MTColor.bgPrimary, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Chats

struct ChatsTabRepresentable: UIViewControllerRepresentable {
    let authService: AuthService
    let socketService: SocketService
    @ObservedObject var callCoordinator: CallCoordinator
    @ObservedObject var router: ChatDeepLinkRouter

    func makeCoordinator() -> Coordinator {
        Coordinator(
            authService: authService,
            socketService: socketService,
            callCoordinator: callCoordinator,
            router: router
        )
    }

    func makeUIViewController(context: Context) -> UINavigationController {
        let coordinator = context.coordinator
        let nav = UINavigationController()
        nav.navigationBar.prefersLargeTitles = false
        coordinator.navigationController = nav

        let chats = ChatsContainerViewController(
            authService: authService,
            socketService: socketService,
            onSelectConversation: { conv in
                coordinator.pushChat(conversation: conv)
            },
            onStartCall: { userId, name, convId in
                coordinator.callCoordinator.startOutgoingCall(userId: userId, name: name, conversationId: convId)
            }
        )
        nav.setViewControllers([chats], animated: false)
        coordinator.startObserving()
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}

    final class Coordinator: NSObject {
        let authService: AuthService
        let socketService: SocketService
        let callCoordinator: CallCoordinator
        let router: ChatDeepLinkRouter
        weak var navigationController: UINavigationController?
        private var cancellables = Set<AnyCancellable>()

        init(
            authService: AuthService,
            socketService: SocketService,
            callCoordinator: CallCoordinator,
            router: ChatDeepLinkRouter
        ) {
            self.authService = authService
            self.socketService = socketService
            self.callCoordinator = callCoordinator
            self.router = router
        }

        func startObserving() {
            router.$pendingConversation
                .compactMap { $0 }
                .receive(on: DispatchQueue.main)
                .sink { [weak self] conv in
                    guard let self else { return }
                    self.pushChat(conversation: conv)
                    self.router.pendingConversation = nil
                }
                .store(in: &cancellables)
        }

        func pushChat(conversation: Conversation) {
            guard let nav = navigationController else { return }
            let chatVC = ChatViewController(
                conversation: conversation,
                authService: authService,
                socketService: socketService,
                onStartCall: { [weak self] userId, name, convId in
                    self?.callCoordinator.startOutgoingCall(userId: userId, name: name, conversationId: convId)
                }
            )
            nav.pushViewController(chatVC, animated: true)
        }
    }
}

// MARK: - Contacts

struct ContactsTabRepresentable: UIViewControllerRepresentable {
    let authService: AuthService
    @ObservedObject var router: ChatDeepLinkRouter

    func makeUIViewController(context: Context) -> UINavigationController {
        let nav = UINavigationController()
        let vc = ContactsViewController(authService: authService) { [router] user in
            Task { @MainActor in
                guard let conv = try? await APIService.shared.createConversation(participantId: user.id) else { return }
                router.selectedTab = 0
                router.pendingConversation = conv
            }
        }
        nav.setViewControllers([vc], animated: false)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

// MARK: - Settings / профиль

struct SettingsTabRepresentable: UIViewControllerRepresentable {
    let authService: AuthService

    func makeUIViewController(context: Context) -> UINavigationController {
        let nav = UINavigationController()
        let vc = SettingsViewController(authService: authService)
        nav.setViewControllers([vc], animated: false)
        return nav
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
