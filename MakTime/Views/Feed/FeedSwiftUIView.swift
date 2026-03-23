import SwiftUI
import UIKit
import AVKit
import AVFoundation
import Kingfisher

/// Вертикальная лента в стиле Reels: полный экран, свайп между постами.
struct FeedSwiftUIView: View {
    @ObservedObject var authService: AuthService
    @StateObject private var vm = FeedViewModel()
    @StateObject private var feedSound = FeedVideoSoundState()
    @State private var activeVideoPostId: String?
    @State private var currentIndex: Int = 0
    @State private var showCreate = false
    @State private var commentPost: Post?

    var body: some View {
        NavigationStack {
            ZStack {
                MTColor.bgPrimary.ignoresSafeArea()
                if vm.isLoading && vm.posts.isEmpty {
                    ProgressView()
                        .tint(MTColor.accent)
                } else if vm.posts.isEmpty {
                    Text(vm.loadError ?? "Пока нет постов")
                        .font(MTFont.body)
                        .foregroundStyle(MTColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding()
                } else {
                    VerticalReelsPager(
                        posts: vm.posts,
                        currentIndex: $currentIndex,
                        activeVideoPostId: activeVideoPostId,
                        authService: authService,
                        vm: vm,
                        feedSound: feedSound,
                        commentPost: $commentPost
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Лента")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(MTColor.bgPrimary, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                .presentationDetents([.fraction(0.5), .large])
                .presentationDragIndicator(.visible)
            }
        }
        .task {
            await vm.loadPosts()
        }
        .onChange(of: currentIndex) { newIdx in
            syncActiveVideo(forIndex: newIdx)
            Task { await vm.loadMoreIfNeeded(currentIndex: newIdx, totalCount: vm.posts.count) }
        }
        .onChange(of: vm.posts.count) { count in
            if count > 0, currentIndex >= count {
                currentIndex = max(0, count - 1)
            }
            if count > 0 { syncActiveVideo(forIndex: min(currentIndex, count - 1)) }
        }
        .onAppear {
            if !vm.posts.isEmpty {
                syncActiveVideo(forIndex: currentIndex)
            }
        }
    }

    private func syncActiveVideo(forIndex idx: Int) {
        guard vm.posts.indices.contains(idx) else {
            activeVideoPostId = nil
            return
        }
        let post = vm.posts[idx]
        activeVideoPostId = post.type == .video ? post.id : nil
    }

}

// MARK: - Вертикальный paging без поворота TabView (убирает лишний зазор снизу)

private struct VerticalReelsPager: UIViewControllerRepresentable {
    var posts: [Post]
    @Binding var currentIndex: Int
    var activeVideoPostId: String?
    @ObservedObject var authService: AuthService
    @ObservedObject var vm: FeedViewModel
    @ObservedObject var feedSound: FeedVideoSoundState
    @Binding var commentPost: Post?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let vc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .vertical,
            options: [UIPageViewController.OptionsKey.interPageSpacing: 0]
        )
        vc.dataSource = context.coordinator
        vc.delegate = context.coordinator
        vc.view.backgroundColor = Theme.bgPrimary
        DispatchQueue.main.async {
            tuneVerticalReelsScrollInsets(in: vc.view)
        }
        return vc
    }

    func updateUIViewController(_ pageVC: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        context.coordinator.sync(pageVC: pageVC)
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: VerticalReelsPager
        private var cache: [String: UIHostingController<ReelPageView>] = [:]
        private var lastIds: [String] = []
        private var lastSyncedIndex: Int = -2

        init(_ parent: VerticalReelsPager) {
            self.parent = parent
        }

        func sync(pageVC: UIPageViewController) {
            let posts = parent.posts
            guard !posts.isEmpty else {
                pageVC.setViewControllers(nil, direction: .forward, animated: false)
                cache.removeAll()
                lastIds = []
                lastSyncedIndex = -2
                return
            }

            let ids = posts.map(\.id)
            if ids != lastIds {
                let valid = Set(ids)
                cache = cache.filter { valid.contains($0.key) }
                lastIds = ids
            }

            let idx = min(max(0, parent.currentIndex), posts.count - 1)

            for p in posts {
                if let h = cache[p.id] {
                    h.rootView = makeReelPage(for: p)
                }
            }

            if lastSyncedIndex == idx {
                return
            }

            let vc = controller(for: posts[idx])
            let animated = lastSyncedIndex >= 0 && abs(idx - lastSyncedIndex) == 1
            let direction: UIPageViewController.NavigationDirection = idx >= lastSyncedIndex ? .forward : .reverse
            pageVC.setViewControllers([vc], direction: direction, animated: animated)
            lastSyncedIndex = idx
            DispatchQueue.main.async {
                tuneVerticalReelsScrollInsets(in: pageVC.view)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                tuneVerticalReelsScrollInsets(in: pageVC.view)
            }
        }

        private func controller(for post: Post) -> UIViewController {
            if let existing = cache[post.id] {
                existing.rootView = makeReelPage(for: post)
                existing.view.accessibilityIdentifier = post.id
                return existing
            }
            let host = UIHostingController(rootView: makeReelPage(for: post))
            host.view.backgroundColor = Theme.bgPrimary
            host.view.insetsLayoutMarginsFromSafeArea = false
            host.additionalSafeAreaInsets = .zero
            host.view.accessibilityIdentifier = post.id
            cache[post.id] = host
            return host
        }

        private func makeReelPage(for post: Post) -> ReelPageView {
            ReelPageView(
                post: post,
                isActiveVideo: post.type == .video && parent.activeVideoPostId == post.id,
                authService: parent.authService,
                vm: parent.vm,
                feedSound: parent.feedSound,
                commentPost: parent.$commentPost
            )
        }

        private func index(of viewController: UIViewController) -> Int? {
            guard let id = viewController.view.accessibilityIdentifier else { return nil }
            return parent.posts.firstIndex { $0.id == id }
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let i = index(of: viewController), i > 0 else { return nil }
            return controller(for: parent.posts[i - 1])
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let i = index(of: viewController), i < parent.posts.count - 1 else { return nil }
            return controller(for: parent.posts[i + 1])
        }

        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let vc = pageViewController.viewControllers?.first, let idx = index(of: vc) else { return }
            parent.currentIndex = idx
            lastSyncedIndex = idx
            DispatchQueue.main.async {
                tuneVerticalReelsScrollInsets(in: pageViewController.view)
            }
        }
    }
}

