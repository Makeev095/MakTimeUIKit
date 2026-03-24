import UIKit
import PhotosUI

// MARK: - UI / layout — публикация сторис (фото + текст)
// Превью, поле текста, состояния загрузки/ошибки.

final class StoryUploadViewController: UIViewController {
    private let onClose: () -> Void
    private let onPublished: () -> Void
    
    private var imageData: Data?
    private var textOverlay = ""
    private var isUploading = false
    private var errorMessage: String?
    private let textField = UITextField()
    private let imageView = UIImageView()
    private let publishButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    private let pickerButton = UIButton(type: .system)
    
    init(onClose: @escaping () -> Void, onPublished: @escaping () -> Void) {
        self.onClose = onClose
        self.onPublished = onPublished
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bgPrimary
        
        closeButton.setImage(UIImage(systemName: "xmark"), for: .normal)
        closeButton.tintColor = Theme.textPrimary
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        closeButton.frame = CGRect(x: 16, y: 12, width: 44, height: 44)
        view.addSubview(closeButton)
        
        let titleLabel = UILabel()
        titleLabel.text = "Новая история"
        titleLabel.font = Theme.fontHeadline
        titleLabel.textColor = Theme.textPrimary
        titleLabel.frame = CGRect(x: 72, y: 12, width: 200, height: 44)
        view.addSubview(titleLabel)
        
        publishButton.setTitle("Опубликовать", for: .normal)
        publishButton.tintColor = Theme.accent
        publishButton.addTarget(self, action: #selector(publishTapped), for: .touchUpInside)
        publishButton.frame = CGRect(x: view.bounds.width - 120, y: 12, width: 100, height: 44)
        publishButton.isHidden = true
        view.addSubview(publishButton)
        
        pickerButton.setTitle("Выберите фото или видео", for: .normal)
        pickerButton.setImage(UIImage(systemName: "photo.on.rectangle.angled"), for: .normal)
        pickerButton.tintColor = Theme.accent
        pickerButton.addTarget(self, action: #selector(showPicker), for: .touchUpInside)
        pickerButton.frame = CGRect(x: 0, y: 120, width: view.bounds.width, height: 120)
        view.addSubview(pickerButton)
        
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        imageView.frame = CGRect(x: 16, y: 80, width: view.bounds.width - 32, height: 300)
        view.addSubview(imageView)
        
        textField.placeholder = "Добавить текст..."
        textField.textColor = Theme.textPrimary
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        textField.layer.cornerRadius = Theme.radiusSm
        textField.layer.borderWidth = 1
        textField.layer.borderColor = Theme.border.cgColor
        textField.isHidden = true
        textField.frame = CGRect(x: 16, y: 400, width: view.bounds.width - 32, height: 44)
        textField.addTarget(self, action: #selector(textChanged), for: .editingChanged)
        view.addSubview(textField)
    }
    
    @objc private func closeTapped() { onClose() }
    
    @objc private func textChanged() { textOverlay = textField.text ?? "" }
    
    @objc private func showPicker() {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func publishTapped() {
        guard let data = imageData else { return }
        isUploading = true
        errorMessage = nil
        publishButton.isEnabled = false
        
        Task {
            do {
                let fileUrl = try await MediaService.uploadData(data, filename: "story_\(UUID().uuidString).jpg", mimeType: "image/jpeg")
                _ = try await APIService.shared.createStory(type: "image", fileUrl: fileUrl, textOverlay: textOverlay, bgColor: "")
                await MainActor.run {
                    onPublished()
                    onClose()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Не удалось загрузить историю"
                    publishButton.isEnabled = true
                }
            }
            await MainActor.run { isUploading = false }
        }
    }
}

extension StoryUploadViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        result.itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { [weak self] data, _ in
            guard let data = data, let img = UIImage(data: data), let self = self else { return }
            let jpegData = img.jpegData(compressionQuality: 0.8) ?? data
            DispatchQueue.main.async {
                self.imageData = jpegData
                self.imageView.image = img
                self.imageView.isHidden = false
                self.pickerButton.isHidden = true
                self.textField.isHidden = false
                self.publishButton.isHidden = false
            }
        }
    }
}
