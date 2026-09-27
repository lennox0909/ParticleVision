import SwiftUI
import RealityKit

struct ContentView: View {
    var body: some View {
        VStack(spacing: 30) {
            
            Text("Particle Life 控制台")
                .font(.extraLargeTitle)
                .fontWeight(.bold)
            
            ControlPanelView()
            
            // 直接使用模組化的按鈕取代原本冗長的 Toggle 與 onChange 邏輯
            ToggleImmersiveSpaceButton()
                .padding(.top, 20)
        }
        .padding(40)
    }
}
