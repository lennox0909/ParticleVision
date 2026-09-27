import SwiftUI
import RealityKit
import ARKit

// 1. 建立自訂的 ViewModifier 來封裝雙手縮放邏輯
struct ContainerMagnifyGestureModifier: ViewModifier {
    @Binding var isScaling: Bool
    @Binding var activeHand: HandAnchor.Chirality?
    @Binding var scaleStart: SIMD3<Float>?
    
    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                MagnifyGesture()
                    .targetedToAnyEntity()
                    .onChanged { value in
                        // 標記正在縮放，並清除單手旋轉的狀態，避免手勢衝突
                        isScaling = true
                        activeHand = nil
                        
                        let entity = value.entity
                        // 紀錄初始縮放比例
                        if scaleStart == nil {
                            scaleStart = entity.scale
                        }
                        // 套用放大/縮小倍率
                        entity.scale = scaleStart! * Float(value.magnification)
                    }
                    .onEnded { _ in
                        // 結束時重置狀態
                        isScaling = false
                        scaleStart = nil
                    }
            )
    }
}

// 2. 建立 View 擴充，方便在主畫面呼叫
extension View {
    func containerMagnifyGesture(
        isScaling: Binding<Bool>,
        activeHand: Binding<HandAnchor.Chirality?>,
        scaleStart: Binding<SIMD3<Float>?>
    ) -> some View {
        self.modifier(
            ContainerMagnifyGestureModifier(
                isScaling: isScaling,
                activeHand: activeHand,
                scaleStart: scaleStart
            )
        )
    }
}
