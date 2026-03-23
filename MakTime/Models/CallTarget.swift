import Foundation

struct CallTarget: Equatable {
    let userId: String
    let name: String
    let conversationId: String
    let isInitiator: Bool
    /// `true` — видеозвонок, `false` — только голос (WebRTC audio-only).
    let isVideo: Bool
}
