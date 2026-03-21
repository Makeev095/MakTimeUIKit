import UIKit
import WebRTC
import Combine

final class VideoCallViewController: UIViewController {
    private let target: CallTarget
    private let authService: AuthService
    private let socketService: SocketService
    private let pipManager: CallPiPManager
    private let onEnd: () -> Void
    private let onToggleMinimize: (VideoCallViewController) -> Void
    private let onWebRTCConnected: (() -> Void)?
    
    let vm: VideoCallViewModel
    private var cancellables = Set<AnyCancellable>()
    private var pipSetupDone = false
    
    private let remoteVideoView = RTCMTLVideoView()
    private let localVideoView = RTCMTLVideoView()
    private let avatarView = AvatarView()
    private let statusLabel = UILabel()
    private let nameLabel = UILabel()
    private let muteBtn = UIButton(type: .system)
    private let videoBtn = UIButton(type: .system)
    private let switchCameraBtn = UIButton(type: .system)
    private let endBtn = UIButton(type: .system)
    
    init(
        target: CallTarget,
        authService: AuthService,
        socketService: SocketService,
        pipManager: CallPiPManager,
        onEnd: @escaping () -> Void,
        onToggleMinimize: @escaping (VideoCallViewController) -> Void,
        onWebRTCConnected: (() -> Void)? = nil
    ) {
        self.target = target
        self.authService = authService
        self.socketService = socketService
        self.pipManager = pipManager
        self.onEnd = onEnd
        self.onToggleMinimize = onToggleMinimize
        self.onWebRTCConnected = onWebRTCConnected
        self.vm = VideoCallViewModel(target: target)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(hex: "0F0F2D")
        
        vm.onEnd = onEnd
        vm.onConnected = onWebRTCConnected
        vm.setup(socketService: socketService, callerName: authService.user?.displayName ?? "")
        
        remoteVideoView.videoContentMode = .scaleAspectFill
        remoteVideoView.clipsToBounds = true
        remoteVideoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(remoteVideoView)
        
        avatarView.configure(name: target.name, color: "#6C63FF", size: 110)
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(avatarView)
        
        nameLabel.text = target.name
        nameLabel.font = Theme.fontTitle
        nameLabel.textColor = .white
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(nameLabel)
        
        statusLabel.font = Theme.fontCaption
        statusLabel.textColor = .white.withAlphaComponent(0.6)
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)
        
        localVideoView.videoContentMode = .scaleAspectFill
        localVideoView.clipsToBounds = true
        localVideoView.transform = CGAffineTransform(scaleX: -1, y: 1)
        localVideoView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(localVideoView)
        
        let controlsContainer = UIView()
        controlsContainer.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        controlsContainer.layer.cornerRadius = Theme.radiusLg
        controlsContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(controlsContainer)
        
