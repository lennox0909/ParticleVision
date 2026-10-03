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
            
            // 改用 Entity+Extensions 提供的優雅語法
            containerBox.addBoxEdges(size: boxSize)
            
            // 讀取儲存的縮放比例，若無則使用預設值
            if let savedScale = UserDefaults.standard.array(forKey: "BoxScale") as? [Float], savedScale.count == 3 {
                containerBox.scale = SIMD3<Float>(savedScale[0], savedScale[1], savedScale[2])
            } else {
                containerBox.scale = SIMD3<Float>(repeating: 0.1)
            }
            
            // 讀取儲存的空間位置，若無則使用預設值
            if let savedPos = UserDefaults.standard.array(forKey: "BoxPosition") as? [Float], savedPos.count == 3 {
                containerBox.position = SIMD3<Float>(savedPos[0], savedPos[1], savedPos[2])
            } else {
                containerBox.position = SIMD3<Float>(0.4, 1.1, -0.7)
            }
            
            // 替換原本的單一實心碰撞體，改為 12 根邊框專用的碰撞條
            let s = boxSize
            let t: Float = 0.2 // 給予邊框 20 公分的「隱形判定厚度」，讓眼睛隨便看都能輕鬆命中
            let h = s / 2
            
            let edgeShapes: [ShapeResource] = [
                // 橫向 (X軸) 四根
                .generateBox(size: [s, t, t]).offsetBy(translation: [0, h, h]),
                .generateBox(size: [s, t, t]).offsetBy(translation: [0, h, -h]),
                .generateBox(size: [s, t, t]).offsetBy(translation: [0, -h, h]),
                .generateBox(size: [s, t, t]).offsetBy(translation: [0, -h, -h]),
                // 直向 (Y軸) 四根
                .generateBox(size: [t, s, t]).offsetBy(translation: [h, 0, h]),
                .generateBox(size: [t, s, t]).offsetBy(translation: [h, 0, -h]),
                .generateBox(size: [t, s, t]).offsetBy(translation: [-h, 0, h]),
                .generateBox(size: [t, s, t]).offsetBy(translation: [-h, 0, -h]),
                // 深度 (Z軸) 四根
                .generateBox(size: [t, t, s]).offsetBy(translation: [h, h, 0]),
                .generateBox(size: [t, t, s]).offsetBy(translation: [h, -h, 0]),
                .generateBox(size: [t, t, s]).offsetBy(translation: [-h, h, 0]),
                .generateBox(size: [t, t, s]).offsetBy(translation: [-h, -h, 0])
            ]
            
            containerBox.components.set(CollisionComponent(shapes: edgeShapes))
            containerBox.components.set(InputTargetComponent())
            
            content.add(containerBox)
            
            // 嚴格規定每一幀的更新順序
            let subscription = content.subscribe(to: SceneEvents.Update.self) { _ in
                guard !self.particleEntities.isEmpty else { return }
                
                // 觸發 FPS 計算
                simulator.updateFPS()
                
                // 1. 呼叫 ImmersiveView+HandTracking 裡的擴充方法
                updateBoxWithHandTracking()
                
                // 2. 執行 GPU 運算 (內部已自動透過 updateMeshVertices 即時縮放單顆粒子大小)
                simulator.updateSimulation()
                
                // 3. 呼叫 ImmersiveView+Particles 裡的擴充方法同步視覺
                syncParticlesToVisuals()
            }
            
            Task { @MainActor in
                self.frameSubscription = subscription
                do {
                    let usdaTemplate = try await Entity(named: "Sphere")
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
        // ✨ 已移除原本會把整個宇宙 Entity 縮小的 .onChange(of: simulator.particleScale)
        // 現在單顆粒子大小完全由 Metal 的 updateMeshVertices 控制，並自動隨 containerBox 等比例縮放！
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
        // 監聽螢光開關，一旦切換就呼叫材質更新函式
        .onChange(of: simulator.glowIntensity) { _, _ in
            updateParticleMaterials()
        }
        .onChange(of: simulator.currentColors) { _, _ in
            updateParticleMaterials()
        }
        .onDisappear {
            frameSubscription?.cancel()
            frameSubscription = nil
        }
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
