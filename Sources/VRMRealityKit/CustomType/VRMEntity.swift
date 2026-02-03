#if canImport(RealityKit)
import CoreGraphics
import Foundation
import RealityKit
import VRMKit

@available(iOS 18.0, macOS 15.0, visionOS 2.0, *)
struct BlendShapeNormalTangentComponent: Component {
    let baseNormals: [SIMD3<Float>]
    let baseTangents: [SIMD3<Float>]
    let normalOffsets: [[SIMD3<Float>]]
    let tangentOffsets: [[SIMD3<Float>]]
}

@available(iOS 18.0, macOS 15.0, visionOS 2.0, *)
struct MaterialNameComponent: Component {
    let materialNames: [String]
}

@available(iOS 18.0, macOS 15.0, visionOS 2.0, *)
@MainActor
public final class VRMEntity {
    public let vrm: VRM
    public let entity: Entity
    public let humanoid = Humanoid()

    private let enableNormalTangentBlendShape = false

    var blendShapeClips: [BlendShapeKey: BlendShapeClip] = [:]
    private var materialBaseValues: [MaterialValueKey: SIMD4<Float>] = [:]
    private var skinBindings: [SkinBinding] = []
    private var springBones: [VRMEntitySpringBone] = []

    private struct MaterialValueKey: Hashable {
        let entityID: ObjectIdentifier
        let materialIndex: Int
        let valueName: String
    }

    struct SkinBinding {
        let modelEntity: ModelEntity
        let skeleton: MeshResource.Skeleton
        let jointEntities: [Entity]
    }

    init(vrm: VRM) {
        self.vrm = vrm
        self.entity = Entity()
    }

    func setUpHumanoid(nodes: [Entity?]) {
        humanoid.setUp(humanoid: vrm.humanoid, nodes: nodes)
    }

