//
//  UIImage+GLTF.swift
//  VRMRealityKit
//
//  Created by Tatsuya Tanaka on 20180911.
//

#if canImport(RealityKit)
import VRMKit
import UIKit

@available(iOS 18.0, *)
extension UIImage {
    convenience init(image: GLTF.Image, relativeTo rootDirectory: URL?, loader: VRMRealityKitSceneLoader) throws {
        let data: Data
        if let uri = image.uri {
            data = try Data(gltfUrlString: uri, relativeTo: rootDirectory)
        } else if let bufferViewIndex = image.bufferView {
            data = try loader.bufferView(withBufferViewIndex: bufferViewIndex).bufferView
        } else {
            throw NSError(domain: "VRMRealityKit.UIImage+GLTF", code: 1, userInfo: [NSLocalizedDescriptionKey: "failed to load images"])
        }
        guard let uiImage = UIImage(data: data), let cgImage = uiImage.cgImage else {
            throw NSError(domain: "VRMRealityKit.UIImage+GLTF", code: 2, userInfo: [NSLocalizedDescriptionKey: "failed to load image"])
        }
        self.init(cgImage: cgImage)
    }
}
#endif
