import Foundation

@MainActor
class ContactsViewModel: ObservableObject {
    @Published var contacts: [User] = []
    @Published var isLoading = false

    private var socketService: SocketService?

    func setup(socketService: SocketService) {
        self.socketService = socketService
    }

    func loadContacts() async {
        isLoading = true
        do {
            contacts = try await APIService.shared.getContacts()
            socketService?.seedOnlineFromUsers(contacts)
        } catch {}
        isLoading = false
    }

    func addContact(userId: String) async {
        do {
            try await APIService.shared.addContact(contactId: userId)
            await loadContacts()
        } catch {}
    }
}
