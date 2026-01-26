//
//  ContentView.swift
//  MacExample
//
//  Created by tattn on 2026/01/26.
//  Copyright © 2026 tattn. All rights reserved.
//

import SwiftUI
import RealityKit
internal import VRMRealityKit
internal import Combine

struct ContentView: View {
    @State private var viewModel = ContentViewModel()
    
    var body: some View {
        VStack {
            RealityView { content in
                content.add(viewModel.rootEntity)
            }
            .task {
                await viewModel.loadEntity()
            }
            .onReceive(viewModel.updateTimer) { _ in
                viewModel.update()
            }
            
            if let errorMessage = viewModel.errorMessage {
                Text("Error: \(errorMessage)")
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}

@MainActor
@Observable
final class ContentViewModel {
    let rootEntity = Entity()
    private(set) var errorMessage: String?
    private var vrmEntity: VRMEntity?
    private var time: TimeInterval = 0
    private var lastUpdateTime: Date?
    
    let updateTimer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    
    func loadEntity() async {
        do {
            let loader = try VRMEntityLoader(named: "AliciaSolid.vrm")
            let vrmEntity = try loader.loadEntity()
            
            vrmEntity.entity.transform.translation = SIMD3<Float>(0, -1, 0)
            vrmEntity.entity.transform.rotation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
            rootEntity.addChild(vrmEntity.entity)
            
            // Adjust pose
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
            
            self.vrmEntity = vrmEntity
            self.lastUpdateTime = Date()
        } catch {
            errorMessage = error.localizedDescription
            print("VRM Load Error: \(error)")
        }
    }
    
    func update() {
        guard let vrmEntity else { return }
        
        let now = Date()
        let deltaTime = lastUpdateTime.map { now.timeIntervalSince($0) } ?? (1.0 / 60.0)
        lastUpdateTime = now
        
        time += deltaTime
        
        // An animation that sways left and right
        let cycle = time.truncatingRemainder(dividingBy: 1.0)
        let angle: Float
        if cycle < 0.5 {
            let progress = Float(cycle) / 0.5
            angle = -0.5 * progress
        } else {
            let progress = Float(cycle - 0.5) / 0.5
            angle = -0.5 + 0.5 * progress
        }
        
        vrmEntity.entity.transform.rotation = simd_quatf(angle: .pi + angle, axis: SIMD3<Float>(0, 1, 0))
        vrmEntity.update(at: deltaTime)
    }
}

#Preview {
    ContentView()
}