/// Сбрасывает contentInset у вложенных `UIScrollView` внутри `UIPageViewController` — иначе снизу остаётся пустая полоса.
private func tuneVerticalReelsScrollInsets(in root: UIView) {
    if let scroll = root as? UIScrollView {
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.contentInset = .zero
        scroll.verticalScrollIndicatorInsets = .zero
        scroll.horizontalScrollIndicatorInsets = .zero
    }
    for sub in root.subviews {
        tuneVerticalReelsScrollInsets(in: sub)
    }
}

// MARK: - Одна страница рилса (нативная ориентация, без rotationEffect)

private struct ReelPageView: View {
    let post: Post
    let isActiveVideo: Bool
    @ObservedObject var authService: AuthService
    @ObservedObject var vm: FeedViewModel
    @ObservedObject var feedSound: FeedVideoSoundState
    @Binding var commentPost: Post?

    @State private var heartBurstVisible = false
    @State private var heartScale: CGFloat = 0.45
    @State private var heartOpacity: Double = 0

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let safe = geo.safeAreaInsets
            let bottomChromePadding = max(safe.bottom, 8) + 10
            let isMine = post.authorId == authService.user?.id

            ZStack {
                MTColor.bgPrimary
                ZStack {
                    reelMediaLayer(width: w, height: h)
                    FeedMediaTapOverlay(
                        singleTapEnabled: post.type == .video,
                        onSingleTap: {
                            feedSound.soundOn.toggle()
                        },
                        onDoubleTap: {
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                            triggerHeartBurst()
                            vm.toggleLike(post: post)
                        }
                    )
                }

                LinearGradient(
                    colors: [.clear, .black.opacity(0.58)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(width: w, height: h)
                .allowsHitTesting(false)

                if heartBurstVisible {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 96))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.white, MTColor.danger.opacity(0.95)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: .black.opacity(0.45), radius: 12, y: 4)
                        .scaleEffect(heartScale)
                        .opacity(heartOpacity)
                        .allowsHitTesting(false)
                }

