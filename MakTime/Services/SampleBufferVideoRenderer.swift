import AVFoundation
import CoreMedia
import WebRTC

/// Рендерер WebRTC-кадров в AVSampleBufferDisplayLayer для PiP.
/// Apple требует AVSampleBufferDisplayLayer — RTCMTLVideoView/GLKView не поддерживаются в PiP.
final class SampleBufferVideoRenderer: NSObject, RTCVideoRenderer {
    private weak var displayLayer: AVSampleBufferDisplayLayer?

    init(displayLayer: AVSampleBufferDisplayLayer) {
        self.displayLayer = displayLayer
        super.init()
    }

    func setSize(_ size: CGSize) {}

    func renderFrame(_ frame: RTCVideoFrame?) {
        guard let frame = frame, let layer = displayLayer else { return }
        guard let sampleBuffer = createSampleBuffer(from: frame) else { return }

        DispatchQueue.main.async {
            layer.enqueue(sampleBuffer)
        }
    }

    private func createSampleBuffer(from frame: RTCVideoFrame) -> CMSampleBuffer? {
        guard let cvBuffer = frame.buffer as? RTCCVPixelBuffer else { return nil }
        let pixelBuffer = cvBuffer.pixelBuffer

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
