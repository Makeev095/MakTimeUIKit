import UIKit
import Combine
import PhotosUI

final class ChatViewController: UIViewController {
    private let conversation: Conversation
    private let authService: AuthService
    private let socketService: SocketService
    private let onStartCall: (String, String, String) -> Void
    
    private let vm: ChatViewModel
    private var cancellables = Set<AnyCancellable>()
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let chatInput = ChatInputBar()
    private let typingLabel = UILabel()
    private var chatInputBottomConstraint: NSLayoutConstraint?
    
    init(conversation: Conversation, authService: AuthService, socketService: SocketService, onStartCall: @escaping (String, String, String) -> Void) {
        self.conversation = conversation
        self.authService = authService
        self.socketService = socketService
        self.onStartCall = onStartCall
        self.vm = ChatViewModel(conversation: conversation)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bgPrimary
        title = conversation.participant?.displayName ?? "Чат"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "video.fill"),
            style: .plain,
            target: self,
            action: #selector(videoCallTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = Theme.accent
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(MessageCell.self, forCellReuseIdentifier: "cell")
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.keyboardDismissMode = .interactive
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.estimatedRowHeight = 80
        tableView.rowHeight = UITableView.automaticDimension
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        typingLabel.text = "Печатает..."
        typingLabel.font = Theme.fontCaption
        typingLabel.textColor = Theme.textSecondary
        typingLabel.isHidden = true
        typingLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(typingLabel)
        
        chatInput.configure(vm: vm)
        chatInput.onSend = { [weak self] text in
            self?.vm.sendTextMessageWith(text)
        }
        chatInput.onPhoto = { [weak self] in
            self?.showPhotoPicker()
        }
        chatInput.onVoiceRecord = { [weak self] in
            self?.vm.startVoiceRecording()
        }
        chatInput.onVoiceStop = { [weak self] in
            self?.vm.stopVoiceRecording()
        }
        chatInput.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(chatInput)
        
        chatInputBottomConstraint = chatInput.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: typingLabel.topAnchor),
            typingLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            typingLabel.bottomAnchor.constraint(equalTo: chatInput.topAnchor, constant: -4),
            chatInput.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            chatInput.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            chatInputBottomConstraint!
        ])
        
        vm.setup(socketService: socketService, userId: authService.user?.id ?? "")
        
        vm.$messages.receive(on: DispatchQueue.main).sink { [weak self] _ in
            self?.tableView.reloadData()
            self?.scrollToBottom()
        }.store(in: &cancellables)
        
        vm.$isTyping.map { !$0 }.assign(to: \.isHidden, on: typingLabel).store(in: &cancellables)
        
        Task { await vm.loadMessages() }
        
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide), name: UIResponder.keyboardWillHideNotification, object: nil)
    }
    
    private func scrollToBottom() {
        guard !vm.messages.isEmpty else { return }
        let last = IndexPath(row: vm.messages.count - 1, section: 0)
        tableView.scrollToRow(at: last, at: .bottom, animated: true)
    }
    
    @objc private func videoCallTapped() {
        guard let p = conversation.participant else { return }
        onStartCall(p.id, p.displayName, conversation.id)
    }
    
    @objc private func keyboardWillShow(_ n: Notification) {
        guard let frame = n.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect,
              let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        let keyboardHeight: CGFloat
        let keyboardFrameInView = view.convert(frame, from: nil)
        keyboardHeight = max(0, view.bounds.maxY - keyboardFrameInView.minY)
        chatInputBottomConstraint?.constant = -keyboardHeight
        let curve = n.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? UIView.AnimationOptions.curveEaseInOut.rawValue
        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curve << 16)) {
            self.view.layoutIfNeeded()
        } completion: { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.scrollToBottom() }
        }
    }
    
    @objc private func keyboardWillHide(_ n: Notification) {
        guard let duration = n.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval else { return }
        chatInputBottomConstraint?.constant = 0
        let curve = n.userInfo?[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? UIView.AnimationOptions.curveEaseInOut.rawValue
        UIView.animate(withDuration: duration, delay: 0, options: UIView.AnimationOptions(rawValue: curve << 16)) {
            self.view.layoutIfNeeded()
        }
    }
    
    private func showPhotoPicker() {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
}

extension ChatViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        vm.messages.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! MessageCell
        let msg = vm.messages[indexPath.row]
        cell.configure(
            message: msg,
            isMine: vm.isMine(msg),
            replyTo: vm.replyToMessage(for: msg),
            onDelete: { Task { await self.vm.deleteMessage(msg) } }
        )
        return cell
    }
}

extension ChatViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        result.itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { [weak self] data, _ in
            guard let data = data else { return }
            Task { await self?.vm.sendPhoto(data: data) }
        }
        result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { [weak self] url, _ in
            guard let url = url else { return }
            Task { await self?.vm.sendVideo(url: url) }
        }
    }
}