                if post.type == .video, isActiveVideo {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: feedSound.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill")
                                .font(.title3)
                                .foregroundStyle(.white)
                                .padding(11)
                                .background(Circle().fill(Color.black.opacity(0.42)))
                                .shadow(color: .black.opacity(0.35), radius: 6)
                                .padding(.top, safe.top + 10)
                                .padding(.trailing, 14)
                                .animation(.spring(response: 0.38, dampingFraction: 0.72), value: feedSound.soundOn)
                        }
                        Spacer()
                    }
                    .frame(width: w, height: h)
                    .allowsHitTesting(false)
                }

                VStack {
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 10) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .center, spacing: 10) {
                                MTAvatarView(name: post.authorName, colorHex: post.authorAvatarColor, size: 44)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(post.authorName)
                                        .font(MTFont.headline)
                                        .foregroundStyle(.white)
                                        .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
                                    Text(post.timeAgo)
                                        .font(MTFont.caption)
                                        .foregroundStyle(.white.opacity(0.88))
                                }
                            }
                            if !post.caption.isEmpty {
                                Text(post.caption)
                                    .font(MTFont.body)
                                    .foregroundStyle(.white)
                                    .lineLimit(8)
                                    .multilineTextAlignment(.leading)
                                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 4)

                        VStack(spacing: 20) {
                            Button {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                triggerHeartBurst()
                                vm.toggleLike(post: post)
                            } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                                        .font(.title2)
                                        .foregroundStyle(post.isLiked ? MTColor.danger : .white)
                                    Text("\(post.likesCount)")
                                        .font(MTFont.caption)
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                commentPost = post
                            } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: "bubble.right")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                    Text("\(post.commentsCount)")
                                        .font(MTFont.caption)
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                vm.repost(post: post)
                            } label: {
                                VStack(spacing: 5) {
                                    Image(systemName: "arrow.2.squarepath")
                                        .font(.title2)
                                        .foregroundStyle(.white)
                                    Text("\(post.repostsCount)")
                                        .font(MTFont.caption)
                                        .foregroundStyle(.white)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(width: 56)
                    }
                    .padding(.leading, 16)
                    .padding(.trailing, 12)
                    .padding(.bottom, bottomChromePadding)
                }
                .frame(width: w, height: h, alignment: .bottom)
            }
            .frame(width: w, height: h)
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func triggerHeartBurst() {
        heartBurstVisible = true
        heartOpacity = 1
        heartScale = 0.42
        withAnimation(.spring(response: 0.38, dampingFraction: 0.62)) {
            heartScale = 1.12
        }
        withAnimation(.easeOut(duration: 0.5).delay(0.15)) {
            heartOpacity = 0
            heartScale = 1.45
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.62) {
            heartBurstVisible = false
        }
    }

    @ViewBuilder
    private func reelMediaLayer(width: CGFloat, height: CGFloat) -> some View {
        switch post.type {
        case .image:
            KFImage(URL(string: post.fullFileUrl))
                .placeholder { Color.gray.opacity(0.25) }
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)
                .clipped()
        case .video:
            if let url = URL(string: post.fullFileUrl) {
                FeedVideoPlayerView(
                    url: url,
                    isPlaying: isActiveVideo,
                    feedSound: feedSound
                )
                .frame(width: width, height: height)
            } else {
                Color.gray.opacity(0.3)
                    .frame(width: width, height: height)
            }
        }
    }
}

