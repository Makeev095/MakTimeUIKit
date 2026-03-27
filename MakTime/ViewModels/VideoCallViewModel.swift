import Foundation
import Combine
import WebRTC
import AVFoundation
import AudioToolbox

@MainActor
class VideoCallViewModel: ObservableObject {
    @Published var status: CallStatus = .connecting
    @Published var isMuted = false
    @Published var isVideoOff = false
    @Published var duration: Int = 0
    @Published var remoteVideoTrack: RTCVideoTrack?
    
    let target: CallTarget
    let webRTCService = WebRTCService()
    
    private var socketService: SocketService?
    private var cancellables = Set<AnyCancellable>()
    private var durationTimer: Timer?
    private var callTimeout: Timer?
    private var iceRestartCount = 0
    private var ended = false
    private var ringPlayer: AVAudioPlayer?
    private var ringTimer: Timer?
    private var didReportConnected = false

    /// Один раз при установлении ICE connected/completed (для CallKit `CXSetConnectedCallAction`).
    var onConnected: (() -> Void)?
    
    enum CallStatus: String {
        case calling = "Вызов..."
        case connecting = "Подключение..."
        case connected = ""
        case rejected = "Вызов отклонён"
        case unavailable = "Абонент недоступен"
        case error = "Ошибка соединения"
    }
    
    init(target: CallTarget) {
        self.target = target
        self.status = target.isInitiator ? .calling : .connecting
    }
    
    var statusText: String {
        if status == .connected {
            let m = duration / 60
            let s = duration % 60
            return String(format: "%02d:%02d", m, s)
        }
        return status.rawValue
    }
    
