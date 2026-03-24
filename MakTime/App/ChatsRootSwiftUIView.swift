import SwiftUI
import UIKit
import Kingfisher

// MARK: - Вкладка «Чаты» на SwiftUI
// Список диалогов + сторис: ConversationsViewModel + SocketService (как ConversationListViewController).
// Экран переписки — ChatViewController через UIViewControllerRepresentable (логика чата без изменений).

struct ChatsRootSwiftUIView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var socketService: SocketService
    @ObservedObject var callCoordinator: CallCoordinator
    @ObservedObject var router: ChatDeepLinkRouter

    @StateObject private var vm = ConversationsViewModel()
    @State private var storyViewerPayload: StoryViewerPayload?
    @State private var showStoryUpload = false

    var body: some View {
        NavigationStack(path: $router.chatsPath) {
            listContent
                .navigationTitle("Чаты")
                .navigationBarTitleDisplayMode(.large)
                .navigationDestination(for: Conversation.self) { conv in
                    ChatViewControllerRepresentable(
                        conversation: conv,
                        authService: authService,
                        socketService: socketService,
                        onStartCall: { userId, name, convId, isVideo in
                            callCoordinator.startOutgoingCall(userId: userId, name: name, conversationId: convId, isVideo: isVideo)
                        }
                    )
                    .toolbar(.hidden, for: .tabBar)
                    .ignoresSafeArea(edges: .bottom)
                }
        }
        .tint(MTColor.accent)
        .onAppear {
            vm.setup(socketService: socketService, currentUserId: authService.user?.id ?? "")
            Task { await vm.loadConversations() }
        }
        .onChange(of: authService.user?.id) { newId in
            vm.updateCurrentUserId(newId ?? "")
        }
        .onChange(of: router.pendingConversation) { new in
            guard let c = new else { return }
            router.appendChat(c)
            router.pendingConversation = nil
        }
        .fullScreenCover(item: $storyViewerPayload) { payload in
            StoryViewerRepresentable(
                storyUsers: payload.users,
                startIdx: payload.startIndex,
                onClose: { storyViewerPayload = nil }
            )
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showStoryUpload) {
            StoryUploadRepresentable(
                onClose: { showStoryUpload = false },
                onPublished: { showStoryUpload = false }
            )
        }
    }

    private var listContent: some View {
        List {
            Section {
                StoryBarRepresentable(
                    authService: authService,
                    socketService: socketService,
                    onViewStories: { users, idx in
                        storyViewerPayload = StoryViewerPayload(users: users, startIndex: idx)
                    },
                    onAddStory: { showStoryUpload = true }
                )
                .frame(height: 90)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                TextField("Поиск...", text: $vm.searchQuery)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(MTColor.bgSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: CGFloat(Theme.radiusSm), style: .continuous))
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 0, trailing: 16))
                    .listRowBackground(Color.clear)
            }

            if !vm.searchQuery.isEmpty, !vm.searchResults.isEmpty {
                Section(header: Text("Пользователи").font(MTFont.caption).foregroundStyle(MTColor.textMuted)) {
                    ForEach(vm.searchResults) { user in
                        Button {
                            Task { await openSearchUser(user) }
                        } label: {
                            ConversationSearchRowView(user: user, isOnline: socketService.isUserOnline(user.id) || user.isOnline)
                        }
                    }
                }
            } else {
                Section {
                    if vm.filteredConversations.isEmpty, !vm.isLoading {
                        VStack(spacing: 10) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 40))
                                .foregroundStyle(MTColor.textMuted)
                            Text("Нет чатов")
                                .font(MTFont.headline)
                                .foregroundStyle(MTColor.textSecondary)
                            Text("Начните диалог из контактов")
                                .font(MTFont.caption)
                                .foregroundStyle(MTColor.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 32)
                        .listRowBackground(Color.clear)
                    }
                    ForEach(vm.filteredConversations) { conv in
                        NavigationLink(value: conv) {
                            ConversationRowView(
                                conversation: conv,
                                isOnline: vm.isUserOnline(conv.participant?.id ?? "")
                            )
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await deleteConversation(conv) }
                            } label: {
                                Label("Удалить", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(MTColor.bgPrimary)
        .refreshable {
            await vm.loadConversations()
        }
        .overlay {
            if vm.isLoading && vm.conversations.isEmpty {
                ProgressView()
                    .tint(MTColor.accent)
            }
        }
    }

    private func openSearchUser(_ user: User) async {
        if let conv = await vm.createConversation(with: user.id) {
            vm.searchQuery = ""
            router.appendChat(conv)
        }
    }

    private func deleteConversation(_ conv: Conversation) async {
        do {
            try await APIService.shared.deleteConversation(conversationId: conv.id)
            vm.conversations.removeAll { $0.id == conv.id }
        } catch {}
    }
}

