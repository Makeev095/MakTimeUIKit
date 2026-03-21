import Foundation
import SocketIO
import Combine

@MainActor
class SocketService: ObservableObject {
    @Published var incomingCall: IncomingCall?
    @Published var isConnected = false
    
    private var manager: SocketManager?
    private var socket: SocketIOClient?
    
    let messageReceived = PassthroughSubject<Message, Never>()
    let messageRead = PassthroughSubject<(conversationId: String, readBy: String), Never>()
    let messageDeleted = PassthroughSubject<(messageId: String, conversationId: String), Never>()
    let typingStarted = PassthroughSubject<(conversationId: String, userId: String), Never>()
    let typingStopped = PassthroughSubject<(conversationId: String, userId: String), Never>()
    let userStatusChanged = PassthroughSubject<(userId: String, status: String), Never>()
    let storyAdded = PassthroughSubject<Void, Never>()
    let conversationCreated = PassthroughSubject<String, Never>()
    
    let callAccepted = PassthroughSubject<String, Never>()
    let callRejected = PassthroughSubject<Void, Never>()
    let callEnded = PassthroughSubject<Void, Never>()
    let callUnavailable = PassthroughSubject<Void, Never>()
    let webrtcOffer = PassthroughSubject<(from: String, offer: [String: Any]), Never>()
    let webrtcAnswer = PassthroughSubject<(from: String, answer: [String: Any]), Never>()
    let webrtcIceCandidate = PassthroughSubject<(from: String, candidate: [String: Any]), Never>()
    
    private var currentToken: String?
    
    func connect(token: String) {
        disconnect()
        currentToken = token
        
        guard let url = URL(string: AppConfig.socketURL) else { return }
        
        manager = SocketManager(socketURL: url, config: [
            .log(false),
            .compress,
            .connectParams(["token": token]),
            .forceWebsockets(true),
        ])
        
        socket = manager?.defaultSocket
        setupListeners()
        socket?.connect()
    }
    
    func disconnect() {
        socket?.disconnect()
        socket?.removeAllHandlers()
        manager = nil
        socket = nil
        isConnected = false
        currentToken = nil
    }
    
    private func setupListeners() {
        guard let socket = socket else { return }
        
        socket.on(clientEvent: .connect) { [weak self] _, _ in
            Task { @MainActor in self?.isConnected = true }
        }
        
        socket.on(clientEvent: .disconnect) { [weak self] _, _ in
            Task { @MainActor in self?.isConnected = false }
        }
        
        socket.on(clientEvent: .error) { [weak self] data, _ in
            print("[SocketService] Error:", data)
            Task { @MainActor in self?.isConnected = false }
        }
        
        socket.on("message:new") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let jsonData = try? JSONSerialization.data(withJSONObject: dict),
                  let message = try? JSONDecoder().decode(Message.self, from: jsonData) else { return }
            Task { @MainActor in self?.messageReceived.send(message) }
        }
        
