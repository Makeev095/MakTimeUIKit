import UIKit
import Lottie

/// Анимированный индикатор загрузки через Lottie.
/// Добавьте loading.json в проект для кастомной анимации, иначе показывается UIActivityIndicator.
final class LoadingLottieView: UIView {
    private let animationView = LottieAnimationView()
    private let fallbackSpinner = UIActivityIndicatorView(style: .large)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(animationView)
        addSubview(fallbackSpinner)
        animationView.translatesAutoresizingMaskIntoConstraints = false
        fallbackSpinner.translatesAutoresizingMaskIntoConstraints = false
        fallbackSpinner.color = Theme.accent
        NSLayoutConstraint.activate([
            animationView.centerXAnchor.constraint(equalTo: centerXAnchor),
            animationView.centerYAnchor.constraint(equalTo: centerYAnchor),
            animationView.widthAnchor.constraint(equalToConstant: 80),
            animationView.heightAnchor.constraint(equalToConstant: 80),
            fallbackSpinner.centerXAnchor.constraint(equalTo: centerXAnchor),
            fallbackSpinner.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
        if let anim = LottieAnimation.named("loading_dots", bundle: .main) {
            animationView.animation = anim
            animationView.loopMode = .loop
            animationView.isHidden = false
            fallbackSpinner.isHidden = true
            animationView.play()
        } else {
            animationView.isHidden = true
            fallbackSpinner.isHidden = false
            fallbackSpinner.startAnimating()
        }
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func play() {
        if animationView.isHidden {
            fallbackSpinner.startAnimating()
        } else {
            animationView.play()
        }
    }
    
    func stop() {
        animationView.stop()
        fallbackSpinner.stopAnimating()
    }
}