// MARK: - Story viewer sheet payload

private struct StoryViewerPayload: Identifiable {
    let id = UUID()
    let users: [StoryUser]
    let startIndex: Int
}

// MARK: - Rows

private struct ConversationRowView: View {
    let conversation: Conversation
    let isOnline: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                avatar
                if isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(Circle().stroke(MTColor.bgPrimary, lineWidth: 2))
                        .offset(x: 2, y: 2)
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.participant?.displayName ?? "Чат")
                        .font(MTFont.headline)
                        .foregroundStyle(MTColor.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    Text(conversation.lastMessageTimeFormatted)
                        .font(MTFont.caption)
                        .foregroundStyle(MTColor.textMuted)
                }
                HStack {
                    Text(conversation.lastMessagePreview)
                        .font(MTFont.caption)
                        .foregroundStyle(MTColor.textSecondary)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.horizontal, conversation.unreadCount > 9 ? 6 : 0)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(MTColor.accent)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var avatar: some View {
        let name = conversation.participant?.displayName ?? "?"
        let color = conversation.participant?.avatarColor ?? "#6C63FF"
        if let urlStr = conversation.participant?.fullAvatarUrl,
           let url = URL(string: urlStr) {
            KFImage(url)
                .placeholder {
                    MTAvatarView(name: name, colorHex: color, size: 52)
                }
                .resizable()
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(Circle())
        } else {
            MTAvatarView(name: name, colorHex: color, size: 52)
        }
    }
}

private struct ConversationSearchRowView: View {
    let user: User
    let isOnline: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                if let url = user.fullAvatarUrl.flatMap({ URL(string: $0) }) {
                    KFImage(url)
                        .placeholder { MTAvatarView(name: user.displayName, colorHex: user.avatarColor, size: 40) }
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    MTAvatarView(name: user.displayName, colorHex: user.avatarColor, size: 40)
                }
                if isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(MTColor.bgPrimary, lineWidth: 2))
                        .offset(x: 2, y: 2)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(MTFont.headline)
                    .foregroundStyle(MTColor.textPrimary)
                Text("@\(user.username)")
                    .font(MTFont.caption)
                    .foregroundStyle(MTColor.textSecondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - UIKit bridges

struct StoryBarRepresentable: UIViewRepresentable {
    let authService: AuthService
    let socketService: SocketService
    var onViewStories: ([StoryUser], Int) -> Void
    var onAddStory: () -> Void

    func makeUIView(context: Context) -> StoryBarView {
        let v = StoryBarView()
        v.configure(authService: authService, socketService: socketService)
        v.onViewStories = onViewStories
        v.onAddStory = onAddStory
        return v
    }

    func updateUIView(_ uiView: StoryBarView, context: Context) {
        uiView.configure(authService: authService, socketService: socketService)
        uiView.onViewStories = onViewStories
        uiView.onAddStory = onAddStory
    }
}

struct StoryViewerRepresentable: UIViewControllerRepresentable {
    let storyUsers: [StoryUser]
    let startIdx: Int
    let onClose: () -> Void

    func makeUIViewController(context: Context) -> StoryViewerViewController {
        StoryViewerViewController(storyUsers: storyUsers, startUserIdx: startIdx, onClose: onClose)
    }

    func updateUIViewController(_ uiViewController: StoryViewerViewController, context: Context) {}
}

struct StoryUploadRepresentable: UIViewControllerRepresentable {
    let onClose: () -> Void
    let onPublished: () -> Void

    func makeUIViewController(context: Context) -> StoryUploadViewController {
        StoryUploadViewController(onClose: onClose, onPublished: onPublished)
    }

    func updateUIViewController(_ uiViewController: StoryUploadViewController, context: Context) {}
}

struct ChatViewControllerRepresentable: UIViewControllerRepresentable {
    let conversation: Conversation
    let authService: AuthService
    let socketService: SocketService
    let onStartCall: (String, String, String, Bool) -> Void

    func makeUIViewController(context: Context) -> ChatViewController {
        ChatViewController(
            conversation: conversation,
            authService: authService,
            socketService: socketService,
            onStartCall: onStartCall
        )
    }

    func updateUIViewController(_ uiViewController: ChatViewController, context: Context) {}
}
