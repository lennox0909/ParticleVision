import SwiftUI
import RealityKit
import ARKit

extension ImmersiveView {
    
    /// ✨ 初始化左右手食指尖的 3D 能量光球（作為 containerBox 的子實體，直接使用局部座標定位）
    func setupHandOrbs(in box: Entity) {
        let orbMesh = MeshResource.generateSphere(radius: 0.08)
        let attractMat = UnlitMaterial(color: UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.85))
        
        leftHandOrb = ModelEntity(mesh: orbMesh, materials: [attractMat])
        rightHandOrb = ModelEntity(mesh: orbMesh, materials: [attractMat])
        
        leftHandOrb.isEnabled = false
        rightHandOrb.isEnabled = false
        
        box.addChild(leftHandOrb)
        box.addChild(rightHandOrb)
    }
    
    /// ✨ 當透明盒子處於「🔒 鎖定觀察模式」時，將雙手食指尖轉換為盒子內部力場奇點
    func updateGodHandForceField() {
        // 若目前處於「🖐️ 允許操作透明盒子」模式，停用神之手力場與光球，避免搬移盒子時干擾粒子
        guard !simulator.isBoxInteractionEnabled else {
            simulator.handForces = [SIMD4<Float>(repeating: 0), SIMD4<Float>(repeating: 0)]
            leftHandOrb.isEnabled = false
            rightHandOrb.isEnabled = false
            return
        }
        
        let boxInverse = containerBox.transform.matrix.inverse
        let hands: [(HandAnchor.Chirality, Int, ModelEntity)] = [
            (.left, 0, leftHandOrb),
            (.right, 1, rightHandOrb)
        ]
        
        for (chirality, index, orb) in hands {
            guard let anchor = latestHandAnchors[chirality],
                  anchor.isTracked,
                  let skeleton = anchor.handSkeleton else {
                simulator.handForces[index] = SIMD4<Float>(repeating: 0)
                orb.isEnabled = false
                continue
            }
            
            let indexTip = skeleton.joint(.indexFingerTip)
            let thumbTip = skeleton.joint(.thumbTip)
            guard indexTip.isTracked, thumbTip.isTracked else {
                simulator.handForces[index] = SIMD4<Float>(repeating: 0)
                orb.isEnabled = false
                continue
            }
            
            // 1. 計算食指尖與拇指尖在世界座標系的位置
            let indexWorldMatrix = anchor.originFromAnchorTransform * indexTip.anchorFromJointTransform
            let thumbWorldMatrix = anchor.originFromAnchorTransform * thumbTip.anchorFromJointTransform
            
            let indexCol = indexWorldMatrix.columns.3
            let thumbCol = thumbWorldMatrix.columns.3
            
            let indexWorldPos = SIMD3<Float>(indexCol.x, indexCol.y, indexCol.z)
            let thumbWorldPos = SIMD3<Float>(thumbCol.x, thumbCol.y, thumbCol.z)
            
            // 2. 將食指尖世界座標轉換為 containerBox 內部局部座標 (-2.0 ~ +2.0 為盒子內部範圍)
            let localPos4 = boxInverse * SIMD4<Float>(indexWorldPos.x, indexWorldPos.y, indexWorldPos.z, 1.0)
            let localPos = SIMD3<Float>(localPos4.x, localPos4.y, localPos4.z)
            
            // 3. 檢查手指是否伸入透明盒子有效感應區內 (-2.2 ~ +2.2)
            let activeBounds: Float = 2.2
            guard abs(localPos.x) <= activeBounds &&
                    abs(localPos.y) <= activeBounds &&
                    abs(localPos.z) <= activeBounds else {
                simulator.handForces[index] = SIMD4<Float>(repeating: 0)
                orb.isEnabled = false
                continue
            }
            
            // 4. 判斷手勢：食指與拇指距離 < 3.2 公分視為「🤏 捏合排斥 (-1.0)」，否則為「✋ 張開吸引 (+1.0)」
            let pinchDist = simd_distance(indexWorldPos, thumbWorldPos)
            let isPinching = pinchDist < 0.032
            let mode: Float = isPinching ? -1.0 : 1.0
            
            simulator.handForces[index] = SIMD4<Float>(localPos.x, localPos.y, localPos.z, mode)
            
            // 5. 更新指尖 3D 能量光球的位置、顏色與大小
            orb.isEnabled = true
            orb.position = localPos
            orb.scale = isPinching ? SIMD3<Float>(repeating: 1.35) : SIMD3<Float>(repeating: 1.0)
            
            let orbColor = isPinching
            ? UIColor(red: 1.0, green: 0.22, blue: 0.30, alpha: 0.90) // 🤏 捏合：熾紅超新星斥力光球
            : UIColor(red: 0.0, green: 0.95, blue: 1.0, alpha: 0.85)  // ✋ 張開：青色漩渦引力光球
            orb.model?.materials = [UnlitMaterial(color: orbColor)]
        }
    }
    
    func findPinchingHand() -> HandAnchor.Chirality? {
        var pinchingHand: HandAnchor.Chirality? = nil
        var minPinchDistance: Float = .infinity
        
        for (chirality, anchor) in latestHandAnchors where anchor.isTracked {
            guard let skeleton = anchor.handSkeleton else { continue }
            
            let thumb = skeleton.joint(.thumbTip)
            let index = skeleton.joint(.indexFingerTip)
            guard thumb.isTracked, index.isTracked else { continue }
            
            let thumbPos = thumb.anchorFromJointTransform.columns.3
            let indexPos = index.anchorFromJointTransform.columns.3
            
            let dist = simd_distance(
                SIMD3<Float>(thumbPos.x, thumbPos.y, thumbPos.z),
                SIMD3<Float>(indexPos.x, indexPos.y, indexPos.z)
            )
            
            if dist < minPinchDistance {
                minPinchDistance = dist
                pinchingHand = chirality
            }
        }
        return pinchingHand
    }
    
    func updateBoxWithHandTracking() {
        // 防誤觸檢查：當鎖定透明盒子時，不進行任何手部追蹤位移與旋轉計算
        guard simulator.isBoxInteractionEnabled,
              !isScaling,
              let chirality = activeHand,
              let currentAnchor = latestHandAnchors[chirality],
              currentAnchor.isTracked,
              let initHand = initialHandTransform,
              let initBox = initialBoxTransform else { return }
        
        let currentHand = currentAnchor.originFromAnchorTransform
        let deltaTransform = currentHand * initHand.inverse
        
        let oldMatrix = containerBox.transform.matrix
        let newMatrix = deltaTransform * initBox
        
        simulator.applyInertia(oldBoxMatrix: oldMatrix, newBoxMatrix: newMatrix)
        containerBox.transform.matrix = newMatrix
        
        // ✨ 即時同步最新的空間座標、大小與旋轉角度至 simulator
        simulator.boxPosition = containerBox.position
        simulator.boxScale = containerBox.scale
        simulator.boxOrientation = containerBox.orientation
    }
    
    /// 動態啟用 / 停用 containerBox 的系統輸入判定，並清除殘留的手勢狀態
    func updateBoxInteractability(isEnabled: Bool) {
        if isEnabled {
            containerBox.components.set(InputTargetComponent())
            leftHandOrb.isEnabled = false
            rightHandOrb.isEnabled = false
            simulator.handForces = [SIMD4<Float>(repeating: 0), SIMD4<Float>(repeating: 0)]
        } else {
            containerBox.components.remove(InputTargetComponent.self)
            
            // ✨ 鎖定瞬間也將當前盒子的座標與大小持久化存檔
            simulator.saveBoxTransform(from: containerBox)
            
            activeHand = nil
            initialHandTransform = nil
            initialBoxTransform = nil
            scaleStart = nil
            isScaling = false
        }
    }
}
