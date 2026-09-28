import SwiftUI

struct ControlPanelView: View {
    @Environment(ParticleSimulator.self) private var simulator
    
    @State private var particleCount: Double = 100000
    @State private var numTypes: Double = 6
    @State private var particleScale: Double = 0.015
    @State private var friction: Double = 0.95
    
    var body: some View {
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
            
            VStack(alignment: .leading) {
                Text("粒子大小: \(String(format: "%.3f", particleScale))")
                    .font(.headline)
                Slider(value: $particleScale, in: 0.005...0.05, step: 0.001)
                    .onChange(of: particleScale) { _, newValue in
                        simulator.particleScale = Float(newValue)
                    }
            }
            
            VStack(alignment: .leading) {
                Text("空間摩擦力: \(String(format: "%.2f", friction))")
                    .font(.headline)
                Slider(value: $friction, in: 0.01...0.99, step: 0.05)
                    .onChange(of: friction) { _, newValue in
                        simulator.friction = Float(newValue)
                    }
            }
            
            @Bindable var bindableSimulator = simulator
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
                Button("隨機引力規則") {
                    simulator.randomizeRules()
                }
                .buttonStyle(.bordered)
                
                Button("套用並重置宇宙") {
                    simulator.resetSimulation(newCount: Int(particleCount), newTypes: Int(numTypes))
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.top, 10)
        }
        // ✨ 已移除這裡的 padding、frame 與 glassBackgroundEffect，交給外層處理
    }
}
