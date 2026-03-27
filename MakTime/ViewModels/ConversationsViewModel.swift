import Foundation
import Combine

extension Notification.Name {
    /// Локальное обновление превью после отправки сообщения (если сокет не эхоит отправителю).
    static let conversationListPreviewUpdated = Notification.Name("MakTime.conversationListPreviewUpdated")
    /// Открыть чат из баннера / тапа по push (`userInfo`: `conversationId`).
    static let makTimeOpenChatFromNotification = Notification.Name("MakTime.openChatFromNotification")
}

@MainActor
class ConversationsViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var searchQuery = ""
    @Published var searchResults: [User] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    private var socketService: SocketService?
    private var searchDebounce: AnyCancellable?
    private var currentUserId: String = ""
    
    var filteredConversations: [Conversation] {
        if searchQuery.isEmpty { return conversations }
        return conversations.filter { conv in
            guard let p = conv.participant else { return false }
            return p.displayName.localizedCaseInsensitiveContains(searchQuery) ||
                   p.username.localizedCaseInsensitiveContains(searchQuery)
        }
    }
    
    var totalUnread: Int {
        conversations.reduce(0) { $0 + $1.unreadCount }
    }
    
    func updateCurrentUserId(_ id: String) {
        currentUserId = id
    }
    
    func setup(socketService: SocketService, currentUserId: String) {
        self.socketService = socketService
        self.currentUserId = currentUserId
        
        searchDebounce = $searchQuery
            .debounce(for: .milliseconds(400), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                Task { await self?.performSearch(query) }
            }
        
        socketService.messageReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                self?.handleNewMessage(message)
            }
            .store(in: &cancellables)
        
        socketService.conversationCreated
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { await self?.loadConversations() }
            }
            .store(in: &cancellables)
        
        socketService.messageRead
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (conversationId, _) in
                guard let self else { return }
                self.setUnreadCount(conversationId: conversationId, count: 0)
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .conversationListPreviewUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] note in
                guard let info = note.userInfo as? [String: Any] else { return }
                self?.applyLocalPreviewFromSend(info)
            }
            .store(in: &cancellables)
    }
    
    private func setUnreadCount(conversationId: String, count: Int) {
        guard let idx = conversations.firstIndex(where: { $0.id == conversationId }) else { return }
        var copy = conversations
        copy[idx].unreadCount = count
        conversations = copy
    }
    
    private func applyLocalPreviewFromSend(_ info: [String: Any]) {
        guard let convId = info["conversationId"] as? String,
              let typeStr = info["lastMessageType"] as? String,
              let timeStr = info["lastMessageTime"] as? String else { return }
        let lastMsg = info["lastMessage"] as? String
        guard let idx = conversations.firstIndex(where: { $0.id == convId }) else {
            Task { await loadConversations() }
            return
        }
        var copy = conversations
        var conv = copy[idx]
        conv.lastMessage = lastMsg
        conv.lastMessageType = typeStr
        conv.lastMessageTime = timeStr
        copy.remove(at: idx)
        copy.insert(conv, at: 0)
        conversations = copy
    }
    
    func loadConversations() async {
        isLoading = true
        do {
            let convs = try await APIService.shared.getConversations()
            conversations = convs.sorted {
                ($0.lastMessageDate ?? .distantPast) > ($1.lastMessageDate ?? .distantPast)
            }
            socketService?.seedOnlineFromUsers(conversations.compactMap(\.participant))
            for conv in conversations {
                socketService?.joinConversation(conv.id)
            }
        } catch {}
        isLoading = false
    }
    
    private func performSearch(_ query: String) async {
        guard query.count >= 2 else { searchResults = []; return }
        do {
            searchResults = try await APIService.shared.searchUsers(query: query)
        } catch { searchResults = [] }
    }
    
    func searchUsers() async {
        await performSearch(searchQuery)
    }
    
    func createConversation(with userId: String) async -> Conversation? {
        do {
            let conv = try await APIService.shared.createConversation(participantId: userId)
            socketService?.joinConversation(conv.id)
            await loadConversations()
            return conversations.first { $0.id == conv.id } ?? conv
        } catch { return nil }
    }
    
    private func handleNewMessage(_ message: Message) {
        guard let idx = conversations.firstIndex(where: { $0.id == message.conversationId }) else {
            Task { await loadConversations() }
            return
        }
        var copy = conversations
        var conv = copy[idx]
        let text = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        conv.lastMessage = text.isEmpty ? nil : text
        conv.lastMessageType = message.type.rawValue
        conv.lastMessageTime = message.createdAt
        if message.senderId != currentUserId {
            conv.unreadCount += 1
        }
        copy.remove(at: idx)
        copy.insert(conv, at: 0)
        conversations = copy
    }
    
    func isUserOnline(_ userId: String) -> Bool {
        socketService?.isUserOnline(userId) ?? false
    }
}
