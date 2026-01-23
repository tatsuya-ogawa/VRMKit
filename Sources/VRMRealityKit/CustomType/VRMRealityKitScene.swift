#if canImport(RealityKit)
import RealityKit

@available(iOS 18.0, visionOS 2.0, *)
public final class VRMRealityKitScene {
    public let rootEntity: Entity
    public let vrmEntity: VRMRealityKitEntity

    init(entity: VRMRealityKitEntity) {
        self.vrmEntity = entity
        self.rootEntity = Entity()
        self.rootEntity.addChild(entity.entity)
    }
}
#endif
