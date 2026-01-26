import Foundation
import VRMKit
import SceneKit

@available(*, deprecated, message: "Deprecated. Use VRMRealityKit instead.")
open class VRM1SceneLoader {
    let vrm1: VRM1
    private let gltf: GLTF
    private let sceneData: SceneData
    private var rootDirectory: URL? = nil
    
    public init(vrm1: VRM1, rootDirectory: URL? = nil) {
        self.vrm1 = vrm1
        self.gltf = vrm1.gltf.jsonData
        self.rootDirectory = rootDirectory
        self.sceneData = SceneData(vrm: gltf)
    }
    
    public func loadThumbnail() throws -> VRMImage? {
        guard let imageIndex = vrm1.meta.thumbnailImage else {
            return nil
        }
        
        if let cache = try sceneData.load(\.images, index: imageIndex) {
            return cache
        }
        
        return try image(withImageIndex: imageIndex)
    }
    
    func image(withImageIndex index: Int) throws -> VRMImage {
        if let cache = try sceneData.load(\.images, index: index) {
            return cache
        }
        
        guard let gltfImages = gltf.images else {
            throw VRMError.keyNotFound("images")
        }
        
        guard index >= 0 && index < gltfImages.count,
              let gltfImage = gltfImages[safe: index] else {
            throw VRMError.dataInconsistent("Image index \(index) is out of bounds for \(gltfImages.count) images.")
        }
        
        let image = try VRMImage.from(gltfImage, relativeTo: rootDirectory, loader: self)
        sceneData.images[index] = image
        return image
    }

    func bufferView(withBufferViewIndex index: Int) throws -> (bufferView: Data, stride: Int?) {
        if let cache = try sceneData.load(\.bufferViews, index: index) {
            let gltfBufferView = try gltf.load(\.bufferViews)[index]
            return (cache, gltfBufferView.byteStride)
        }
        let result = try vrm1.gltf.bufferViewData(at: index, relativeTo: rootDirectory)
        sceneData.bufferViews[index] = result.data
        return (result.data, result.stride)
    }
}

@available(*, deprecated, message: "Deprecated. Use VRMRealityKit instead.")
extension VRM1SceneLoader {
    public convenience init(withURL url: URL, rootDirectory: URL? = nil) throws {
        let vrm1 = try VRMLoader().load(VRM1.self, withURL: url)
        self.init(vrm1: vrm1, rootDirectory: rootDirectory)
    }
    
    public convenience init(named: String, rootDirectory: URL? = nil) throws {
        let vrm1 = try VRMLoader().load(VRM1.self, named: named)
        self.init(vrm1: vrm1, rootDirectory: rootDirectory)
    }
    
    public convenience init(withData data: Data, rootDirectory: URL? = nil) throws {
        let vrm1 = try VRMLoader().load(VRM1.self, withData: data)
        self.init(vrm1: vrm1, rootDirectory: rootDirectory)
    }
}
