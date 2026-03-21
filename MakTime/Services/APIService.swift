import Foundation

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int, String)
    case decodingError(Error)
    case networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Неверный ответ сервера"
        case .httpError(let code, let msg): return "Ошибка \(code): \(msg)"
        case .decodingError: return "Ошибка обработки данных"
        case .networkError(let err): return err.localizedDescription
        }
    }
}

actor APIService {
    static let shared = APIService()
    
    private var token: String?
    
    func setToken(_ token: String?) {
        self.token = token
    }
    
    // MARK: - Auth
    
    struct AuthResponse: Codable {
        let token: String
        let user: User
    }
    
    struct ErrorResponse: Codable {
        let error: String?
        let message: String?
    }
    
    func register(username: String, displayName: String, password: String) async throws -> AuthResponse {
        let body: [String: Any] = ["username": username, "displayName": displayName, "password": password]
        return try await post("/auth/register", body: body)
    }
    
    func login(username: String, password: String) async throws -> AuthResponse {
        let body: [String: Any] = ["username": username, "password": password]
        return try await post("/auth/login", body: body)
    }
    
    func getMe() async throws -> User {
        return try await get("/auth/me")
    }

    /// Регистрация VoIP device token на бэкенде (путь согласовать при деплое).
    func registerVoIPDeviceToken(hexToken: String) async throws {
        let body: [String: Any] = ["token": hexToken, "platform": "ios"]
        let _: EmptyResponse = try await post("/devices/voip-token", body: body)
    }
    
    func updateProfile(displayName: String, bio: String, avatarUrl: String? = nil) async throws -> User {
        var body: [String: Any] = ["displayName": displayName, "bio": bio]
        if let url = avatarUrl { body["avatarUrl"] = url }
        return try await put("/auth/profile", body: body)
    }
    
    // MARK: - Users
    
    func searchUsers(query: String) async throws -> [User] {
        return try await get("/users/search?q=\(query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query)")
    }
    
    // MARK: - Contacts
    
    func addContact(contactId: String) async throws {
        let _: EmptyResponse = try await post("/contacts/\(contactId)", body: [:])
    }
    
    func getContacts() async throws -> [User] {
        return try await get("/contacts")
    }
    
    // MARK: - Conversations
    
    func getConversations() async throws -> [Conversation] {
        return try await get("/conversations")
    }
    
    struct CreateConversationResponse: Codable {
        let id: String
        let existing: Bool?
    }
    
    func createConversation(participantId: String) async throws -> Conversation {
        let body: [String: Any] = ["participantId": participantId]
        let response: CreateConversationResponse = try await post("/conversations", body: body)
        return Conversation(
            id: response.id,
            lastMessage: nil,
            lastMessageType: nil,
            lastMessageTime: nil,
            unreadCount: 0,
            participant: nil
        )
    }
    
    func getMessages(conversationId: String) async throws -> [Message] {
        return try await get("/conversations/\(conversationId)/messages")
    }

    func deleteConversation(conversationId: String) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "/conversations/\(conversationId)")
    }
    
    func deleteMessage(messageId: String) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "/messages/\(messageId)")
    }
    
    // MARK: - Upload
    
    func uploadFile(data: Data, filename: String, mimeType: String) async throws -> UploadResponse {
        let boundary = UUID().uuidString
        var urlRequest = URLRequest(url: URL(string: "\(AppConfig.apiURL)/upload")!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        if let token = token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        urlRequest.httpBody = body
        
        let (responseData, response) = try await URLSession.shared.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else { throw APIError.invalidResponse }
        guard (200...299).contains(httpResponse.statusCode) else {
            let errMsg = String(data: responseData, encoding: .utf8) ?? "Unknown error"
            throw APIError.httpError(httpResponse.statusCode, errMsg)
        }
        return try JSONDecoder().decode(UploadResponse.self, from: responseData)
    }
    
    struct UploadResponse: Codable {
        let fileUrl: String
    }
    
    // MARK: - Stories
    
    struct CreateStoryResponse: Codable {
        let id: String
    }
    
    func createStory(type: String, fileUrl: String, textOverlay: String, bgColor: String) async throws -> CreateStoryResponse {
        let body: [String: Any] = ["type": type, "fileUrl": fileUrl, "textOverlay": textOverlay, "bgColor": bgColor]
        return try await post("/stories", body: body)
    }
    
    func getStories() async throws -> [StoryUser] {
        return try await get("/stories")
    }
    
    func viewStory(storyId: String) async throws {
        let _: EmptyResponse = try await post("/stories/\(storyId)/view", body: [:])
    }
    
    func getStoryViewers(storyId: String) async throws -> [StoryViewer] {
        return try await get("/stories/\(storyId)/viewers")
    }
    
    func reactToStory(storyId: String, emoji: String) async throws {
        let _: EmptyResponse = try await post("/stories/\(storyId)/react", body: ["emoji": emoji])
    }
    
    func deleteStory(storyId: String) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "/stories/\(storyId)")
    }
    
    func getStoryReactions(storyId: String) async throws -> [StoryReaction] {
        return try await get("/stories/\(storyId)/reactions")
    }
    
    // MARK: - Feed / Posts
    
    func getPosts(limit: Int = 30, offset: Int = 0) async throws -> [Post] {
        return try await get("/posts?limit=\(limit)&offset=\(offset)")
    }
    
    func createPost(type: String, fileUrl: String, caption: String) async throws -> Post {
        let body: [String: Any] = ["type": type, "fileUrl": fileUrl, "caption": caption]
        return try await post("/posts", body: body)
    }
    
    func likePost(postId: String) async throws {
        let _: EmptyResponse = try await post("/posts/\(postId)/like", body: [:])
    }
    
    func unlikePost(postId: String) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "/posts/\(postId)/like")
    }
    
    func repostPost(postId: String) async throws {
        let _: EmptyResponse = try await post("/posts/\(postId)/repost", body: [:])
    }
    
    func deletePost(postId: String) async throws {
        let _: EmptyResponse = try await request("DELETE", path: "/posts/\(postId)")
    }
    
    func getComments(postId: String) async throws -> [PostComment] {
        return try await get("/posts/\(postId)/comments")
    }
    
    func addComment(postId: String, text: String) async throws -> PostComment {
        let body: [String: Any] = ["text": text]
        return try await post("/posts/\(postId)/comments", body: body)
    }
    
    // MARK: - Private helpers
    
    private struct EmptyResponse: Codable {}
    
    private func get<T: Decodable>(_ path: String) async throws -> T {
        return try await request("GET", path: path)
    }
    
    private func post<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        return try await request("POST", path: path, body: body)
    }
    
    private func put<T: Decodable>(_ path: String, body: [String: Any]) async throws -> T {
        return try await request("PUT", path: path, body: body)
    }
    
    private func request<T: Decodable>(_ method: String, path: String, body: [String: Any]? = nil) async throws -> T {
        guard let url = URL(string: "\(AppConfig.apiURL)\(path)") else {
            throw APIError.invalidResponse
        }
        
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = method
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = token {
            urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        if let body = body, method != "GET" {
            urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }
            
            if !(200...299).contains(httpResponse.statusCode) {
                let errBody = try? JSONDecoder().decode(ErrorResponse.self, from: data)
                let msg = errBody?.error ?? errBody?.message ?? String(data: data, encoding: .utf8) ?? "Unknown error"
                throw APIError.httpError(httpResponse.statusCode, msg)
            }
            
            if T.self == EmptyResponse.self {
                return EmptyResponse() as! T
            }
            
            do {
                let decoder = JSONDecoder()
                return try decoder.decode(T.self, from: data)
            } catch {
                throw APIError.decodingError(error)
            }
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.networkError(error)
        }
    }
}