        muteBtn.setImage(UIImage(systemName: "mic.fill"), for: .normal)
        muteBtn.tintColor = .white
        muteBtn.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        muteBtn.layer.cornerRadius = 25
        muteBtn.addTarget(self, action: #selector(toggleMute), for: .touchUpInside)
        muteBtn.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(muteBtn)
        
        videoBtn.setImage(UIImage(systemName: "video.fill"), for: .normal)
        videoBtn.tintColor = .white
        videoBtn.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        videoBtn.layer.cornerRadius = 25
        videoBtn.addTarget(self, action: #selector(toggleVideo), for: .touchUpInside)
        videoBtn.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(videoBtn)
        
        switchCameraBtn.setImage(UIImage(systemName: "camera.rotate"), for: .normal)
        switchCameraBtn.tintColor = .white
        switchCameraBtn.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        switchCameraBtn.layer.cornerRadius = 25
        switchCameraBtn.addTarget(self, action: #selector(switchCameraTapped), for: .touchUpInside)
        switchCameraBtn.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(switchCameraBtn)
        
        endBtn.setImage(UIImage(systemName: "phone.down.fill"), for: .normal)
        endBtn.tintColor = .white
        endBtn.backgroundColor = Theme.danger
        endBtn.layer.cornerRadius = 32
        endBtn.addTarget(self, action: #selector(endCall), for: .touchUpInside)
        endBtn.translatesAutoresizingMaskIntoConstraints = false
        controlsContainer.addSubview(endBtn)
        
        let minimizeBtn = UIButton(type: .system)
        minimizeBtn.setImage(UIImage(systemName: "arrow.down.right.and.arrow.up.left"), for: .normal)
        minimizeBtn.tintColor = .white
        minimizeBtn.addTarget(self, action: #selector(minimizeTapped), for: .touchUpInside)
        minimizeBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(minimizeBtn)
        
        NSLayoutConstraint.activate([
            remoteVideoView.topAnchor.constraint(equalTo: view.topAnchor),
            remoteVideoView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            remoteVideoView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            remoteVideoView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            avatarView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            avatarView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            avatarView.widthAnchor.constraint(equalToConstant: 110),
            avatarView.heightAnchor.constraint(equalToConstant: 110),
            nameLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            nameLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 16),
            statusLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8),
            localVideoView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            localVideoView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 60),
            localVideoView.widthAnchor.constraint(equalToConstant: 110),
            localVideoView.heightAnchor.constraint(equalToConstant: 150),
            controlsContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            controlsContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            controlsContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -40),
            controlsContainer.heightAnchor.constraint(equalToConstant: 80),
            muteBtn.leadingAnchor.constraint(equalTo: controlsContainer.leadingAnchor, constant: 24),
            muteBtn.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            muteBtn.widthAnchor.constraint(equalToConstant: 50),
            muteBtn.heightAnchor.constraint(equalToConstant: 50),
            videoBtn.leadingAnchor.constraint(equalTo: muteBtn.trailingAnchor, constant: 16),
            videoBtn.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            videoBtn.widthAnchor.constraint(equalToConstant: 50),
            videoBtn.heightAnchor.constraint(equalToConstant: 50),
            switchCameraBtn.leadingAnchor.constraint(equalTo: videoBtn.trailingAnchor, constant: 16),
            switchCameraBtn.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            switchCameraBtn.widthAnchor.constraint(equalToConstant: 50),
            switchCameraBtn.heightAnchor.constraint(equalToConstant: 50),
            endBtn.trailingAnchor.constraint(equalTo: controlsContainer.trailingAnchor, constant: -24),
            endBtn.centerYAnchor.constraint(equalTo: controlsContainer.centerYAnchor),
            endBtn.widthAnchor.constraint(equalToConstant: 64),
            endBtn.heightAnchor.constraint(equalToConstant: 64),
            minimizeBtn.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            minimizeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            minimizeBtn.widthAnchor.constraint(equalToConstant: 44),
            minimizeBtn.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        vm.$status.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.updateUI()
        }.store(in: &cancellables)
        
        vm.$remoteVideoTrack.receive(on: DispatchQueue.main).sink { [weak self] track in
            guard let self else { return }
            if let track {
                track.add(self.remoteVideoView)
                if self.pipSetupDone {
                    self.pipManager.updateRemoteTrack(track)
                }
            }
        }.store(in: &cancellables)
        
        vm.$status.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.statusLabel.text = self?.vm.statusText ?? ""
        }.store(in: &cancellables)
        
        vm.$status.receive(on: DispatchQueue.main).sink { [weak self] status in
            if status == .calling || status == .connecting {
                self?.initPiPEarly()
            }
        }.store(in: &cancellables)
        
        vm.$isMuted.receive(on: DispatchQueue.main).sink { [weak self] muted in
            self?.muteBtn.setImage(UIImage(systemName: muted ? "mic.slash.fill" : "mic.fill"), for: .normal)
            self?.muteBtn.backgroundColor = muted ? Theme.danger : UIColor.white.withAlphaComponent(0.2)
        }.store(in: &cancellables)
        
        vm.$isVideoOff.receive(on: DispatchQueue.main).sink { [weak self] off in
            self?.videoBtn.setImage(UIImage(systemName: off ? "video.slash.fill" : "video.fill"), for: .normal)
            self?.videoBtn.backgroundColor = off ? Theme.danger : UIColor.white.withAlphaComponent(0.2)
        }.store(in: &cancellables)
        
        if let localTrack = vm.webRTCService.localStream {
            localTrack.add(localVideoView)
        }
    }
    
    
    private func initPiPEarly() {
        guard !pipSetupDone else { return }
        pipSetupDone = true
        // Для PiP нужен видимый source view в иерархии; картинка в окне PiP — с remote track (SampleBuffer), не с этого view
        pipManager.setup(sourceView: view, remoteTrack: vm.remoteVideoTrack)
    }
    
    private func updateUI() {
        let connected = vm.status == .connected
        remoteVideoView.isHidden = !connected || vm.remoteVideoTrack == nil
        avatarView.isHidden = connected && vm.remoteVideoTrack != nil
        localVideoView.isHidden = !connected
    }
    
    @objc private func toggleMute() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        vm.toggleMute()
    }
    @objc private func toggleVideo() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        vm.toggleVideo()
    }
    @objc private func switchCameraTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        vm.switchCamera()
    }
    @objc private func endCall() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        vm.endCall()
    }
    @objc private func minimizeTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onToggleMinimize(self)
    }
}
