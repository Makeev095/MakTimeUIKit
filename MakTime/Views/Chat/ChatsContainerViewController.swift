import UIKit
import Combine

final class ChatsContainerViewController: UIViewController {
    private let authService: AuthService
    private let socketService: SocketService
    private let onSelectConversation: (Conversation) -> Void
    private let onStartCall: (String, String, String) -> Void
    
    private let storyBar = StoryBarView()
    private let divider = UIView()
    private let conversationListVC: ConversationListViewController
    
    init(authService: AuthService, socketService: SocketService, onSelectConversation: @escaping (Conversation) -> Void, onStartCall: @escaping (String, String, String) -> Void) {
        self.authService = authService
        self.socketService = socketService
        self.onSelectConversation = onSelectConversation
        self.onStartCall = onStartCall
        self.conversationListVC = ConversationListViewController(
            socketService: socketService,
            onSelectConversation: onSelectConversation,
            onStartCall: onStartCall
        )
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bgPrimary
        title = "Чаты"
        
        storyBar.configure(authService: authService, socketService: socketService)
        storyBar.onViewStories = { [weak self] users, idx in
            let vc = StoryViewerViewController(storyUsers: users, startUserIdx: idx) { [weak self] in
                self?.dismiss(animated: true)
            }
            vc.modalPresentationStyle = .fullScreen
            self?.present(vc, animated: true)
        }
        storyBar.onAddStory = { [weak self] in
            let vc = StoryUploadViewController { [weak self] in
                self?.dismiss(animated: true)
            } onPublished: { [weak self] in
                self?.dismiss(animated: true)
            }
            vc.modalPresentationStyle = .pageSheet
            self?.present(vc, animated: true)
        }
        
        addChild(conversationListVC)
        view.addSubview(storyBar)
        view.addSubview(divider)
        view.addSubview(conversationListVC.view)
        conversationListVC.didMove(toParent: self)
        
        storyBar.translatesAutoresizingMaskIntoConstraints = false
        divider.translatesAutoresizingMaskIntoConstraints = false
        conversationListVC.view.translatesAutoresizingMaskIntoConstraints = false
        
        divider.backgroundColor = Theme.border
        
        NSLayoutConstraint.activate([
            storyBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            storyBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            storyBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            storyBar.heightAnchor.constraint(equalToConstant: 90),
            divider.topAnchor.constraint(equalTo: storyBar.bottomAnchor),
            divider.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            divider.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1),
            conversationListVC.view.topAnchor.constraint(equalTo: divider.bottomAnchor),
            conversationListVC.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            conversationListVC.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            conversationListVC.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}
