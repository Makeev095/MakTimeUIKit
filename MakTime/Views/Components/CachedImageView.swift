import UIKit
import Kingfisher

final class CachedImageView: UIImageView {
    
    func load(url: URL?) {
        kf.cancelDownloadTask()
        guard let url = url else {
            image = nil
            return
        }
        kf.setImage(
            with: url,
            placeholder: nil,
            options: [
                .transition(.fade(0.2)),
                .cacheOriginalImage,
                .scaleFactor(UIScreen.main.scale)
            ]
        )
    }
}
