import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        VStack(spacing: 35) {
            
            // 將標題縮小一級，避免字體過大撐破邊界
            Text("Particle Life 控制台")
                .font(.largeTitle)
                .fontWeight(.bold)
            
            // 嵌入乾淨的控制面板
            ControlPanelView()
            
            ToggleImmersiveSpaceButton()
        }
        // ✨ 統一在這裡給予所有元件距離玻璃邊緣 50 點的安全呼吸空間
        .padding(50)
        // ✨ 不再寫死固定寬高，而是給予「最小限制」，讓 visionOS 系統自動計算最完美的視窗尺寸
        .frame(minWidth: 550, minHeight: 700)
    }
}
