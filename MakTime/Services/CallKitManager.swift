import Foundation
import CallKit
import AVFoundation
import WebRTC

/// Системный слой CallKit + синхронизация `RTCAudioSession` с сессией, которую активирует CallKit.
@MainActor
final class CallKitManager: NSObject {
    private let provider: CXProvider
    private let callController = CXCallController()

    /// UUID звонка → метаданные для сигналинга
    private(set) var pendingIncoming: [UUID: IncomingCall] = [:]
    private(set) var outgoingContexts: [UUID: CallTarget] = [:]

    var onAnswerIncoming: ((UUID, IncomingCall) -> Void)?
    var onEndCall: ((UUID) -> Void)?
    var onSetMuted: ((UUID, Bool) -> Void)?
    /// Исходящий: система готова — показать UI и поднять WebRTC
    var onPerformStartOutgoing: ((UUID, CallTarget) -> Void)?

    override init() {
        let config = CXProviderConfiguration(localizedName: "MakTime")
        config.supportsVideo = true
        config.maximumCallsPerCallGroup = 1
        config.maximumCallGroups = 2
        config.supportedHandleTypes = [.generic]
        config.iconTemplateImageData = nil
        config.ringtoneSound = nil
        provider = CXProvider(configuration: config)
        super.init()
        provider.setDelegate(self, queue: nil)
    }

    func reportIncomingCall(uuid: UUID, call: IncomingCall, completion: @escaping (Error?) -> Void) {
        pendingIncoming[uuid] = call
        let update = CXCallUpdate()
        update.remoteHandle = CXHandle(type: .generic, value: call.from)
        update.localizedCallerName = call.callerName
        update.hasVideo = true
        update.supportsDTMF = false
        update.supportsHolding = false
        update.supportsGrouping = false
        update.supportsUngrouping = false
        provider.reportNewIncomingCall(with: uuid, update: update, completion: completion)
    }

    func requestStartOutgoingCall(uuid: UUID, call: CallTarget, completion: @escaping (Error?) -> Void) {
        outgoingContexts[uuid] = call
        let handle = CXHandle(type: .generic, value: call.userId)
        let action = CXStartCallAction(call: uuid, handle: handle)
        action.isVideo = true
        let tx = CXTransaction(action: action)
        callController.request(tx) { error in
            Task { @MainActor in
                if error != nil {
                    self.outgoingContexts.removeValue(forKey: uuid)
                }
                completion(error)
            }
        }
    }

    func removePendingIncoming(uuid: UUID) {
        pendingIncoming.removeValue(forKey: uuid)
    }

    func reportCallEnded(uuid: UUID, reason: CXCallEndedReason = .remoteEnded) {
        let action = CXEndCallAction(call: uuid)
        let tx = CXTransaction(action: action)
        callController.request(tx) { _ in }
        pendingIncoming.removeValue(forKey: uuid)
        outgoingContexts.removeValue(forKey: uuid)
    }

}

extension CallKitManager: CXProviderDelegate {
    nonisolated func providerDidReset(_ provider: CXProvider) {
        Task { @MainActor in
            self.pendingIncoming.removeAll()
            self.outgoingContexts.removeAll()
        }
    }

    nonisolated func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        let rtc = RTCAudioSession.sharedInstance()
        rtc.audioSessionDidActivate(audioSession)
        rtc.isAudioEnabled = true
    }

    nonisolated func provider(_ provider: CXProvider, didDeactivate audioSession: AVAudioSession) {
        RTCAudioSession.sharedInstance().audioSessionDidDeactivate(audioSession)
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        Task { @MainActor in
            guard let call = self.pendingIncoming[action.callUUID] else {
                action.fail()
                return
            }
            self.onAnswerIncoming?(action.callUUID, call)
            action.fulfill()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        Task { @MainActor in
            self.onEndCall?(action.callUUID)
            self.pendingIncoming.removeValue(forKey: action.callUUID)
            self.outgoingContexts.removeValue(forKey: action.callUUID)
            action.fulfill()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        Task { @MainActor in
            self.onSetMuted?(action.callUUID, action.isMuted)
            action.fulfill()
        }
    }

    nonisolated func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        Task { @MainActor in
            guard let target = self.outgoingContexts[action.callUUID] else {
                action.fail()
                return
            }
            self.onPerformStartOutgoing?(action.callUUID, target)
            action.fulfill(withDateStarted: Date())
        }
    }

    nonisolated func provider(_ provider: CXProvider, timedOutPerforming action: CXAction) {
        Task { @MainActor in
            action.fail()
        }
    }
}
