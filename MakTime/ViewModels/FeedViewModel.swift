import Foundation
import Kingfisher

@MainActor
class FeedViewModel: ObservableObject {
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isRefreshing = false
    @Published var isLoadingMore = false
    @Published var hasMore = true
    @Published var loadError: String?
    @Published var publishError: String?
    @Published var deleteError: String?

    private let pageSize = 20
    private var currentOffset = 0

    func loadPosts() async {
        isLoading = true
        loadError = nil
        currentOffset = 0
        hasMore = true
        do {
            let batch = try await APIService.shared.getPosts(limit: pageSize, offset: 0)
            posts = batch
            currentOffset = batch.count
            hasMore = batch.count >= pageSize
            prefetchImages(for: Array(batch.prefix(8)))
        } catch {
            loadError = "Не удалось загрузить ленту"
        }
        isLoading = false
    }

    func refreshPosts() async {
        isRefreshing = true
        currentOffset = 0
        hasMore = true
        do {
            let batch = try await APIService.shared.getPosts(limit: pageSize, offset: 0)
            posts = batch
            currentOffset = batch.count
            hasMore = batch.count >= pageSize
            loadError = nil
            prefetchImages(for: Array(batch.prefix(8)))
        } catch {}
        isRefreshing = false
    }

    /// Подгрузка при скролле (вызывать с последних ячеек).
    func loadMoreIfNeeded() async {
        guard hasMore, !isLoadingMore, !isLoading, !isRefreshing else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let batch = try await APIService.shared.getPosts(limit: pageSize, offset: currentOffset)
            if batch.count < pageSize { hasMore = false }
            posts.append(contentsOf: batch)
            currentOffset += batch.count
            prefetchImages(for: batch)
        } catch {}
    }

    private func prefetchImages(for batch: [Post]) {
        let urls = batch.compactMap { p -> URL? in
            guard p.type == .image else { return nil }
            return URL(string: p.fullFileUrl)
        }
        guard !urls.isEmpty else { return }
        ImagePrefetcher(urls: urls).start()
    }

    func toggleLike(post: Post) {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        let wasLiked = posts[idx].isLiked
        posts[idx].isLiked.toggle()
        posts[idx].likesCount += wasLiked ? -1 : 1
        Task {
            do {
                if wasLiked {
                    try await APIService.shared.unlikePost(postId: post.id)
                } else {
                    try await APIService.shared.likePost(postId: post.id)
                }
            } catch {
                if let idx = posts.firstIndex(where: { $0.id == post.id }) {
                    posts[idx].isLiked = wasLiked
                    posts[idx].likesCount += wasLiked ? 1 : -1
                }
            }
        }
    }

    func repost(post: Post) {
        guard let idx = posts.firstIndex(where: { $0.id == post.id }) else { return }
        posts[idx].repostsCount += 1
        Task {
            try? await APIService.shared.repostPost(postId: post.id)
        }
    }

    func deletePost(_ post: Post) {
        deleteError = nil
        Task {
            do {
                try await APIService.shared.deletePost(postId: post.id)
                posts.removeAll { $0.id == post.id }
            } catch let err as APIError {
                switch err {
                case .httpError(404, _):
                    deleteError = "Пост не найден или уже удалён"
                case .httpError(403, _):
                    deleteError = "Нет прав на удаление"
                default:
                    deleteError = err.localizedDescription
                }
                print("Delete post error: \(err)")
            } catch {
                deleteError = "Не удалось удалить пост"
                print("Delete post error: \(error)")
            }
        }
    }

    func publishPost(photoData: Data, caption: String) async -> String? {
        publishError = nil
        do {
            let fileUrl = try await MediaService.uploadData(
                photoData,
                filename: "post_\(UUID().uuidString).jpg",
                mimeType: "image/jpeg"
            )
            let newPost = try await APIService.shared.createPost(
                type: "image",
                fileUrl: fileUrl,
                caption: caption
            )
            posts.insert(newPost, at: 0)
            currentOffset += 1
            return nil
        } catch {
            let msg = "Не удалось опубликовать: \(error.localizedDescription)"
            publishError = msg
            return msg
        }
    }

    func publishVideoPost(videoData: Data, caption: String) async -> String? {
        publishError = nil
        do {
            let fileUrl = try await MediaService.uploadData(
                videoData,
                filename: "post_\(UUID().uuidString).mp4",
                mimeType: "video/mp4"
            )
            let newPost = try await APIService.shared.createPost(
                type: "video",
                fileUrl: fileUrl,
                caption: caption
            )
            posts.insert(newPost, at: 0)
            currentOffset += 1
            return nil
        } catch let err as APIError {
            let msg = friendlyVideoError(err)
            publishError = msg
            return msg
        } catch {
            let msg = "Не удалось опубликовать: \(error.localizedDescription)"
            publishError = msg
            return msg
        }
    }

    private func friendlyVideoError(_ err: APIError) -> String {
        if case .httpError(_, let body) = err {
            if body.contains("413") || body.contains("Request Entity Too Large") || body.contains("Too Large") || body.contains("<") {
                return "Видео слишком большое. Максимум: 1 минута, 500 МБ."
            }
        }
        return "Не удалось опубликовать: \(err.localizedDescription)"
    }
}
