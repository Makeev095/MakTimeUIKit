import Foundation

struct Post: Codable, Identifiable, Equatable {
    let id: String
    let authorId: String
    let authorName: String
    let authorAvatarColor: String
    let type: PostType
    let fileUrl: String
    var caption: String
    var likesCount: Int
    var commentsCount: Int
    var repostsCount: Int
    var isLiked: Bool
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, type, caption
        case authorId = "authorId"
        case authorName = "authorName"
        case authorAvatarColor = "authorAvatarColor"
        case fileUrl = "fileUrl"
        case likesCount = "likesCount"
        case commentsCount = "commentsCount"
        case repostsCount = "repostsCount"
        case isLiked = "isLiked"
        case createdAt = "createdAt"
    }

    var fullFileUrl: String {
        if fileUrl.hasPrefix("http") { return fileUrl }
        if fileUrl.hasPrefix("/") {
            return "\(AppConfig.baseURL)\(fileUrl)"
        }
        return "\(AppConfig.baseURL)/\(fileUrl)"
    }

    var timeAgo: String {
        guard let date = DateParsing.parse(createdAt) else { return "" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "только что" }
        if interval < 3600 { return "\(Int(interval / 60)) мин" }
        if interval < 86400 { return "\(Int(interval / 3600)) ч" }
        if interval < 604800 { return "\(Int(interval / 86400)) д" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        formatter.locale = Locale(identifier: "ru_RU")
        return formatter.string(from: date)
    }
}

enum PostType: String, Codable {
    case image
    case video
}

struct PostComment: Codable, Identifiable, Equatable {
    let id: String
    let authorId: String
    let authorName: String
    let authorAvatarColor: String
    let text: String
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, text
        case authorId = "authorId"
        case authorName = "authorName"
        case authorAvatarColor = "authorAvatarColor"
        case createdAt = "createdAt"
    }

    var timeAgo: String {
        guard let date = DateParsing.parse(createdAt) else { return "" }
        let interval = Date().timeIntervalSince(date)
        if interval < 60 { return "только что" }
        if interval < 3600 { return "\(Int(interval / 60)) мин" }
        if interval < 86400 { return "\(Int(interval / 3600)) ч" }
        return "\(Int(interval / 86400)) д"
    }
}
