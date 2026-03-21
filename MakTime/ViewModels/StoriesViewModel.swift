import Foundation
import Combine

@MainActor
class StoriesViewModel: ObservableObject {
    @Published var storyUsers: [StoryUser] = []
    @Published var isLoading = false
    
    private var cancellables = Set<AnyCancellable>()
    
    func setup(socketService: SocketService) {
        socketService.storyAdded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in Task { await self?.loadStories() } }
            .store(in: &cancellables)
    }
    
    func loadStories() async {
        do {
            storyUsers = try await APIService.shared.getStories()
        } catch {}
    }
    
    func viewStory(storyId: String) async {
        do { try await APIService.shared.viewStory(storyId: storyId) } catch {}
    }
    
    func deleteStory(storyId: String) async {
        do {
            try await APIService.shared.deleteStory(storyId: storyId)
            await loadStories()
        } catch {}
    }
    
    func reactToStory(storyId: String, emoji: String) async {
        do { try await APIService.shared.reactToStory(storyId: storyId, emoji: emoji) } catch {}
    }
    
    func getViewers(storyId: String) async -> [StoryViewer] {
        (try? await APIService.shared.getStoryViewers(storyId: storyId)) ?? []
    }
}
