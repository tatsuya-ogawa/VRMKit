import SceneKit
import VRMKit

@available(*, deprecated, message: "Deprecated. Use VRMRealityKit instead.")
open class VRMNode: SCNNode {
    public let vrm: VRM
    public let humanoid = Humanoid()
    private let timer = Timer()
    private var springBones: [VRMSpringBone] = []

    var blendShapeClips: [BlendShapeKey: BlendShapeClip] = [:]
    private var materialsByName: [String: [SCNMaterial]] = [:]
    private var materialBaseValues: [MaterialValueKey: SCNVector4] = [:]

    private struct MaterialValueKey: Hashable {
        let materialID: ObjectIdentifier
        let valueName: String
    }

    public init(vrm: VRM) {
        self.vrm = vrm
        super.init()
    }

    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func setUpHumanoid(nodes: [SCNNode?]) {
        humanoid.setUp(humanoid: vrm.humanoid, nodes: nodes)
    }

    func setUpBlendShapes(meshes: [SCNNode?]) {
        materialsByName = collectMaterialsByName(from: meshes)
        blendShapeClips = vrm.blendShapeMaster.blendShapeGroups
            .map { group in
                let blendShapeBinding: [BlendShapeBinding] = group.binds?
                    .compactMap {
                        guard let mesh = meshes[$0.mesh] else {
                            return nil
                        }
                        return BlendShapeBinding(mesh: mesh, index: $0.index, weight: $0.weight)
                    } ?? []
                let materialValues: [MaterialValueBinding] = group.materialValues?.map {
                    let target = SCNVector4(
                        SCNFloat($0.targetValue[safe: 0] ?? 0),
                        SCNFloat($0.targetValue[safe: 1] ?? 0),
                        SCNFloat($0.targetValue[safe: 2] ?? 0),
                        SCNFloat($0.targetValue[safe: 3] ?? 0)
                    )
                    return MaterialValueBinding(materialName: $0.materialName,
                                                valueName: $0.propertyName,
                                                targetValue: target)
                } ?? []
                return BlendShapeClip(name: group.name,
                                      preset: BlendShapePreset(name: group.presetName),
                                      values: blendShapeBinding,
                                      materialValues: materialValues,
                                      isBinary: group.isBinary)
            }
            .reduce(into: [:]) { result, clip in
                result[clip.key] = clip
        }
    }
    
    func setUpSpringBones(loader: VRMSceneLoader) throws {
        var springBones: [VRMSpringBone] = []
        let secondaryAnimation = vrm.secondaryAnimation
        for boneGroup in secondaryAnimation.boneGroups {
            guard !boneGroup.bones.isEmpty else { return }
            let rootBones: [SCNNode] = try boneGroup.bones.compactMap({ try loader.node(withNodeIndex: $0) }).compactMap({ $0 })
            let centerNode = try? loader.node(withNodeIndex: boneGroup.center)
            let colliderGroups = try secondaryAnimation.colliderGroups.map({ try VRMSpringBoneColliderGroup(colliderGroup: $0, loader: loader) })
            let springBone = VRMSpringBone(center: centerNode,
                                           rootBones: rootBones,
                                           comment: boneGroup.comment,
                                           stiffnessForce: Float(boneGroup.stiffiness),
                                           gravityPower: Float(boneGroup.gravityPower),
                                           gravityDir: boneGroup.gravityDir.simd,
                                           dragForce: Float(boneGroup.dragForce),
                                           hitRadius: Float(boneGroup.hitRadius),
                                           colliderGroups: colliderGroups)
            springBones.append(springBone)
        }
        self.springBones = springBones
    }

    /// Set blend shapes to avatar
    ///
    /// - Parameters:
    ///   - value: a weight of the blend shape (0.0 <= value <= 1.0)
    ///   - key: a key of the blend shape
    public func setBlendShape(value: CGFloat, for key: BlendShapeKey) {
        guard let clip = blendShapeClips[key] else { return }
        let value: CGFloat = clip.isBinary ? round(value) : value
        for binding in clip.values {
            let weight = CGFloat(binding.weight / 100.0)
            for primitive in binding.mesh.childNodes {
                guard let morpher = primitive.morpher else { continue }
                morpher.setWeight(weight * value, forTargetAt: binding.index)
            }
        }
        applyMaterialValues(clip.materialValues, weight: value)
    }

    /// Get a weight of the blend shape
    ///
    /// - Parameter key: a key of the blend shape
    /// - Returns: a weight of the blend shape
    public func blendShape(for key: BlendShapeKey) -> CGFloat {
        guard let clip = blendShapeClips[key],
            let binding = clip.values.first,
            let morpher = binding.mesh.childNodes.lazy.compactMap({ $0.morpher }).first else { return 0 }
        return morpher.weight(forTargetAt: binding.index)
    }

    private func collectMaterialsByName(from meshes: [SCNNode?]) -> [String: [SCNMaterial]] {
        var result: [String: [SCNMaterial]] = [:]
        for mesh in meshes {
            guard let mesh else { continue }
            var stack: [SCNNode] = [mesh]
            while let node = stack.popLast() {
                if let geometry = node.geometry {
                    for material in geometry.materials {
                        guard let name = material.name, !name.isEmpty else { continue }
                        result[name, default: []].append(material)
                    }
                }
                stack.append(contentsOf: node.childNodes)
            }
        }
        return result
    }

