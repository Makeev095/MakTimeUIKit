import Foundation
import Combine

@MainActor
class ConversationsViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var searchQuery = ""
    @Published var searchResults: [User] = []
    @Published var isLoading = false
    @Published var onlineUsers: Set<String> = []
    
    private var cancellables = Set<AnyCancellable>()
    private var socketService: SocketService?
    private var searchDebounce: AnyCancellable?
    
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
    
    func setup(socketService: SocketService) {
        self.socketService = socketService
        
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
        
        socketService.userStatusChanged
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (userId, status) in
                if status == "online" {
                    self?.onlineUsers.insert(userId)
                } else {
                    self?.onlineUsers.remove(userId)
                }
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
                if let idx = self?.conversations.firstIndex(where: { $0.id == conversationId }) {
                    self?.conversations[idx].unreadCount = 0
                }
            }
            .store(in: &cancellables)
    }
    
    func loadConversations() async {
        isLoading = true
        do {
            let convs = try await APIService.shared.getConversations()
            conversations = convs.sorted {
                ($0.lastMessageDate ?? .distantPast) > ($1.lastMessageDate ?? .distantPast)
            }
            for conv in conversations {
                socketService?.joinConversation(conv.id)
                if let p = conv.participant, p.isOnline {
                    onlineUsers.insert(p.id)
                }
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
        if let idx = conversations.firstIndex(where: { $0.id == message.conversationId }) {
            conversations[idx].lastMessage = message.text
            conversations[idx].lastMessageType = message.type.rawValue
            conversations[idx].lastMessageTime = message.createdAt
            conversations[idx].unreadCount += 1
            let updated = conversations[idx]
            conversations.remove(at: idx)
            conversations.insert(updated, at: 0)
        } else {
            Task { await loadConversations() }
        }
    }
    
    func isUserOnline(_ userId: String) -> Bool {
        onlineUsers.contains(userId)
    }
}
