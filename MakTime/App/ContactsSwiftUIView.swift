import SwiftUI
import Kingfisher

// MARK: - Вкладка «Контакты» (SwiftUI)
// ContactsViewModel + SocketService; по тапу — createConversation и переход в чат через router.appendChat.

struct ContactsSwiftUIView: View {
    @ObservedObject var authService: AuthService
    @ObservedObject var socketService: SocketService
    @ObservedObject var router: ChatDeepLinkRouter

    @StateObject private var vm = ContactsViewModel()
    @State private var searchQuery = ""
    @State private var searchResults: [User] = []
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Найти пользователя...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(MTColor.bgSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: CGFloat(Theme.radiusSm), style: .continuous))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .onChange(of: searchQuery) { q in
                            searchTask?.cancel()
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 350_000_000)
                                guard !Task.isCancelled else { return }
                                await performSearch(q)
                            }
                        }
                }

                if searchQuery.count >= 2, !searchResults.isEmpty {
                    Section(header: Text("Результаты поиска").font(MTFont.caption)) {
                        ForEach(searchResults) { user in
                            Button {
                                Task { await selectUser(user) }
                            } label: {
                                ContactRowView(user: user, showAdd: !vm.contacts.contains { $0.id == user.id }, isOnline: socketService.isUserOnline(user.id) || user.isOnline)
                            }
                        }
                    }
                } else {
                    Section {
                        ForEach(vm.contacts) { user in
                            Button {
                                Task { await selectUser(user) }
                            } label: {
                                ContactRowView(user: user, showAdd: false, isOnline: socketService.isUserOnline(user.id) || user.isOnline)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(MTColor.bgPrimary)
            .navigationTitle("Контакты")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await vm.loadContacts()
            }
        }
        .tint(MTColor.accent)
        .onAppear {
            vm.setup(socketService: socketService)
            Task { await vm.loadContacts() }
        }
    }

    private func performSearch(_ query: String) async {
        guard query.count >= 2 else {
            await MainActor.run { searchResults = [] }
            return
        }
        do {
            let results = try await APIService.shared.searchUsers(query: query)
            await MainActor.run { searchResults = results }
        } catch {
            await MainActor.run { searchResults = [] }
        }
    }

    private func selectUser(_ user: User) async {
        if searchQuery.count >= 2, !searchResults.isEmpty, searchResults.contains(where: { $0.id == user.id }) {
            if !vm.contacts.contains(where: { $0.id == user.id }) {
                await vm.addContact(userId: user.id)
            }
        }
        guard let conv = try? await APIService.shared.createConversation(participantId: user.id) else { return }
        await MainActor.run {
            router.selectedTab = 0
            router.appendChat(conv)
            searchQuery = ""
            searchResults = []
        }
    }
}

private struct ContactRowView: View {
    let user: User
    let showAdd: Bool
    let isOnline: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                avatar
                if isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(MTColor.bgPrimary, lineWidth: 2))
                        .offset(x: 2, y: 2)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(MTFont.headline)
                    .foregroundStyle(MTColor.textPrimary)
                Text("@\(user.username)")
                    .font(MTFont.caption)
                    .foregroundStyle(MTColor.textSecondary)
            }
            Spacer()
            if showAdd {
                Image(systemName: "person.badge.plus")
                    .foregroundStyle(MTColor.accent)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var avatar: some View {
        if let url = user.fullAvatarUrl.flatMap({ URL(string: $0) }) {
            KFImage(url)
                .placeholder { MTAvatarView(name: user.displayName, colorHex: user.avatarColor, size: 44) }
                .resizable()
                .scaledToFill()
                .frame(width: 44, height: 44)
                .clipShape(Circle())
        } else {
            MTAvatarView(name: user.displayName, colorHex: user.avatarColor, size: 44)
        }
    }
}
