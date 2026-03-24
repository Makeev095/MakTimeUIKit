import SwiftUI
import Lottie

// MARK: - UI / layout — Lottie в SwiftUI
// Встраивание JSON из бандла (Resources/Lottie); contentMode, loop, пауза при уходе с экрана.

/// SwiftUI-обёртка над Lottie (анимации лежат в бандле, например `loading_dots.json`).
struct LottieLoopView: UIViewRepresentable {
    let name: String
    var loopMode: LottieLoopMode = .loop

    func makeUIView(context: Context) -> LottieAnimationView {
        let v = LottieAnimationView(name: name, bundle: .main)
        v.loopMode = loopMode
        v.contentMode = .scaleAspectFit
        v.backgroundBehavior = .pauseAndRestore
        v.play()
        return v
    }

    func updateUIView(_ uiView: LottieAnimationView, context: Context) {
        uiView.loopMode = loopMode
        if !uiView.isAnimationPlaying {
            uiView.play()
        }
    }
}
