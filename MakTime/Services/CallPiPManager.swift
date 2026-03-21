import AVKit
import WebRTC
import UIKit

@MainActor
final class CallPiPManager: NSObject, ObservableObject {
    @Published var isPiPActive = false
    @Published var isRestoring = false

    private var pipController: AVPictureInPictureController?
    private var pipContentVC: AVPictureInPictureVideoCallViewController?
    private var sampleBufferView: SampleBufferVideoCallView?
    private var sampleBufferRenderer: SampleBufferVideoRenderer?
    private var currentRemoteTrack: RTCVideoTrack?
    private var startPiPRetryCount = 0
    private let maxRetries = 5

    var onRestoreFullScreen: (() -> Void)?
    var onPiPStarted: (() -> Void)?

    // MARK: - Setup

    /// Call as soon as a remote track is available (or earlier with nil track for placeholder).
    func setup(sourceView: UIView, remoteTrack: RTCVideoTrack?) {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }

        // Detach old renderer if re-setting up
        if let old = currentRemoteTrack, let renderer = sampleBufferRenderer {
            old.remove(renderer)
        }

        let vc = AVPictureInPictureVideoCallViewController()
        vc.preferredContentSize = CGSize(width: 180, height: 240)

        let bufferView = SampleBufferVideoCallView(frame: .zero)
        bufferView.clipsToBounds = true
        bufferView.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(bufferView)
        NSLayoutConstraint.activate([
            bufferView.topAnchor.constraint(equalTo: vc.view.topAnchor),
            bufferView.leadingAnchor.constraint(equalTo: vc.view.leadingAnchor),
            bufferView.trailingAnchor.constraint(equalTo: vc.view.trailingAnchor),
            bufferView.bottomAnchor.constraint(equalTo: vc.view.bottomAnchor)
        ])

        let renderer = SampleBufferVideoRenderer(displayLayer: bufferView.sampleBufferDisplayLayer)
        if let track = remoteTrack {
            track.add(renderer)
        }

        let source = AVPictureInPictureController.ContentSource(
            activeVideoCallSourceView: sourceView,
            contentViewController: vc
        )

        let ctrl = AVPictureInPictureController(contentSource: source)
        ctrl.delegate = self
        // Иначе система может сама поднять PiP при открытии панели управления / неполном «уходе».
        ctrl.canStartPictureInPictureAutomaticallyFromInline = false

        self.pipContentVC = vc
        self.sampleBufferView = bufferView
        self.sampleBufferRenderer = renderer
        self.pipController = ctrl
        self.currentRemoteTrack = remoteTrack
    }

    /// Update remote track after initial setup (e.g. when track arrives after app was backgrounded).
    func updateRemoteTrack(_ track: RTCVideoTrack) {
        if let old = currentRemoteTrack, let renderer = sampleBufferRenderer {
            old.remove(renderer)
        }
        currentRemoteTrack = track
        if let renderer = sampleBufferRenderer {
            track.add(renderer)
        }
    }

    // MARK: - Control

    func startPiP() {
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }
        startPiPRetryCount = 0
        attemptStartPiP()
    }

    private func attemptStartPiP() {
        guard let ctrl = pipController else { return }

        if ctrl.isPictureInPicturePossible {
            ctrl.startPictureInPicture()
            startPiPRetryCount = 0
        } else if startPiPRetryCount < maxRetries {
            startPiPRetryCount += 1
            let delay = Double(startPiPRetryCount) * 0.4
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.attemptStartPiP()
            }
        } else {
            print("PiP: failed to start after \(maxRetries) retries")
            startPiPRetryCount = 0
        }
    }

    func stopPiP() {
        pipController?.stopPictureInPicture()
    }

    func cleanup() {
        stopPiP()
        startPiPRetryCount = 0
        if let track = currentRemoteTrack, let renderer = sampleBufferRenderer {
            track.remove(renderer)
        }
        pipController = nil
        pipContentVC = nil
        sampleBufferView = nil
        sampleBufferRenderer = nil
        currentRemoteTrack = nil
        isPiPActive = false
    }
}

// MARK: - AVPictureInPictureControllerDelegate

extension CallPiPManager: AVPictureInPictureControllerDelegate {

    nonisolated func pictureInPictureControllerWillStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        Task { @MainActor in self.isPiPActive = true }
    }

    nonisolated func pictureInPictureControllerDidStartPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        Task { @MainActor in
            self.isPiPActive = true
            self.onPiPStarted?()
        }
    }

    nonisolated func pictureInPictureControllerWillStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        Task { @MainActor in self.isPiPActive = false }
    }

    nonisolated func pictureInPictureControllerDidStopPictureInPicture(
        _ controller: AVPictureInPictureController
    ) {
        Task { @MainActor in self.isPiPActive = false }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler: @escaping (Bool) -> Void
    ) {
        Task { @MainActor in
            self.isRestoring = true
            self.onRestoreFullScreen?()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.isRestoring = false
                completionHandler(true)
            }
        }
    }

    nonisolated func pictureInPictureController(
        _ controller: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: Error
    ) {
        print("PiP failed: \(error.localizedDescription)")
        Task { @MainActor in
            // Retry once after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.attemptStartPiP()
            }
        }
    }
}
