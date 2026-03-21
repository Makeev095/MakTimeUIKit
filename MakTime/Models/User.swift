import Foundation

struct User: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let username: String
    let displayName: String
    let avatarColor: String
    var avatarUrl: String?
    var bio: String?
    var status: String?
    var lastSeen: String?
    
    enum CodingKeys: String, CodingKey {
        case id, username, bio, status
        case displayName = "displayName"
        case avatarColor = "avatarColor"
        case avatarUrl = "avatarUrl"
        case lastSeen = "lastSeen"
    }
    
    var isOnline: Bool {
        status == "online"
    }
    
    var initials: String {
        let parts = displayName.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(displayName.prefix(2)).uppercased()
    }

    var fullAvatarUrl: String? {
        guard let url = avatarUrl, !url.isEmpty else { return nil }
        if url.hasPrefix("http") { return url }
        return "\(AppConfig.baseURL)\(url)"
    }
}
