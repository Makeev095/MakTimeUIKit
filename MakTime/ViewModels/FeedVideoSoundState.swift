import SwiftUI

@MainActor
final class FeedVideoSoundState: ObservableObject {
    /// По умолчанию со звуком (как в Reels).
    @Published var soundOn: Bool = true
}
