import Foundation

@MainActor
class SettingsViewModel: ObservableObject {
    @Published var displayName = ""
    @Published var bio = ""
    @Published var avatarUrl: String?
    @Published var isSaving = false
    @Published var saved = false
    
    func load(from user: User?) {
        displayName = user?.displayName ?? ""
        bio = user?.bio ?? ""
        avatarUrl = user?.avatarUrl
    }
    
    func save(authService: AuthService) async {
        isSaving = true
        await authService.updateProfile(displayName: displayName, bio: bio, avatarUrl: avatarUrl)
        isSaving = false
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.saved = false
        }
    }
    
    func setAvatarUrl(_ url: String?) {
        avatarUrl = url
    }
}
