import Foundation
#if canImport(SceneKit)
import SceneKit
#endif

open class VRMLoader {
    public init() {}

    open func load(named: String) throws -> VRM {
        guard let url = Bundle.main.url(forResource: named, withExtension: nil) else {
            throw URLError(.fileDoesNotExist)
        }
        return try load(withURL: url)
    }

    open func load(withURL url: URL) throws -> VRM {
        let data = try Data(contentsOf: url)
        return try load(withData: data)
    }

    open func load(withData data: Data) throws -> VRM {
        return try VRM(data: data)
    }

    open func load<T: VRMFile>(_ type: T.Type = T.self, named: String) throws -> T {
        guard let url = Bundle.main.url(forResource: named, withExtension: nil) else {
            throw URLError(.fileDoesNotExist)
        }
        return try load(type, withURL: url)
    }

    open func load<T: VRMFile>(_ type: T.Type = T.self, withURL url: URL) throws -> T {
        let data = try Data(contentsOf: url)
        return try load(type, withData: data)
    }

    open func load<T: VRMFile>(_ type: T.Type = T.self, withData data: Data) throws -> T {
        return try T(data: data)
    }

    open func loadThumbnail(from vrm: VRM) throws -> VRMImage {
        let textureIndex = try vrm.meta.texture ??? .keyNotFound("texture")
        return try loadImage(from: vrm.gltf, at: textureIndex)
    }

    open func loadThumbnail(from vrm1: VRM1) throws -> VRMImage {
        let imageIndex = try vrm1.meta.thumbnailImage ??? .keyNotFound("thumbnailImage")
        return try loadImage(from: vrm1.gltf, at: imageIndex)
    }

    private func loadImage(from gltf: BinaryGLTF, at index: Int, relativeTo rootDirectory: URL? = nil) throws -> VRMImage {
        let gltfImage = try gltf.jsonData.load(\.images)[index]
        let imageData: Data
        if let uri = gltfImage.uri {
            imageData = try Data(gltfUrlString: uri, relativeTo: rootDirectory)
        } else if let bufferViewIndex = gltfImage.bufferView {
            imageData = try gltf.bufferViewData(at: bufferViewIndex).data
        } else {
            throw VRMError._dataInconsistent("Image has neither uri nor bufferView")
        }
        return try VRMImage(data: imageData) ??? ._dataInconsistent("Failed to create image from data")
    }
}
