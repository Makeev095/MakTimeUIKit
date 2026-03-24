import UIKit
import AVKit
import AVFoundation

// MARK: - UI / layout — полноэкранные рилсы (UIKit)
// Вертикальный paging видео, оверлеи лайк/комментарий; альтернатива/дополнение к FeedSwiftUIView.

final class ReelsViewController: UIViewController {
    private let posts: [Post]
    private var currentIndex: Int
    private let onClose: () -> Void
    private let onLike: (Post) -> Void
    private let onComment: (Post) -> Void
    private let onRepost: (Post) -> Void
    
    private let collectionView: UICollectionView
    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?
    
    init(posts: [Post], startIndex: Int, onClose: @escaping () -> Void, onLike: @escaping (Post) -> Void, onComment: @escaping (Post) -> Void, onRepost: @escaping (Post) -> Void) {
        self.posts = posts
        self.currentIndex = startIndex
        self.onClose = onClose
        self.onLike = onLike
        self.onComment = onComment
        self.onRepost = onRepost
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        self.collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(ReelCell.self, forCellWithReuseIdentifier: "cell")
        collectionView.isPagingEnabled = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.backgroundColor = .black
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)
        
        let closeBtn = UIButton(type: .system)
        closeBtn.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeBtn.tintColor = .white
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeBtn.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeBtn)
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            closeBtn.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            closeBtn.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            closeBtn.widthAnchor.constraint(equalToConstant: 44),
            closeBtn.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        collectionView.scrollToItem(at: IndexPath(item: currentIndex, section: 0), at: .centeredVertically, animated: false)
    }
    
    @objc private func closeTapped() { onClose() }
}

extension ReelsViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        posts.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "cell", for: indexPath) as! ReelCell
        let post = posts[indexPath.item]
        cell.configure(post: post, onLike: { [weak self] in self?.onLike(post) }, onComment: { [weak self] in self?.onComment(post) }, onRepost: { [weak self] in self?.onRepost(post) })
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        collectionView.bounds.size
    }
    
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        let page = Int(scrollView.contentOffset.y / scrollView.bounds.height)
        currentIndex = page
    }
}

private final class ReelCell: UICollectionViewCell {
    private let playerView = UIView()
    private var playerLayer: AVPlayerLayer?
    private var player: AVPlayer?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(playerView)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(post: Post, onLike: @escaping () -> Void, onComment: @escaping () -> Void, onRepost: @escaping () -> Void) {
        player?.pause()
        playerLayer?.removeFromSuperlayer()
        
        guard let url = URL(string: post.fullFileUrl) else { return }
        let p = AVPlayer(url: url)
        p.play()
        let layer = AVPlayerLayer(player: p)
        layer.videoGravity = .resizeAspectFill
        layer.frame = contentView.bounds
        playerView.layer.addSublayer(layer)
        player = p
        playerLayer = layer
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerView.frame = contentView.bounds
        playerLayer?.frame = contentView.bounds
    }
}
