import Foundation
import KeychainAccess
import Combine

@MainActor
class AuthService: ObservableObject {
    @Published var user: User?
    @Published var token: String?
    @Published var isLoading = false
    @Published var error: String?
    
    private let keychain = Keychain(service: "com.maktime.app")
    private let tokenKey = "auth_token"
    
    var isAuthenticated: Bool { token != nil && user != nil }
    
    func tryAutoLogin() {
        guard let savedToken = keychain[tokenKey] else { return }
        token = savedToken
        Task { await APIService.shared.setToken(savedToken) }
        isLoading = true
        Task {
            do {
                let me = try await APIService.shared.getMe()
                self.user = me
            } catch {
                self.token = nil
                keychain[tokenKey] = nil
                await APIService.shared.setToken(nil)
            }
            self.isLoading = false
        }
    }
    
    func login(username: String, password: String) async {
        error = nil
        isLoading = true
        do {
            let response = try await APIService.shared.login(username: username, password: password)
            self.token = response.token
            self.user = response.user
            keychain[tokenKey] = response.token
            await APIService.shared.setToken(response.token)
        } catch let err as APIError {
            self.error = err.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func register(username: String, displayName: String, password: String) async {
        error = nil
        isLoading = true
        do {
            let response = try await APIService.shared.register(
                username: username, displayName: displayName, password: password
            )
            self.token = response.token
            self.user = response.user
            keychain[tokenKey] = response.token
            await APIService.shared.setToken(response.token)
        } catch let err as APIError {
            self.error = err.localizedDescription
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
    
    func updateProfile(displayName: String, bio: String, avatarUrl: String? = nil) async {
        do {
            let updated = try await APIService.shared.updateProfile(displayName: displayName, bio: bio, avatarUrl: avatarUrl)
            self.user = updated
        } catch {}
    }
    
    func logout() {
        token = nil
        user = nil
        keychain[tokenKey] = nil
        Task { await APIService.shared.setToken(nil) }
    }
}
