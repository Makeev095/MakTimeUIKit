import Foundation

/// Контракт payload VoIP push для бэкенда (ключи можно согласовать).
/// Пример JSON: `{ "callUUID": "...", "from": "userId", "callerName": "...", "conversationId": "..." }`
struct VoIPPushPayload {
    let callUUID: UUID?
    let fromUserId: String
    let callerName: String
    let conversationId: String
    let isVideo: Bool

    init?(dictionary: [AnyHashable: Any]) {
        let d = dictionary as? [String: Any] ?? [:]
        if let s = d["callUUID"] as? String {
            self.callUUID = UUID(uuidString: s)
        } else {
            self.callUUID = nil
        }
        guard let from = d["from"] as? String ?? d["fromUserId"] as? String else { return nil }
        guard let name = d["callerName"] as? String ?? d["name"] as? String else { return nil }
        guard let conv = d["conversationId"] as? String else { return nil }
        self.fromUserId = from
        self.callerName = name
        self.conversationId = conv
        if let v = d["isVideo"] as? Bool {
            self.isVideo = v
        } else if let n = d["isVideo"] as? NSNumber {
            self.isVideo = n.boolValue
        } else {
            self.isVideo = true
        }
    }
}

/*
 Ручной QA (после сборки на устройстве):
 — Фон / возврат: активный звонок, PiP, восстановление полноэкрана.
 — Kill приложения во время звонка; с VoIP — повторный входящий через CallKit.
 — Разрыв сети, ICE restart.
 — Входящий на заблокированном экране (после настройки VoIP push + capability).
 — Динамик / Bluetooth / гарнитура.
 — Второй входящий (CallKit).
 — Лента: быстрый скролл, пауза видео при уходе ячейки.
 — VoiceOver и увеличенный шрифт на чатах и ленте.
*/