    private func applyMaterialValues(_ materialValues: [MaterialValueBinding], weight: CGFloat) {
        for binding in materialValues {
            guard let materials = materialsByName[binding.materialName] else { continue }
            for material in materials {
                applyMaterialValue(binding, to: material, weight: weight)
            }
        }
    }

    private func applyMaterialValue(_ binding: MaterialValueBinding,
                                    to material: SCNMaterial,
                                    weight: CGFloat) {
        let valueName = binding.valueName
        let lowerName = valueName.lowercased()
        if isTextureTransformValueName(lowerName) {
            let base = baseTextureTransform(for: material, valueName: valueName)
            let blended = blend(base: base, target: binding.targetValue, weight: weight)
            let finalValue = applyPartialTransformIfNeeded(name: lowerName, base: base, blended: blended)
            var transform = SCNMatrix4MakeScale(finalValue.x, finalValue.y, 1)
            transform.m41 = finalValue.z
            transform.m42 = finalValue.w
            material.diffuse.contentsTransform = transform
            return
        }

        if let property = materialProperty(for: lowerName, on: material) {
            let base = baseColor(for: material, valueName: valueName, property: property)
            let blended = blend(base: base, target: binding.targetValue, weight: weight)
            property.contents = color(from: blended)
        }
    }

    private func isTextureTransformValueName(_ lowerName: String) -> Bool {
        return lowerName == "_maintex_st" || lowerName.hasSuffix("_st_s") || lowerName.hasSuffix("_st_t")
    }

    private func applyPartialTransformIfNeeded(name: String,
                                               base: SCNVector4,
                                               blended: SCNVector4) -> SCNVector4 {
        if name.hasSuffix("_st_s") {
            return SCNVector4(blended.x, base.y, blended.z, base.w)
        }
        if name.hasSuffix("_st_t") {
            return SCNVector4(base.x, blended.y, base.z, blended.w)
        }
        return blended
    }

    private func baseTextureTransform(for material: SCNMaterial, valueName: String) -> SCNVector4 {
        let key = MaterialValueKey(materialID: ObjectIdentifier(material), valueName: valueName)
        if let cached = materialBaseValues[key] {
            return cached
        }
        let transform = material.diffuse.contentsTransform
        let base = SCNVector4(transform.m11, transform.m22, transform.m41, transform.m42)
        materialBaseValues[key] = base
        return base
    }

    private func baseColor(for material: SCNMaterial,
                           valueName: String,
                           property: SCNMaterialProperty) -> SCNVector4 {
        let key = MaterialValueKey(materialID: ObjectIdentifier(material), valueName: valueName)
        if let cached = materialBaseValues[key] {
            return cached
        }
        let baseColor = colorVector(from: property.contents)
        materialBaseValues[key] = baseColor
        return baseColor
    }

    private func blend(base: SCNVector4, target: SCNVector4, weight: CGFloat) -> SCNVector4 {
        let w = SCNFloat(weight)
        return SCNVector4(
            base.x + (target.x - base.x) * w,
            base.y + (target.y - base.y) * w,
            base.z + (target.z - base.z) * w,
            base.w + (target.w - base.w) * w
        )
    }

    private func materialProperty(for lowerName: String, on material: SCNMaterial) -> SCNMaterialProperty? {
        if lowerName == "color" || lowerName == "_color" {
            return material.diffuse
        }
        if lowerName == "emissioncolor" || lowerName == "_emissioncolor" {
            return material.emission
        }
        return nil
    }

    private func colorVector(from contents: Any?) -> SCNVector4 {
        switch contents {
        case let color as VRMColor:
            return color.toVector4()
        case let cgColor as CGColor:
            #if os(macOS)
            if let color = VRMColor(cgColor: cgColor) {
                return color.toVector4()
            }
            #else
            return VRMColor(cgColor: cgColor).toVector4()
            #endif
        default:
            return SCNVector4(1, 1, 1, 1)
        }
    }

    private func color(from vector: SCNVector4) -> VRMColor {
        return VRMColor(red: CGFloat(vector.x),
                        green: CGFloat(vector.y),
                        blue: CGFloat(vector.z),
                        alpha: CGFloat(vector.w))
    }
}

@available(*, deprecated, message: "Deprecated. Use VRMRealityKit instead.")
extension VRMNode: RenderUpdatable {
    public func update(at time: TimeInterval) {
        let seconds = timer.deltaTime(updateAtTime: time)
        springBones.forEach({ $0.update(deltaTime: seconds) })
    }
}

private extension VRMColor {
    func toVector4() -> SCNVector4 {
        #if os(macOS)
        let rgb = usingColorSpace(.deviceRGB) ?? self
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        rgb.getRed(&r, green: &g, blue: &b, alpha: &a)
        #else
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return SCNVector4(r, g, b, a)
    }
}
