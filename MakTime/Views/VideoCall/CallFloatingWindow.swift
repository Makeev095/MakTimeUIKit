import UIKit
import WebRTC

/// Маленькое плавающее окно видеозвонка (как в Telegram/WhatsApp).
/// Используется когда системный PiP недоступен (симулятор) или как in-app минимизация.
final class CallFloatingWindow: UIWindow {
    private let videoView = RTCMTLVideoView()
    private let nameLabel = UILabel()
    private let tapGesture: UITapGestureRecognizer
    private let panGesture: UIPanGestureRecognizer
    private var initialCenter: CGPoint = .zero
    
    var onTapToRestore: (() -> Void)?
    var onClose: (() -> Void)?
    
    private let size = CGSize(width: 120, height: 160)
    
    init(windowScene: UIWindowScene, remoteTrack: RTCVideoTrack?) {
        tapGesture = UITapGestureRecognizer()
        panGesture = UIPanGestureRecognizer()
        super.init(frame: .zero)
        self.windowScene = windowScene
        self.backgroundColor = .clear
        self.windowLevel = .statusBar + 1
        
        let container = UIView()
        container.backgroundColor = Theme.bgSecondary
        container.layer.cornerRadius = Theme.radiusLg
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.3
        container.layer.shadowRadius = 12
        container.layer.shadowOffset = CGSize(width: 0, height: 4)
        container.clipsToBounds = false
        container.translatesAutoresizingMaskIntoConstraints = false
        rootViewController = UIViewController()
        rootViewController?.view.backgroundColor = .clear
        rootViewController?.view.addSubview(container)
        NSLayoutConstraint.activate([
            container.trailingAnchor.constraint(equalTo: rootViewController!.view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            container.bottomAnchor.constraint(equalTo: rootViewController!.view.safeAreaLayoutGuide.bottomAnchor, constant: -100)
        ])
        
        videoView.videoContentMode = .scaleAspectFill
        videoView.clipsToBounds = true
        videoView.layer.cornerRadius = Theme.radiusLg
        videoView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(videoView)
        
        nameLabel.font = Theme.fontCaption
        nameLabel.textColor = .white
        nameLabel.textAlignment = .center
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(nameLabel)
        
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeBtn.tintColor = .white
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(closeBtn)
        
        tapGesture.addTarget(self, action: #selector(handleTap))
        panGesture.addTarget(self, action: #selector(handlePan(_:)))
        container.addGestureRecognizer(tapGesture)
        container.addGestureRecognizer(panGesture)
        
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: size.width),
            container.heightAnchor.constraint(equalToConstant: size.height),
            videoView.topAnchor.constraint(equalTo: container.topAnchor),
            videoView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            videoView.bottomAnchor.constraint(equalTo: nameLabel.topAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: closeBtn.leadingAnchor, constant: -4),
            nameLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),
            nameLabel.heightAnchor.constraint(equalToConstant: 20),
            closeBtn.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            closeBtn.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            closeBtn.widthAnchor.constraint(equalToConstant: 24),
            closeBtn.heightAnchor.constraint(equalToConstant: 24)
        ])
        
        if let track = remoteTrack {
            track.add(videoView)
        }
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(name: String, remoteTrack: RTCVideoTrack?) {
        nameLabel.text = name
        if let track = remoteTrack {
            track.add(videoView)
        }
    }
    
    func updateRemoteTrack(_ track: RTCVideoTrack) {
        track.add(videoView)
    }
    
    func show(in windowScene: UIWindowScene) {
        self.windowScene = windowScene
        frame = windowScene.coordinateSpace.bounds
        rootViewController?.view.frame = bounds
        isHidden = false
    }
    
    @objc private func handleTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onTapToRestore?()
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let container = gesture.view else { return }
        switch gesture.state {
        case .began:
            initialCenter = container.center
        case .changed:
            let translation = gesture.translation(in: container.superview)
            container.center = CGPoint(x: initialCenter.x + translation.x, y: initialCenter.y + translation.y)
            gesture.setTranslation(.zero, in: container.superview)
        default:
            break
        }
    }
    
    @objc private func closeTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onClose?()
    }
}