    func setup(socketService: SocketService, callerName: String) {
        self.socketService = socketService
        webRTCService.delegate = self
        webRTCService.setup(audioOnly: !target.isVideo)
        configureAudioSession(speaker: true)
        
        socketService.callAccepted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] from in
                guard let self = self, from == self.target.userId else { return }
                self.callTimeout?.invalidate()
                self.stopRingtone()
                self.status = .connecting
                Task { await self.createAndSendOffer() }
            }
            .store(in: &cancellables)
        
        socketService.callRejected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.callTimeout?.invalidate()
                self?.stopRingtone()
                self?.status = .rejected
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self?.endCallRemote() }
            }
            .store(in: &cancellables)
        
        socketService.callEnded
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.stopRingtone()
                self?.endCallRemote()
            }
            .store(in: &cancellables)
        
        socketService.callUnavailable
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in
                self?.callTimeout?.invalidate()
                self?.stopRingtone()
                self?.status = .unavailable
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self?.endCallRemote() }
            }
            .store(in: &cancellables)
        
        socketService.webrtcOffer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (from, offerDict) in
                guard let self = self, from == self.target.userId else { return }
                Task { await self.handleOffer(offerDict) }
            }
            .store(in: &cancellables)
        
        socketService.webrtcAnswer
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (from, answerDict) in
                guard let self = self, from == self.target.userId else { return }
                Task { await self.handleAnswer(answerDict) }
            }
            .store(in: &cancellables)
        
        socketService.webrtcIceCandidate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] (from, candidateDict) in
                guard let self = self, from == self.target.userId else { return }
                Task { await self.handleICECandidate(candidateDict) }
            }
            .store(in: &cancellables)
        
        if target.isInitiator {
            socketService.initiateCall(
                to: target.userId,
                conversationId: target.conversationId,
                callerName: callerName,
                isVideo: target.isVideo
            )
            startRingtone()
            callTimeout = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.status = .unavailable
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self?.endCall() }
                }
            }
        } else {
            socketService.acceptCall(to: target.userId)
        }
    }
    
    private func startRingtone() {
        guard target.isInitiator else { return }
        applyCallAudioCategoryOnly()

        ringTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.playBeep()
            }
        }
        playBeep()
    }
    
    private func playBeep() {
        guard status == .calling else { stopRingtone(); return }
        AudioServicesPlaySystemSound(1151)
    }
    
    private func stopRingtone() {
        ringTimer?.invalidate()
        ringTimer = nil
    }
    
    private func createAndSendOffer() async {
        do {
            let offer = try await webRTCService.createOffer()
            socketService?.sendWebRTCOffer(to: target.userId, offer: WebRTCService.sdpToDict(offer))
        } catch {}
    }
    
    private func handleOffer(_ dict: [String: Any]) async {
        guard let sdp = WebRTCService.dictToSDP(dict) else { return }
        do {
            try await webRTCService.setRemoteDescription(sdp)
            let answer = try await webRTCService.createAnswer()
            socketService?.sendWebRTCAnswer(to: target.userId, answer: WebRTCService.sdpToDict(answer))
        } catch {}
    }
    
    private func handleAnswer(_ dict: [String: Any]) async {
        guard let sdp = WebRTCService.dictToSDP(dict) else { return }
        do {
            try await webRTCService.setRemoteDescription(sdp)
        } catch {}
    }
    
    private func handleICECandidate(_ dict: [String: Any]) async {
        guard let candidate = WebRTCService.dictToCandidate(dict) else { return }
        do {
            try await webRTCService.addICECandidate(candidate)
        } catch {}
    }
    
    var onEnd: (() -> Void)?
    
    func endCall() {
        guard !ended else { return }
        ended = true
        socketService?.endCall(to: target.userId)
        cleanup()
        onEnd?()
    }

    /// Завершение со стороны CallKit (уже без повторного `reportCallEnded`).
    func terminateForCallKit() {
        guard !ended else { return }
        ended = true
        socketService?.endCall(to: target.userId)
        cleanup()
    }

    func setMutedFromCallKit(_ muted: Bool) {
        guard isMuted != muted else { return }
        isMuted = muted
        webRTCService.setMicEnabled(!muted)
    }
    
    private func endCallRemote() {
        guard !ended else { return }
        ended = true
        cleanup()
        onEnd?()
    }
    
    private func cleanup() {
        stopRingtone()
        callTimeout?.invalidate()
        durationTimer?.invalidate()
        cancellables.removeAll()
        webRTCService.close()
    }
    
    func toggleMute() {
        isMuted.toggle()
        webRTCService.setMicEnabled(!isMuted)
    }
    
    func toggleVideo() {
        isVideoOff.toggle()
        webRTCService.setVideoEnabled(!isVideoOff)
    }
    
    func switchCamera() {
        webRTCService.switchCamera()
    }

    /// Только категория/режим/опции — без `setActive`: активацией управляет CallKit, иначе — ошибка 561017449.
    private func applyCallAudioCategoryOnly(preferSpeaker: Bool = true) {
        let rtc = RTCAudioSession.sharedInstance()
        rtc.useManualAudio = false
        rtc.lockForConfiguration()
        defer { rtc.unlockForConfiguration() }
        let mode: AVAudioSession.Mode = target.isVideo ? .videoChat : .voiceChat
        let toSpeaker = target.isVideo || preferSpeaker
        let options: AVAudioSession.CategoryOptions = toSpeaker
            ? [.defaultToSpeaker, .allowBluetoothHFP]
            : [.allowBluetoothHFP]
        do {
            try rtc.setCategory(AVAudioSession.Category.playAndRecord, mode: mode, options: options)
            if toSpeaker {
                try rtc.overrideOutputAudioPort(.speaker)
            }
        } catch {
            print("[Call] RTCAudioSession category: \(error)")
        }
        rtc.isAudioEnabled = true
    }

    private func configureAudioSession(speaker: Bool) {
        applyCallAudioCategoryOnly(preferSpeaker: speaker)
    }

    /// После ICE connected: повторно выставить маршрут и режим (на случай если CallKit пришёл раньше `target`).
    private func routeCallAudioToSpeakerIfNeeded() {
        guard target.isVideo else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self, self.status == .connected else { return }
            self.applyCallAudioCategoryOnly()
        }
    }
}

extension VideoCallViewModel: WebRTCServiceDelegate {
    nonisolated func webRTCService(_ service: WebRTCService, didReceiveRemoteVideoTrack track: RTCVideoTrack) {
        Task { @MainActor in self.remoteVideoTrack = track }
    }
    
    nonisolated func webRTCService(_ service: WebRTCService, didChangeConnectionState state: RTCIceConnectionState) {
        Task { @MainActor in
            switch state {
            case .connected, .completed:
                self.callTimeout?.invalidate()
                self.status = .connected
                if !self.didReportConnected {
                    self.didReportConnected = true
                    self.onConnected?()
                }
                self.routeCallAudioToSpeakerIfNeeded()
                if self.durationTimer == nil {
                    self.durationTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                        Task { @MainActor in self?.duration += 1 }
                    }
                }
            case .failed:
                if self.iceRestartCount < 3 {
                    self.iceRestartCount += 1
                    service.restartICE()
                } else {
                    self.endCall()
                }
            case .disconnected:
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
                    if self?.status != .connected { self?.endCall() }
                }
            default: break
            }
        }
    }
    
    nonisolated func webRTCService(_ service: WebRTCService, didGenerateICECandidate candidate: RTCIceCandidate) {
        Task { @MainActor in
            self.socketService?.sendICECandidate(
                to: self.target.userId,
                candidate: WebRTCService.candidateToDict(candidate)
            )
        }
    }
}
