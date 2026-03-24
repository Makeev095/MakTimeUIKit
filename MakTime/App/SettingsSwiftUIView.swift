import SwiftUI
import PhotosUI
import Kingfisher

// MARK: - Вкладка «Профиль» / настройки (SwiftUI)
// SettingsViewModel + AuthService — сохранение профиля, выход; загрузка аватара через PhotosPicker + APIService.uploadFile.

struct SettingsSwiftUIView: View {
    @ObservedObject var authService: AuthService
    @StateObject private var vm = SettingsViewModel()
    @State private var showLogoutConfirm = false
    @State private var photoPickerItem: PhotosPickerItem?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    profileHeader
                        .listRowBackground(Color.clear)
                }

                Section(header: Text("Профиль")) {
                    TextField("Имя", text: $vm.displayName)
                        .foregroundStyle(MTColor.textPrimary)
                    TextField("О себе", text: $vm.bio, axis: .vertical)
                        .lineLimit(3...6)
                        .foregroundStyle(MTColor.textPrimary)
                    Button {
                        Task { await vm.save(authService: authService) }
                    } label: {
                        HStack {
                            Spacer()
                            if vm.isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text(vm.saved ? "Сохранено ✓" : "Сохранить")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .listRowBackground(MTColor.accent.opacity(vm.isSaving ? 0.7 : 1))
                    .foregroundStyle(.white)
                    .disabled(vm.isSaving)
                }

                Section {
                    HStack {
                        Text("Версия")
                        Spacer()
                        Text("1.0.0").foregroundStyle(MTColor.textSecondary)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        Text("Выйти из аккаунта")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(MTColor.bgPrimary)
            .navigationTitle("Настройки")
            .navigationBarTitleDisplayMode(.large)
        }
        .tint(MTColor.accent)
        .onAppear {
            vm.load(from: authService.user)
        }
        .onChange(of: authService.user?.id) { _ in
            vm.load(from: authService.user)
        }
        .confirmationDialog("Выйти из аккаунта?", isPresented: $showLogoutConfirm, titleVisibility: .visible) {
            Button("Выйти", role: .destructive) { authService.logout() }
            Button("Отмена", role: .cancel) {}
        }
        .onChange(of: photoPickerItem) { item in
            Task { await loadPhoto(item) }
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $photoPickerItem, matching: .images) {
                avatarView
            }
            .buttonStyle(.plain)

            Text(authService.user?.displayName ?? "")
                .font(MTFont.title)
                .foregroundStyle(MTColor.textPrimary)
            Text("@\(authService.user?.username ?? "")")
                .font(MTFont.caption)
                .foregroundStyle(MTColor.textSecondary)
            Text("Нажмите на аватар, чтобы изменить")
                .font(.caption2)
                .foregroundStyle(MTColor.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var avatarView: some View {
        let name = authService.user?.displayName ?? "?"
        let color = authService.user?.avatarColor ?? "#6C63FF"
        let path = vm.avatarUrl ?? authService.user?.avatarUrl
        if let path, !path.isEmpty,
           let url = URL(string: path.hasPrefix("http") ? path : "\(AppConfig.baseURL)\(path)") {
            KFImage(url)
                .placeholder { MTAvatarView(name: name, colorHex: color, size: 88) }
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 88)
                .clipShape(Circle())
                .overlay(Circle().stroke(MTColor.border, lineWidth: 1))
        } else {
            MTAvatarView(name: name, colorHex: color, size: 88)
                .overlay(Circle().stroke(MTColor.border, lineWidth: 1))
        }
    }

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else { return }
            let resp = try await APIService.shared.uploadFile(
                data: data,
                filename: "avatar_\(UUID().uuidString).jpg",
                mimeType: "image/jpeg"
            )
            await MainActor.run {
                vm.setAvatarUrl(resp.fileUrl)
            }
            await authService.updateProfile(displayName: vm.displayName, bio: vm.bio, avatarUrl: resp.fileUrl)
        } catch {}
    }
}
