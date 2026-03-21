import Foundation
import AVFoundation
import PhotosUI
import SwiftUI

class MediaService: NSObject, ObservableObject {
    // MARK: - Published
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var isRecordingVideo = false
    @Published var videoDuration: TimeInterval = 0

    // MARK: - Audio recording
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var recordingURL: URL?

    func startVoiceRecording() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
        try session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice_\(UUID().uuidString).m4a")
        recordingURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        isRecording = true
        recordingDuration = 0

        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
    }

    func stopVoiceRecording() -> (url: URL, duration: TimeInterval)? {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        isRecording = false
        guard let url = recordingURL else { return nil }
        let duration = recordingDuration
        recordingDuration = 0
        return (url: url, duration: duration)
    }

    func cancelVoiceRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil
        audioRecorder?.stop()
        audioRecorder?.deleteRecording()
        isRecording = false
        recordingDuration = 0
    }

    // MARK: - Video Note recording (AVCaptureSession)
    private(set) var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var videoNoteURL: URL?
    private var videoTimer: Timer?
    var onVideoNoteReady: ((URL, TimeInterval) -> Void)?

    @discardableResult
    func setupCaptureSession() -> AVCaptureSession? {
        let session = AVCaptureSession()
        session.sessionPreset = .hd1280x720

        // Front camera
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let cameraInput = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(cameraInput) else {
            print("MediaService: Camera not available")
            return nil
        }
        session.addInput(cameraInput)

        // Microphone
        if let mic = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: mic),
           session.canAddInput(micInput) {
            session.addInput(micInput)
        }

        // File output
        let output = AVCaptureMovieFileOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        self.videoOutput = output
        self.captureSession = session
        return session
    }

    func startVideoNoteRecording() {
        guard let output = videoOutput else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("vnote_\(UUID().uuidString).mp4")
        videoNoteURL = url
        isRecordingVideo = true
        videoDuration = 0

        output.startRecording(to: url, recordingDelegate: self)

        videoTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.videoDuration += 0.1
            if self.videoDuration >= 60 {
                self.stopVideoNoteRecording()
            }
        }
    }

    func stopVideoNoteRecording() {
        videoTimer?.invalidate()
        videoTimer = nil
        videoOutput?.stopRecording()
        isRecordingVideo = false
    }

    func teardownCaptureSession() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
    }

    // MARK: - Permissions
    static func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    static func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .authorized { return true }
        return await AVCaptureDevice.requestAccess(for: .video)
    }

    // MARK: - Upload
    static func uploadData(_ data: Data, filename: String, mimeType: String) async throws -> String {
        let response = try await APIService.shared.uploadFile(data: data, filename: filename, mimeType: mimeType)
        return response.fileUrl
    }

    static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "png":         return "image/png"
        case "gif":         return "image/gif"
        case "mp4", "mov":  return "video/mp4"
        case "m4a", "aac":  return "audio/m4a"
        case "mp3":         return "audio/mpeg"
        case "pdf":         return "application/pdf"
        default:            return "application/octet-stream"
        }
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate
extension MediaService: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        guard error == nil else { return }
        let duration = videoDuration
        DispatchQueue.main.async { [weak self] in
            self?.onVideoNoteReady?(outputFileURL, duration)
        }
    }
}
