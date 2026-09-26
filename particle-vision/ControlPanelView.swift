import SwiftUI

struct ControlPanelView: View {
    // 取得與 ImmersiveView 共用的模擬器實體
    @Environment(ParticleSimulator.self) private var simulator
    
    // 對應粒子種類的視覺顏色，方便在矩陣中識別
    private let particleColors: [Color] = [.red, .green, .blue, .yellow, .purple, .orange]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // MARK: - 1. 全域物理參數設定
                    GroupBox("環境物理參數") {
                        VStack(spacing: 16) {
                            paramSlider(title: "最大作用半徑 (rMax)", value: rMaxBinding, range: 0.1...1.0)
                            paramSlider(title: "排斥半徑 (rMin)", value: rMinBinding, range: 0.01...0.2)
                            paramSlider(title: "摩擦力/阻尼 (Friction)", value: frictionBinding, range: 0.8...0.99)
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // MARK: - 2. 交互作用力矩陣 (Rule Matrix)
                    GroupBox("粒子引力矩陣 (Attraction / Repulsion)") {
                        VStack(spacing: 12) {
                            Text("正值(右側)代表吸引，負值(左側)代表排斥")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            let numTypes = simulator.numTypes
                            
                            // 建立 N x N 的方陣控制面板
                            Grid(alignment: .center, horizontalSpacing: 16, verticalSpacing: 16) {
                                ForEach(0..<numTypes, id: \.self) { row in
                                    GridRow {
                                        // 顯示被作用的粒子顏色標籤
                                        Circle()
                                            .fill(particleColors[row % particleColors.count])
                                            .frame(width: 20, height: 20)
                                        
                                        ForEach(0..<numTypes, id: \.self) { col in
                                            VStack {
                                                // 顯示目標粒子的顏色點綴
                                                Circle()
                                                    .fill(particleColors[col % particleColors.count])
                                                    .frame(width: 10, height: 10)
                                                
                                                // 矩陣獨立的滑桿
                                                Slider(value: matrixBinding(row: row, col: col), in: -1.0...1.0)
                                                    .tint(matrixBinding(row: row, col: col).wrappedValue > 0 ? .green : .red)
                                            }
                                            .frame(minWidth: 80)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    // MARK: - 3. 功能按鈕
                    Button(action: randomizeRules) {
                        Label("隨機產生新規則", systemImage: "shuffle")
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(24)
            }
            .navigationTitle("粒子生命控制台")
            // 在 visionOS 中，設定玻璃背景效果
            .glassBackgroundEffect()
        }
    }
    
    // MARK: - 自訂的綁定 (Bindings)
    
    // 將滑桿的值綁定到 Metal 參數，並在數值改變時同步更新 GPU Buffer
    private var rMaxBinding: Binding<Float> {
        Binding(
            get: { simulator.params.rMax },
            set: { newValue in
                simulator.params.rMax = newValue
                simulator.updateParamsBuffer() // 同步到 GPU
            }
        )
    }
    
    private var rMinBinding: Binding<Float> {
        Binding(
            get: { simulator.params.rMin },
            set: { newValue in
                simulator.params.rMin = newValue
                simulator.updateParamsBuffer()
            }
        )
    }
    
    private var frictionBinding: Binding<Float> {
        Binding(
            get: { simulator.params.friction },
            set: { newValue in
                simulator.params.friction = newValue
                simulator.updateParamsBuffer()
            }
        )
    }
    
    // 將矩陣索引映射到 1D Array，由於 simulator.ruleMatrix 變更時，
    // ParticleSimulator 內部的 didSet 已經處理了 updateRuleMatrixBuffer()，因此不需手動更新
    private func matrixBinding(row: Int, col: Int) -> Binding<Float> {
        let index = row * simulator.numTypes + col
        return Binding(
            get: { simulator.ruleMatrix[index] },
            set: { newValue in
                simulator.ruleMatrix[index] = newValue
            }
        )
    }
    
    // MARK: - 輔助視圖與功能
    
    // 參數滑桿元件
    private func paramSlider(title: String, value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%.3f", value.wrappedValue))
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
            Slider(value: value, in: range)
        }
    }
    
    // 隨機化矩陣功能
    private func randomizeRules() {
        let size = simulator.numTypes * simulator.numTypes
        simulator.ruleMatrix = (0..<size).map { _ in Float.random(in: -1...1) }
    }
}
