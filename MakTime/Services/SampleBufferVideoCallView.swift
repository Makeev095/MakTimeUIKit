import AVFoundation
import UIKit

/// View с AVSampleBufferDisplayLayer для PiP.
/// Apple требует именно этот слой — RTCMTLVideoView/GLKView не поддерживаются в PiP.
final class SampleBufferVideoCallView: UIView {
    override class var layerClass: AnyClass { AVSampleBufferDisplayLayer.self }

    var sampleBufferDisplayLayer: AVSampleBufferDisplayLayer {
        layer as! AVSampleBufferDisplayLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        sampleBufferDisplayLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
