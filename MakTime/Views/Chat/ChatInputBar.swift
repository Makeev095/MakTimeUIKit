import UIKit
import Combine
import SnapKit

// MARK: - UI / layout — нижняя панель ввода в чате
// Высота intrinsicContentSize, кнопки фото/микрофона/отправки, поле UITextView, верхняя линия-разделитель.

final class ChatInputBar: UIView {
    var onSend: ((String) -> Void)?
    var onPhoto: (() -> Void)?
    var onVoiceRecord: (() -> Void)?
    var onVoiceStop: (() -> Void)?
    
    private weak var vm: ChatViewModel?
    private var cancellables = Set<AnyCancellable>()
    
    private let textView = UITextView()
    private let photoButton = UIButton(type: .system)
    private let voiceButton = UIButton(type: .system)
    private let sendButton = UIButton(type: .system)

    private var photoBottomToSafeArea: NSLayoutConstraint!
    private var photoBottomToBarBottom: NSLayoutConstraint!
    private var keyboardOpen = false
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setup() {
        backgroundColor = Theme.bgSecondary
        clipsToBounds = true
        layer.cornerRadius = Theme.radiusLg
        layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        layer.cornerCurve = .continuous

        let topBorder = UIView()
        topBorder.backgroundColor = Theme.glassBorder
        addSubview(topBorder)
        
        photoButton.setImage(UIImage(systemName: "photo.on.rectangle"), for: .normal)
        photoButton.tintColor = Theme.accent
        photoButton.addTarget(self, action: #selector(photoTapped), for: .touchUpInside)
        addSubview(photoButton)
        
        voiceButton.setImage(UIImage(systemName: "mic.circle"), for: .normal)
        voiceButton.tintColor = Theme.accent
        voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)
        addSubview(voiceButton)
        
        textView.backgroundColor = Theme.bgTertiary
        textView.textColor = Theme.textPrimary
        textView.font = Theme.fontBody
        textView.layer.cornerRadius = Theme.radiusLg
        textView.layer.cornerCurve = .continuous
        textView.clipsToBounds = true
        textView.layer.borderWidth = 0
        textView.textContainerInset = UIEdgeInsets(top: 9, left: 14, bottom: 9, right: 14)
        textView.delegate = self
        addSubview(textView)
        
        sendButton.setImage(UIImage(systemName: "arrow.up.circle.fill"), for: .normal)
        sendButton.tintColor = Theme.accent
        sendButton.addTarget(self, action: #selector(sendTapped), for: .touchUpInside)
        addSubview(sendButton)
        
        topBorder.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.height.equalTo(1)
        }
        photoButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.top.greaterThanOrEqualTo(topBorder.snp.bottom).offset(8)
            make.size.equalTo(38)
        }
        photoBottomToSafeArea = photoButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -8)
        photoBottomToBarBottom = photoButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6)
        photoBottomToSafeArea.isActive = true
        photoBottomToBarBottom.isActive = false
        voiceButton.snp.makeConstraints { make in
            make.leading.equalTo(photoButton.snp.trailing).offset(8)
            make.centerY.equalTo(photoButton.snp.centerY)
            make.size.equalTo(38)
        }
        textView.snp.makeConstraints { make in
            make.leading.equalTo(voiceButton.snp.trailing).offset(10)
            make.centerY.equalTo(photoButton.snp.centerY)
            make.height.greaterThanOrEqualTo(38)
            make.height.lessThanOrEqualTo(100)
        }
        sendButton.snp.makeConstraints { make in
            make.leading.equalTo(textView.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalTo(textView.snp.centerY)
            make.size.equalTo(38)
        }
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        invalidateIntrinsicContentSize()
    }

    override var intrinsicContentSize: CGSize {
        let bottomInset: CGFloat = keyboardOpen ? 0 : safeAreaInsets.bottom
        return CGSize(width: UIView.noIntrinsicMetric, height: 56 + bottomInset)
    }

    /// Клавиатура открыта: панель — только верхние углы; поле ввода — все четыре угла с `Theme.radiusLg`. Закрыта: панель снизу, поле — со всех сторон.
    func setKeyboardOpen(_ isOpen: Bool) {
        guard isOpen != keyboardOpen else { return }
        keyboardOpen = isOpen
        photoBottomToSafeArea.isActive = !isOpen
        photoBottomToBarBottom.isActive = isOpen
        if isOpen {
            layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
            textView.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
        } else {
            layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
            textView.layer.maskedCorners = [
                .layerMinXMinYCorner, .layerMaxXMinYCorner,
                .layerMinXMaxYCorner, .layerMaxXMaxYCorner
            ]
        }
        invalidateIntrinsicContentSize()
    }
    
    func configure(vm: ChatViewModel) {
        self.vm = vm
        vm.$isRecording.receive(on: DispatchQueue.main).sink { [weak self] recording in
            self?.voiceButton.setImage(UIImage(systemName: recording ? "mic.circle.fill" : "mic.circle"), for: .normal)
            self?.voiceButton.tintColor = recording ? Theme.danger : Theme.accent
        }.store(in: &cancellables)
    }
    
    @objc private func photoTapped() {
        AnimationHelper.hapticLight()
        onPhoto?()
    }
    
    @objc private func voiceTapped() {
        AnimationHelper.hapticLight()
        if vm?.isRecording == true {
            onVoiceStop?()
        } else {
            onVoiceRecord?()
        }
    }
    
    @objc private func sendTapped() {
        let text = (vm?.messageText ?? textView.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        AnimationHelper.hapticLight()
        AnimationHelper.quickScale(view: sendButton)
        onSend?(text)
        textView.text = ""
    }
}

extension ChatInputBar: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        vm?.messageText = textView.text
        vm?.handleTyping()
    }
}
