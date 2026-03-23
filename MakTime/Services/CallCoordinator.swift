import Foundation
import Combine
import UIKit
import AVKit
import CallKit

/// Связывает Socket, CallKit, PiP и показ `VideoCallViewController`.
@MainActor
final class CallCoordinator: ObservableObject {
    let callKit: CallKitManager
    private let voipPush: VoIPPushManager
    private let socketService: SocketService
    private let authService: AuthService

    let pipManager = CallPiPManager()

    weak var hostViewController: UIViewController?

    private var cancellables = Set<AnyCancellable>()
    /// Текущий экран видеозвонка (полноэкранный или свёрнутый).
    private var videoCallVC: VideoCallViewController?
    private var floatingWindow: CallFloatingWindow?
    private var floatingVideoCancellable: AnyCancellable?
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid

    private var callTarget: CallTarget?
    private var activeCallKitUUID: UUID?

    init(
        callKit: CallKitManager,
        voipPush: VoIPPushManager,
        socketService: SocketService,
        authService: AuthService
    ) {
        self.callKit = callKit
        self.voipPush = voipPush
        self.socketService = socketService
        self.authService = authService
        wireCallKit()
        wireVoIP()
        wireSocketIncoming()
    }

    private func wireCallKit() {
        callKit.onAnswerIncoming = { [weak self] uuid, incoming in
            self?.presentAnsweredIncoming(uuid: uuid, incoming: incoming)
        }
        callKit.onEndCall = { [weak self] uuid in
            self?.handleCallKitEnd(uuid: uuid)
        }
        callKit.onSetMuted = { [weak self] _, muted in
            self?.videoCallVC?.vm.setMutedFromCallKit(muted)
        }
        callKit.onPerformStartOutgoing = { [weak self] uuid, target in
            self?.activeCallKitUUID = uuid
            self?.callTarget = target
            self?.presentVideoCall(target: target, callKitUUID: uuid)
        }
    }

    private func wireVoIP() {
        voipPush.onIncomingVoIPCall = { [weak self] call, uuid in
            self?.callKit.reportIncomingCall(uuid: uuid, call: call) { err in
                if let err { print("[VoIP] report incoming: \(err)") }
            }
        }
        voipPush.onVoIPToken = { token in
            let hex = token.map { String(format: "%02.2hhx", $0) }.joined()
            print("[VoIP] device token (send to backend): \(hex)")
        }
    }

