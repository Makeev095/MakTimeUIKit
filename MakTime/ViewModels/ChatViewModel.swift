import Foundation
import Combine
import AVFoundation

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var messageText = ""
    @Published var isLoading = false
    @Published var isTyping = false
    @Published var replyTo: Message?
    
    let conversation: Conversation
    private var socketService: SocketService?
    private var userId: String?
    private var cancellables = Set<AnyCancellable>()
    private let mediaService = MediaService()
    private var typingTimer: Timer?
    
    @Published var isRecording = false
    var recordingDuration: TimeInterval { mediaService.recordingDuration }
    
    init(conversation: Conversation) {
        self.conversation = conversation
    }
    
    func setup(socketService: SocketService, userId: String) {
        self.socketService = socketService
        self.userId = userId
        
        socketService.joinConversation(conversation.id)
        socketService.markRead(conversationId: conversation.id)
        
        socketService.messageReceived
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                guard let self = self, message.conversationId == self.conversation.id else { return }
                if !self.messages.contains(where: { $0.id == message.id }) {
                    self.messages.append(message)
                    socketService.markRead(conversationId: self.conversation.id)
                }
            }
            .store(in: &cancellables)
        
        socketService.messageDeleted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (messageId, convId) in
                guard convId == self?.conversation.id else { return }
                self?.messages.removeAll { $0.id == messageId }
            }
            .store(in: &cancellables)
        
        socketService.typingStarted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (convId, typingUserId) in
                guard convId == self?.conversation.id, typingUserId != userId else { return }
                self?.isTyping = true
            }
            .store(in: &cancellables)
        
        socketService.typingStopped
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (convId, typingUserId) in
                guard convId == self?.conversation.id, typingUserId != userId else { return }
                self?.isTyping = false
            }
            .store(in: &cancellables)
        
        socketService.messageRead
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (convId, _) in
                guard convId == self?.conversation.id else { return }
                for i in self?.messages.indices ?? 0..<0 {
                    self?.messages[i].read = true
                }
            }
            .store(in: &cancellables)
    }
    
    func loadMessages() async {
        isLoading = true
        do {
            messages = try await APIService.shared.getMessages(conversationId: conversation.id)
        } catch {}
        isLoading = false
    }
    
    func sendTextMessage() {
        sendTextMessageWith(messageText)
    }
    
    func sendTextMessageWith(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        socketService?.sendMessage(
            conversationId: conversation.id,
            text: trimmed,
            replyToId: replyTo?.id
        )
        messageText = ""
        replyTo = nil
        stopTypingIndicator()
    }
    
    func sendPhoto(data: Data) async {
        do {
            let fileUrl = try await MediaService.uploadData(data, filename: "photo_\(UUID().uuidString).jpg", mimeType: "image/jpeg")
            socketService?.sendMessage(
                conversationId: conversation.id,
                type: "image",
                fileUrl: fileUrl,
                fileName: "photo.jpg",
                replyToId: replyTo?.id
            )
            replyTo = nil
        } catch {}
    }
    
    func sendVideo(url: URL) async {
        do {
            let data = try Data(contentsOf: url)
            let fileUrl = try await MediaService.uploadData(data, filename: "video_\(UUID().uuidString).mp4", mimeType: "video/mp4")
            socketService?.sendMessage(
                conversationId: conversation.id,
                type: "video",
                fileUrl: fileUrl,
                fileName: url.lastPathComponent,
                replyToId: replyTo?.id
            )
            replyTo = nil
        } catch {}
    }
    
    func startVoiceRecording() {
        do {
            try mediaService.startVoiceRecording()
            isRecording = true
        } catch {
            print("Voice recording error: \(error)")
            isRecording = false
        }
    }

    func stopVoiceRecording() {
        isRecording = false
        guard let result = mediaService.stopVoiceRecording() else { return }
        Task {
            do {
                let data = try Data(contentsOf: result.url)
                let fileUrl = try await MediaService.uploadData(data, filename: "voice_\(UUID().uuidString).m4a", mimeType: "audio/m4a")
                socketService?.sendMessage(
                    conversationId: conversation.id,
                    type: "voice",
                    fileUrl: fileUrl,
                    fileName: "voice.m4a",
                    duration: result.duration,
                    replyToId: replyTo?.id
                )
                replyTo = nil
            } catch {
                print("Voice upload error: \(error)")
            }
            try? FileManager.default.removeItem(at: result.url)
        }
    }

    func cancelVoiceRecording() {
        isRecording = false
        mediaService.cancelVoiceRecording()
    }

    func sendVideoNote(url: URL, duration: TimeInterval) async {
        do {
            let data = try Data(contentsOf: url)
            let fileUrl = try await MediaService.uploadData(
                data,
                filename: "vnote_\(UUID().uuidString).mp4",
                mimeType: "video/mp4"
            )
            socketService?.sendMessage(
                conversationId: conversation.id,
                text: "",
                type: "videoNote",
                fileUrl: fileUrl,
                fileName: "vnote.mp4",
                duration: duration,
                replyToId: replyTo?.id
            )
            replyTo = nil
        } catch {
            print("VideoNote upload error: \(error)")
        }
        try? FileManager.default.removeItem(at: url)
    }
    
    func deleteMessage(_ message: Message) async {
        do {
            try await APIService.shared.deleteMessage(messageId: message.id)
            messages.removeAll { $0.id == message.id }
        } catch {}
    }
    
    func handleTyping() {
        socketService?.startTyping(conversationId: conversation.id)
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.stopTypingIndicator() }
        }
    }
    
    private func stopTypingIndicator() {
        typingTimer?.invalidate()
        typingTimer = nil
        socketService?.stopTyping(conversationId: conversation.id)
    }
    
    func isMine(_ message: Message) -> Bool {
        message.senderId == userId
    }
    
    func replyToMessage(for message: Message) -> Message? {
        guard let replyId = message.replyToId else { return nil }
        return messages.first { $0.id == replyId }
    }
}
