import UIKit
import SkeletonView

// MARK: - UI / layout — плейсхолдер карточки при загрузке
// SkeletonView-анимация; геометрия должна совпадать с PostCardCell по сетке.

final class SkeletonPostCell: UITableViewCell {
    private let cardContainer = UIView()
    private let avatarView = UIView()
    private let line1 = UIView()
    private let line2 = UIView()
    private let mediaPlaceholder = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        selectionStyle = .none
        contentView.addSubview(cardContainer)
        cardContainer.addSubview(avatarView)
        cardContainer.addSubview(line1)
        cardContainer.addSubview(line2)
        cardContainer.addSubview(mediaPlaceholder)
        
        cardContainer.backgroundColor = Theme.bgCard
        cardContainer.layer.cornerRadius = Theme.radiusLg
        cardContainer.clipsToBounds = true
        
        avatarView.backgroundColor = Theme.bgTertiary
        avatarView.layer.cornerRadius = 20
        line1.backgroundColor = Theme.bgTertiary
        line1.layer.cornerRadius = 4
        line2.backgroundColor = Theme.bgTertiary
        line2.layer.cornerRadius = 4
        mediaPlaceholder.backgroundColor = Theme.bgTertiary
        mediaPlaceholder.layer.cornerRadius = Theme.radius
        
        cardContainer.translatesAutoresizingMaskIntoConstraints = false
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        line1.translatesAutoresizingMaskIntoConstraints = false
        line2.translatesAutoresizingMaskIntoConstraints = false
        mediaPlaceholder.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            cardContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            cardContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            cardContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            cardContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            avatarView.topAnchor.constraint(equalTo: cardContainer.topAnchor, constant: 16),
            avatarView.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            avatarView.widthAnchor.constraint(equalToConstant: 40),
            avatarView.heightAnchor.constraint(equalToConstant: 40),
            line1.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            line1.topAnchor.constraint(equalTo: avatarView.topAnchor, constant: 8),
            line1.widthAnchor.constraint(equalToConstant: 120),
            line1.heightAnchor.constraint(equalToConstant: 12),
            line2.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 12),
            line2.topAnchor.constraint(equalTo: line1.bottomAnchor, constant: 8),
            line2.widthAnchor.constraint(equalToConstant: 200),
            line2.heightAnchor.constraint(equalToConstant: 12),
            mediaPlaceholder.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 16),
            mediaPlaceholder.leadingAnchor.constraint(equalTo: cardContainer.leadingAnchor, constant: 16),
            mediaPlaceholder.trailingAnchor.constraint(equalTo: cardContainer.trailingAnchor, constant: -16),
            mediaPlaceholder.heightAnchor.constraint(equalToConstant: 200),
            mediaPlaceholder.bottomAnchor.constraint(equalTo: cardContainer.bottomAnchor, constant: -48)
        ])
        
        cardContainer.isSkeletonable = true
        avatarView.isSkeletonable = true
        line1.isSkeletonable = true
        line2.isSkeletonable = true
        mediaPlaceholder.isSkeletonable = true
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    func showSkeleton() {
        cardContainer.showAnimatedGradientSkeleton()
    }
}
