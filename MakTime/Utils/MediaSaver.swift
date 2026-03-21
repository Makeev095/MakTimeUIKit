import UIKit
import Photos

enum MediaSaver {
    static func save(urlString: String, isVideo: Bool) {
        guard let url = URL(string: urlString) else { return }

        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                print("MediaSaver: photo library access denied")
                return
            }

            let task = URLSession.shared.dataTask(with: url) { data, response, error in
                guard let data = data, error == nil else {
                    print("MediaSaver: download failed – \(error?.localizedDescription ?? "unknown")")
                    return
                }

                if isVideo {
                    saveVideoData(data, fileExtension: url.pathExtension.isEmpty ? "mp4" : url.pathExtension)
                } else {
                    saveImageData(data)
                }
            }
            task.resume()
        }
    }

    private static func saveImageData(_ data: Data) {
        guard let image = UIImage(data: data) else { return }
        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAsset(from: image)
        } completionHandler: { ok, error in
            DispatchQueue.main.async {
                if ok {
                    print("MediaSaver: image saved")
                } else {
                    print("MediaSaver: save image error – \(error?.localizedDescription ?? "")")
                }
            }
        }
    }

    private static func saveVideoData(_ data: Data, fileExtension: String) {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("save_\(UUID().uuidString).\(fileExtension)")
        do {
            try data.write(to: tempURL)
        } catch {
            print("MediaSaver: write temp failed – \(error)")
            return
        }

        PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: tempURL)
        } completionHandler: { ok, error in
            try? FileManager.default.removeItem(at: tempURL)
            DispatchQueue.main.async {
                if ok {
                    print("MediaSaver: video saved")
                } else {
                    print("MediaSaver: save video error – \(error?.localizedDescription ?? "")")
                }
            }
        }
    }
}
