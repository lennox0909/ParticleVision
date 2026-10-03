import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        // ✨ 透過 HStack 的 spacing: 35 創造兩個獨立毛玻璃視窗之間的透明間隔
        HStack(alignment: .center, spacing: 35) {
            
            // 左側獨立毛玻璃視窗：Particle Life 控制台
            VStack(spacing: 30) {
                Text("Particle Life 控制台")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                ControlPanelView()
                
                Spacer(minLength: 0)
                
                ToggleImmersiveSpaceButton()
            }
            .padding(45)
            .frame(width: 500, height: 720)
            .glassBackgroundEffect() // ✨ 賦予左側面板獨立的原生毛玻璃背景
            
            // 右側獨立毛玻璃視窗：基因引力矩陣編輯器
            RuleMatrixView()
                .frame(width: 480, height: 720)
                .glassBackgroundEffect() // ✨ 賦予右側面板獨立的原生毛玻璃背景
        }
        .padding(20)
    }
}