    func setUpBlendShapes(meshes: [Entity?]) {
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
                    let values = $0.targetValue
                    let target = SIMD4<Float>(
                        Float(values[safe: 0] ?? 0),
                        Float(values[safe: 1] ?? 0),
                        Float(values[safe: 2] ?? 0),
                        Float(values[safe: 3] ?? 0)
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

    func setUpSpringBones(loader: VRMEntityLoader) throws {
        var springBones: [VRMEntitySpringBone] = []
        let secondaryAnimation = vrm.secondaryAnimation
        for boneGroup in secondaryAnimation.boneGroups {
            guard !boneGroup.bones.isEmpty else { continue }
            let rootBones: [Entity] = try boneGroup.bones.compactMap { try loader.node(withNodeIndex: $0) }
            let centerNode = try? loader.node(withNodeIndex: boneGroup.center)
            let colliderGroups = try secondaryAnimation.colliderGroups.map {
                try VRMEntitySpringBoneColliderGroup(colliderGroup: $0, loader: loader)
            }
            let springBone = VRMEntitySpringBone(center: centerNode,
                                                     rootBones: rootBones,
                                                     comment: boneGroup.comment,
                                                     stiffnessForce: Float(boneGroup.stiffiness),
                                                     gravityPower: Float(boneGroup.gravityPower),
                                                     gravityDir: SIMD3<Float>(Float(boneGroup.gravityDir.x), Float(boneGroup.gravityDir.y), Float(boneGroup.gravityDir.z)),
                                                     dragForce: Float(boneGroup.dragForce),
                                                     hitRadius: Float(boneGroup.hitRadius),
                                                     colliderGroups: colliderGroups)
            springBones.append(springBone)
        }
        self.springBones = springBones
    }

    func registerSkinBinding(modelEntity: ModelEntity,
                             skeleton: MeshResource.Skeleton,
                             jointEntities: [Entity]) {
        let binding = SkinBinding(modelEntity: modelEntity,
                                  skeleton: skeleton,
                                  jointEntities: jointEntities)
        skinBindings.append(binding)
        initializeSkinPose(for: binding)
    }

    public func update(at time: TimeInterval) {
        updateSkinning()
        springBones.forEach { $0.update(deltaTime: time) }
    }

    private func updateSkinning() {
        for binding in skinBindings {
            updateSkinPose(for: binding)
        }
    }

    private func initializeSkinPose(for binding: SkinBinding) {
        let transforms = jointTransforms(for: binding)
        var pose = SkeletalPose(id: binding.skeleton.id, from: binding.skeleton)
        pose.jointTransforms = transforms

        var component = binding.modelEntity.components[SkeletalPosesComponent.self] ?? SkeletalPosesComponent(poses: [pose])
        component.poses[pose.id] = pose
        component.poses.default = pose
        binding.modelEntity.components.set(component)
    }

    private func updateSkinPose(for binding: SkinBinding) {
        let transforms = jointTransforms(for: binding)
        guard var component = binding.modelEntity.components[SkeletalPosesComponent.self] else {
            initializeSkinPose(for: binding)
            return
        }

        if var pose = component.poses[binding.skeleton.id] ?? component.poses.default {
            pose.jointTransforms = transforms
            component.poses[pose.id] = pose
            component.poses.default = pose
        } else {
            var pose = SkeletalPose(id: binding.skeleton.id, from: binding.skeleton)
            pose.jointTransforms = transforms
            component.poses[pose.id] = pose
            component.poses.default = pose
        }

        binding.modelEntity.components.set(component)
    }

    private func jointTransforms(for binding: SkinBinding) -> JointTransforms {
        let jointEntities = binding.jointEntities
        let joints = binding.skeleton.joints
        var transforms: [Transform] = []
        transforms.reserveCapacity(jointEntities.count)

        let modelWorld = binding.modelEntity.transformMatrix(relativeTo: nil)
        let modelWorldInverse = simd_inverse(modelWorld)

        for index in 0..<jointEntities.count {
            let jointEntity = jointEntities[index]
            let jointWorld = jointEntity.transformMatrix(relativeTo: nil)
            let localMatrix: simd_float4x4
            if index < joints.count, let parentIndex = joints[index].parentIndex, parentIndex < jointEntities.count {
                let parentWorld = jointEntities[parentIndex].transformMatrix(relativeTo: nil)
                localMatrix = simd_mul(simd_inverse(parentWorld), jointWorld)
            } else {
                localMatrix = simd_mul(modelWorldInverse, jointWorld)
            }
            transforms.append(Transform(matrix: localMatrix))
        }

        return JointTransforms(transforms)
    }

    public func setBlendShape(value: CGFloat, for key: BlendShapeKey) {
        guard let clip = blendShapeClips[key] else { return }
        let normalized = max(0.0, min(1.0, clip.isBinary ? round(value) : value))
        for binding in clip.values {
            let weight = Float(binding.weight / 100.0) * Float(normalized)
            applyBlendShapeWeight(weight, targetIndex: binding.index, on: binding.mesh)
        }
        applyMaterialValues(clip.materialValues, weight: Float(normalized))
        if enableNormalTangentBlendShape {
            var meshesToUpdate: [Entity] = []
            var seenMeshes = Set<ObjectIdentifier>()
            for binding in clip.values {
                let meshID = ObjectIdentifier(binding.mesh)
                if seenMeshes.insert(meshID).inserted {
                    meshesToUpdate.append(binding.mesh)
                }
            }
            for mesh in meshesToUpdate {
                updateBlendShapeNormalsAndTangents(on: mesh)
            }
        }
    }

    public func blendShape(for key: BlendShapeKey) -> CGFloat {
        guard let clip = blendShapeClips[key],
              let binding = clip.values.first else { return 0 }
        return CGFloat(readBlendShapeWeight(targetIndex: binding.index, on: binding.mesh))
    }

    private func modelEntities(in root: Entity) -> [ModelEntity] {
        var result: [ModelEntity] = []
        var stack: [Entity] = [root]
        while let entity = stack.popLast() {
            if let modelEntity = entity as? ModelEntity {
                result.append(modelEntity)
            }
            stack.append(contentsOf: entity.children)
        }
        return result
    }

    private func applyBlendShapeWeight(_ weight: Float, targetIndex: Int, on mesh: Entity) {
        let targetName = "blendShape_\(targetIndex)"
        let models = modelEntities(in: mesh)
        for modelEntity in models {
            ensureBlendShapeComponent(on: modelEntity)
            var weights = modelEntity.blendWeights
            let names = modelEntity.blendWeightNames
            guard !weights.isEmpty else { continue }
            var didSet = false
            if !names.isEmpty {
                for setIndex in names.indices {
                    if let nameIndex = names[setIndex].firstIndex(of: targetName),
                       nameIndex < weights[setIndex].count {
                        weights[setIndex][nameIndex] = weight
                        didSet = true
                    }
                }
            }
            if !didSet {
                for setIndex in weights.indices {
                    guard targetIndex < weights[setIndex].count else { continue }
                    weights[setIndex][targetIndex] = weight
                }
            }
            modelEntity.blendWeights = weights
        }
    }

    private func updateBlendShapeNormalsAndTangents(on mesh: Entity) {
        for modelEntity in modelEntities(in: mesh) {
            applyNormalTangentMorphs(on: modelEntity)
        }
    }

    private func applyNormalTangentMorphs(on modelEntity: ModelEntity) {
        guard let component = modelEntity.components[BlendShapeNormalTangentComponent.self] else { return }
        let hasNormalOffsets = !component.normalOffsets.isEmpty
        let hasTangentOffsets = !component.tangentOffsets.isEmpty
        guard hasNormalOffsets || hasTangentOffsets else { return }

        let normals = hasNormalOffsets
            ? applyOffsets(base: component.baseNormals,
                           offsets: component.normalOffsets,
                           weights: blendShapeWeights(for: modelEntity,
                                                      targetCount: component.normalOffsets.count))
            : nil
        let tangents = hasTangentOffsets
            ? applyOffsets(base: component.baseTangents,
                           offsets: component.tangentOffsets,
                           weights: blendShapeWeights(for: modelEntity,
                                                      targetCount: component.tangentOffsets.count))
            : nil
        guard normals != nil || tangents != nil else { return }
        guard let model = modelEntity.components[ModelComponent.self] else { return }
        updateMeshBuffers(mesh: model.mesh, normals: normals, tangents: tangents)
    }

    private func blendShapeWeights(for modelEntity: ModelEntity, targetCount: Int) -> [Float] {
        guard let firstSet = modelEntity.blendWeights.first else {
            return Array(repeating: 0, count: targetCount)
        }
        var result = Array(repeating: Float(0), count: targetCount)
        let names = modelEntity.blendWeightNames.first ?? []
        if !names.isEmpty, names.count == firstSet.count {
            for (index, name) in names.enumerated() {
                guard let targetIndex = parseBlendShapeIndex(from: name),
                      targetIndex < targetCount,
                      index < firstSet.count else { continue }
                result[targetIndex] = firstSet[index]
            }
        } else {
            let count = min(targetCount, firstSet.count)
            for index in 0..<count {
                result[index] = firstSet[index]
            }
        }
        return result
    }

    private func parseBlendShapeIndex(from name: String) -> Int? {
        let prefix = "blendShape_"
        guard name.hasPrefix(prefix) else { return nil }
        return Int(name.dropFirst(prefix.count))
    }

    private func applyOffsets(base: [SIMD3<Float>],
                              offsets: [[SIMD3<Float>]],
                              weights: [Float]) -> [SIMD3<Float>]? {
        guard !base.isEmpty, !offsets.isEmpty else { return nil }
        guard offsets.count == weights.count else { return nil }
        guard offsets.allSatisfy({ $0.count == base.count }) else { return nil }

        var result = base
        for targetIndex in 0..<offsets.count {
            let weight = weights[targetIndex]
            guard weight != 0 else { continue }
            let targetOffsets = offsets[targetIndex]
            for i in 0..<result.count {
                result[i] += targetOffsets[i] * weight
            }
        }
        return result
    }

    private func updateMeshBuffers(mesh: MeshResource,
                                   normals: [SIMD3<Float>]?,
                                   tangents: [SIMD3<Float>]?) {
        guard normals != nil || tangents != nil else { return }
        var contents = mesh.contents
        var updatedModels = MeshModelCollection()
        for model in contents.models {
            var model = model
            var updatedParts = MeshPartCollection()
            for part in model.parts {
                var part = part
                let vertexCount = part.positions.count
                if let normals, !normals.isEmpty, normals.count == vertexCount {
                    part.normals = MeshBuffer(normals)
                }
                if let tangents, !tangents.isEmpty, tangents.count == vertexCount {
                    part.tangents = MeshBuffer(tangents)
                }
                updatedParts.insert(part)
            }
            model.parts = updatedParts
            updatedModels.insert(model)
        }
        contents.models = updatedModels
        try? mesh.replace(with: contents)
    }

    private func readBlendShapeWeight(targetIndex: Int, on mesh: Entity) -> Float {
        let targetName = "blendShape_\(targetIndex)"
        for modelEntity in modelEntities(in: mesh) {
            let weights = modelEntity.blendWeights
            if let firstSet = weights.first, targetIndex < firstSet.count {
                let names = modelEntity.blendWeightNames
                if let firstNames = names.first,
                   let nameIndex = firstNames.firstIndex(of: targetName),
                   nameIndex < firstSet.count {
                    return firstSet[nameIndex]
                }
                return firstSet[targetIndex]
            }
        }
        return 0
    }

    private func ensureBlendShapeComponent(on modelEntity: ModelEntity) {
        if modelEntity.components[BlendShapeWeightsComponent.self] != nil {
            return
        }
        guard let model = modelEntity.components[ModelComponent.self] else { return }
        let mapping = BlendShapeWeightsMapping(meshResource: model.mesh)
        modelEntity.components.set(BlendShapeWeightsComponent(weightsMapping: mapping))
    }

    private func applyMaterialValues(_ materialValues: [MaterialValueBinding], weight: Float) {
        for binding in materialValues {
            applyMaterialValue(binding, weight: weight)
        }
    }

    private func applyMaterialValue(_ binding: MaterialValueBinding, weight: Float) {
        let lowerName = binding.valueName.lowercased()
        let isTextureTransform = lowerName == "_maintex_st" || lowerName.hasSuffix("_st_s") || lowerName.hasSuffix("_st_t")

        for modelEntity in modelEntities(in: entity) {
            guard let nameComponent = modelEntity.components[MaterialNameComponent.self] else { continue }
            guard let model = modelEntity.components[ModelComponent.self] else { continue }
            var materials = model.materials
            for index in materials.indices {
                guard index < nameComponent.materialNames.count,
                      nameComponent.materialNames[index] == binding.materialName else { continue }
                if isTextureTransform {
                    if let updated = applyTextureTransform(binding: binding,
                                                           weight: weight,
                                                           lowerName: lowerName,
                                                           modelEntity: modelEntity,
                                                           materialIndex: index,
                                                           material: materials[index]) {
                        materials[index] = updated
                    }
                } else if isColorValueName(lowerName),
                          let updated = applyColorValue(binding: binding,
                                                        weight: weight,
                                                        lowerName: lowerName,
                                                        modelEntity: modelEntity,
                                                        materialIndex: index,
                                                        material: materials[index]) {
                    materials[index] = updated
                }
            }
            modelEntity.model?.materials = materials
        }
    }

    private func applyTextureTransform(binding: MaterialValueBinding,
                                       weight: Float,
                                       lowerName: String,
                                       modelEntity: ModelEntity,
                                       materialIndex: Int,
                                       material: Material) -> Material? {
        let base = baseTextureTransform(for: modelEntity,
                                        materialIndex: materialIndex,
                                        valueName: binding.valueName,
                                        material: material)
        let blended = blend(base: base, target: binding.targetValue, weight: weight)
        let finalValue = applyPartialTransformIfNeeded(name: lowerName, base: base, blended: blended)
        let transform = MaterialParameterTypes.TextureCoordinateTransform(
            offset: SIMD2<Float>(finalValue.z, finalValue.w),
            scale: SIMD2<Float>(finalValue.x, finalValue.y),
            rotation: 0
        )

        if var unlit = material as? UnlitMaterial {
            unlit.textureCoordinateTransform = transform
            return unlit
        }
        if var pbr = material as? PhysicallyBasedMaterial {
            pbr.textureCoordinateTransform = transform
            return pbr
        }
        return nil
    }

    private func applyColorValue(binding: MaterialValueBinding,
                                 weight: Float,
                                 lowerName: String,
                                 modelEntity: ModelEntity,
                                 materialIndex: Int,
                                 material: Material) -> Material? {
        let base = baseColorValue(for: modelEntity,
                                  materialIndex: materialIndex,
                                  valueName: binding.valueName,
                                  material: material,
                                  lowerName: lowerName)
        let blended = blend(base: base, target: binding.targetValue, weight: weight)
        let color = VRMColor(red: CGFloat(blended.x),
                             green: CGFloat(blended.y),
                             blue: CGFloat(blended.z),
                             alpha: CGFloat(blended.w))

        if var unlit = material as? UnlitMaterial {
            var baseColor = unlit.color
            baseColor.tint = color
            unlit.color = baseColor
            return unlit
        }
        if var pbr = material as? PhysicallyBasedMaterial {
            if lowerName.contains("emission") {
                var emissive = pbr.emissiveColor
                emissive.color = color
                pbr.emissiveColor = emissive
            } else {
                var baseColor = pbr.baseColor
                baseColor.tint = color
                pbr.baseColor = baseColor
            }
            return pbr
        }
        return nil
    }

    private func isColorValueName(_ lowerName: String) -> Bool {
        return lowerName == "color"
            || lowerName == "_color"
            || lowerName == "emissioncolor"
            || lowerName == "_emissioncolor"
    }

    private func applyPartialTransformIfNeeded(name: String,
                                               base: SIMD4<Float>,
                                               blended: SIMD4<Float>) -> SIMD4<Float> {
        if name.hasSuffix("_st_s") {
            return SIMD4<Float>(blended.x, base.y, blended.z, base.w)
        }
        if name.hasSuffix("_st_t") {
            return SIMD4<Float>(base.x, blended.y, base.z, blended.w)
        }
        return blended
    }

    private func baseTextureTransform(for modelEntity: ModelEntity,
                                      materialIndex: Int,
                                      valueName: String,
                                      material: Material) -> SIMD4<Float> {
        let key = MaterialValueKey(entityID: ObjectIdentifier(modelEntity),
                                   materialIndex: materialIndex,
                                   valueName: valueName)
        if let cached = materialBaseValues[key] {
            return cached
        }
        let transform: MaterialParameterTypes.TextureCoordinateTransform
        if let unlit = material as? UnlitMaterial {
            transform = unlit.textureCoordinateTransform
        } else if let pbr = material as? PhysicallyBasedMaterial {
            transform = pbr.textureCoordinateTransform
        } else {
            transform = MaterialParameterTypes.TextureCoordinateTransform()
        }
        let base = SIMD4<Float>(transform.scale.x, transform.scale.y,
                                transform.offset.x, transform.offset.y)
        materialBaseValues[key] = base
        return base
    }

    private func baseColorValue(for modelEntity: ModelEntity,
                                materialIndex: Int,
                                valueName: String,
                                material: Material,
                                lowerName: String) -> SIMD4<Float> {
        let key = MaterialValueKey(entityID: ObjectIdentifier(modelEntity),
                                   materialIndex: materialIndex,
                                   valueName: valueName)
        if let cached = materialBaseValues[key] {
            return cached
        }
        var baseColor = VRMColor.white
        if let unlit = material as? UnlitMaterial {
            baseColor = unlit.color.tint
        } else if let pbr = material as? PhysicallyBasedMaterial {
            baseColor = lowerName.contains("emission")
                ? pbr.emissiveColor.color
                : pbr.baseColor.tint
        }
        let vector = baseColor.toVector4()
        materialBaseValues[key] = vector
        return vector
    }

    private func blend(base: SIMD4<Float>, target: SIMD4<Float>, weight: Float) -> SIMD4<Float> {
        return SIMD4<Float>(
            base.x + (target.x - base.x) * weight,
            base.y + (target.y - base.y) * weight,
            base.z + (target.z - base.z) * weight,
            base.w + (target.w - base.w) * weight
        )
    }
}

private extension VRMColor {
    func toVector4() -> SIMD4<Float> {
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
        return SIMD4<Float>(Float(r), Float(g), Float(b), Float(a))
    }
}
#endif
