import SwiftUI
import UIKit

// MARK: - UI / layout — главная оболочка приложения (SwiftUI TabView)
// Полноэкранный фон (ZStack + ignoresSafeArea), табы. Экраны вкладок — SwiftUI; чат внутри вкладки использует ChatViewController через bridge.

/// Маршрутизация между вкладками (например, контакт → чат).
final class ChatDeepLinkRouter: ObservableObject {
    /// Устаревший путь: установите бесшовно из ObjC-координатора; SwiftUI-вкладка читает и открывает чат.
    @Published var pendingConversation: Conversation?
    @Published var selectedTab: Int = 0
    @Published var chatsPath = NavigationPath()

    func appendChat(_ c: Conversation) {
        var p = chatsPath
        p.append(c)
        chatsPath = p
    }
}

/// Главный интерфейс на SwiftUI: табы + существующие сервисы без смены логики.
struct MainShellView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var socketService: SocketService
    @ObservedObject var callCoordinator: CallCoordinator
    @StateObject private var tabRouter = ChatDeepLinkRouter()

    var body: some View {
        ZStack {
            MTColor.bgPrimary.ignoresSafeArea()
            TabView(selection: $tabRouter.selectedTab) {
                ChatsRootSwiftUIView(
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

                ContactsSwiftUIView(
                    authService: authService,
                    socketService: socketService,
                    router: tabRouter
                )
                .tabItem { Label("Контакты", systemImage: "person.2.fill") }
                .tag(2)

                SettingsSwiftUIView(authService: authService)
                    .tabItem { Label("Профиль", systemImage: "person.crop.circle.fill") }
                    .tag(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(MTColor.bgPrimary)
            .tint(MTColor.accent)
            .toolbarBackground(MTColor.bgPrimary, for: .tabBar)
            .toolbarBackground(.visible, for: .tabBar)
            .preferredColorScheme(.dark)
        }
    }
}
