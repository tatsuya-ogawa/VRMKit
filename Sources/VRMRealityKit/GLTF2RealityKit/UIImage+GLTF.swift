#if canImport(RealityKit)
import Foundation
import VRMKit

@available(iOS 18.0, macOS 15.0, visionOS 2.0, *)
extension VRMImage {
    @MainActor
    static func from(_ image: GLTF.Image, relativeTo rootDirectory: URL?, loader: VRMEntityLoader) throws -> VRMImage {
        let data: Data
        if let uri = image.uri {
            data = try Data(gltfUrlString: uri, relativeTo: rootDirectory)
        } else if let bufferViewIndex = image.bufferView {
            data = try loader.bufferView(withBufferViewIndex: bufferViewIndex).bufferView
        } else {
            throw VRMError._dataInconsistent("failed to load image: both uri and bufferView are nil")
        }
        guard let image = VRMImage(data: data) else {
            throw VRMError._dataInconsistent("failed to create image from data")
        }

        return image
    }
}
#endif
