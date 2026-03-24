import UIKit

// MARK: - UI / layout — анимации и тактильный отклик
// Длительности из Theme; spring, лёгкое scale на тапах, haptic — для полировки UI, не для структуры экрана.

/// Хелпер для spring-анимаций и haptic feedback.
enum AnimationHelper {
    
    static func spring(duration: TimeInterval = Theme.animationNormal, damping: CGFloat = Theme.animationSpringDamping, animations: @escaping () -> Void, completion: ((Bool) -> Void)? = nil) {
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: damping,
            initialSpringVelocity: 0.5,
            options: [.curveEaseInOut, .allowUserInteraction],
            animations: animations,
            completion: completion
        )
    }
    
    static func quickScale(view: UIView, to scale: CGFloat = 0.96) {
        UIView.animate(withDuration: 0.1, animations: {
            view.transform = CGAffineTransform(scaleX: scale, y: scale)
        }) { _ in
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 0.5) {
                view.transform = .identity
            }
        }
    }
    
    static func hapticLight() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    static func hapticMedium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    static func hapticSuccess() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}
