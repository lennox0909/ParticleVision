import SwiftUI

struct ControlPanelView: View {
    @Environment(ParticleSimulator.self) private var simulator
    
    @State private var particleCount: Double = 100000
    @State private var numTypes: Double = 6
    
    var body: some View {
        // ✨ 將 @Bindable 提升至頂部，讓粒子大小、空間摩擦力與螢光強度皆能零延遲直接雙向綁定
        @Bindable var bindableSimulator = simulator
        
        VStack(spacing: 20) {
            
            // FPS 顯示面板
            HStack {
                Text("FPS:")
                    .font(.headline)
                Text("\(simulator.currentFPS)")
                    .font(.system(.title2, design: .monospaced).bold())
                    .foregroundColor(simulator.currentFPS >= 75 ? .green : (simulator.currentFPS >= 60 ? .yellow : .red))
                Spacer()
            }
            .padding(.bottom, -5)
            
            VStack(alignment: .leading) {
                Text("粒子數量: \(Int(particleCount))")
                    .font(.headline)
                Slider(value: $particleCount, in: 1000...100000, step: 1000)
            }
            
            VStack(alignment: .leading) {
                Text("粒子種類: \(Int(numTypes))")
                    .font(.headline)
                Slider(value: $numTypes, in: 2...8, step: 1)
            }
            
            // ✨ 直接綁定 $bindableSimulator.particleScale，拉動瞬間立即改變 3D 顆粒大小
            VStack(alignment: .leading) {
                Text("粒子大小: \(String(format: "%.3f", simulator.particleScale))")
                    .font(.headline)
                Slider(value: $bindableSimulator.particleScale, in: 0.005...0.050, step: 0.001)
            }
            
            // ✨ 直接綁定 $bindableSimulator.friction，即時同步空間摩擦力
            VStack(alignment: .leading) {
                Text("空間摩擦力: \(String(format: "%.2f", simulator.friction))")
                    .font(.headline)
                Slider(value: $bindableSimulator.friction, in: 0.01...0.99, step: 0.01)
            }
            
            VStack(alignment: .leading) {
                Text("螢光強度: \(String(format: "%.1f", simulator.glowIntensity))")
                    .font(.headline)
                
                HStack(spacing: 15) {
                    Slider(value: $bindableSimulator.glowIntensity, in: 0...5, step: 0.5)
                        .tint(.cyan)
                    
                    Button {
                        simulator.glowIntensity = max(0, simulator.glowIntensity - 0.1)
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    
                    Button {
                        simulator.glowIntensity = min(5, simulator.glowIntensity + 0.1)
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                }
            }
            
            HStack(spacing: 20) {
                Button("套用並重置宇宙") {
                    simulator.resetSimulation(newCount: Int(particleCount), newTypes: Int(numTypes))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 10)
        }
        .onAppear {
            // 確保面板開啟時，滑桿顯示的初始數量與種類和模擬器實際狀態一致
            particleCount = Double(simulator.particleCount)
            numTypes = Double(simulator.numTypes)
        }
    }
}
