import SwiftUI
import UIKit

// MARK: - Экран входа / регистрации (SwiftUI)
// Логика: AuthViewModel + AuthService.login / .register — как в AuthViewController.

struct AuthSwiftUIView: View {
    @ObservedObject var authService: AuthService
    @StateObject private var vm = AuthViewModel()
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case username, displayName, password, confirm
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                tabPicker
                formBlock
                errorText
                submitButton
            }
            .padding(.horizontal, 24)
            .padding(.top, 48)
            .padding(.bottom, 40)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(
            LinearGradient(
                colors: [MTColor.bgPrimary, Color(uiColor: Theme.bgSecondary).opacity(0.85)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Makke")
                .font(MTFont.largeTitle)
                .foregroundStyle(MTColor.accent)
            Text("Мессенджер нового поколения")
                .font(MTFont.caption)
                .foregroundStyle(MTColor.textSecondary)
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 0) {
            tabButton(title: "Вход", isSelected: vm.isLogin) {
                guard !vm.isLogin else { return }
                vm.isLogin = true
                vm.clear()
            }
            tabButton(title: "Регистрация", isSelected: !vm.isLogin) {
                guard vm.isLogin else { return }
                vm.isLogin = false
                vm.clear()
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(Theme.radiusSm), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(Theme.radiusSm), style: .continuous)
                .stroke(MTColor.border.opacity(0.4), lineWidth: 1)
        )
    }

    private func tabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(MTFont.headline)
                .foregroundStyle(isSelected ? Color.white : MTColor.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(isSelected ? MTColor.accent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: CGFloat(Theme.radiusSm - 2), style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var formBlock: some View {
        VStack(spacing: 14) {
            mtField(icon: "person", placeholder: "Имя пользователя", text: $vm.username, field: .username)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !vm.isLogin {
                mtField(icon: "person.text.rectangle", placeholder: "Отображаемое имя", text: $vm.displayName, field: .displayName)
            }
            mtField(icon: "lock", placeholder: "Пароль", text: $vm.password, secure: true, field: .password)
            if !vm.isLogin {
                mtField(icon: "lock.rotation", placeholder: "Повторите пароль", text: $vm.confirmPassword, secure: true, field: .confirm)
            }
        }
        .mtGlassCard()
    }

    private func mtField(
        icon: String,
        placeholder: String,
        text: Binding<String>,
        secure: Bool = false,
        field: Field
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(MTColor.accent)
                .frame(width: 20)
            if secure {
                SecureField(placeholder, text: text)
                    .focused($focusedField, equals: field)
            } else {
                TextField(placeholder, text: text)
                    .focused($focusedField, equals: field)
            }
        }
        .font(MTFont.body)
        .foregroundStyle(MTColor.textPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: CGFloat(Theme.radiusSm), style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: CGFloat(Theme.radiusSm), style: .continuous)
                .stroke(MTColor.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var errorText: some View {
        let msg = vm.validationError ?? authService.error ?? ""
        if !msg.isEmpty {
            Text(msg)
                .font(MTFont.caption)
                .foregroundStyle(MTColor.danger)
                .multilineTextAlignment(.center)
        }
    }

    private var submitButton: some View {
        let canSubmit = vm.canSubmit && !authService.isLoading
        return Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            focusedField = nil
            Task {
                if vm.isLogin {
                    await authService.login(username: vm.username, password: vm.password)
                } else {
                    await authService.register(username: vm.username, displayName: vm.displayName, password: vm.password)
                }
            }
        } label: {
            ZStack {
                if authService.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(vm.isLogin ? "Войти" : "Зарегистрироваться")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .buttonStyle(MTPrimaryButtonStyle())
        .opacity(canSubmit ? 1 : 0.55)
        .disabled(!canSubmit)
    }
}
