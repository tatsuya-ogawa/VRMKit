import SwiftUI
import RealityKit
import VRMRealityKit

struct MainView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        VStack(spacing: 20) {
            Text("VRM Example")
                .font(.largeTitle)

            Button {
                Task {
                    switch appModel.immersiveSpaceState {
                    case .closed:
                        appModel.immersiveSpaceState = .inTransition
                        let result = await openImmersiveSpace(id: appModel.immersiveSpaceID)
                        if case .error = result {
                            appModel.immersiveSpaceState = .closed
                        }
                    case .open:
                        appModel.immersiveSpaceState = .inTransition
                        await dismissImmersiveSpace()
                    case .inTransition:
                        break
                    }
                }
            } label: {
                Text(appModel.immersiveSpaceState == .open ? "Hide VRM" : "Show VRM")
            }
            .disabled(appModel.immersiveSpaceState == .inTransition)
        }
        .padding()
    }
}

struct ImmersiveView: View {
    @State private var viewModel = ImmersiveViewModel()

    var body: some View {
        RealityView { content in
            content.add(viewModel.rootEntity)
        }
        .task {
            await viewModel.loadScene()
        }
        .onReceive(viewModel.updateTimer) { _ in
            viewModel.update()
        }
    }
}

@MainActor
@Observable
final class ImmersiveViewModel {
    let rootEntity = Entity()
    private(set) var errorMessage: String?
    private var scene: VRMRealityKitScene?
    private var time: TimeInterval = 0
    private var lastUpdateTime: Date?
    
    let updateTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()

    func loadScene() async {
        do {
            let loader = try VRMRealityKitSceneLoader(named: "AliciaSolid.vrm")
            let scene = try loader.loadScene()
            
            scene.rootEntity.transform.translation = SIMD3<Float>(0, 0, -1.5)
            scene.rootEntity.transform.rotation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
            rootEntity.addChild(scene.rootEntity)
            
            // ポーズ調整
            let vrmEntity = scene.vrmEntity
            let neck = vrmEntity.humanoid.node(for: .neck)
            let leftShoulder = vrmEntity.humanoid.node(for: .leftShoulder) ?? vrmEntity.humanoid.node(for: .leftUpperArm)
            let rightShoulder = vrmEntity.humanoid.node(for: .rightShoulder) ?? vrmEntity.humanoid.node(for: .rightUpperArm)
            
            let neckRotation = simd_quatf(angle: 20 * .pi / 180, axis: SIMD3<Float>(0, 0, 1))
            let shoulderRotation = simd_quatf(angle: 40 * .pi / 180, axis: SIMD3<Float>(0, 0, 1))
            if let neck {
                neck.transform.rotation = neck.transform.rotation * neckRotation
            }
            if let leftShoulder {
                leftShoulder.transform.rotation = leftShoulder.transform.rotation * shoulderRotation
            }
            if let rightShoulder {
                rightShoulder.transform.rotation = rightShoulder.transform.rotation * shoulderRotation
            }
            vrmEntity.setBlendShape(value: 1.0, for: .custom("><"))
            
            self.scene = scene
            self.lastUpdateTime = Date()
        } catch {
            errorMessage = error.localizedDescription
            print("VRM Load Error: \(error)")
        }
    }
    
    func update() {
        guard let scene else { return }
        
        let now = Date()
        let deltaTime = lastUpdateTime.map { now.timeIntervalSince($0) } ?? (1.0 / 60.0)
        lastUpdateTime = now
        
        time += deltaTime
        
        // 左右に揺れるアニメーション
        let cycle = time.truncatingRemainder(dividingBy: 1.0)
        let angle: Float
        if cycle < 0.5 {
            let progress = Float(cycle) / 0.5
            angle = -0.5 * progress
        } else {
            let progress = Float(cycle - 0.5) / 0.5
            angle = -0.5 + 0.5 * progress
        }
        
        scene.rootEntity.transform.rotation = simd_quatf(angle: .pi + angle, axis: SIMD3<Float>(0, 1, 0))
        scene.vrmEntity.update(at: deltaTime)
    }
}
