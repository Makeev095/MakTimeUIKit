import UIKit
import AudioToolbox
import AVFoundation

// MARK: - UI / layout — входящий звонок (fullscreen overlay)
// Имя, кнопки принять/отклонить, визуальный стиль поверх текущего экрана.

final class IncomingCallOverlayView: UIView {
    private let call: IncomingCall
    private let onAccept: () -> Void
    private let onReject: () -> Void
    private var ringTimer: Timer?
    
    init(call: IncomingCall, onAccept: @escaping () -> Void, onReject: @escaping () -> Void) {
        self.call = call
        self.onAccept = onAccept
        self.onReject = onReject
        super.init(frame: .zero)
        setup()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setup() {
        backgroundColor = UIColor(hex: "0F0F2D")
        
        let titleLabel = UILabel()
        titleLabel.text = "ВХОДЯЩИЙ ВИДЕОЗВОНОК"
        titleLabel.font = Theme.fontCaption
        titleLabel.textColor = .white.withAlphaComponent(0.6)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        let avatar = AvatarView()
        avatar.configure(name: call.callerName, color: "#6C63FF", size: 120)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        addSubview(avatar)
        
        let nameLabel = UILabel()
        nameLabel.text = call.callerName
        nameLabel.font = Theme.fontTitle
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(nameLabel)
        
        let rejectBtn = UIButton(type: .system)
        rejectBtn.backgroundColor = Theme.danger
        rejectBtn.setImage(UIImage(systemName: "phone.down.fill"), for: .normal)
        rejectBtn.tintColor = .white
        rejectBtn.layer.cornerRadius = Theme.radiusXl
        rejectBtn.clipsToBounds = true
        rejectBtn.addTarget(self, action: #selector(rejectTapped), for: .touchUpInside)
        rejectBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rejectBtn)
        
        let rejectLabel = UILabel()
        rejectLabel.text = "Отклонить"
        rejectLabel.font = Theme.fontCaption
        rejectLabel.textColor = .white.withAlphaComponent(0.6)
        rejectLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rejectLabel)
        
        let acceptBtn = UIButton(type: .system)
        acceptBtn.backgroundColor = Theme.success
        acceptBtn.setImage(UIImage(systemName: "phone.fill"), for: .normal)
        acceptBtn.tintColor = .white
        acceptBtn.transform = CGAffineTransform(rotationAngle: -CGFloat.pi / 4 * 3)
        acceptBtn.layer.cornerRadius = Theme.radiusXl
        acceptBtn.clipsToBounds = true
        acceptBtn.addTarget(self, action: #selector(acceptTapped), for: .touchUpInside)
        acceptBtn.translatesAutoresizingMaskIntoConstraints = false
        addSubview(acceptBtn)
        
        let acceptLabel = UILabel()
        acceptLabel.text = "Принять"
        acceptLabel.font = Theme.fontCaption
        acceptLabel.textColor = .white.withAlphaComponent(0.6)
        acceptLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(acceptLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 60),
            avatar.centerXAnchor.constraint(equalTo: centerXAnchor),
            avatar.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 40),
            avatar.widthAnchor.constraint(equalToConstant: 120),
            avatar.heightAnchor.constraint(equalToConstant: 120),
            nameLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            nameLabel.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 24),
            rejectBtn.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 60),
            rejectBtn.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -60),
            rejectBtn.widthAnchor.constraint(equalToConstant: 70),
            rejectBtn.heightAnchor.constraint(equalToConstant: 70),
            rejectLabel.centerXAnchor.constraint(equalTo: rejectBtn.centerXAnchor),
            rejectLabel.topAnchor.constraint(equalTo: rejectBtn.bottomAnchor, constant: 8),
            acceptBtn.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -60),
            acceptBtn.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -60),
            acceptBtn.widthAnchor.constraint(equalToConstant: 70),
            acceptBtn.heightAnchor.constraint(equalToConstant: 70),
            acceptLabel.centerXAnchor.constraint(equalTo: acceptBtn.centerXAnchor),
            acceptLabel.topAnchor.constraint(equalTo: acceptBtn.bottomAnchor, constant: 8)
        ])
        
        startRingtone()
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            UIView.animate(withDuration: Theme.animationNormal, delay: 0, options: .curveEaseOut) {
                self.alpha = 1
                self.transform = .identity
            }
        } else {
            stopRingtone()
        }
    }
    
    private func startRingtone() {
        try? AVAudioSession.sharedInstance().setCategory(.soloAmbient)
        try? AVAudioSession.sharedInstance().setActive(true)
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        AudioServicesPlaySystemSound(1005)
        ringTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            AudioServicesPlaySystemSound(1005)
        }
    }
    
    private func stopRingtone() {
        ringTimer?.invalidate()
        ringTimer = nil
    }
    
    @objc private func rejectTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        stopRingtone()
        onReject()
        removeFromSuperview()
    }
    
    @objc private func acceptTapped() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        stopRingtone()
        onAccept()
        removeFromSuperview()
    }
}
