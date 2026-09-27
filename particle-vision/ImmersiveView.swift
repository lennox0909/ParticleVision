import SwiftUI
import RealityKit
import ARKit

struct ImmersiveView: View {
    @Environment(ParticleSimulator.self) private var simulator
    @State private var particleEntities: [Entity] = []
    @State private var frameSubscription: EventSubscription?

    @State private var containerBox = ModelEntity()
    @State private var coreTemplate: Entity?
    
    @State private var session = ARKitSession()
    @State private var handTracking = HandTrackingProvider()
    @State private var latestHandAnchors: [HandAnchor.Chirality: HandAnchor] = [:]
    
    @State private var activeHand: HandAnchor.Chirality? = nil
    @State private var initialHandTransform: simd_float4x4? = nil
    @State private var initialBoxTransform: simd_float4x4? = nil
    @State private var scaleStart: SIMD3<Float>?
    
    @State private var isScaling: Bool = false

    var body: some View {
        RealityView { content in
            let boxSize: Float = 4.0
            
            addBoxEdges(to: containerBox, size: boxSize)
            
            containerBox.scale = SIMD3<Float>(repeating: 0.1)
            containerBox.position = SIMD3<Float>(0, 1.1, -0.7)
            
            containerBox.components.set(CollisionComponent(shapes: [.generateBox(size: [boxSize, boxSize, boxSize])]))
            containerBox.components.set(InputTargetComponent())
            
            content.add(containerBox)
            
            // 【核心修復】嚴格規定每一幀的更新順序
            let subscription = content.subscribe(to: SceneEvents.Update.self) { _ in
                guard !self.particleEntities.isEmpty else { return }
                
                // 1. 先處理手部追蹤，並呼叫 applyInertia 將邏輯粒子留在原地 (被網子掃過)
                updateBoxWithHandTracking()
                
                // 2. 執行 GPU 運算，觸發 Metal 裡面的穿透推擠力
                simulator.updateSimulation()
                
                // 3. 將最終結果同步回 RealityKit 視覺實體
                syncParticlesToVisuals()
            }
            
            Task { @MainActor in
                self.frameSubscription = subscription
                do {
                    let usdaTemplate = try await Entity(named: "Sphere")
                    self.coreTemplate = findModelEntity(in: usdaTemplate)
                    if self.coreTemplate != nil {
                        setupParticleVisuals(in: containerBox)
                    }
                } catch {
                    print("無法載入 USDA 模型：\(error)")
                }
            }
        }
        .task {
            do {
                if HandTrackingProvider.isSupported {
                    try await session.run([handTracking])
                    for await update in handTracking.anchorUpdates {
                        latestHandAnchors[update.anchor.chirality] = update.anchor
                    }
                }
            } catch {
                print("ARKit 手部追蹤啟動失敗：\(error)")
            }
        }
        .onChange(of: simulator.particleScale) { _, newScale in
            let newScaleVector = SIMD3<Float>(repeating: newScale)
            for entity in particleEntities {
                entity.scale = newScaleVector
            }
        }
        .onChange(of: simulator.needsVisualRebuild) { _, needsRebuild in
            if needsRebuild {
                for entity in particleEntities {
                    entity.removeFromParent()
                }
                particleEntities.removeAll()
                setupParticleVisuals(in: containerBox)
                simulator.needsVisualRebuild = false
            }
        }
        .onDisappear {
            frameSubscription?.cancel()
            frameSubscription = nil
        }
        
        // 使用我們剛剛抽離出來的乾淨 API
        .containerDragGesture(
            isScaling: $isScaling,
            activeHand: $activeHand,
            initialHandTransform: $initialHandTransform,
            initialBoxTransform: $initialBoxTransform,
            latestHandAnchors: latestHandAnchors,
            containerBox: containerBox,
            findPinchingHand: findPinchingHand
        )
        .simultaneousGesture(
            MagnifyGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    isScaling = true
                    activeHand = nil
                    
                    let entity = value.entity
                    if scaleStart == nil { scaleStart = entity.scale }
                    entity.scale = scaleStart! * Float(value.magnification)
                }
                .onEnded { _ in
                    isScaling = false
                    scaleStart = nil
                }
        )
    }
    
    private func findPinchingHand() -> HandAnchor.Chirality? {
        var pinchingHand: HandAnchor.Chirality? = nil
        var minPinchDistance: Float = .infinity
        
        for (chirality, anchor) in latestHandAnchors where anchor.isTracked {
            guard let skeleton = anchor.handSkeleton else { continue }
            
            let thumb = skeleton.joint(.thumbTip)
            let index = skeleton.joint(.indexFingerTip)
            guard thumb.isTracked, index.isTracked else { continue }
            
            let thumbPos = thumb.anchorFromJointTransform.columns.3
            let indexPos = index.anchorFromJointTransform.columns.3
            
            let dist = distance(SIMD3<Float>(thumbPos.x, thumbPos.y, thumbPos.z),
                                SIMD3<Float>(indexPos.x, indexPos.y, indexPos.z))
            
            if dist < minPinchDistance {
                minPinchDistance = dist
                pinchingHand = chirality
            }
        }
        return pinchingHand
    }
    
    private func updateBoxWithHandTracking() {
        guard !isScaling,
              let chirality = activeHand,
              let currentAnchor = latestHandAnchors[chirality],
              currentAnchor.isTracked,
              let initHand = initialHandTransform,
              let initBox = initialBoxTransform else { return }
        
        let currentHand = currentAnchor.originFromAnchorTransform
        let deltaTransform = currentHand * initHand.inverse
        
        // 紀錄舊的矩陣，並計算新的矩陣
        let oldMatrix = containerBox.transform.matrix
        let newMatrix = deltaTransform * initBox
        
        // 【打通物理邏輯的關鍵開關】在真的移動畫面盒子前，對底層粒子施加相對位移 (慣性)
        simulator.applyInertia(oldBoxMatrix: oldMatrix, newBoxMatrix: newMatrix)
        
        // 更新視覺盒子的位置
        containerBox.transform.matrix = newMatrix
    }
    
    private func addBoxEdges(to parent: Entity, size: Float) {
        let thickness: Float = 0.015
        let half = size / 2.0
        let edgeMaterial = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.8))
        
        for y in [-half, half] {
            for z in [-half, half] {
                let edge = ModelEntity(mesh: .generateBox(size: [size, thickness, thickness]), materials: [edgeMaterial])
                edge.position = SIMD3<Float>(0, y, z)
                parent.addChild(edge)
            }
        }
        for x in [-half, half] {
            for z in [-half, half] {
                let edge = ModelEntity(mesh: .generateBox(size: [thickness, size, thickness]), materials: [edgeMaterial])
                edge.position = SIMD3<Float>(x, 0, z)
                parent.addChild(edge)
            }
        }
        for x in [-half, half] {
            for y in [-half, half] {
                let edge = ModelEntity(mesh: .generateBox(size: [thickness, thickness, size]), materials: [edgeMaterial])
                edge.position = SIMD3<Float>(x, y, 0)
                parent.addChild(edge)
            }
        }
    }
    
    private func findModelEntity(in entity: Entity) -> Entity? {
        if entity.components[ModelComponent.self] != nil { return entity }
        for child in entity.children {
            if let found = findModelEntity(in: child) { return found }
        }
        return nil
    }
    
    private func setupParticleVisuals(in parent: Entity) {
        guard let coreTemplate = self.coreTemplate else { return }
        
        let count = simulator.particleCount
        let numTypes = simulator.numTypes
        let pointer = simulator.particleBuffer.contents().bindMemory(to: Particle.self, capacity: count)
        let colors: [UIColor] = [.systemRed, .systemGreen, .systemBlue, .systemYellow, .systemPurple, .systemOrange]
        
        var materials: [UnlitMaterial] = []
        for i in 0..<numTypes { materials.append(UnlitMaterial(color: colors[i % colors.count])) }
        
        var newEntities: [Entity] = []
        newEntities.reserveCapacity(count)
        let initialScale = SIMD3<Float>(repeating: simulator.particleScale)
        
        for i in 0..<count {
            let particle = pointer[i]
            let typeIndex = Int(particle.type) % materials.count
            let clone = coreTemplate.clone(recursive: true)
            
            if var modelComp = clone.components[ModelComponent.self] {
                modelComp.materials = [materials[typeIndex]]
                clone.components.set(modelComp)
            }
            
            clone.scale = initialScale
            clone.position = particle.position
            parent.addChild(clone)
            newEntities.append(clone)
        }
        self.particleEntities = newEntities
    }
    
    private func syncParticlesToVisuals() {
        let count = simulator.particleCount
        let pointer = simulator.particleBuffer.contents().bindMemory(to: Particle.self, capacity: count)
        for i in 0..<count {
            particleEntities[i].position = pointer[i].position
        }
    }
}
