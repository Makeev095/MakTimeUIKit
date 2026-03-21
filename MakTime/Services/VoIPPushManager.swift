import Foundation
import PushKit

/// Регистрация VoIP push. Payload должен совпадать с контрактом бэкенда — см. `VoIPPushPayload`.
@MainActor
final class VoIPPushManager: NSObject {
    private let registry: PKPushRegistry

    /// Распарсенный входящий звонок для CallKit (или nil при невалидном payload).
    var onIncomingVoIPCall: ((IncomingCall, UUID) -> Void)?

    /// Токен для отправки на бэкенд (APNs VoIP).
    var onVoIPToken: ((Data) -> Void)?

    override init() {
        registry = PKPushRegistry(queue: .main)
        super.init()
        registry.delegate = self
        registry.desiredPushTypes = [.voIP]
    }
}

extension VoIPPushManager: PKPushRegistryDelegate {
    nonisolated func pushRegistry(_ registry: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        Task { @MainActor in
            self.onVoIPToken?(pushCredentials.token)
        }
    }

    nonisolated func pushRegistry(_ registry: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {}

    nonisolated func pushRegistry(
        _ registry: PKPushRegistry,
        didReceiveIncomingPushWith payload: PKPushPayload,
        for type: PKPushType,
        completion: @escaping () -> Void
    ) {
        Task { @MainActor in
            defer { completion() }
            guard type == .voIP else { return }
            guard let parsed = VoIPPushPayload(dictionary: payload.dictionaryPayload) else { return }
            let call = IncomingCall(
                from: parsed.fromUserId,
                callerName: parsed.callerName,
                conversationId: parsed.conversationId
            )
            let uuid = parsed.callUUID ?? UUID()
            self.onIncomingVoIPCall?(call, uuid)
        }
    }
}
