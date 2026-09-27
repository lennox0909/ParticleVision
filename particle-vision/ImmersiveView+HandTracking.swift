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
        guard !isScaling,
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
    }
}
