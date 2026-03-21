import Foundation

enum AppConfig {
    static let baseURL = "https://maktime.space"
    static let apiURL = "\(baseURL)/api"
    static let socketURL = baseURL
    
    static let turnHost = "maktime.space"
    static let turnPort: UInt16 = 3478
    static let turnUser = "maktime"
    static let turnPass = "MakTimeT0rn2026!"
    
    static let stunServers = [
        "stun:stun.l.google.com:19302",
        "stun:stun1.l.google.com:19302",
    ]
}
