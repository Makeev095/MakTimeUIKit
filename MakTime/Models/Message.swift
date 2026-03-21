import Foundation

struct Message: Codable, Identifiable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    let type: MessageType
    var text: String
    var fileUrl: String?
    var fileName: String?
    var duration: Double?
    var replyToId: String?
    let createdAt: String
    var read: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, type, text, duration, read
        case conversationId = "conversationId"
        case senderId = "senderId"
        case fileUrl = "fileUrl"
        case fileName = "fileName"
        case replyToId = "replyToId"
        case createdAt = "createdAt"
    }
    
    var fullFileUrl: String? {
        guard let fileUrl = fileUrl else { return nil }
        if fileUrl.hasPrefix("http") { return fileUrl }
        return "\(AppConfig.baseURL)\(fileUrl)"
    }
    
    var dateFormatted: String {
        guard let date = DateParsing.parse(createdAt) else { return "" }
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        return timeFormatter.string(from: date)
    }
    
    var date: Date? {
        DateParsing.parse(createdAt)
    }
}

enum MessageType: String, Codable {
    case text
    case voice
    case image
    case video
    case videoNote
    case file
}

enum DateParsing {
    private static let iso8601Full: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    
    private static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    
    private static let sqlite: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.timeZone = TimeZone(identifier: "UTC")
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    static func parse(_ string: String) -> Date? {
        iso8601Full.date(from: string)
            ?? iso8601.date(from: string)
            ?? sqlite.date(from: string)
    }
}
