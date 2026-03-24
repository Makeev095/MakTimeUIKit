import UIKit
import PhotosUI

// MARK: - UI / layout — создание поста (фото + подпись)
// Превью изображения, UITextView для текста, кнопки публикации/закрытия.

final class CreatePostViewController: UIViewController {
    private let vm: FeedViewModel
    private let onClose: () -> Void
    
    private var selectedImageData: Data?
    private let imageView = UIImageView()
    private let captionField = UITextView()
    private let publishButton = UIButton(type: .system)
    
    init(vm: FeedViewModel, onClose: @escaping () -> Void) {
        self.vm = vm
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bgPrimary
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(closeTapped))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Опубликовать", style: .done, target: self, action: #selector(publishTapped))
        navigationItem.rightBarButtonItem?.tintColor = Theme.accent
        
        let pickerBtn = UIButton(type: .system)
        pickerBtn.setTitle("Выберите фото или видео", for: .normal)
        pickerBtn.setImage(UIImage(systemName: "photo.on.rectangle.angled"), for: .normal)
        pickerBtn.tintColor = Theme.accent
        pickerBtn.addTarget(self, action: #selector(showPicker), for: .touchUpInside)
        pickerBtn.frame = CGRect(x: 0, y: 100, width: view.bounds.width, height: 80)
        view.addSubview(pickerBtn)
        
        imageView.contentMode = .scaleAspectFit
        imageView.isHidden = true
        imageView.frame = CGRect(x: 16, y: 80, width: view.bounds.width - 32, height: 200)
        view.addSubview(imageView)
        
        captionField.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        captionField.textColor = Theme.textPrimary
        captionField.font = Theme.fontBody
        captionField.layer.cornerRadius = Theme.radiusSm
        captionField.frame = CGRect(x: 16, y: 300, width: view.bounds.width - 32, height: 100)
        captionField.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view.addSubview(captionField)
    }
    
    @objc private func closeTapped() { onClose() }
    
    @objc private func showPicker() {
        var config = PHPickerConfiguration()
        config.filter = .any(of: [.images, .videos])
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
    
    @objc private func publishTapped() {
        guard let data = selectedImageData else { return }
        navigationItem.rightBarButtonItem?.isEnabled = false
        Task {
            do {
                let fileUrl = try await MediaService.uploadData(data, filename: "post_\(UUID().uuidString).jpg", mimeType: "image/jpeg")
                _ = try await APIService.shared.createPost(type: "image", fileUrl: fileUrl, caption: captionField.text ?? "")
                await vm.refreshPosts()
                await MainActor.run { onClose() }
            } catch {
                await MainActor.run { navigationItem.rightBarButtonItem?.isEnabled = true }
            }
        }
    }
}

extension CreatePostViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        result.itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { [weak self] data, _ in
            guard let data = data, let img = UIImage(data: data), let self = self else { return }
            let jpegData = img.jpegData(compressionQuality: 0.8) ?? data
            DispatchQueue.main.async {
                self.selectedImageData = jpegData
                self.imageView.image = img
                self.imageView.isHidden = false
            }
        }
    }
}
