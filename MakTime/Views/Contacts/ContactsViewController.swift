import UIKit
import Combine

// MARK: - UI / layout — список контактов
// Поиск, UITableView, ячейки пользователей; переход в чат через роутер.

final class ContactsViewController: UIViewController {
    private let authService: AuthService
    private let socketService: SocketService
    private let onSelectUser: (User) -> Void
    
    private let vm = ContactsViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    private let searchBar = SearchBarView()
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var searchResults: [User] = []
    private var searchQuery = ""
    
    init(authService: AuthService, socketService: SocketService, onSelectUser: @escaping (User) -> Void) {
        self.authService = authService
        self.socketService = socketService
        self.onSelectUser = onSelectUser
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bgPrimary
        title = "Контакты"
        
        searchBar.placeholder = "Найти пользователя..."
        searchBar.onTextChanged = { [weak self] text in
            self?.searchQuery = text
            if text.count >= 2 {
                Task { await self?.performSearch(text) }
            } else {
                self?.searchResults = []
                self?.tableView.reloadData()
            }
        }
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(searchBar)
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ContactCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            searchBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            searchBar.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            searchBar.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            searchBar.heightAnchor.constraint(equalToConstant: 42),
            tableView.topAnchor.constraint(equalTo: searchBar.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        
        vm.setup(socketService: socketService)

        vm.$contacts.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.tableView.reloadData()
        }.store(in: &cancellables)

        socketService.$onlineUserIds.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.tableView.reloadData()
        }.store(in: &cancellables)

        Task { await vm.loadContacts() }
    }
    
    private func performSearch(_ query: String) async {
        do {
            searchResults = try await APIService.shared.searchUsers(query: query)
            await MainActor.run { tableView.reloadData() }
        } catch {
            searchResults = []
            await MainActor.run { tableView.reloadData() }
        }
    }
    
    private var filteredContacts: [User] {
        if searchQuery.isEmpty { return vm.contacts }
        return vm.contacts.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchQuery) ||
            $0.username.localizedCaseInsensitiveContains(searchQuery)
        }
    }
}

extension ContactsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !searchQuery.isEmpty && !searchResults.isEmpty {
            return searchResults.count
        }
        return filteredContacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! ContactCell
        if !searchQuery.isEmpty && !searchResults.isEmpty {
            let user = searchResults[indexPath.row]
            let online = socketService.isUserOnline(user.id) || user.isOnline
            cell.configure(user: user, showAdd: !vm.contacts.contains { $0.id == user.id }, isOnline: online)
        } else {
            let user = filteredContacts[indexPath.row]
            let online = socketService.isUserOnline(user.id) || user.isOnline
            cell.configure(user: user, showAdd: false, isOnline: online)
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if !searchQuery.isEmpty && !searchResults.isEmpty {
            let user = searchResults[indexPath.row]
            if !vm.contacts.contains(where: { $0.id == user.id }) {
                Task { await vm.addContact(userId: user.id) }
            }
        }
        let user = (!searchQuery.isEmpty && !searchResults.isEmpty) ? searchResults[indexPath.row] : filteredContacts[indexPath.row]
        onSelectUser(user)
    }
}

private final class ContactCell: UITableViewCell {
    private let avatar = AvatarView()
    private let nameLabel = UILabel()
    private let usernameLabel = UILabel()
    private let addIcon = UIImageView(image: UIImage(systemName: "person.badge.plus"))
    private var addIconWidthConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(avatar)
        contentView.addSubview(nameLabel)
        contentView.addSubview(usernameLabel)
        contentView.addSubview(addIcon)
        nameLabel.font = Theme.fontSubhead
        nameLabel.textColor = Theme.textPrimary
        usernameLabel.font = Theme.fontCaption
        usernameLabel.textColor = Theme.textSecondary
        addIcon.tintColor = Theme.accent
        addIcon.contentMode = .scaleAspectFit
        
        avatar.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        usernameLabel.translatesAutoresizingMaskIntoConstraints = false
        addIcon.translatesAutoresizingMaskIntoConstraints = false
        
        addIconWidthConstraint = addIcon.widthAnchor.constraint(equalToConstant: 24)
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatar.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            avatar.widthAnchor.constraint(equalToConstant: 44),
            avatar.heightAnchor.constraint(equalToConstant: 44),
            nameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: addIcon.leadingAnchor, constant: -8),
            usernameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            usernameLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            usernameLabel.trailingAnchor.constraint(lessThanOrEqualTo: addIcon.leadingAnchor, constant: -8),
            usernameLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12),
            addIcon.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            addIcon.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            addIconWidthConstraint,
            addIcon.heightAnchor.constraint(equalToConstant: 24)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(user: User, showAdd: Bool, isOnline: Bool) {
        avatar.configure(name: user.displayName, color: user.avatarColor, avatarUrl: user.avatarUrl, size: 44, showOnline: isOnline)
        nameLabel.text = user.displayName
        usernameLabel.text = "@\(user.username)"
        addIcon.isHidden = !showAdd
        addIconWidthConstraint.constant = showAdd ? 24 : 0
    }
}
