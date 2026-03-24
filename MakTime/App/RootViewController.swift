import UIKit
import Combine

// MARK: - UI / layout — корень UIKit (если не используете только SwiftUI)
// Переключение дочерних VC (splash / MainTabController / Auth); фон view — Theme.bgPrimary.

final class RootViewController: UIViewController {
    private let authService: AuthService
    private let socketService: SocketService
    private let callCoordinator: CallCoordinator
    private var cancellables = Set<AnyCancellable>()
    
    private var currentChild: UIViewController?
    
    init(authService: AuthService, socketService: SocketService, callCoordinator: CallCoordinator) {
        self.authService = authService
        self.socketService = socketService
        self.callCoordinator = callCoordinator
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bgPrimary
        
        authService.$isLoading
            .combineLatest(authService.$token, authService.$user)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading, token, user in
                let isAuthenticated = token != nil && user != nil
                self?.updateChild(isLoading: isLoading, token: token, isAuthenticated: isAuthenticated)
            }
            .store(in: &cancellables)
        
        updateChild(isLoading: authService.isLoading, token: authService.token, isAuthenticated: authService.isAuthenticated)
    }
    
    private func updateChild(isLoading: Bool, token: String?, isAuthenticated: Bool) {
        let newChild: UIViewController
        if isLoading && token != nil {
            newChild = SplashViewController()
        } else if isAuthenticated {
            newChild = MainTabController(authService: authService, socketService: socketService, callCoordinator: callCoordinator)
        } else {
            newChild = AuthViewController(authService: authService)
        }
        
        guard type(of: newChild) != type(of: currentChild) else { return }
        
        if let old = currentChild {
            old.willMove(toParent: nil)
            UIView.transition(with: view, duration: 0.3, options: .transitionCrossDissolve) {
                old.view.removeFromSuperview()
                old.removeFromParent()
            }
        }
        
        addChild(newChild)
        newChild.view.frame = view.bounds
        newChild.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(newChild.view)
        newChild.didMove(toParent: self)
        currentChild = newChild
    }
}
