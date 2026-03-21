import UIKit

final class PostCardCell: UITableViewCell {
    private let cardContainer = UIView()
    private let avatar = AvatarView()
    private let nameLabel = UILabel()
    private let timeLabel = UILabel()
    private let captionLabel = UILabel()
    private let mediaView = CachedImageView()
    private let actionsStack = UIStackView()
    private let likeButton = UIButton(type: .system)
    private let commentButton = UIButton(type: .system)
    private let repostButton = UIButton(type: .system)
    
    private var onLike: (() -> Void)?
    private var onComment: (() -> Void)?
    private var onRepost: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(cardContainer)
        cardContainer.addSubview(avatar)
        cardContainer.addSubview(nameLabel)
        cardContainer.addSubview(timeLabel)
        cardContainer.addSubview(captionLabel)
        cardContainer.addSubview(mediaView)
        cardContainer.addSubview(actionsStack)
        
        cardContainer.backgroundColor = Theme.bgCard
        cardContainer.layer.cornerRadius = Theme.radiusLg
        cardContainer.clipsToBounds = true
        cardContainer.layer.shadowColor = Theme.shadowColor
        cardContainer.layer.shadowOpacity = Theme.shadowOpacity
        cardContainer.layer.shadowRadius = Theme.shadowRadius
        cardContainer.layer.shadowOffset = Theme.shadowOffset
        
        nameLabel.font = Theme.fontHeadline
        nameLabel.textColor = Theme.textPrimary
        timeLabel.font = Theme.fontCaption
        timeLabel.textColor = Theme.textMuted
        captionLabel.font = Theme.fontBody
        captionLabel.textColor = Theme.textPrimary
        captionLabel.numberOfLines = 0
        
        likeButton.setImage(UIImage(systemName: "heart"), for: .normal)
        likeButton.tintColor = Theme.textSecondary
        likeButton.addTarget(self, action: #selector(likeTapped), for: .touchUpInside)
        commentButton.setImage(UIImage(systemName: "bubble.right"), for: .normal)
        commentButton.tintColor = Theme.textSecondary
        commentButton.addTarget(self, action: #selector(commentTapped), for: .touchUpInside)
        repostButton.setImage(UIImage(systemName: "arrow.2.squarepath"), for: .normal)
        repostButton.tintColor = Theme.textSecondary
        repostButton.addTarget(self, action: #selector(repostTapped), for: .touchUpInside)
        
        actionsStack.axis = .horizontal
        actionsStack.spacing = 24
        actionsStack.distribution = .fillEqually
        actionsStack.addArrangedSubview(likeButton)
        actionsStack.addArrangedSubview(commentButton)
        actionsStack.addArrangedSubview(repostButton)
        
        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        mediaView.layer.cornerRadius = Theme.radius
        
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        avatar.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        actionsStack.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            cardContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            avatar.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 16),
            avatar.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            avatar.widthAnchor.constraint(equalToConstant: 40),
            avatar.heightAnchor.constraint(equalToConstant: 40),
            nameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: avatar.topAnchor),
            nameLabel.trailingAnchor.constraint(lessThanOrEqualTo: timeLabel.leadingAnchor, constant: -8),
            timeLabel.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
            timeLabel.centerYAnchor.constraint(equalTo: nameLabel.centerYAnchor),
            captionLabel.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 8),
            captionLabel.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            captionLabel.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
            mediaView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            mediaView.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
            mediaView.heightAnchor.constraint(equalToConstant: 200),
            actionsStack.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            actionsStack.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
            actionsStack.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -12),
            actionsStack.heightAnchor.constraint(equalToConstant: 36)
        ])
        
        mediaViewTopToCaption = mediaView.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 8)
        mediaViewTopToAvatar = mediaView.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 8)
        actionsTopToMedia = actionsStack.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 8)
        actionsTopToCaption = actionsStack.topAnchor.constraint(equalTo: captionLabel.bottomAnchor, constant: 8)
        actionsTopToAvatar = actionsStack.topAnchor.constraint(equalTo: avatar.bottomAnchor, constant: 8)
    }
    
    private var mediaViewTopToCaption: NSLayoutConstraint!
    private var mediaViewTopToAvatar: NSLayoutConstraint!
    private var actionsTopToMedia: NSLayoutConstraint!
    private var actionsTopToCaption: NSLayoutConstraint!
    private var actionsTopToAvatar: NSLayoutConstraint!
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(post: Post, isMine: Bool, onLike: @escaping () -> Void, onComment: @escaping () -> Void, onRepost: @escaping () -> Void) {
        self.onLike = onLike
        self.onComment = onComment
        self.onRepost = onRepost
        
        avatar.configure(name: post.authorName, color: post.authorAvatarColor, size: 40)
        nameLabel.text = post.authorName
        timeLabel.text = post.timeAgo
        captionLabel.text = post.caption
        captionLabel.isHidden = post.caption.isEmpty
        
        likeButton.setImage(UIImage(systemName: post.isLiked ? "heart.fill" : "heart"), for: .normal)
        likeButton.tintColor = post.isLiked ? Theme.accentSecondary : Theme.textSecondary
        likeButton.setTitle(" \(post.likesCount)", for: .normal)
        commentButton.setTitle(" \(post.commentsCount)", for: .normal)
        repostButton.setTitle(" \(post.repostsCount)", for: .normal)
        
        if post.type == .image, let url = URL(string: post.fullFileUrl) {
            mediaView.isHidden = false
            mediaView.load(url: url)
        } else {
            mediaView.isHidden = true
        }
        
        mediaViewTopToCaption.isActive = !captionLabel.isHidden
        mediaViewTopToAvatar.isActive = captionLabel.isHidden
        
        actionsTopToMedia.isActive = !mediaView.isHidden
        actionsTopToCaption.isActive = mediaView.isHidden && !captionLabel.isHidden
        actionsTopToAvatar.isActive = mediaView.isHidden && captionLabel.isHidden
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        mediaView.isHidden = true
    }
    
    @objc private func likeTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onLike?()
    }
    @objc private func commentTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onComment?()
    }
    @objc private func repostTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        onRepost?()
    }
}
