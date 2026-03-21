import Foundation

@MainActor
class ContactsViewModel: ObservableObject {
    @Published var contacts: [User] = []
    @Published var isLoading = false
    
    func loadContacts() async {
        isLoading = true
        do {
            contacts = try await APIService.shared.getContacts()
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
