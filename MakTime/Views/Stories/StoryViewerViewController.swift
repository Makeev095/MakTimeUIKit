import UIKit
import AVKit
import AVFoundation

final class StoryViewerViewController: UIViewController {
    private let storyUsers: [StoryUser]
    private var currentUserIdx: Int
    private var currentStoryIdx = 0
    private var progress: CGFloat = 0
    private var timer: Timer?
    private let onClose: () -> Void
    
    private var currentUser: StoryUser? {
        guard currentUserIdx >= 0, currentUserIdx < storyUsers.count else { return nil }
        return storyUsers[currentUserIdx]
    }
    
    private var currentStory: Story? {
        guard let user = currentUser, currentStoryIdx >= 0, currentStoryIdx < user.stories.count else { return nil }
        return user.stories[currentStoryIdx]
    }
    
    private let mediaContainer = UIView()
    private let imageView = CachedImageView()
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    
    init(storyUsers: [StoryUser], startUserIdx: Int, onClose: @escaping () -> Void) {
        self.storyUsers = storyUsers
        self.currentUserIdx = startUserIdx
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        mediaContainer.frame = view.bounds
        mediaContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(mediaContainer)
        
        imageView.frame = mediaContainer.bounds
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        mediaContainer.addSubview(imageView)
        
        let leftTap = UITapGestureRecognizer(target: self, action: #selector(leftTapped))
        leftTap.delegate = self
        let leftView = UIView(frame: CGRect(x: 0, y: 0, width: view.bounds.width / 3, height: view.bounds.height))
        leftView.addGestureRecognizer(leftTap)
        leftView.isUserInteractionEnabled = true
        view.addSubview(leftView)
        
        let rightTap = UITapGestureRecognizer(target: self, action: #selector(rightTapped))
        rightTap.delegate = self
        let rightView = UIView(frame: CGRect(x: view.bounds.width / 3, y: 0, width: view.bounds.width * 2 / 3, height: view.bounds.height))
        rightView.addGestureRecognizer(rightTap)
        rightView.isUserInteractionEnabled = true
        view.addSubview(rightView)
        
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeBtn.tintColor = .white
        closeBtn.frame = CGRect(x: view.bounds.width - 56, y: 60, width: 44, height: 44)
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeBtn)
        
        loadCurrentStory()
        startTimer()
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        mediaContainer.frame = view.bounds
        imageView.frame = mediaContainer.bounds
        playerLayer?.frame = mediaContainer.bounds
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopTimer()
        player?.pause()
    }
    
    private func loadCurrentStory() {
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        player = nil
        playerLayer = nil
        
        guard let story = currentStory else { return }
        
        if story.type == .video, let url = URL(string: story.fullFileUrl) {
            imageView.isHidden = true
            let p = AVPlayer(url: url)
            p.play()
            let layer = AVPlayerLayer(player: p)
            layer.frame = mediaContainer.bounds
            layer.videoGravity = .resizeAspectFill
            mediaContainer.layer.addSublayer(layer)
            player = p
            playerLayer = layer
        } else if let url = URL(string: story.fullFileUrl) {
            imageView.isHidden = false
            imageView.load(url: url)
        }
    }
    
    private func startTimer() {
        stopTimer()
        progress = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.progress += 0.05 / 5.0
                if self.progress >= 1 { self.nextStory() }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func nextStory() {
        guard let user = currentUser else { onClose(); return }
        if currentStoryIdx < user.stories.count - 1 {
            currentStoryIdx += 1
            loadCurrentStory()
            startTimer()
        } else if currentUserIdx < storyUsers.count - 1 {
            currentUserIdx += 1
            currentStoryIdx = 0
            loadCurrentStory()
            startTimer()
        } else {
            onClose()
        }
    }
    
    private func previousStory() {
        if currentStoryIdx > 0 {
            currentStoryIdx -= 1
            loadCurrentStory()
            startTimer()
        } else if currentUserIdx > 0 {
            currentUserIdx -= 1
            currentStoryIdx = max(0, storyUsers[currentUserIdx].stories.count - 1)
            loadCurrentStory()
            startTimer()
        } else {
            startTimer()
        }
    }
    
    @objc private func leftTapped() { previousStory() }
    @objc private func rightTapped() { nextStory() }
    @objc private func closeTapped() { onClose() }
}

extension StoryViewerViewController: UIGestureRecognizerDelegate {}
