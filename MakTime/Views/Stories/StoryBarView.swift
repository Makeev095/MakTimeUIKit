import UIKit
import Combine

final class StoryBarView: UIView {
    var onViewStories: (([StoryUser], Int) -> Void)?
    var onAddStory: (() -> Void)?
    
    private let vm = StoriesViewModel()
    private var cancellables = Set<AnyCancellable>()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private weak var authService: AuthService?
    private weak var socketService: SocketService?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setup() {
        backgroundColor = Theme.bgSecondary
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        
        stackView.axis = .horizontal
        stackView.spacing = 14
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 10),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -10),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: -20)
        ])
        
        vm.$storyUsers
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
    }
    
    func configure(authService: AuthService, socketService: SocketService) {
        self.authService = authService
        self.socketService = socketService
        vm.setup(socketService: socketService)
        Task { await vm.loadStories() }
    }
    
    private func reload() {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        let addBtn = makeAddButton()
        addBtn.translatesAutoresizingMaskIntoConstraints = false
        addBtn.widthAnchor.constraint(equalToConstant: 72).isActive = true
        stackView.addArrangedSubview(addBtn)
        
        for (idx, user) in vm.storyUsers.enumerated() {
            let item = makeStoryItem(user: user, index: idx)
            item.translatesAutoresizingMaskIntoConstraints = false
            item.widthAnchor.constraint(equalToConstant: 72).isActive = true
            stackView.addArrangedSubview(item)
        }
    }
    
    private func makeAddButton() -> UIView {
        let container = UIView()
        let avatar = AvatarView()
        avatar.configure(
            name: authService?.user?.displayName ?? "?",
            color: authService?.user?.avatarColor ?? "#6C63FF",
            avatarUrl: authService?.user?.avatarUrl,
            size: 58
        )
        container.addSubview(avatar)
        
        let plusBg = UIView()
        plusBg.backgroundColor = Theme.accent
        plusBg.layer.cornerRadius = 11
        plusBg.clipsToBounds = true
        container.addSubview(plusBg)
        
        let plusIcon = UIImageView(image: UIImage(systemName: "plus"))
        plusIcon.tintColor = .white
        plusIcon.contentMode = .scaleAspectFit
        plusBg.addSubview(plusIcon)
        
        let label = UILabel()
        label.text = "История"
        label.font = Theme.fontSmall
        label.textColor = Theme.textSecondary
        label.textAlignment = .center
        container.addSubview(label)
        
        avatar.translatesAutoresizingMaskIntoConstraints = false
        plusBg.translatesAutoresizingMaskIntoConstraints = false
        plusIcon.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 2),
            avatar.topAnchor.constraint(equalTo: container.topAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 58),
            avatar.heightAnchor.constraint(equalToConstant: 58),
            plusBg.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -5),
            plusBg.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -5),
            plusBg.widthAnchor.constraint(equalToConstant: 22),
            plusBg.heightAnchor.constraint(equalToConstant: 22),
            plusIcon.centerXAnchor.constraint(equalTo: plusBg.centerXAnchor),
            plusIcon.centerYAnchor.constraint(equalTo: plusBg.centerYAnchor),
            plusIcon.widthAnchor.constraint(equalToConstant: 14),
            plusIcon.heightAnchor.constraint(equalToConstant: 14),
            label.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.heightAnchor.constraint(equalToConstant: 14)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(addTapped))
        container.addGestureRecognizer(tap)
        container.isUserInteractionEnabled = true
        return container
    }
    
    private func makeStoryItem(user: StoryUser, index: Int) -> UIView {
        let container = UIView()
        container.accessibilityValue = "\(index)"
        
        let ring = UIView()
        ring.layer.cornerRadius = 32
        ring.layer.borderWidth = 2.5
        ring.layer.borderColor = UIColor(hex: "F58529").cgColor
        ring.isHidden = !user.hasUnviewed
        container.addSubview(ring)
        
        let avatar = AvatarView()
        avatar.configure(name: user.displayName, color: user.avatarColor, avatarUrl: user.avatarUrl, size: 56)
        avatar.layer.cornerRadius = 28
        container.addSubview(avatar)
        
        let name = user.isOwn ? "Вы" : (user.displayName.components(separatedBy: " ").first ?? user.displayName)
        let label = UILabel()
        label.text = name
        label.font = Theme.fontSmall
        label.textColor = Theme.textSecondary
        label.textAlignment = .center
        container.addSubview(label)
        
        ring.translatesAutoresizingMaskIntoConstraints = false
        avatar.translatesAutoresizingMaskIntoConstraints = false
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            ring.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            ring.centerYAnchor.constraint(equalTo: avatar.centerYAnchor),
            ring.widthAnchor.constraint(equalToConstant: 64),
            ring.heightAnchor.constraint(equalToConstant: 64),
            avatar.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            avatar.topAnchor.constraint(equalTo: container.topAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 56),
            avatar.heightAnchor.constraint(equalToConstant: 56),
            label.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            label.heightAnchor.constraint(equalToConstant: 14)
        ])
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(storyTapped(_:)))
        container.addGestureRecognizer(tap)
        container.isUserInteractionEnabled = true
        return container
    }
    
    @objc private func addTapped() {
        onAddStory?()
    }
    
    @objc private func storyTapped(_ g: UITapGestureRecognizer) {
        guard let container = g.view, let idxStr = container.accessibilityValue, let idx = Int(idxStr) else { return }
        onViewStories?(vm.storyUsers, idx)
    }
}
