import UIKit
import Combine

final class ConversationListViewController: UIViewController {
    private let authService: AuthService
    private let socketService: SocketService
    private let onSelectConversation: (Conversation) -> Void
    private let onStartCall: (String, String, String, Bool) -> Void
    
    private let vm = ConversationsViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    private let searchBar = SearchBarView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    private let emptyLabel = UILabel()
    
    init(authService: AuthService, socketService: SocketService, onSelectConversation: @escaping (Conversation) -> Void, onStartCall: @escaping (String, String, String, Bool) -> Void) {
        self.authService = authService
        self.socketService = socketService
        self.onSelectConversation = onSelectConversation
        self.onStartCall = onStartCall
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bgPrimary
        
        vm.setup(socketService: socketService, currentUserId: authService.user?.id ?? "")
        authService.$user
            .receive(on: DispatchQueue.main)
            .sink { [weak self] user in
                self?.vm.updateCurrentUserId(user?.id ?? "")
            }
            .store(in: &cancellables)
        
        searchBar.placeholder = "Поиск..."
        searchBar.onTextChanged = { [weak self] text in
            self?.vm.searchQuery = text
        }
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ConversationCell.self, forCellReuseIdentifier: "cell")
        tableView.register(SearchResultCell.self, forCellReuseIdentifier: "search")
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .singleLine
        tableView.separatorColor = Theme.border
        tableView.separatorInset = UIEdgeInsets(top: 0, left: 76, bottom: 0, right: 16)
        tableView.estimatedRowHeight = 76
        tableView.rowHeight = UITableView.automaticDimension
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        emptyLabel.text = "Нет чатов"
        emptyLabel.textColor = Theme.textSecondary
        emptyLabel.font = Theme.fontHeadline
        emptyLabel.textAlignment = .center
        emptyLabel.isHidden = true
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyLabel)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchBar.heightAnchor.constraint(equalToConstant: 42),
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tableView.centerYAnchor)
        ])
        
        vm.$conversations.combineLatest(vm.$searchResults, vm.$searchQuery)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _, _ in
                self?.tableView.reloadData()
                let convs = self?.vm.filteredConversations ?? []
                let results = self?.vm.searchResults ?? []
                let query = self?.vm.searchQuery ?? ""
                let showEmpty = convs.isEmpty && !(self?.vm.isLoading ?? false) && (query.isEmpty || results.isEmpty)
                self?.emptyLabel.isHidden = !showEmpty
            }
            .store(in: &cancellables)

        socketService.$onlineUserIds
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.tableView.reloadData()
            }
            .store(in: &cancellables)
        
        Task { await vm.loadConversations() }
    }
    
    @objc private func refresh() {
        Task {
            await vm.loadConversations()
            refreshControl.endRefreshing()
        }
    }
}

extension ConversationListViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        if !vm.searchQuery.isEmpty && !vm.searchResults.isEmpty {
            return 1
        }
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !vm.searchQuery.isEmpty && !vm.searchResults.isEmpty {
            return vm.searchResults.count
        }
        return vm.filteredConversations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if !vm.searchQuery.isEmpty && !vm.searchResults.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "search", for: indexPath) as! SearchResultCell
            let user = vm.searchResults[indexPath.row]
            cell.configure(user: user)
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ConversationCell
        let conv = vm.filteredConversations[indexPath.row]
        cell.configure(conv: conv, isOnline: vm.isUserOnline(conv.participant?.id ?? ""))
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if !vm.searchQuery.isEmpty && !vm.searchResults.isEmpty {
            let user = vm.searchResults[indexPath.row]
            Task {
                if let conv = await vm.createConversation(with: user.id) {
                    vm.searchQuery = ""
                    vm.searchResults = []
                    searchBar.text = ""
                    onSelectConversation(conv)
                }
            }
        } else {
            let conv = vm.filteredConversations[indexPath.row]
            onSelectConversation(conv)
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard vm.searchQuery.isEmpty else { return nil }
        let conv = vm.filteredConversations[indexPath.row]
        let delete = UIContextualAction(style: .destructive, title: "Удалить") { [weak self] _, _, completion in
            Task {
                do {
                    try await APIService.shared.deleteConversation(conversationId: conv.id)
                    self?.vm.conversations.removeAll { $0.id == conv.id }
                } catch {}
                completion(true)
            }
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }
}

