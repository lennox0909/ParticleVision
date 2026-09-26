import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @State private var isImmersiveSpaceOpen = false
    
    var body: some View {
        VStack(spacing: 30) {
            // 【刪除】原本的 "8000顆粒子的空間雜湊演化"
            
            Text("Particle Life 控制台")
                .font(.extraLargeTitle)
                .fontWeight(.bold)
            
            ControlPanelView()
            
            Toggle(isImmersiveSpaceOpen ? "關閉粒子宇宙" : "開啟粒子宇宙", isOn: $isImmersiveSpaceOpen)
                .toggleStyle(.button)
                .padding(.top, 20)
        }
        .padding(40)
        .onChange(of: isImmersiveSpaceOpen) { _, isOpen in
            Task {
                if isOpen {
                    // 請確保此處的 ID 與 ParticleVisionApp.swift 中註冊的 ImmersiveSpace ID 相同
                    await openImmersiveSpace(id: "ParticleSpace")
                } else {
                    await dismissImmersiveSpace()
                }
            }
        }
    }
}
