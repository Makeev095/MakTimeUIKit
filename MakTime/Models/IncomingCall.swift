import Foundation

struct IncomingCall: Equatable {
    let from: String
    let callerName: String
    let conversationId: String
    /// Если бэкенд не шлёт поле — считаем видеозвонком.
    let isVideo: Bool
}
