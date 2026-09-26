import SwiftUI

struct ContentView: View {
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    
    @State private var isSpaceOpen = false

    var body: some View {
        HStack(alignment: .top, spacing: 40) {
            

            
            // App 主選單與空間啟動開關
            VStack(spacing: 40) {
                VStack(spacing: 16) {
                    Image(systemName: "atom")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundStyle(.blue)
                        .symbolEffect(.pulse)
                    
                    Text("Particle Vision")
                        .font(.extraLargeTitle)
                        .bold()
                    
                    Text("8,000 顆粒子的空間雜湊演化")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                
                Toggle(isSpaceOpen ? "關閉 3D 粒子空間" : "啟動 3D 粒子空間", isOn: $isSpaceOpen)
                    .toggleStyle(.button)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.extraLarge)
                    .tint(isSpaceOpen ? .red : .blue)
            }
            .padding(40)
            .frame(width: 400)
            .glassBackgroundEffect()
            
            // 載入我們先前建立好的物理控制台
            ControlPanelView()
            
        }
        .padding(40)
        // 監聽 Toggle 狀態，負責開啟或關閉 ImmersiveSpace
        .onChange(of: isSpaceOpen) { _, isOpen in
            Task {
                if isOpen {
                    await openImmersiveSpace(id: "ParticleSpace")
                } else {
                    await dismissImmersiveSpace()
                }
            }
        }
    }
}