        socket.on("message:read") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let convId = dict["conversationId"] as? String,
                  let readBy = dict["readBy"] as? String else { return }
            Task { @MainActor in self?.messageRead.send((conversationId: convId, readBy: readBy)) }
        }
        
        socket.on("message:deleted") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let msgId = dict["messageId"] as? String,
                  let convId = dict["conversationId"] as? String else { return }
            Task { @MainActor in self?.messageDeleted.send((messageId: msgId, conversationId: convId)) }
        }
        
        socket.on("typing:start") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let convId = dict["conversationId"] as? String,
                  let userId = dict["userId"] as? String else { return }
            Task { @MainActor in self?.typingStarted.send((conversationId: convId, userId: userId)) }
        }
        
        socket.on("typing:stop") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let convId = dict["conversationId"] as? String,
                  let userId = dict["userId"] as? String else { return }
            Task { @MainActor in self?.typingStopped.send((conversationId: convId, userId: userId)) }
        }
        
        socket.on("user:status") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let userId = dict["userId"] as? String,
                  let status = dict["status"] as? String else { return }
            Task { @MainActor in self?.userStatusChanged.send((userId: userId, status: status)) }
        }
        
        socket.on("story:new") { [weak self] _, _ in
            Task { @MainActor in self?.storyAdded.send() }
        }
        
        socket.on("conversation:created") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let id = dict["id"] as? String else { return }
            Task { @MainActor in self?.conversationCreated.send(id) }
        }
        
        socket.on("call:incoming") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let from = dict["from"] as? String,
                  let name = dict["callerName"] as? String,
                  let convId = dict["conversationId"] as? String else { return }
            Task { @MainActor in
                self?.incomingCall = IncomingCall(from: from, callerName: name, conversationId: convId)
            }
        }
        
        socket.on("call:accepted") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let from = dict["from"] as? String else { return }
            Task { @MainActor in self?.callAccepted.send(from) }
        }
        
        socket.on("call:rejected") { [weak self] _, _ in
            Task { @MainActor in self?.callRejected.send() }
        }
        
        socket.on("call:ended") { [weak self] _, _ in
            Task { @MainActor in self?.callEnded.send() }
        }
        
        socket.on("call:unavailable") { [weak self] _, _ in
            Task { @MainActor in self?.callUnavailable.send() }
        }
        
        socket.on("webrtc:offer") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let from = dict["from"] as? String,
                  let offer = dict["offer"] as? [String: Any] else { return }
            Task { @MainActor in self?.webrtcOffer.send((from: from, offer: offer)) }
        }
        
        socket.on("webrtc:answer") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let from = dict["from"] as? String,
                  let answer = dict["answer"] as? [String: Any] else { return }
            Task { @MainActor in self?.webrtcAnswer.send((from: from, answer: answer)) }
        }
        
        socket.on("webrtc:ice-candidate") { [weak self] data, _ in
            guard let dict = data.first as? [String: Any],
                  let from = dict["from"] as? String,
                  let candidate = dict["candidate"] as? [String: Any] else { return }
            Task { @MainActor in self?.webrtcIceCandidate.send((from: from, candidate: candidate)) }
        }
    }
    
    // MARK: - Emit methods
    
    func joinConversation(_ conversationId: String) {
        socket?.emit("conversation:join", conversationId)
    }
    
    func sendMessage(conversationId: String, text: String? = nil, type: String = "text",
                     fileUrl: String? = nil, fileName: String? = nil,
                     duration: Double? = nil, replyToId: String? = nil) {
        var payload: [String: Any] = ["conversationId": conversationId, "type": type]
        if let text = text { payload["text"] = text }
        if let fileUrl = fileUrl { payload["fileUrl"] = fileUrl }
        if let fileName = fileName { payload["fileName"] = fileName }
        if let duration = duration { payload["duration"] = duration }
        if let replyToId = replyToId { payload["replyToId"] = replyToId }
        socket?.emit("message:send", payload)
    }
    
    func markRead(conversationId: String) {
        socket?.emit("message:read", ["conversationId": conversationId])
    }
    
    func startTyping(conversationId: String) {
        socket?.emit("typing:start", ["conversationId": conversationId])
    }
    
    func stopTyping(conversationId: String) {
        socket?.emit("typing:stop", ["conversationId": conversationId])
    }
    
    func initiateCall(to userId: String, conversationId: String, callerName: String) {
        socket?.emit("call:initiate", [
            "to": userId, "conversationId": conversationId, "callerName": callerName
        ])
    }
    
    func acceptCall(to userId: String) {
        socket?.emit("call:accept", ["to": userId])
    }
    
    func rejectCall(to userId: String) {
        socket?.emit("call:reject", ["to": userId])
    }
    
    func endCall(to userId: String) {
        socket?.emit("call:end", ["to": userId])
    }
    
    func sendWebRTCOffer(to userId: String, offer: [String: Any]) {
        socket?.emit("webrtc:offer", ["to": userId, "offer": offer])
    }
    
    func sendWebRTCAnswer(to userId: String, answer: [String: Any]) {
        socket?.emit("webrtc:answer", ["to": userId, "answer": answer])
    }
    
    func sendICECandidate(to userId: String, candidate: [String: Any]) {
        socket?.emit("webrtc:ice-candidate", ["to": userId, "candidate": candidate])
    }
}
