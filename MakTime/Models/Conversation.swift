import Foundation

struct Conversation: Codable, Identifiable, Equatable, Hashable {
    let id: String
    var lastMessage: String?
    var lastMessageType: String?
    var lastMessageTime: String?
    var unreadCount: Int
    var participant: User?
    
    enum CodingKeys: String, CodingKey {
        case id
        case lastMessage = "lastMessage"
        case lastMessageType = "lastMessageType"
        case lastMessageTime = "lastMessageTime"
        case unreadCount = "unreadCount"
        case participant
    }
    
    var lastMessagePreview: String {
        guard let msg = lastMessage else { return "Нет сообщений" }
        switch lastMessageType {
        case "voice": return "🎤 Голосовое сообщение"
        case "image": return "📷 Фото"
        case "video": return "🎥 Видео"
        case "videoNote": return "📹 Кружок"
        case "file": return "📎 Файл"
        default: return msg
        }
    }
    
    var lastMessageDate: Date? {
        guard let time = lastMessageTime else { return nil }
        return DateParsing.parse(time)
    }
    
    var lastMessageTimeFormatted: String {
        guard let date = lastMessageDate else { return "" }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        if calendar.isDateInToday(date) {
            formatter.dateFormat = "HH:mm"
        } else if calendar.isDateInYesterday(date) {
            return "Вчера"
        } else {
            formatter.dateFormat = "dd.MM"
        }
        return formatter.string(from: date)
    }
}
