import SwiftUI

extension Notification.Name {
    /// Вкладка «Лента» стала видимой/невидимой (см. `MainTabController`).
    static let makTimeFeedTabVisibility = Notification.Name("MakTime.feedTabVisibility")
}

@MainActor
final class FeedVideoSoundState: ObservableObject {
    /// По умолчанию со звуком (как в Reels).
    @Published var soundOn: Bool = true
}
