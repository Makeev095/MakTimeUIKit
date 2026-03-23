import UIKit

final class MessageCell: UITableViewCell {
    private let bubbleView = UIView()
    /// Вертикально: текст, строка времени (время прижато к краю через spacer).
    private let contentStack = UIStackView()
    private let timeRowStack = UIStackView()
    private let timeRowSpacer = UIView()
    private let textLabel_ = UILabel()
    private let timeLabel = UILabel()
    private let mediaView = CachedImageView()

    private var onDelete: (() -> Void)?

    private var bubbleLeadingToContent: NSLayoutConstraint!
    private var bubbleTrailingToContent: NSLayoutConstraint!
    private var bubbleTrailingToStack: NSLayoutConstraint!
    private var bubbleLeadingToStack: NSLayoutConstraint!
    private var contentStackLeadingToBubble: NSLayoutConstraint!
    private var contentStackTrailingToBubble: NSLayoutConstraint!

    private var textTopToBubble: NSLayoutConstraint!
    private var textTopToMedia: NSLayoutConstraint!
    private var mediaHeightConstraint: NSLayoutConstraint!
    private var mediaAspectConstraint: NSLayoutConstraint!
    private var bubbleMaxWidth: NSLayoutConstraint!

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(bubbleView)
        bubbleView.addSubview(mediaView)
        bubbleView.addSubview(contentStack)

        timeRowStack.axis = .horizontal
        timeRowStack.spacing = 6
        timeRowStack.distribution = .fill
        timeRowStack.alignment = .center
        timeRowSpacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        timeRowSpacer.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        contentStack.axis = .vertical
        contentStack.spacing = 4
        contentStack.alignment = .leading
        contentStack.distribution = .fill
        contentStack.addArrangedSubview(textLabel_)
        contentStack.addArrangedSubview(timeRowStack)
        contentStack.setContentHuggingPriority(.required, for: .horizontal)
        contentStack.setContentCompressionResistancePriority(.required, for: .horizontal)

        textLabel_.numberOfLines = 0
        textLabel_.font = Theme.fontBody
        textLabel_.setContentHuggingPriority(.defaultLow, for: .horizontal)
        textLabel_.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
        textLabel_.setContentHuggingPriority(.required, for: .vertical)

        timeLabel.setContentHuggingPriority(.required, for: .horizontal)
        timeLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        timeLabel.font = Theme.fontCaption
        timeLabel.textColor = Theme.textMuted

        mediaView.contentMode = .scaleAspectFill
        mediaView.clipsToBounds = true
        mediaView.layer.cornerRadius = Theme.radius

        bubbleView.layer.cornerRadius = Theme.radiusLg
        bubbleView.clipsToBounds = true
        bubbleView.setContentHuggingPriority(.required, for: .horizontal)
        bubbleView.setContentCompressionResistancePriority(.required, for: .horizontal)
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        mediaView.translatesAutoresizingMaskIntoConstraints = false
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        timeRowStack.translatesAutoresizingMaskIntoConstraints = false

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        bubbleView.addGestureRecognizer(longPress)
        bubbleView.isUserInteractionEnabled = true

