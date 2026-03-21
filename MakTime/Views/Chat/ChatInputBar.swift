import UIKit
import Combine
import SnapKit

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
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    private func setup() {
        backgroundColor = Theme.bgSecondary
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
            make.centerY.equalToSuperview()
            make.size.equalTo(38)
        }
        voiceButton.snp.makeConstraints { make in
            make.leading.equalTo(photoButton.snp.trailing).offset(8)
            make.centerY.equalToSuperview()
            make.size.equalTo(38)
        }
        textView.snp.makeConstraints { make in
            make.leading.equalTo(voiceButton.snp.trailing).offset(10)
            make.centerY.equalToSuperview()
            make.height.greaterThanOrEqualTo(38)
            make.height.lessThanOrEqualTo(100)
        }
        sendButton.snp.makeConstraints { make in
            make.leading.equalTo(textView.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
            make.size.equalTo(38)
        }
    }
    
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 56)
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
