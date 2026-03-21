import UIKit

final class MessageCell: UITableViewCell {
    private let bubbleView = UIView()
    private let textLabel_ = UILabel()
    private let timeLabel = UILabel()
    private let mediaView = CachedImageView()
    
    private var onDelete: (() -> Void)?
    private var isMine = false
    
    private var bubbleLeading: NSLayoutConstraint!
    private var bubbleTrailing: NSLayoutConstraint!
    private var textTopToBubble: NSLayoutConstraint!
    private var textTopToMedia: NSLayoutConstraint!
    private var mediaHeightConstraint: NSLayoutConstraint!
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(mediaView)
        bubbleView.addSubview(textLabel_)
        bubbleView.addSubview(timeLabel)
        
        textLabel_.numberOfLines = 0
        textLabel_.font = Theme.fontBody
        timeLabel.font = Theme.fontCaption
        timeLabel.textColor = Theme.textMuted
        mediaView.contentMode = .scaleAspectFit
        mediaView.clipsToBounds = true
        mediaView.layer.cornerRadius = Theme.radiusSm
        
        bubbleView.layer.cornerRadius = Theme.radiusLg
        bubbleView.clipsToBounds = true
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        textLabel_.translatesAutoresizingMaskIntoConstraints = false
        timeLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        bubbleView.addGestureRecognizer(longPress)
        bubbleView.isUserInteractionEnabled = true
        
        textTopToBubble = textLabel_.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8)
        textTopToMedia = textLabel_.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 4)
        
        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75),
            mediaView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            mediaView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 8),
            mediaView.trailingAnchor.constraint(lessThanOrEqualTo: bubbleView.trailingAnchor, constant: -8),
            mediaView.widthAnchor.constraint(lessThanOrEqualToConstant: 220),
            textLabel_.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            textLabel_.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            timeLabel.topAnchor.constraint(equalTo: textLabel_.bottomAnchor, constant: 4),
            timeLabel.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12),
            timeLabel.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12),
            timeLabel.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8)
        ])
        
        bubbleLeading = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        bubbleTrailing = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        mediaHeightConstraint = mediaView.heightAnchor.constraint(equalToConstant: 0)
        mediaHeightConstraint.isActive = true
        textTopToBubble.isActive = true
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func configure(message: Message, isMine: Bool, replyTo: Message?, onDelete: @escaping () -> Void) {
        self.isMine = isMine
        self.onDelete = onDelete
        
        textLabel_.text = message.text
        textLabel_.textColor = isMine ? .white : Theme.textPrimary
        timeLabel.text = message.dateFormatted
        bubbleView.backgroundColor = isMine ? Theme.msgSent : Theme.msgReceived
        
        mediaView.isHidden = true
        mediaHeightConstraint.constant = 0
        if message.type == .image, let url = URL(string: message.fullFileUrl ?? "") {
            mediaView.isHidden = false
            mediaHeightConstraint.constant = 150
            mediaView.load(url: url)
        }
        textTopToBubble.isActive = mediaView.isHidden
        textTopToMedia.isActive = !mediaView.isHidden
        bubbleLeading.isActive = !isMine
        bubbleTrailing.isActive = isMine
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        textLabel_.text = nil
        mediaView.isHidden = true
        mediaHeightConstraint.constant = 0
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        guard let vc = findViewController() else { return }
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Удалить", style: .destructive) { [weak self] _ in
            self?.onDelete?()
        })
        alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
        if let popover = alert.popoverPresentationController {
            popover.sourceView = bubbleView
            popover.sourceRect = bubbleView.bounds
        }
        vc.present(alert, animated: true)
    }
    
    private func findViewController() -> UIViewController? {
        var responder: UIResponder? = self
        while let r = responder {
            if let vc = r as? UIViewController { return vc }
            responder = r.next
        }
        return nil
    }
}
