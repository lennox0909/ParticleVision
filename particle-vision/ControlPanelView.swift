import SwiftUI

struct ControlPanelView: View {
    @Environment(ParticleSimulator.self) private var simulator
    
    @State private var particleCount: Double = 50000
    @State private var numTypes: Double = 6
    @State private var particleScale: Double = 0.015
    // 【新增】摩擦力的狀態
    @State private var friction: Double = 0.95
    
    var body: some View {
        VStack(spacing: 25) {
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
            
            // 【新增】空間摩擦力拉桿
            VStack(alignment: .leading) {
                Text("空間摩擦力: \(String(format: "%.2f", friction))")
                    .font(.headline)
                Slider(value: $friction, in: 0.01...0.99, step: 0.05)
                    .onChange(of: friction) { _, newValue in
                        simulator.friction = Float(newValue)
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
        }
        .padding(30)
        .glassBackgroundEffect()
    }
}
