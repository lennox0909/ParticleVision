import SwiftUI
import RealityKit
import ARKit

struct ImmersiveView: View {
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
            
            // ✨ 啟動 3D 粒子空間時，直接套用記憶的邊框灰階顏色與粗細建立 12 根邊框
            containerBox.addBoxEdges(
                size: boxSize,
                grayscale: simulator.boxEdgeGrayscale,
                thickness: simulator.boxEdgeThickness
            )
            
            // ✨ 啟動 3D 粒子空間時，直接從 simulator 還原關閉前的精確大小、座標與旋轉角度
            simulator.applySavedTransform(to: containerBox)
            
            // 設定 12 根邊框專用的碰撞條
            let s = boxSize
            let t: Float = 0.2
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
            updateBoxInteractability(isEnabled: simulator.isBoxInteractionEnabled)
            
            content.add(containerBox)
            
            let subscription = content.subscribe(to: SceneEvents.Update.self) { _ in
                guard !self.particleEntities.isEmpty else { return }
                
                simulator.updateFPS()
                updateBoxWithHandTracking()
                simulator.updateSimulation()
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
        .onChange(of: simulator.glowIntensity) { _, _ in
            updateParticleMaterials()
        }
        .onChange(of: simulator.currentColors) { _, _ in
            updateParticleMaterials()
        }
        .onChange(of: simulator.isBoxInteractionEnabled) { _, isEnabled in
            updateBoxInteractability(isEnabled: isEnabled)
        }
        // ✨ 當調整主畫面的「邊框顏色」或「邊框粗細」滑桿時，即時更新 3D 透明盒子邊框
        .onChange(of: simulator.boxEdgeGrayscale) { _, newGray in
            containerBox.updateBoxEdgesAppearance(
                grayscale: newGray,
                thickness: simulator.boxEdgeThickness
            )
        }
        .onChange(of: simulator.boxEdgeThickness) { _, newThickness in
            containerBox.updateBoxEdgesAppearance(
                grayscale: simulator.boxEdgeGrayscale,
                thickness: newThickness
            )
        }
        .onDisappear {
            // ✨ 當點擊「關閉 3D 粒子空間」時，立即將當前盒子的最終大小、座標與旋轉角度完整儲存
            simulator.saveBoxTransform(from: containerBox)
            
            frameSubscription?.cancel()
            frameSubscription = nil
            simulator.resetFPS()
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
