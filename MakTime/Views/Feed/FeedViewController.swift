import UIKit
import Combine
import SnapKit

// MARK: - UI / layout — лента (UIKit-вариант, таблица)
// UITableView + refresh; дублирует сценарий ленты в UIKit. Основной UI — `FeedSwiftUIView`.

final class FeedViewController: UIViewController {
    private let authService: AuthService
    private let vm = FeedViewModel()
    private let feedSound = FeedVideoSoundState()
    private var cancellables = Set<AnyCancellable>()
    
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let refreshControl = UIRefreshControl()
    
    init(authService: AuthService) {
        self.authService = authService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bgPrimary
        title = "Лента"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "plus"),
            style: .plain,
            target: self,
            action: #selector(createPostTapped)
        )
        navigationItem.rightBarButtonItem?.tintColor = Theme.accent
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(PostCardCell.self, forCellReuseIdentifier: "cell")
        tableView.register(SkeletonPostCell.self, forCellReuseIdentifier: "skeleton")
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        tableView.estimatedRowHeight = 300
        tableView.rowHeight = UITableView.automaticDimension
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        vm.$posts.combineLatest(vm.$isLoading)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in
                self?.tableView.reloadData()
            }.store(in: &cancellables)
        
        Task { await vm.loadPosts() }
    }
    
    @objc private func createPostTapped() {
        let vc = CreatePostViewController(vm: vm) { [weak self] in
            self?.dismiss(animated: true)
        }
        vc.modalPresentationStyle = .pageSheet
        present(vc, animated: true)
    }
    
    @objc private func refresh() {
        Task {
            await vm.refreshPosts()
            refreshControl.endRefreshing()
        }
    }
}

extension FeedViewController: UITableViewDelegate, UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        vm.isLoading && vm.posts.isEmpty ? 5 : vm.posts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if vm.isLoading && vm.posts.isEmpty {
            let cell = tableView.dequeueReusableCell(withIdentifier: "skeleton", for: indexPath) as! SkeletonPostCell
            cell.showSkeleton()
            return cell
        }
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! PostCardCell
        let post = vm.posts[indexPath.row]
        cell.configure(
            post: post,
            isMine: post.authorId == authService.user?.id,
            onLike: { [weak self] in self?.vm.toggleLike(post: post) },
            onComment: { [weak self] in
                let commentsVC = CommentsViewController(post: post)
                self?.present(commentsVC, animated: true)
            },
            onRepost: { [weak self] in self?.vm.repost(post: post) }
        )
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard !vm.isLoading || !vm.posts.isEmpty else { return }
        let post = vm.posts[indexPath.row]
        if post.type == .video {
            let videoPosts = vm.posts.filter { $0.type == .video }
            let idx = videoPosts.firstIndex(where: { $0.id == post.id }) ?? 0
            let vc = ReelsViewController(
                posts: videoPosts,
                startIndex: idx,
                onClose: { [weak self] in self?.dismiss(animated: true) },
                onLike: { [weak self] p in self?.vm.toggleLike(post: p) },
                onComment: { [weak self] p in
                    self?.dismiss(animated: true)
                    let commentsVC = CommentsViewController(post: p)
                    self?.present(commentsVC, animated: true)
                },
                onRepost: { [weak self] p in self?.vm.repost(post: p) }
            )
            vc.modalPresentationStyle = .fullScreen
            present(vc, animated: true)
        }
    }
}
