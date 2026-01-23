import Foundation

public extension VRM.MaterialProperty {
    var vrmShader: Shader? {
        return Shader(rawValue: shader)
    }

    enum Shader: String {
        case mToon = "VRM/MToon"
        case unlitTransparent = "VRM/UnlitTransparent"
    }
}
