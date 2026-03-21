import UIKit

final class CommentsViewController: UIViewController {
    private let post: Post
    private var comments: [PostComment] = []
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let inputBar = UIView()
    private let inputField = UITextField()
    private let sendButton = UIButton(type: .system)
    private var inputBarBottomConstraint: NSLayoutConstraint?
    
    init(post: Post) {
        self.post = post
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bgPrimary
        title = "Комментарии"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(CommentCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = .clear
        tableView.estimatedRowHeight = 60
        tableView.rowHeight = UITableView.automaticDimension
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.keyboardDismissMode = .interactive
        view.addSubview(tableView)
        
        inputBar.backgroundColor = Theme.bgSecondary
        inputBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(inputBar)
        
        inputField.placeholder = "Добавить комментарий..."
        inputField.textColor = Theme.textPrimary
        inputField.backgroundColor = Theme.bgTertiary
        inputField.layer.cornerRadius = Theme.radiusSm
        inputField.translatesAutoresizingMaskIntoConstraints = false
        inputBar.addSubview(inputField)
        
        sendButton.setTitle("Отправить", for: .normal)
        sendButton.tintColor = Theme.accent
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        sendButton.translatesAutoresizingMaskIntoConstraints = false
        inputBar.addSubview(sendButton)
        
        inputBarBottomConstraint = inputBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: inputBar.topAnchor),
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            inputBarBottomConstraint!,
            inputBar.heightAnchor.constraint(equalToConstant: 56),
            inputField.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor, constant: 16),
            inputField.centerYAnchor.constraint(equalTo: inputBar.centerYAnchor),
            inputField.heightAnchor.constraint(equalToConstant: 40),
            sendButton.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor, constant: -16),
            sendButton.centerYAnchor.constraint(equalTo: inputBar.centerYAnchor),
            inputField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8)
        ])
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        Task { await loadComments() }
    }
    
    @objc private func keyboardWillShow(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        let keyboardFrameInView = view.convert(frame, from: nil)
        let keyboardHeight = max(0, view.bounds.maxY - keyboardFrameInView.minY)
        inputBarBottomConstraint?.constant = -keyboardHeight
        let curve = n.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? UIView.AnimationOptions.curveEaseInOut.rawValue
        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curve << 16)) {
            self.view.layoutIfNeeded()
        }
    }
    
    @objc private func keyboardWillHide(_ n: Notification) {
        guard let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        inputBarBottomConstraint?.constant = 0
        let curve = n.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? UIView.AnimationOptions.curveEaseInOut.rawValue
        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curve << 16)) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func loadComments() async {
        do {
            comments = try await APIService.shared.getComments(postId: post.id)
            await MainActor.run { tableView.reloadData() }
        } catch {}
    }
    
    @objc private func doneTapped() { dismiss(animated: true) }
    
    @objc private func sendTapped() {
        let text = (inputField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputField.text = ""
        Task {
            if let comment = try? await APIService.shared.addComment(postId: post.id, text: text) {
                await MainActor.run {
                    comments.append(comment)
                    tableView.reloadData()
                }
            }
        }
    }
}

extension CommentsViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        comments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! CommentCell
        cell.configure(comment: comments[indexPath.row])
        return cell
    }
}

private final class CommentCell: UITableViewCell {
    private let avatar = AvatarView()
    private let nameLabel = UILabel()
    private let commentTextLabel = UILabel()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(avatar)
        contentView.addSubview(nameLabel)
        contentView.addSubview(commentTextLabel)
        nameLabel.font = Theme.fontSubhead
        nameLabel.textColor = Theme.textPrimary
        commentTextLabel.font = Theme.fontBody
        commentTextLabel.textColor = Theme.textSecondary
        commentTextLabel.numberOfLines = 0
        avatar.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        commentTextLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            avatar.widthAnchor.constraint(equalToConstant: 36),
            avatar.heightAnchor.constraint(equalToConstant: 36),
            nameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 8),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            commentTextLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 8),
            commentTextLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 4),
            commentTextLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            commentTextLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(comment: PostComment) {
        avatar.configure(name: comment.authorName, color: comment.authorAvatarColor, size: 36)
        nameLabel.text = comment.authorName
        commentTextLabel.text = comment.text
    }
}
