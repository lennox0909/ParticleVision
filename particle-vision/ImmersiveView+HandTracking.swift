import SwiftUI
import RealityKit
import ARKit

extension ImmersiveView {
    
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
            
            let dist = distance(SIMD3<Float>(thumbPos.x, thumbPos.y, thumbPos.z),
                                SIMD3<Float>(indexPos.x, indexPos.y, indexPos.z))
            
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