        textTopToBubble = contentStack.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8)
        textTopToMedia = contentStack.topAnchor.constraint(equalTo: mediaView.bottomAnchor, constant: 4)

        bubbleLeadingToContent = bubbleView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12)
        bubbleTrailingToContent = bubbleView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        bubbleTrailingToStack = bubbleView.trailingAnchor.constraint(equalTo: contentStack.trailingAnchor, constant: 12)
        bubbleLeadingToStack = bubbleView.leadingAnchor.constraint(equalTo: contentStack.leadingAnchor, constant: -12)
        contentStackLeadingToBubble = contentStack.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 12)
        contentStackTrailingToBubble = contentStack.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -12)

        bubbleMaxWidth = bubbleView.widthAnchor.constraint(lessThanOrEqualTo: contentView.widthAnchor, multiplier: 0.75)

        NSLayoutConstraint.activate([
            bubbleView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubbleView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            bubbleMaxWidth,
            mediaView.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: 8),
            mediaView.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 8),
            mediaView.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -8),
            contentStack.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -8)
        ])

        mediaHeightConstraint = mediaView.heightAnchor.constraint(equalToConstant: 0)
        mediaAspectConstraint = mediaView.heightAnchor.constraint(equalTo: mediaView.widthAnchor, multiplier: 1)
        mediaHeightConstraint.isActive = true
        mediaAspectConstraint.isActive = false
        applyTextTopConstraints(hasMedia: false)
        applyHorizontalLayout(isMine: false)
    }

    private func applyTimeRowOrder(isMine: Bool) {
        timeRowStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        if isMine {
            timeRowStack.addArrangedSubview(timeRowSpacer)
            timeRowStack.addArrangedSubview(timeLabel)
        } else {
            timeRowStack.addArrangedSubview(timeLabel)
            timeRowStack.addArrangedSubview(timeRowSpacer)
        }
    }

    private func applyTextTopConstraints(hasMedia: Bool) {
        NSLayoutConstraint.deactivate([textTopToBubble, textTopToMedia])
        if hasMedia {
            textTopToMedia.isActive = true
        } else {
            textTopToBubble.isActive = true
        }
    }

    private func applyHorizontalLayout(isMine: Bool) {
        NSLayoutConstraint.deactivate([
            bubbleLeadingToContent, bubbleTrailingToContent,
            bubbleTrailingToStack, bubbleLeadingToStack,
            contentStackLeadingToBubble, contentStackTrailingToBubble
        ])
        contentStack.alignment = isMine ? .trailing : .leading
        applyTimeRowOrder(isMine: isMine)
        if isMine {
            bubbleTrailingToContent.isActive = true
            bubbleLeadingToStack.isActive = true
            contentStackTrailingToBubble.isActive = true
        } else {
            bubbleLeadingToContent.isActive = true
            bubbleTrailingToStack.isActive = true
            contentStackLeadingToBubble.isActive = true
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyLabelPreferredMaxWidth()
    }

    private func applyLabelPreferredMaxWidth() {
        let w = contentView.bounds.width
        guard w > 0 else { return }
        let cap = max(0, w * 0.75 - 48)
        if textLabel_.isHidden {
            textLabel_.preferredMaxLayoutWidth = 0
            textLabel_.invalidateIntrinsicContentSize()
            return
        }
        guard let text = textLabel_.text, !text.isEmpty else {
            textLabel_.preferredMaxLayoutWidth = 0
            textLabel_.invalidateIntrinsicContentSize()
            return
        }
        let font = textLabel_.font ?? Theme.fontBody
        let singleLineW = (text as NSString).size(withAttributes: [.font: font]).width
        let rect = (text as NSString).boundingRect(
            with: CGSize(width: cap, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        if rect.height > font.lineHeight * 1.55 {
            textLabel_.preferredMaxLayoutWidth = cap
        } else {
            textLabel_.preferredMaxLayoutWidth = min(cap, max(ceil(singleLineW), 1))
        }
        textLabel_.invalidateIntrinsicContentSize()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func configure(message: Message, isMine: Bool, replyTo: Message?, onDelete: @escaping () -> Void) {
        self.onDelete = onDelete

        let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch message.type {
        case .voice:
            let totalSec = max(0, Int(round(message.duration ?? 0)))
            let mins = totalSec / 60
            let secs = totalSec % 60
            textLabel_.text = String(format: "🎤 %d:%02d", mins, secs)
            textLabel_.isHidden = false
        case .image:
            textLabel_.text = message.text
            textLabel_.isHidden = trimmed.isEmpty
        default:
            textLabel_.text = message.text
            textLabel_.isHidden = trimmed.isEmpty
        }
        textLabel_.textColor = isMine ? .white : Theme.textPrimary
        timeLabel.text = message.dateFormatted
        bubbleView.backgroundColor = isMine ? Theme.msgSent : Theme.msgReceived

        mediaView.isHidden = true
        mediaAspectConstraint.isActive = false
        mediaHeightConstraint.constant = 0
        mediaHeightConstraint.isActive = true
        if message.type == .image, let url = URL(string: message.fullFileUrl ?? "") {
            mediaView.isHidden = false
            mediaHeightConstraint.isActive = false
            mediaAspectConstraint.isActive = true
            mediaView.load(url: url)
        }
        let hasMedia = !mediaView.isHidden && mediaAspectConstraint.isActive
        applyTextTopConstraints(hasMedia: hasMedia)
        applyHorizontalLayout(isMine: isMine)
        setNeedsLayout()
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        bubbleLeadingToContent.isActive = false
        bubbleTrailingToContent.isActive = false
        bubbleTrailingToStack.isActive = false
        bubbleLeadingToStack.isActive = false
        contentStackLeadingToBubble.isActive = false
        contentStackTrailingToBubble.isActive = false
        textLabel_.text = nil
        textLabel_.isHidden = false
        mediaView.isHidden = true
        mediaAspectConstraint.isActive = false
        mediaHeightConstraint.constant = 0
        mediaHeightConstraint.isActive = true
        applyTextTopConstraints(hasMedia: false)
        applyTimeRowOrder(isMine: false)
        applyHorizontalLayout(isMine: false)
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
