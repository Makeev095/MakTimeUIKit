import Foundation
import AVFoundation
import WebRTC
import Combine

protocol WebRTCServiceDelegate: AnyObject {
    func webRTCService(_ service: WebRTCService, didReceiveRemoteVideoTrack track: RTCVideoTrack)
    func webRTCService(_ service: WebRTCService, didChangeConnectionState state: RTCIceConnectionState)
    func webRTCService(_ service: WebRTCService, didGenerateICECandidate candidate: RTCIceCandidate)
}

class WebRTCService: NSObject, @unchecked Sendable {
    weak var delegate: WebRTCServiceDelegate?
    
    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory(
            encoderFactory: RTCDefaultVideoEncoderFactory(),
            decoderFactory: RTCDefaultVideoDecoderFactory()
        )
    }()
    
    private var peerConnection: RTCPeerConnection?
    private var localVideoTrack: RTCVideoTrack?
    private var localAudioTrack: RTCAudioTrack?
    private var videoCapturer: RTCCameraVideoCapturer?
    private var localVideoSource: RTCVideoSource?
    private var isFrontCamera = true
    private var audioOnly = false
    
    var localStream: RTCVideoTrack? { localVideoTrack }
    
    // MARK: - Setup
    
    func setup(audioOnly: Bool = false) {
        self.audioOnly = audioOnly
        let config = RTCConfiguration()
        config.iceServers = [
            RTCIceServer(urlStrings: AppConfig.stunServers),
            RTCIceServer(
                urlStrings: [
                    "turn:\(AppConfig.turnHost):\(AppConfig.turnPort)",
                    "turn:\(AppConfig.turnHost):\(AppConfig.turnPort)?transport=tcp"
                ],
                username: AppConfig.turnUser,
                credential: AppConfig.turnPass
            ),
        ]
        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually
        config.candidateNetworkPolicy = .all
        config.iceCandidatePoolSize = 10
        
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )
        
        peerConnection = Self.factory.peerConnection(with: config, constraints: constraints, delegate: self)
        
        setupLocalMedia(audioOnly: audioOnly)
    }
    
    private func setupLocalMedia(audioOnly: Bool) {
        let audioConstraints = RTCMediaConstraints(mandatoryConstraints: nil, optionalConstraints: nil)
        let audioSource = Self.factory.audioSource(with: audioConstraints)
        localAudioTrack = Self.factory.audioTrack(with: audioSource, trackId: "audio0")
        localAudioTrack?.isEnabled = true
        peerConnection?.add(localAudioTrack!, streamIds: ["stream0"])
        
        guard !audioOnly else { return }
        
        localVideoSource = Self.factory.videoSource()
        localVideoTrack = Self.factory.videoTrack(with: localVideoSource!, trackId: "video0")
        localVideoTrack?.isEnabled = true
        peerConnection?.add(localVideoTrack!, streamIds: ["stream0"])
        
        videoCapturer = RTCCameraVideoCapturer(delegate: localVideoSource!)
        startCapture()
    }
    
    func startCapture() {
        guard let capturer = videoCapturer else { return }
        let position: AVCaptureDevice.Position = isFrontCamera ? .front : .back
        guard let device = RTCCameraVideoCapturer.captureDevices().first(where: { $0.position == position }) else { return }
        
        let candidates = device.formats
            .filter { CMVideoFormatDescriptionGetDimensions($0.formatDescription).width <= 1280 }
            .sorted { f1, f2 in
                let d1 = CMVideoFormatDescriptionGetDimensions(f1.formatDescription)
                let d2 = CMVideoFormatDescriptionGetDimensions(f2.formatDescription)
                return d1.width * d1.height > d2.width * d2.height
            }
        
        guard let format = candidates.first ?? device.formats.last else { return }
        
        let fps = format.videoSupportedFrameRateRanges
            .map { min($0.maxFrameRate, 30) }
            .max() ?? 30
        
        capturer.startCapture(with: device, format: format, fps: Int(fps))
        enableMultitaskingCameraIfSupported()
        // Сессия может создаваться асинхронно — повторная попытка через 0.5 сек
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.enableMultitaskingCameraIfSupported()
        }
    }
    
    /// Включает камеру в фоне (PiP) — чтобы собеседник видел видео, когда приложение свёрнуто.
    private func enableMultitaskingCameraIfSupported() {
        guard #available(iOS 16.0, *) else { return }
        guard let capturer = videoCapturer as? NSObject else { return }
        guard let session = capturer.value(forKey: "captureSession") as? AVCaptureSession else { return }
        guard session.isMultitaskingCameraAccessSupported else { return }
        session.beginConfiguration()
        session.isMultitaskingCameraAccessEnabled = true
        session.commitConfiguration()
    }

    func switchCamera() {
        guard localVideoTrack != nil else { return }
        isFrontCamera.toggle()
        videoCapturer?.stopCapture()
        startCapture()
    }
    
    // MARK: - Offer/Answer
    
    func createOffer() async throws -> RTCSessionDescription {
        let wantVideo = !audioOnly
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": wantVideo ? "true" : "false"
            ],
            optionalConstraints: nil
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            peerConnection?.offer(for: constraints) { [weak self] sdp, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sdp = sdp else {
                    continuation.resume(throwing: NSError(domain: "WebRTC", code: -1, userInfo: [NSLocalizedDescriptionKey: "No SDP"]))
                    return
                }
                self?.peerConnection?.setLocalDescription(sdp) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: sdp)
                    }
                }
            }
        }
    }
    
    func createAnswer() async throws -> RTCSessionDescription {
        let wantVideo = !audioOnly
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "true",
                "OfferToReceiveVideo": wantVideo ? "true" : "false"
            ],
            optionalConstraints: nil
        )
        
        return try await withCheckedThrowingContinuation { continuation in
            peerConnection?.answer(for: constraints) { [weak self] sdp, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sdp = sdp else {
                    continuation.resume(throwing: NSError(domain: "WebRTC", code: -1, userInfo: [NSLocalizedDescriptionKey: "No SDP"]))
                    return
                }
                self?.peerConnection?.setLocalDescription(sdp) { error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: sdp)
                    }
                }
            }
        }
    }
    
    func setRemoteDescription(_ sdp: RTCSessionDescription) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            peerConnection?.setRemoteDescription(sdp) { error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    func addICECandidate(_ candidate: RTCIceCandidate) async throws {
        try await peerConnection?.add(candidate)
    }
    
    func restartICE() {
        peerConnection?.restartIce()
    }
    
    // MARK: - Controls
    
    func setMicEnabled(_ enabled: Bool) {
        localAudioTrack?.isEnabled = enabled
    }
    
    func setVideoEnabled(_ enabled: Bool) {
        guard localVideoTrack != nil else { return }
        localVideoTrack?.isEnabled = enabled
        if !enabled {
            videoCapturer?.stopCapture()
        } else {
            startCapture()
        }
    }
    
    // MARK: - Cleanup
    
    func close() {
        videoCapturer?.stopCapture()
        peerConnection?.close()
        peerConnection = nil
        localVideoTrack = nil
        localAudioTrack = nil
        videoCapturer = nil
        localVideoSource = nil
    }
    
    // MARK: - Helpers
    
    static func sdpToDict(_ sdp: RTCSessionDescription) -> [String: Any] {
        var typeStr: String
        switch sdp.type {
        case .offer: typeStr = "offer"
        case .answer: typeStr = "answer"
        case .prAnswer: typeStr = "pranswer"
        case .rollback: typeStr = "rollback"
        @unknown default: typeStr = "offer"
        }
        return ["type": typeStr, "sdp": sdp.sdp]
    }
    
    static func dictToSDP(_ dict: [String: Any]) -> RTCSessionDescription? {
        guard let typeStr = dict["type"] as? String, let sdp = dict["sdp"] as? String else { return nil }
        let type: RTCSdpType
        switch typeStr {
        case "offer": type = .offer
        case "answer": type = .answer
        case "pranswer": type = .prAnswer
        default: type = .offer
        }
        return RTCSessionDescription(type: type, sdp: sdp)
    }
    
    static func dictToCandidate(_ dict: [String: Any]) -> RTCIceCandidate? {
        guard let sdp = dict["candidate"] as? String,
              let sdpMLineIndex = dict["sdpMLineIndex"] as? Int32 else { return nil }
        let sdpMid = dict["sdpMid"] as? String
        return RTCIceCandidate(sdp: sdp, sdpMLineIndex: sdpMLineIndex, sdpMid: sdpMid)
    }
    
    static func candidateToDict(_ candidate: RTCIceCandidate) -> [String: Any] {
        var dict: [String: Any] = [
            "candidate": candidate.sdp,
            "sdpMLineIndex": candidate.sdpMLineIndex,
        ]
        if let mid = candidate.sdpMid { dict["sdpMid"] = mid }
        return dict
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WebRTCService: RTCPeerConnectionDelegate {
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange stateChanged: RTCSignalingState) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {
        if let videoTrack = stream.videoTracks.first {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.delegate?.webRTCService(self, didReceiveRemoteVideoTrack: videoTrack)
            }
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceConnectionState) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.webRTCService(self, didChangeConnectionState: newState)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didChange newState: RTCIceGatheringState) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.webRTCService(self, didGenerateICECandidate: candidate)
        }
    }
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
    
    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {}
}
