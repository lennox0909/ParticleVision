import SwiftUI
import RealityKit
import ARKit

// 1. 建立自訂的 ViewModifier 來封裝拖曳手勢邏輯
struct ContainerDragGestureModifier: ViewModifier {
    // 使用 @Binding 來與 ImmersiveView 共用狀態
    @Binding var isScaling: Bool
    @Binding var activeHand: HandAnchor.Chirality?
    @Binding var initialHandTransform: simd_float4x4?
    @Binding var initialBoxTransform: simd_float4x4?
    
    // 傳入唯讀的依賴屬性與閉包
    var latestHandAnchors: [HandAnchor.Chirality: HandAnchor]
    var containerBox: Entity
    var findPinchingHand: () -> HandAnchor.Chirality?
    
    func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0.0)
                    .targetedToAnyEntity()
                    .onChanged { value in
                        // 如果正在進行雙手縮放，則忽略單手拖曳旋轉
                        guard !isScaling else { return }
                        
                        if activeHand == nil {
                            activeHand = findPinchingHand()
                            
                            if let chirality = activeHand,
                               let anchor = latestHandAnchors[chirality] {
                                // 紀錄捏合瞬間的手部與容器矩陣，做為 6-DOF 計算的基準
                                initialHandTransform = anchor.originFromAnchorTransform
                                initialBoxTransform = containerBox.transform.matrix
                            }
                        }
                    }
                    .onEnded { _ in
                        // 手勢結束時清空狀態，避免影響下一次互動
                        activeHand = nil
                        initialHandTransform = nil
                        initialBoxTransform = nil
                    }
            )
    }
}

// 2. 建立 View 的擴充，讓語法在使用時更自然
extension View {
    func containerDragGesture(
        isScaling: Binding<Bool>,
        activeHand: Binding<HandAnchor.Chirality?>,
        initialHandTransform: Binding<simd_float4x4?>,
        initialBoxTransform: Binding<simd_float4x4?>,
        latestHandAnchors: [HandAnchor.Chirality: HandAnchor],
        containerBox: Entity,
        findPinchingHand: @escaping () -> HandAnchor.Chirality?
    ) -> some View {
        self.modifier(
            ContainerDragGestureModifier(
                isScaling: isScaling,
                activeHand: activeHand,
                initialHandTransform: initialHandTransform,
                initialBoxTransform: initialBoxTransform,
                latestHandAnchors: latestHandAnchors,
                containerBox: containerBox,
                findPinchingHand: findPinchingHand
            )
        )
    }
}
