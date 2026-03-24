import UIKit
import WebRTC

// MARK: - UI / layout — мини-окно звонка (отдельное UIWindow)
// Размер, позиция, жесты pan/tap, превью RTCMTLVideoView.

/// Маленькое плавающее окно видеозвонка (как в Telegram/WhatsApp).
/// Используется когда системный PiP недоступен (симулятор) или как in-app минимизация.
final class CallFloatingWindow: UIWindow {
    private let videoView = RTCMTLVideoView()
    private let nameLabel = UILabel()
    private let tapGesture = UITapGestureRecognizer()
    private let panGesture = UIPanGestureRecognizer()

    private let container = UIView()
    private let cardSize = CGSize(width: 120, height: 160)
    private var panStartCenter: CGPoint = .zero

    var onTapToRestore: (() -> Void)?
    var onClose: (() -> Void)?

    private var attachedTrack: RTCVideoTrack?

    init(windowScene: UIWindowScene, remoteTrack: RTCVideoTrack?) {
        super.init(frame: .zero)
        self.windowScene = windowScene
        backgroundColor = .clear
        windowLevel = .statusBar + 1

        rootViewController = UIViewController()
        rootViewController?.view.backgroundColor = .clear

        container.backgroundColor = Theme.bgSecondary
        container.layer.cornerRadius = Theme.radiusLg
        container.layer.shadowColor = UIColor.black.cgColor
        container.layer.shadowOpacity = 0.3
        container.layer.shadowRadius = 12
        container.layer.shadowOffset = CGSize(width: 0, height: 4)
        container.clipsToBounds = false
        rootViewController?.view.addSubview(container)

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
            container.widthAnchor.constraint(equalToConstant: cardSize.width),
            container.heightAnchor.constraint(equalToConstant: cardSize.height),
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
            closeBtn.heightAnchor.constraint(equalToConstant: 24),
        ])

        if let track = remoteTrack {
            track.add(videoView)
            attachedTrack = track
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(name: String, remoteTrack: RTCVideoTrack?) {
        nameLabel.text = name
        if let track = remoteTrack, track !== attachedTrack {
            if let old = attachedTrack {
                old.remove(videoView)
            }
            track.add(videoView)
            attachedTrack = track
        }
    }

    func updateRemoteTrack(_ track: RTCVideoTrack) {
        if track !== attachedTrack {
            attachedTrack?.remove(videoView)
            track.add(videoView)
            attachedTrack = track
        }
    }

    func show(in windowScene: UIWindowScene) {
        self.windowScene = windowScene
        frame = windowScene.coordinateSpace.bounds
        rootViewController?.view.frame = bounds
        layoutContainerInitial()
        isHidden = false
    }

    private func layoutContainerInitial() {
        guard let v = rootViewController?.view else { return }
        v.layoutIfNeeded()
        let safe = v.safeAreaInsets
        let w = cardSize.width
        let h = cardSize.height
        let x = v.bounds.width - safe.right - 20 - w
        let y = v.bounds.height - safe.bottom - 100 - h
        container.frame = CGRect(x: x, y: y, width: w, height: h)
    }

    @objc private func handleTap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onTapToRestore?()
    }

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let superview = container.superview else { return }
        switch gesture.state {
        case .began:
            panStartCenter = container.center
        case .changed:
            let t = gesture.translation(in: superview)
            container.center = CGPoint(x: panStartCenter.x + t.x, y: panStartCenter.y + t.y)
        case .ended, .cancelled, .failed:
            panStartCenter = container.center
            gesture.setTranslation(.zero, in: superview)
        default:
            break
        }
    }

    @objc private func closeTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onClose?()
    }
}
