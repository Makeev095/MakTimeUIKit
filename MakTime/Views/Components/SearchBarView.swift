import UIKit
import Combine

// MARK: - UI / layout — строка поиска (переиспользуемая)
// Поле, кнопка очистки, фон и скругление — для списков (чаты, контакты).

final class SearchBarView: UIView {
    var text: String {
        get { textField.text ?? "" }
        set {
            textField.text = newValue
            clearButton.isHidden = newValue.isEmpty
        }
    }
    
    var placeholder: String = "Поиск..." {
        didSet { textField.placeholder = placeholder }
    }
    
    var onTextChanged: ((String) -> Void)?
    
    private let textField = UITextField()
    private let iconView = UIImageView(image: UIImage(systemName: "magnifyingglass"))
    private let clearButton = UIButton(type: .system)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setup() {
        backgroundColor = UIColor.white.withAlphaComponent(0.03)
        layer.cornerRadius = Theme.radiusSm
        layer.borderWidth = 1
        layer.borderColor = Theme.glassBorder.cgColor
        
        iconView.tintColor = Theme.textMuted
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)
        
        textField.placeholder = placeholder
        textField.textColor = Theme.textPrimary
        textField.autocorrectionType = .no
        textField.autocapitalizationType = .none
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        addSubview(textField)
        
        clearButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        clearButton.tintColor = Theme.textMuted
        clearButton.addTarget(self, action: #selector(clearTapped), for: .touchUpInside)
        clearButton.isHidden = true
        addSubview(clearButton)
        
        iconView.translatesAutoresizingMaskIntoConstraints = false
        textField.translatesAutoresizingMaskIntoConstraints = false
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 18),
            iconView.heightAnchor.constraint(equalToConstant: 18),
            textField.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            textField.centerYAnchor.constraint(equalTo: centerYAnchor),
            textField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -8),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 40),
            clearButton.heightAnchor.constraint(equalToConstant: 42)
        ])
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 42)
    }
    
    @objc private func textChanged() {
        clearButton.isHidden = (textField.text ?? "").isEmpty
        onTextChanged?(textField.text ?? "")
    }
    
    @objc private func clearTapped() {
        textField.text = ""
        clearButton.isHidden = true
        onTextChanged?("")
    }
}
