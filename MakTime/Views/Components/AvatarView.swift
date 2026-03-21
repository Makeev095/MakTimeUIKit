import UIKit

final class AvatarView: UIView {
    var name: String = "" { didSet { updateInitials() } }
    var color: String = "#6C63FF" { didSet { updateColor() } }
    var avatarUrl: String? { didSet { loadImage() } }
    var size: CGFloat = 44 { didSet { updateSize() } }
    var showOnline: Bool = false { didSet { onlineIndicator.isHidden = !showOnline } }
    
    private let imageView = UIImageView()
    private let initialsLabel = UILabel()
    private let onlineIndicator = UIView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setup() {
        clipsToBounds = true
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        addSubview(imageView)
        
        initialsLabel.textAlignment = .center
        initialsLabel.textColor = .white
        initialsLabel.backgroundColor = .clear
        addSubview(initialsLabel)
        
        onlineIndicator.backgroundColor = Theme.success
        onlineIndicator.layer.borderWidth = 2
        onlineIndicator.layer.borderColor = Theme.bgPrimary.cgColor
        onlineIndicator.isHidden = true
        addSubview(onlineIndicator)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = bounds
        initialsLabel.frame = bounds
        let indSize = max(10, size * 0.26)
        let inset: CGFloat = 1.5
        // Полностью внутри bounds — раньше +2 выносило индикатор за круг и обрезалось clipsToBounds.
        onlineIndicator.frame = CGRect(
            x: bounds.width - indSize - inset,
            y: bounds.height - indSize - inset,
            width: indSize,
            height: indSize
        )
        onlineIndicator.layer.cornerRadius = indSize / 2
    }
    
    override var bounds: CGRect {
        didSet { layer.cornerRadius = bounds.width / 2 }
    }
    
    private func updateSize() {
        frame.size = CGSize(width: size, height: size)
    }
    
    private func updateInitials() {
        let parts = name.split(separator: " ")
        let text: String
        if parts.count >= 2 {
            text = String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        } else {
            text = String(name.prefix(2)).uppercased()
        }
        initialsLabel.text = text
        initialsLabel.font = .systemFont(ofSize: size * 0.38, weight: .semibold)
    }
    
    private func updateColor() {
        backgroundColor = UIColor(hex: color)
    }
    
    private func loadImage() {
        guard let urlStr = avatarUrl, !urlStr.isEmpty,
              let url = URL(string: urlStr.hasPrefix("http") ? urlStr : "\(AppConfig.baseURL)\(urlStr)") else {
            imageView.image = nil
            imageView.isHidden = true
            initialsLabel.isHidden = false
            return
        }
        imageView.isHidden = true
        initialsLabel.isHidden = false
        Task {
            if let img = await ImageCache.shared.load(url: url) {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    imageView.image = img
                    imageView.isHidden = false
                    initialsLabel.isHidden = true
                }
            }
        }
    }
    
    func configure(name: String, color: String, avatarUrl: String? = nil, size: CGFloat = 44, showOnline: Bool = false) {
        self.name = name
        self.color = color
        self.avatarUrl = avatarUrl
        self.size = size
        self.showOnline = showOnline
        frame.size = CGSize(width: size, height: size)
        updateInitials()
        updateColor()
        loadImage()
    }
}
