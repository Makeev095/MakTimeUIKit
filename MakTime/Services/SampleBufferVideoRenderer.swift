import AVFoundation
import CoreImage
import CoreMedia
import WebRTC

/// Рендерер WebRTC-кадров в AVSampleBufferDisplayLayer для PiP.
/// Apple требует AVSampleBufferDisplayLayer — RTCMTLVideoView/GLKView не поддерживаются в PiP.
/// Учитывает `RTCVideoRotation`: без этого в PiP картинка часто «лежит» на 90° относительно полноэкранного `RTCMTLVideoView`.
final class SampleBufferVideoRenderer: NSObject, RTCVideoRenderer {
    private weak var displayLayer: AVSampleBufferDisplayLayer?
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])

    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        super.init()
    }

    func setSize(_ size: CGSize) {}

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame, let layer = displayLayer else { return }
        guard let sampleBuffer = createSampleBuffer(from: frame) else { return }

        DispatchQueue.main.async {
            layer.enqueue(sampleBuffer)
        }
    }

    /// Соответствие поворота кадра WebRTC ориентации CIImage (как у Metal-рендерера в SDK).
    private func cgOrientation(for rotation: RTCVideoRotation) -> CGImagePropertyOrientation {
        switch rotation.rawValue {
        case 90: return .right
        case 180: return .down
        case 270: return .left
        default: return .up
        }
    }

    /// Возвращает буфер для кодека: при rotation = 0 — исходный; иначе — повёрнутый BGRA для стабильного показа в display layer.
    private func pixelBufferForDisplay(from input: CVPixelBuffer, rotation: RTCVideoRotation) -> CVPixelBuffer? {
        if rotation.rawValue == 0 { return input }

        var oriented = CIImage(cvPixelBuffer: input).oriented(cgOrientation(for: rotation))
        oriented = oriented.transformed(by: CGAffineTransform(
            translationX: -oriented.extent.origin.x,
            y: -oriented.extent.origin.y
        ))

        let width = max(1, Int(oriented.extent.width.rounded()))
        let height = max(1, Int(oriented.extent.height.rounded()))

        var output: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferPixelFormatTypeKey: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as [String: Any]
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attrs as CFDictionary, &output)
        guard status == kCVReturnSuccess, let out = output else { return nil }

        ciContext.render(oriented, to: out)
        return out
    }

    private func createSampleBuffer(from frame: RTCVideoFrame) -> CMSampleBuffer? {
        guard let cvBuffer = frame.buffer as? RTCCVPixelBuffer else { return nil }
        let inputPB = cvBuffer.pixelBuffer
        guard let pixelBuffer = pixelBufferForDisplay(from: inputPB, rotation: frame.rotation) else { return nil }

        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )
        guard let format = formatDescription else { return nil }

        let scale = CMTimeScale(NSEC_PER_SEC)
        let pts = CMTime(
            value: CMTimeValue(Double(frame.timeStampNs) / Double(NSEC_PER_SEC) * Double(scale)),
            timescale: scale
        )
        var timing = CMSampleTimingInfo(
            duration: CMTime.invalid,
            presentationTimeStamp: pts,
            decodeTimeStamp: CMTime.invalid
        )

        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: format,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let buffer = sampleBuffer else { return nil }

        if let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: true) as NSArray?,
           let dict = attachments.firstObject as? NSMutableDictionary {
            dict[kCMSampleAttachmentKey_DisplayImmediately] = true
        }
        return buffer
    }
}
