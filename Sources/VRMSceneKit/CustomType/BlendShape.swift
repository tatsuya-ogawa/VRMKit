import SceneKit

@available(*, deprecated, message: "Deprecated. Use VRMRealityKit instead.")
struct BlendShapeClip {
    let name: String
    let preset: BlendShapePreset
    let values: [BlendShapeBinding]
    //        let materialValues: [MaterialValueBinding] // TODO:
    let isBinary: Bool
    var key: BlendShapeKey {
        return preset == .unknown ? .custom(name) : .preset(preset)
    }
}

@available(*, deprecated, message: "Deprecated. Use VRMRealityKit instead.")
struct BlendShapeBinding {
    let mesh: SCNNode
    let index: Int
    let weight: Double
}

@available(*, deprecated, message: "Deprecated. Use VRMRealityKit instead.")
struct MaterialValueBinding {
    let materialName: String
    let valueName: String
    let targetValue: SCNVector4
    let baseValue: SCNVector4
}

@available(*, deprecated, message: "Deprecated. Use VRMRealityKit instead.")
public enum BlendShapeKey: Hashable {
    case preset(BlendShapePreset)
    case custom(String)
    var isPreset: Bool {
        switch self {
        case .preset: return true
        case .custom: return false
        }
    }
}

@available(*, deprecated, message: "Deprecated. Use VRMRealityKit instead.")
public enum BlendShapePreset: String {
    case unknown
    case neutral
    case a
    case i
    case u
    case e
    case o
    case blink
    case joy
    case angry
    case sorrow
    case fun
    case lookUp = "lookup"
    case lookDown = "lookdown"
    case lookLeft = "lookleft"
    case lookRight = "lookright"
    case blinkL = "blink_l"
    case blinkR = "blink_r"

    init(name: String) {
        self = BlendShapePreset(rawValue: name.lowercased()) ?? .unknown
    }
}
