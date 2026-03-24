import UIKit
import Combine
import PhotosUI

// MARK: - UI / layout — профиль / настройки
// UITableView с секциями; в файле же — `ProfileCell` (аватар, имя, кнопка смены фото).

private final class ProfileCell: UITableViewCell {
    private let avatar = AvatarView()
    private let nameLabel = UILabel()
    private let userLabel = UILabel()
    private let pickerBtn = UIButton(type: .system)
    var onAvatarTap: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = Theme.bgSecondary
        selectionStyle = .none
        contentView.addSubview(avatar)
        contentView.addSubview(nameLabel)
        contentView.addSubview(userLabel)
        contentView.addSubview(pickerBtn)
        nameLabel.font = Theme.fontHeadline
        nameLabel.textColor = Theme.textPrimary
        userLabel.font = Theme.fontSubhead
        userLabel.textColor = Theme.textSecondary
        pickerBtn.setTitle("Изменить аватар", for: .normal)
        pickerBtn.tintColor = Theme.accent
        pickerBtn.addTarget(self, action: #selector(tapped), for: .touchUpInside)
        avatar.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        userLabel.translatesAutoresizingMaskIntoConstraints = false
        pickerBtn.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatar.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatar.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            avatar.widthAnchor.constraint(equalToConstant: 56),
            avatar.heightAnchor.constraint(equalToConstant: 56),
            nameLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            userLabel.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            userLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 2),
            userLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            pickerBtn.leadingAnchor.constraint(equalTo: avatar.trailingAnchor, constant: 12),
            pickerBtn.topAnchor.constraint(equalTo: userLabel.bottomAnchor, constant: 8),
            pickerBtn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -12)
        ])
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(displayName: String, username: String, avatarColor: String, avatarUrl: String?) {
        avatar.configure(name: displayName, color: avatarColor, avatarUrl: avatarUrl, size: 56)
        nameLabel.text = displayName
        userLabel.text = "@\(username)"
    }
    @objc private func tapped() { onAvatarTap?() }
}

final class SettingsViewController: UIViewController {
    private let authService: AuthService
    private let vm = SettingsViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    
    init(authService: AuthService) {
        self.authService = authService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bgPrimary
        title = "Настройки"
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(ProfileCell.self, forCellReuseIdentifier: "profile")
        tableView.backgroundColor = .clear
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        vm.load(from: authService.user)
    }
}

extension SettingsViewController: UITableViewDelegate, UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int { 4 }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 1
        case 1: return 4
        case 2: return 1
        case 3: return 1
        default: return 0
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .value1, reuseIdentifier: nil)
        cell.backgroundColor = Theme.bgSecondary
        cell.textLabel?.textColor = Theme.textPrimary
        cell.detailTextLabel?.textColor = Theme.textSecondary
        
        switch indexPath.section {
        case 0:
            let profileCell = tableView.dequeueReusableCell(withIdentifier: "profile", for: indexPath) as! ProfileCell
            profileCell.configure(
                displayName: authService.user?.displayName ?? "",
                username: authService.user?.username ?? "",
                avatarColor: authService.user?.avatarColor ?? "#6C63FF",
                avatarUrl: vm.avatarUrl ?? authService.user?.avatarUrl
            )
            profileCell.onAvatarTap = { [weak self] in self?.changeAvatarTapped() }
            return profileCell
        case 1:
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Имя"
                cell.detailTextLabel?.text = vm.displayName
                cell.accessoryType = .disclosureIndicator
            case 1:
                cell.textLabel?.text = "О себе"
                cell.detailTextLabel?.text = vm.bio
                cell.accessoryType = .disclosureIndicator
            case 2:
                cell.textLabel?.text = "Сохранить"
                cell.textLabel?.textColor = .white
                cell.backgroundColor = Theme.accent
                cell.textLabel?.textAlignment = .center
            case 3:
                cell.textLabel?.text = ""
            default: break
            }
        case 2:
            cell.textLabel?.text = "Версия"
            cell.detailTextLabel?.text = "1.0.0"
            cell.selectionStyle = .none
        case 3:
            cell.textLabel?.text = "Выйти из аккаунта"
            cell.textLabel?.textColor = Theme.danger
        default: break
        }
        return cell
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        if indexPath.section == 1 && indexPath.row == 2 {
            Task { await vm.save(authService: authService) }
        } else if indexPath.section == 3 {
            let alert = UIAlertController(title: "Выйти из аккаунта?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Выйти", style: .destructive) { [weak self] _ in
                self?.authService.logout()
            })
            alert.addAction(UIAlertAction(title: "Отмена", style: .cancel))
            present(alert, animated: true)
        }
    }
    
    @objc private func changeAvatarTapped() {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = self
        present(picker, animated: true)
    }
}

extension SettingsViewController: PHPickerViewControllerDelegate {
    func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
        picker.dismiss(animated: true)
        guard let result = results.first else { return }
        result.itemProvider.loadDataRepresentation(forTypeIdentifier: "public.image") { [weak self] data, _ in
            guard let data = data else { return }
            Task {
                do {
                    let resp = try await APIService.shared.uploadFile(data: data, filename: "avatar_\(UUID().uuidString).jpg", mimeType: "image/jpeg")
                    await MainActor.run {
                        self?.vm.setAvatarUrl(resp.fileUrl)
                        Task {
                            await self?.authService.updateProfile(displayName: self?.vm.displayName ?? "", bio: self?.vm.bio ?? "", avatarUrl: resp.fileUrl)
                        }
                    }
                } catch {}
            }
        }
    }
}
