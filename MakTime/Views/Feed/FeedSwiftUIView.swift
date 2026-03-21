import SwiftUI
import AVKit
import Kingfisher

/// Лента на SwiftUI: ленивая подгрузка, один активный видеоплеер, кэш картинок через Kingfisher.
struct FeedSwiftUIView: View {
    @ObservedObject var authService: AuthService
    @StateObject private var vm = FeedViewModel()
    @StateObject private var feedSound = FeedVideoSoundState()
    @State private var activeVideoPostId: String?
    @State private var showCreate = false
    @State private var commentPost: Post?

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: MTSpacing.md) {
                    if vm.isLoading && vm.posts.isEmpty {
                        ForEach(0..<5, id: \.self) { _ in
                            postSkeleton
                        }
                    } else {
                        ForEach(vm.posts) { post in
                            postCard(post: post)
                                .onAppear {
                                    if post.type == .video {
                                        activeVideoPostId = post.id
                                    }
                                    if post.id == vm.posts.last?.id {
                                        Task { await vm.loadMoreIfNeeded() }
                                    }
                                }
                                .onDisappear {
                                    if activeVideoPostId == post.id {
                                        activeVideoPostId = nil
                                    }
                                }
                        }
                        if vm.isLoadingMore {
                            ProgressView()
                                .tint(MTColor.accent)
                                .padding()
                        }
                    }
                }
                .padding(.vertical, MTSpacing.sm)
            }
            .background(MTColor.bgPrimary)
            .refreshable {
                await vm.refreshPosts()
            }
            .navigationTitle("Лента")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreate = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundStyle(MTColor.accent)
                    }
                }
            }
            .sheet(isPresented: $showCreate) {
                CreatePostViewControllerRepresentable(vm: vm) {
                    showCreate = false
                }
            }
            .sheet(item: $commentPost) { post in
                NavigationStack {
                    CommentsViewControllerRepresentable(post: post)
                }
            }
        }
        .task {
            await vm.loadPosts()
        }
    }

    private var postSkeleton: some View {
        RoundedRectangle(cornerRadius: Theme.radiusLg)
            .fill(MTColor.bgCard)
            .frame(height: 280)
            .redacted(reason: .placeholder)
            .shimmering()
            .padding(.horizontal, MTSpacing.md)
    }

    @ViewBuilder
    private func postCard(post: Post) -> some View {
        let isMine = post.authorId == authService.user?.id
        VStack(alignment: .leading, spacing: MTSpacing.sm) {
            HStack(spacing: MTSpacing.sm) {
                MTAvatarView(name: post.authorName, colorHex: post.authorAvatarColor, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(post.authorName)
                        .font(MTFont.headline)
                        .foregroundStyle(MTColor.textPrimary)
                    Text(post.timeAgo)
                        .font(MTFont.caption)
                        .foregroundStyle(MTColor.textMuted)
                }
                Spacer()
            }
            .padding(.horizontal, MTSpacing.md)

            if !post.caption.isEmpty {
                Text(post.caption)
                    .font(MTFont.body)
                    .foregroundStyle(MTColor.textPrimary)
                    .padding(.horizontal, MTSpacing.md)
            }

            mediaBlock(post: post)

            HStack(spacing: MTSpacing.lg) {
                Button {
                    vm.toggleLike(post: post)
                } label: {
                    Label("\(post.likesCount)", systemImage: post.isLiked ? "heart.fill" : "heart")
                        .foregroundStyle(post.isLiked ? MTColor.danger : MTColor.textSecondary)
                }
                .buttonStyle(.plain)

                Button {
                    commentPost = post
                } label: {
                    Label("\(post.commentsCount)", systemImage: "bubble.right")
                        .foregroundStyle(MTColor.textSecondary)
                }
                .buttonStyle(.plain)

                Button {
                    vm.repost(post: post)
                } label: {
                    Label("\(post.repostsCount)", systemImage: "arrow.2.squarepath")
                        .foregroundStyle(MTColor.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .font(MTFont.caption)
            .padding(.horizontal, MTSpacing.md)
            .padding(.bottom, MTSpacing.sm)
        }
        .background(MTColor.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.radiusLg, style: .continuous)
                .stroke(MTColor.border, lineWidth: 1)
        )
        .padding(.horizontal, MTSpacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(post.authorName), \(post.caption.prefix(80))")
        .contextMenu {
            if isMine {
                Button(role: .destructive) {
                    vm.deletePost(post)
                } label: {
                    Label("Удалить", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func mediaBlock(post: Post) -> some View {
        switch post.type {
        case .image:
            KFImage(URL(string: post.fullFileUrl))
                .placeholder { Color.gray.opacity(0.2) }
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 220)
                .clipped()
        case .video:
            if let url = URL(string: post.fullFileUrl) {
                FeedVideoPlayerView(
                    url: url,
                    isPlaying: activeVideoPostId == post.id,
                    feedSound: feedSound
                )
                .frame(height: 220)
                .clipped()
            } else {
                Color.gray.opacity(0.2).frame(height: 220)
            }
        }
    }
}

private struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay {
                LinearGradient(
                    colors: [.clear, .white.opacity(0.12), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .mask(content)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 200
                }
            }
    }
}

private extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

struct FeedVideoPlayerView: UIViewRepresentable {
    let url: URL
    let isPlaying: Bool
    @ObservedObject var feedSound: FeedVideoSoundState

    func makeUIView(context: Context) -> PlayerContainerView {
        let v = PlayerContainerView()
        v.configure(url: url, feedSound: feedSound)
        return v
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.setPlaying(isPlaying)
        uiView.setMuted(!feedSound.soundOn)
    }
}

final class PlayerContainerView: UIView {
    private var player: AVPlayer?
    private var looper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    private var feedSound: FeedVideoSoundState?

    func configure(url: URL, feedSound: FeedVideoSoundState) {
        self.feedSound = feedSound
        let item = AVPlayerItem(url: url)
        let qp = AVQueuePlayer()
        queuePlayer = qp
        looper = AVPlayerLooper(player: qp, templateItem: item)
        player = qp
        let layer = AVPlayerLayer(player: qp)
        layer.videoGravity = .resizeAspectFill
        self.layer.addSublayer(layer)
        contextLayer = layer
        qp.isMuted = !feedSound.soundOn
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(routeChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
    }

    private var contextLayer: AVPlayerLayer?

    override func layoutSubviews() {
        super.layoutSubviews()
        contextLayer?.frame = bounds
    }

    func setPlaying(_ playing: Bool) {
        if playing {
            queuePlayer?.play()
        } else {
            queuePlayer?.pause()
        }
    }

    func setMuted(_ muted: Bool) {
        queuePlayer?.isMuted = muted
    }

    @objc private func routeChanged() {
        queuePlayer?.isMuted = !(feedSound?.soundOn ?? false)
    }

    deinit {
        queuePlayer?.pause()
        NotificationCenter.default.removeObserver(self)
    }
}

struct CreatePostViewControllerRepresentable: UIViewControllerRepresentable {
    @ObservedObject var vm: FeedViewModel
    var onDismiss: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let vc = CreatePostViewController(vm: vm, onClose: onDismiss)
        return UINavigationController(rootViewController: vc)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}

struct CommentsViewControllerRepresentable: UIViewControllerRepresentable {
    let post: Post

    func makeUIViewController(context: Context) -> UINavigationController {
        UINavigationController(rootViewController: CommentsViewController(post: post))
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
