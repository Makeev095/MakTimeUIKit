import Foundation

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isLogin = true
    @Published var username = ""
    @Published var displayName = ""
    @Published var password = ""
    @Published var confirmPassword = ""
    
    var canSubmit: Bool {
        if isLogin {
            return !username.isEmpty && !password.isEmpty
        }
        return !username.isEmpty && !displayName.isEmpty && !password.isEmpty && password == confirmPassword
    }
    
    var validationError: String? {
        if !isLogin && !password.isEmpty && !confirmPassword.isEmpty && password != confirmPassword {
            return "Пароли не совпадают"
        }
        let usernameRegex = try! NSRegularExpression(pattern: "^[a-zA-Z0-9_]+$")
        if !username.isEmpty && usernameRegex.firstMatch(in: username, range: NSRange(username.startIndex..., in: username)) == nil {
            return "Только латиница, цифры и _"
        }
        return nil
    }
    
    func clear() {
        username = ""
        displayName = ""
        password = ""
        confirmPassword = ""
    }
}
