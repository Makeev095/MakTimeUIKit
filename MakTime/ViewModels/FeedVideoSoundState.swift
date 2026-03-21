import SwiftUI

@MainActor
final class FeedVideoSoundState: ObservableObject {
    @Published var soundOn: Bool = false
}