/// Одиночный тап и двойной не конфликтуют: `single` ждёт провала `double`.
private struct FeedMediaTapOverlay: UIViewRepresentable {
    var singleTapEnabled: Bool
    var onSingleTap: () -> Void
    var onDoubleTap: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(singleTapEnabled: singleTapEnabled, onSingleTap: onSingleTap, onDoubleTap: onDoubleTap)
    }

    func makeUIView(context: Context) -> UIView {
        let v = UIView()
        v.backgroundColor = .clear
        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDouble))
        doubleTap.numberOfTapsRequired = 2
        let singleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleSingle))
        singleTap.numberOfTapsRequired = 1
        singleTap.require(toFail: doubleTap)
        v.addGestureRecognizer(doubleTap)
        v.addGestureRecognizer(singleTap)
        return v
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.singleTapEnabled = singleTapEnabled
        context.coordinator.onSingleTap = onSingleTap
        context.coordinator.onDoubleTap = onDoubleTap
    }

    final class Coordinator: NSObject {
        var singleTapEnabled: Bool
        var onSingleTap: () -> Void
        var onDoubleTap: () -> Void

        init(singleTapEnabled: Bool, onSingleTap: @escaping () -> Void, onDoubleTap: @escaping () -> Void) {
            self.singleTapEnabled = singleTapEnabled
            self.onSingleTap = onSingleTap
            self.onDoubleTap = onDoubleTap
        }

        @objc func handleSingle() {
            guard singleTapEnabled else { return }
            onSingleTap()
        }

        @objc func handleDouble() {
            onDoubleTap()
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
    private var looper: AVPlayerLooper?
    private var queuePlayer: AVQueuePlayer?
    private var feedSound: FeedVideoSoundState?
    private var itemStatusObservation: NSKeyValueObservation?
    private var pendingPlay = false

    func configure(url: URL, feedSound: FeedVideoSoundState) {
        self.feedSound = feedSound
        itemStatusObservation?.invalidate()
        itemStatusObservation = nil
        NotificationCenter.default.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)
        queuePlayer?.pause()
        looper = nil
        queuePlayer = nil
        contextLayer?.removeFromSuperlayer()
        contextLayer = nil

        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 2

        let qp = AVQueuePlayer()
        qp.automaticallyWaitsToMinimizeStalling = false
        queuePlayer = qp
        looper = AVPlayerLooper(player: qp, templateItem: item)

        let layer = AVPlayerLayer(player: qp)
        layer.videoGravity = .resizeAspect
        backgroundColor = .black
        self.layer.addSublayer(layer)
        contextLayer = layer
        qp.isMuted = !feedSound.soundOn

        let observedItem = qp.currentItem ?? item
        itemStatusObservation = observedItem.observe(\.status, options: [.new]) { [weak self] it, _ in
            guard it.status == .readyToPlay else { return }
            guard let self = self, self.pendingPlay else { return }
            self.activatePlaybackSessionIfNeeded()
            self.queuePlayer?.play()
        }

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

    private func activatePlaybackSessionIfNeeded() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
        try? session.setActive(true)
    }

    func setPlaying(_ playing: Bool) {
        pendingPlay = playing
        if playing {
            activatePlaybackSessionIfNeeded()
            if queuePlayer?.currentItem?.status == .readyToPlay {
                queuePlayer?.play()
            } else {
                queuePlayer?.play()
            }
        } else {
            queuePlayer?.pause()
        }
    }

    func setMuted(_ muted: Bool) {
        queuePlayer?.isMuted = muted
    }

    @objc private func routeChanged() {
        queuePlayer?.isMuted = !(feedSound?.soundOn ?? true)
    }

    deinit {
        queuePlayer?.pause()
        itemStatusObservation?.invalidate()
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
