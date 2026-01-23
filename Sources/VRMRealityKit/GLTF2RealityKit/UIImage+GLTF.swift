#if canImport(RealityKit)
import VRMKit
import UIKit

@available(iOS 18.0, visionOS 2.0, *)
extension UIImage {
    @MainActor
    convenience init(image: GLTF.Image, relativeTo rootDirectory: URL?, loader: VRMEntityLoader) throws {
        let data: Data
        if let uri = image.uri {
            data = try Data(gltfUrlString: uri, relativeTo: rootDirectory)
        } else if let bufferViewIndex = image.bufferView {
            data = try loader.bufferView(withBufferViewIndex: bufferViewIndex).bufferView
        } else {
            throw VRMError._dataInconsistent("failed to load image: both uri and bufferView are nil")
        }
        guard let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage else {
            throw VRMError._dataInconsistent("failed to create UIImage from data")
        }
        self.init(cgImage: cgImage)
    }
}
#endif