private final class ConversationCell: UITableViewCell {
    private let avatar = AvatarView()
    private let nameLabel = UILabel()
    private let previewLabel = UILabel()
    private let timeLabel = UILabel()
    private let unreadBadge = UILabel()
    private var unreadWidthConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(avatar)
        contentView.addSubview(nameLabel)
        contentView.addSubview(previewLabel)
        contentView.addSubview(timeLabel)
        contentView.addSubview(unreadBadge)
        nameLabel.font = Theme.fontHeadline
        nameLabel.textColor = Theme.textPrimary
        nameLabel.lineBreakMode = .byTruncatingTail
        previewLabel.font = Theme.fontSubhead
        previewLabel.textColor = Theme.textSecondary
        previewLabel.lineBreakMode = .byTruncatingTail
        timeLabel.font = Theme.fontCaption
        timeLabel.textColor = Theme.textMuted
        unreadBadge.font = Theme.fontSmallBold
        unreadBadge.textColor = .white
        unreadBadge.backgroundColor = Theme.accent
        unreadBadge.textAlignment = .center
        unreadBadge.layer.cornerRadius = 10
        unreadBadge.clipsToBounds = true
        
        avatar.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        unreadBadge.translatesAutoresizingMaskIntoConstraints = false
        
        unreadWidthConstraint = unreadBadge.widthAnchor.constraint(equalToConstant: 20)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            avatar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            avatar.widthAnchor.constraint(equalToConstant: 52),
            avatar.heightAnchor.constraint(equalToConstant: 52),
            nameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),
            timeLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            timeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            previewLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            previewLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            previewLabel.trailingAnchor.constraint(lessThanOrEqualTo: unreadBadge.leadingAnchor, constant: -8),
            previewLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            unreadBadge.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -14),
            unreadBadge.centerYAnchor.constraint(equalTo: previewLabel.centerYAnchor),
            unreadWidthConstraint,
            unreadBadge.heightAnchor.constraint(equalToConstant: 20)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(conv: Conversation, isOnline: Bool) {
        avatar.configure(
            name: conv.participant?.displayName ?? "?",
            color: conv.participant?.avatarColor ?? "#6C63FF",
            avatarUrl: conv.participant?.avatarUrl,
            size: 52,
            showOnline: isOnline
        )
        nameLabel.text = conv.participant?.displayName ?? "Чат"
        previewLabel.text = conv.lastMessagePreview
        timeLabel.text = conv.lastMessageTimeFormatted
        unreadBadge.text = conv.unreadCount > 0 ? "\(conv.unreadCount)" : ""
        unreadBadge.isHidden = conv.unreadCount == 0
        unreadWidthConstraint.constant = conv.unreadCount > 0 ? 28 : 0
    }
}

private final class SearchResultCell: UITableViewCell {
    private let avatar = AvatarView()
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(avatar)
        contentView.addSubview(nameLabel)
        contentView.addSubview(usernameLabel)
        nameLabel.font = Theme.fontSubhead
        nameLabel.textColor = Theme.textPrimary
        usernameLabel.font = Theme.fontCaption
        usernameLabel.textColor = Theme.textSecondary
        
        avatar.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatar.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 40),
            avatar.heightAnchor.constraint(equalToConstant: 40),
            nameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            usernameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            usernameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            usernameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(user: User) {
        avatar.configure(name: user.displayName, color: user.avatarColor, avatarUrl: user.avatarUrl, size: 40)
        nameLabel.text = user.displayName
        usernameLabel.text = "@\(user.username)"
    }
}
