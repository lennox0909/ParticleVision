import SwiftUI
import RealityKit
import ARKit

struct ImmersiveView: View {
    // 移除 private 以便讓拆分到其他檔案的 Extension 也能存取這些狀態
    @Environment(ParticleSimulator.self) var simulator
    
    @State var particleEntities: [Entity] = []
    @State var frameSubscription: EventSubscription?

    @State var containerBox = ModelEntity()
    @State var coreTemplate: Entity?
    
    @State var session = ARKitSession()
    @State var handTracking = HandTrackingProvider()
    @State var latestHandAnchors: [HandAnchor.Chirality: HandAnchor] = [:]
    
    @State var activeHand: HandAnchor.Chirality? = nil
    @State var initialHandTransform: simd_float4x4? = nil
    @State var initialBoxTransform: simd_float4x4? = nil
    @State var scaleStart: SIMD3<Float>?
    
    @State var isScaling: Bool = false

    var body: some View {
        RealityView { content in
            let boxSize: Float = 4.0
            
            // ✨ 改用 Entity+Extensions 提供的優雅語法
            containerBox.addBoxEdges(size: boxSize)
            
            containerBox.scale = SIMD3<Float>(repeating: 0.1)
            containerBox.position = SIMD3<Float>(0.4, 1.1, -0.7)
            
            containerBox.components.set(CollisionComponent(shapes: [.generateBox(size: [boxSize, boxSize, boxSize])]))
            containerBox.components.set(InputTargetComponent())
            
            content.add(containerBox)
            
            // 嚴格規定每一幀的更新順序
            let subscription = content.subscribe(to: SceneEvents.Update.self) { _ in
                guard !self.particleEntities.isEmpty else { return }
                
                // 1. 呼叫 ImmersiveView+HandTracking 裡的擴充方法
                updateBoxWithHandTracking()
                
                // 2. 執行 GPU 運算
                simulator.updateSimulation()
                
                // 3. 呼叫 ImmersiveView+Particles 裡的擴充方法同步視覺
                syncParticlesToVisuals()
            }
            
            Task { @MainActor in
                self.frameSubscription = subscription
                do {
                    let usdaTemplate = try await Entity(named: "Sphere")
                    // ✨ 改用 Entity+Extensions 提供的優雅語法
                    self.coreTemplate = usdaTemplate.findModelEntity()
                    
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
        // ✨ 新增：監聽螢光開關，一旦切換就呼叫剛剛寫好的材質更新函式
        .onChange(of: simulator.glowIntensity) { _, _ in
                    updateParticleMaterials()
        }
        
        .onDisappear {
            frameSubscription?.cancel()
            frameSubscription = nil
        }
        // ✨ 使用我們抽離出來的手勢 ViewModifier，讓主視圖極度清爽
        .containerDragGesture(
            isScaling: $isScaling,
            activeHand: $activeHand,
            initialHandTransform: $initialHandTransform,
            initialBoxTransform: $initialBoxTransform,
            latestHandAnchors: latestHandAnchors,
            containerBox: containerBox,
            findPinchingHand: findPinchingHand
        )
        .containerMagnifyGesture(
            isScaling: $isScaling,
            activeHand: $activeHand,
            scaleStart: $scaleStart
        )
    }
}
