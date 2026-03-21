import UIKit
import Combine

final class AuthViewController: UIViewController {
    private let authService: AuthService
    private let vm = AuthViewModel()
    private var cancellables = Set<AnyCancellable>()
    
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    
    private let logoLabel: UILabel = {
        let l = UILabel()
        l.text = "Makke"
        l.font = Theme.fontLargeTitle
        l.textAlignment = .center
        l.textColor = Theme.accent
        return l
    }()
    
    private let subtitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Мессенджер нового поколения"
        l.font = Theme.fontSubhead
        l.textColor = Theme.textSecondary
        l.textAlignment = .center
        return l
    }()
    
    private let tabContainer = UIView()
    private let loginTabButton = UIButton(type: .system)
    private let registerTabButton = UIButton(type: .system)
    
    private let formStack = UIStackView()
    private let usernameField = UITextField()
    private let displayNameField = UITextField()
    private let passwordField = UITextField()
    private let confirmPasswordField = UITextField()
    
    private let errorLabel: UILabel = {
        let l = UILabel()
        l.font = Theme.fontCaption
        l.textColor = Theme.danger
        l.numberOfLines = 0
        l.textAlignment = .center
        return l
    }()
    
    private let submitButton = UIButton(type: .system)
    
    init(authService: AuthService) {
        self.authService = authService
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.bgPrimary
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.keyboardDismissMode = .onDrag
        view.addSubview(scrollView)
        
        stackView.axis = .vertical
        stackView.spacing = 24
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        setupTabSelector()
        setupForm()
        setupSubmitButton()
        
        stackView.addArrangedSubview(logoLabel)
        stackView.setCustomSpacing(8, after: logoLabel)
        stackView.addArrangedSubview(subtitleLabel)
        stackView.setCustomSpacing(20, after: subtitleLabel)
        stackView.addArrangedSubview(tabContainer)
        stackView.setCustomSpacing(14, after: tabContainer)
        stackView.addArrangedSubview(formStack)
        stackView.addArrangedSubview(errorLabel)
        stackView.addArrangedSubview(submitButton)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 60),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -24),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -40),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -48)
        ])
        
        bind()
        updateTabUI()
        updateFormVisibility()
    }
    
    private func setupTabSelector() {
        tabContainer.backgroundColor = UIColor.white.withAlphaComponent(0.03)
        tabContainer.layer.cornerRadius = Theme.radiusSm
        tabContainer.layer.borderWidth = 1
        tabContainer.layer.borderColor = Theme.glassBorder.cgColor
        
        loginTabButton.setTitle("Вход", for: .normal)
        loginTabButton.titleLabel?.font = Theme.fontSubhead
        loginTabButton.addTarget(self, action: #selector(loginTabTapped), for: .touchUpInside)
        
        registerTabButton.setTitle("Регистрация", for: .normal)
        registerTabButton.titleLabel?.font = Theme.fontSubhead
        registerTabButton.addTarget(self, action: #selector(registerTabTapped), for: .touchUpInside)
        
        let h = UIStackView(arrangedSubviews: [loginTabButton, registerTabButton])
        h.axis = .horizontal
        h.distribution = .fillEqually
        h.translatesAutoresizingMaskIntoConstraints = false
        tabContainer.addSubview(h)
        NSLayoutConstraint.activate([
            h.topAnchor.constraint(equalTo: tabContainer.topAnchor),
            h.leadingAnchor.constraint(equalTo: tabContainer.leadingAnchor),
            h.trailingAnchor.constraint(equalTo: tabContainer.trailingAnchor),
            h.bottomAnchor.constraint(equalTo: tabContainer.bottomAnchor),
            tabContainer.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    private var displayNameRow: UIView!
    private var confirmPasswordRow: UIView!
    
    private func setupForm() {
        formStack.axis = .vertical
        formStack.spacing = 14
        formStack.layoutMargins = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        formStack.isLayoutMarginsRelativeArrangement = true
        formStack.backgroundColor = UIColor.white.withAlphaComponent(0.03)
        formStack.layer.cornerRadius = Theme.radius
        formStack.layer.borderWidth = 1
        formStack.layer.borderColor = Theme.glassBorder.cgColor
        
        usernameField.placeholder = "Имя пользователя"
        usernameField.autocapitalizationType = .none
        usernameField.autocorrectionType = .no
        
        displayNameField.placeholder = "Отображаемое имя"
        
        passwordField.placeholder = "Пароль"
        passwordField.isSecureTextEntry = true
        
        confirmPasswordField.placeholder = "Повторите пароль"
        confirmPasswordField.isSecureTextEntry = true
        
        formStack.addArrangedSubview(inputRow(icon: "person", field: usernameField))
        displayNameRow = inputRow(icon: "person.text.rectangle", field: displayNameField)
        formStack.addArrangedSubview(displayNameRow)
        formStack.addArrangedSubview(inputRow(icon: "lock", field: passwordField))
        confirmPasswordRow = inputRow(icon: "lock.rotation", field: confirmPasswordField)
        formStack.addArrangedSubview(confirmPasswordRow)
    }
    
    private func styleField(_ field: UITextField, icon: String) {
        field.textColor = Theme.textPrimary
        field.backgroundColor = .clear
    }
    
    private func inputRow(icon: String, field: UITextField) -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 12
        row.alignment = .center
        
        let iconView = UIImageView(image: UIImage(systemName: icon))
        iconView.tintColor = Theme.accent
        iconView.contentMode = .scaleAspectFit
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.widthAnchor.constraint(equalToConstant: 20).isActive = true
        
        field.translatesAutoresizingMaskIntoConstraints = false
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        let container = UIView()
        container.backgroundColor = UIColor.white.withAlphaComponent(0.04)
        container.layer.cornerRadius = Theme.radiusSm
        container.layer.borderWidth = 1
        container.layer.borderColor = Theme.border.cgColor
        
        row.addArrangedSubview(iconView)
        row.addArrangedSubview(field)
        row.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        row.isLayoutMarginsRelativeArrangement = true
        container.addSubview(row)
        row.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: container.topAnchor),
            row.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            row.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            row.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        return container
    }
    
    private func setupSubmitButton() {
        submitButton.setTitle("Войти", for: .normal)
        submitButton.titleLabel?.font = Theme.fontHeadline
        submitButton.setTitleColor(.white, for: .normal)
        submitButton.backgroundColor = Theme.accent
        submitButton.layer.cornerRadius = Theme.radius
        submitButton.translatesAutoresizingMaskIntoConstraints = false
        submitButton.heightAnchor.constraint(equalToConstant: 52).isActive = true
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
    }
    
    private func bind() {
        usernameField.addTarget(self, action: #selector(usernameChanged), for: .editingChanged)
        displayNameField.addTarget(self, action: #selector(displayNameChanged), for: .editingChanged)
        passwordField.addTarget(self, action: #selector(passwordChanged), for: .editingChanged)
        confirmPasswordField.addTarget(self, action: #selector(confirmPasswordChanged), for: .editingChanged)
        
        vm.$username
            .combineLatest(vm.$password)
            .combineLatest(vm.$displayName)
            .combineLatest(vm.$confirmPassword)
            .combineLatest(authService.$error)
            .sink { [weak self] _ in
                self?.errorLabel.text = self?.vm.validationError ?? self?.authService.error ?? ""
            }
            .store(in: &cancellables)
        
        vm.$username
            .combineLatest(vm.$password)
            .combineLatest(vm.$displayName)
            .combineLatest(vm.$confirmPassword)
            .combineLatest(authService.$isLoading)
            .sink { [weak self] _ in
                let canSubmit = self?.vm.canSubmit ?? false
                let loading = self?.authService.isLoading ?? false
                self?.submitButton.isEnabled = canSubmit && !loading
                self?.submitButton.alpha = canSubmit ? 1 : 0.6
            }
            .store(in: &cancellables)
        
        authService.$isLoading.sink { [weak self] loading in
            if loading {
                self?.submitButton.setTitle("", for: .normal)
                let ai = UIActivityIndicatorView(style: .medium)
                ai.color = .white
                ai.startAnimating()
                self?.submitButton.addSubview(ai)
                ai.centerInSuperview()
            } else {
                self?.submitButton.subviews.compactMap { $0 as? UIActivityIndicatorView }.forEach { $0.removeFromSuperview() }
                self?.submitButton.setTitle(self?.vm.isLogin == true ? "Войти" : "Зарегистрироваться", for: .normal)
            }
        }
        .store(in: &cancellables)
    }
    
    @objc private func usernameChanged() { vm.username = usernameField.text ?? "" }
    @objc private func displayNameChanged() { vm.displayName = displayNameField.text ?? "" }
    @objc private func passwordChanged() { vm.password = passwordField.text ?? "" }
    @objc private func confirmPasswordChanged() { vm.confirmPassword = confirmPasswordField.text ?? "" }
    
    @objc private func loginTabTapped() {
        vm.isLogin = true
        vm.clear()
        clearFields()
        updateTabUI()
        updateFormVisibility()
    }
    
    @objc private func registerTabTapped() {
        vm.isLogin = false
        vm.clear()
        clearFields()
        updateTabUI()
        updateFormVisibility()
    }
    
    private func clearFields() {
        usernameField.text = ""
        displayNameField.text = ""
        passwordField.text = ""
        confirmPasswordField.text = ""
    }
    
    private func updateTabUI() {
        UIView.animate(withDuration: Theme.animationFast, delay: 0, options: .curveEaseInOut) {
            let isLogin = self.vm.isLogin
            self.loginTabButton.setTitleColor(isLogin ? .white : Theme.textSecondary, for: .normal)
            self.loginTabButton.backgroundColor = isLogin ? Theme.accent : .clear
            self.registerTabButton.setTitleColor(!isLogin ? .white : Theme.textSecondary, for: .normal)
            self.registerTabButton.backgroundColor = !isLogin ? Theme.accent : .clear
        }
    }
    
    private func updateFormVisibility() {
        UIView.animate(withDuration: Theme.animationFast) {
            self.displayNameRow.isHidden = self.vm.isLogin
            self.confirmPasswordRow.isHidden = self.vm.isLogin
        }
    }
    
    @objc private func submitTapped() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        view.endEditing(true)
        Task {
            if vm.isLogin {
                await authService.login(username: vm.username, password: vm.password)
            } else {
                await authService.register(username: vm.username, displayName: vm.displayName, password: vm.password)
            }
        }
    }
}

private extension UIView {
    func centerInSuperview() {
        guard let sv = superview else { return }
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: sv.centerXAnchor),
            centerYAnchor.constraint(equalTo: sv.centerYAnchor)
        ])
    }
}