    private func wireSocketIncoming() {
        socketService.$incomingCall
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] call in
                guard let self else { return }
                guard self.callTarget == nil, self.videoCallVC == nil else { return }
                self.socketService.incomingCall = nil
                let uuid = UUID()
                self.callKit.reportIncomingCall(uuid: uuid, call: call) { err in
                    if let err { print("[CallKit] report incoming: \(err)") }
                }
            }
            .store(in: &cancellables)
    }

    func startOutgoingCall(userId: String, name: String, conversationId: String, isVideo: Bool = true) {
        guard callTarget == nil, videoCallVC == nil else { return }
        let target = CallTarget(userId: userId, name: name, conversationId: conversationId, isInitiator: true, isVideo: isVideo)
        callTarget = target
        let uuid = UUID()
        activeCallKitUUID = uuid
        callKit.requestStartOutgoingCall(uuid: uuid, call: target) { [weak self] error in
            if let error {
                print("[CallKit] outgoing failed: \(error)")
                self?.callTarget = nil
                self?.activeCallKitUUID = nil
            }
        }
    }

    private func presentAnsweredIncoming(uuid: UUID, incoming: IncomingCall) {
        activeCallKitUUID = uuid
        callTarget = CallTarget(
            userId: incoming.from,
            name: incoming.callerName,
            conversationId: incoming.conversationId,
            isInitiator: false,
            isVideo: incoming.isVideo
        )
        socketService.acceptCall(to: incoming.from)
        callKit.removePendingIncoming(uuid: uuid)
        if let target = callTarget {
            presentVideoCall(target: target, callKitUUID: uuid)
        }
    }

    private func presentVideoCall(target: CallTarget, callKitUUID: UUID) {
        guard let host = hostViewController else { return }
        let vc = VideoCallViewController(
            target: target,
            authService: authService,
            socketService: socketService,
            pipManager: pipManager,
            onEnd: { [weak self] in
                self?.endCallFromApp(callKitUUID: callKitUUID)
            },
            onToggleMinimize: { [weak self] vcc in
                self?.minimizeCall(vc: vcc)
            },
            onWebRTCConnected: { [weak self] in
                self?.callKit.notifyMediaConnected(callKitUUID: callKitUUID)
            }
        )
        vc.modalPresentationStyle = .fullScreen
        host.present(vc, animated: true)
        videoCallVC = vc
    }

    private func endCallFromApp(callKitUUID: UUID) {
        callKit.reportCallEnded(uuid: callKitUUID)
        callTarget = nil
        activeCallKitUUID = nil
        videoCallVC = nil
        endBackgroundTask()
        floatingWindow?.isHidden = true
        floatingWindow = nil
        cancelFloatingSubscription()
    }

    private func handleCallKitEnd(uuid: UUID) {
        if let pending = callKit.pendingIncoming[uuid] {
            socketService.rejectCall(to: pending.from)
            callKit.removePendingIncoming(uuid: uuid)
            return
        }
        guard activeCallKitUUID == uuid else { return }
        videoCallVC?.vm.terminateForCallKit()
        callTarget = nil
        activeCallKitUUID = nil
        videoCallVC = nil
        floatingWindow?.isHidden = true
        floatingWindow = nil
        cancelFloatingSubscription()
    }

    private func cancelFloatingSubscription() {
        floatingVideoCancellable?.cancel()
        floatingVideoCancellable = nil
    }

    func registerPiPNotifications() {
        // Только реальный уход в фон (Home / другое приложение). Панель управления / ЦУ
        // даёт willResignActive без didEnterBackground — иначе дублируется PiP поверх полноэкранного звонка.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        pipManager.onRestoreFullScreen = { [weak self] in
            self?.restoreMinimizedCall()
        }
        pipManager.onPiPStarted = { [weak self] in
            self?.endBackgroundTask()
        }
    }

    @objc private func appDidEnterBackground() {
        guard callTarget != nil, let vc = videoCallVC else { return }
        guard vc.vm.target.isVideo else { return }
        guard !pipManager.isPiPActive else { return }
        // PiP с видео имеет смысл после соединения или когда уже есть remote track
        guard vc.vm.status == .connected || vc.vm.remoteVideoTrack != nil else { return }
        guard AVPictureInPictureController.isPictureInPictureSupported() else { return }

        backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.pipManager.startPiP()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.endBackgroundTask()
            }
        }
    }

    @objc private func didBecomeActive() {
        if pipManager.isPiPActive {
            pipManager.stopPiP()
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskId != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        backgroundTaskId = .invalid
    }

    private func minimizeCall(vc: VideoCallViewController) {
        videoCallVC = vc
        guard vc.vm.target.isVideo else { return }
        if AVPictureInPictureController.isPictureInPictureSupported() {
            pipManager.startPiP()
        } else if let scene = vc.view.window?.windowScene {
            let floating = CallFloatingWindow(
                windowScene: scene,
                remoteTrack: vc.vm.remoteVideoTrack
            )
            floating.configure(name: vc.vm.target.name, remoteTrack: vc.vm.remoteVideoTrack)
            floating.onTapToRestore = { [weak self] in
                self?.floatingWindow?.isHidden = true
                self?.floatingWindow = nil
                self?.cancelFloatingSubscription()
                self?.restoreMinimizedCall()
            }
            floating.onClose = { [weak self] in
                self?.floatingWindow?.isHidden = true
                self?.floatingWindow = nil
                self?.cancelFloatingSubscription()
                self?.videoCallVC?.vm.endCall()
                self?.videoCallVC = nil
                self?.callTarget = nil
            }
            floating.show(in: scene)
            floatingWindow = floating
            floatingVideoCancellable = vc.vm.$remoteVideoTrack
                .receive(on: DispatchQueue.main)
                .sink { [weak self] track in
                    guard let track else { return }
                    self?.floatingWindow?.updateRemoteTrack(track)
                }
        }
        vc.dismiss(animated: true)
    }

    private func restoreMinimizedCall() {
        guard let vc = videoCallVC else { return }
        // Если полноэкранный звонок всё ещё показан (уход на Home + PiP), не дублируем present
        if vc.presentingViewController != nil {
            return
        }
        hostViewController?.present(vc, animated: true)
    }
}
