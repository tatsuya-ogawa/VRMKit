//
//  BlendShape.swift
//  VRMRealityKit
//
//  Created by Tatsuya Ogawa on 2026/01/22.
//

#if canImport(RealityKit)
import RealityKit

struct BlendShapeClip {
    let name: String
    let preset: BlendShapePreset
    let values: [BlendShapeBinding]
    let isBinary: Bool
    var key: BlendShapeKey {
        return preset == .unknown ? .custom(name) : .preset(preset)
    }
}

struct BlendShapeBinding {
    let mesh: Entity
    let index: Int
    let weight: Double
}

struct MaterialValueBinding {
    let materialName: String
    let valueName: String
    let targetValue: SIMD4<Float>
    let baseValue: SIMD4<Float>
}

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
#endif
