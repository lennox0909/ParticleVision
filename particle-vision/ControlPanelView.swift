import SwiftUI

struct ControlPanelView: View {
    @Environment(ParticleSimulator.self) private var simulator
    
    @State private var particleCount: Double = 50000
    @State private var numTypes: Double = 6
    
    private var hasPendingChanges: Bool {
        Int(particleCount) != simulator.particleCount || Int(numTypes) != simulator.numTypes
    }
    
    var body: some View {
        @Bindable var bindableSimulator = simulator
        
        VStack(spacing: 8) {
            
            // MARK: - 區塊 1：宇宙規模設定（需點擊重置套用）
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Label("宇宙規模設定", systemImage: "cube.transparent")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if hasPendingChanges {
                        Text("● 尚未套用變更")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.orange)
                    }
                }
                
                // 1. 粒子數量（單行緊湊滑桿）
                HStack(spacing: 10) {
                    Text("粒子數量")
                        .font(.caption.weight(.medium))
                        .frame(width: 56, alignment: .leading)
                    Slider(value: $particleCount, in: 1000...100000, step: 1000)
                        .controlSize(.small)
                    Text("\(Int(particleCount).formatted())")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(.cyan)
                        .frame(width: 54, alignment: .trailing)
                }
                
                // 2. 粒子種類（單行緊湊滑桿）
                HStack(spacing: 10) {
                    Text("粒子種類")
                        .font(.caption.weight(.medium))
                        .frame(width: 56, alignment: .leading)
                    Slider(value: $numTypes, in: 2...8, step: 1)
                        .controlSize(.small)
                    Text("\(Int(numTypes)) 種")
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(.cyan)
                        .frame(width: 54, alignment: .trailing)
                }
                
                // 套用並重置宇宙按鈕
                Button {
                    simulator.resetSimulation(newCount: Int(particleCount), newTypes: Int(numTypes))
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("套用並重置宇宙")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 1)
                }
                .buttonStyle(.borderedProminent)
                .tint(hasPendingChanges ? .orange : .white.opacity(0.18))
                .controlSize(.small)
                .padding(.top, 1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 14))
            
            // MARK: - 區塊 2：時空流速、邊界物理與中心引力奇點 (Black Hole Singularity)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Label("時空、邊界與中心奇點", systemImage: "hurricane")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    
                    // 快速倍速選擇鍵 (0.2x 超慢動作 / 1.0x 正常 / 2.0x 快轉)
                    HStack(spacing: 4) {
                        ForEach([Float(0.2), Float(1.0), Float(2.0)], id: \.self) { speed in
                            Button {
                                simulator.isPaused = false
                                simulator.timeScale = speed
                            } label: {
                                Text(String(format: "%.1fx", speed))
                                    .font(.system(.caption2, design: .monospaced).bold())
                                    .padding(.horizontal, 5)
                            }
                            .buttonStyle(.bordered)
                            .tint(!simulator.isPaused && abs(simulator.timeScale - speed) < 0.05 ? .cyan : .secondary)
                            .controlSize(.mini)
                        }
                    }
                }
                
                // 1. 暫停凍結按鈕 + 單行時間流速滑桿
                HStack(spacing: 8) {
                    Button {
                        simulator.isPaused.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: simulator.isPaused ? "play.fill" : "pause.fill")
                            Text(simulator.isPaused ? "恢復演化" : "凍結時間")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(width: 82)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(simulator.isPaused ? .orange : .cyan.opacity(0.35))
                    .controlSize(.small)
                    
                    Slider(value: $bindableSimulator.timeScale, in: 0.1...2.0, step: 0.1)
                        .tint(.cyan)
                        .controlSize(.small)
                        .disabled(simulator.isPaused)
                    
                    Text(simulator.isPaused ? "0.0x" : String(format: "%.1fx", simulator.timeScale))
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(simulator.isPaused ? .orange : .cyan)
                        .frame(width: 38, alignment: .trailing)
                }
                
                // 2. 宇宙邊界物理模式切換 (彈性撈網 vs 無縫穿越)
                Picker("邊界模式", selection: $bindableSimulator.isWrapBoundary) {
                    Text("📦 彈性撈網邊界 (Bounce)").tag(false)
                    Text("♾️ 無縫環形穿越 (Wrap)").tag(true)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                
                // ✨ 3. 中心引力奇點模式切換 (關閉 / 星系吸積旋渦 / 黑洞雙極噴流)
                Picker("中心奇點", selection: $bindableSimulator.singularityMode) {
                    Text("關閉奇點").tag(0)
                    
                    // 使用 HStack 組合 Image (透明圓球) 與 Text
                    HStack {
                        Image(systemName: "circle") // 代表透明的玻璃圓球
                        Text("吸積盤旋渦")
                    }.tag(1)
                    
                    HStack {
                         Image(systemName: "circle") // 代表透明的玻璃圓球
                         Text("黑洞雙極噴流")
                    }.tag(2)
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
                
                // 當啟用中心奇點時，顯示奇點重力強度滑桿
                if simulator.singularityMode > 0 {
                    HStack(spacing: 8) {
                        Text(simulator.singularityMode == 1 ? "旋渦強度" : "黑洞質量")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(simulator.singularityMode == 1 ? .cyan : .purple)
                            .frame(width: 56, alignment: .leading)
                        
                        Slider(value: $bindableSimulator.singularityStrength, in: 0.2...3.0, step: 0.1)
                            .tint(simulator.singularityMode == 1 ? .cyan : .purple)
                            .controlSize(.small)
                        
                        Text(String(format: "%.1fx", simulator.singularityStrength))
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(simulator.singularityMode == 1 ? .cyan : .purple)
                            .frame(width: 38, alignment: .trailing)
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 14))
            .animation(.easeInOut(duration: 0.2), value: simulator.singularityMode)
            
            // MARK: - 區塊 3：透明盒子邊框顏色（全黑~灰階~全白）與粗細調整
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Label("透明盒子外觀", systemImage: "squareshape.split.2x2")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("自動記憶設定")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                // 1. 邊框顏色
                HStack(spacing: 8) {
                    Text("邊框顏色")
                        .font(.caption.weight(.medium))
                        .frame(width: 56, alignment: .leading)
                    
                    Slider(value: $bindableSimulator.boxEdgeGrayscale, in: 0.0...1.0, step: 0.01)
                        .tint(Color(white: Double(max(0.35, simulator.boxEdgeGrayscale))))
                        .controlSize(.small)
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color(white: Double(simulator.boxEdgeGrayscale)))
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white.opacity(0.5), lineWidth: 1))
                        Text(edgeColorLabel)
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(.cyan)
                    }
                    .frame(width: 52, alignment: .trailing)
                    
                    Button {
                        let next = max(0.0, simulator.boxEdgeGrayscale - 0.05)
                        simulator.boxEdgeGrayscale = (next * 100).rounded() / 100
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.mini)
                    
                    Button {
                        let next = min(1.0, simulator.boxEdgeGrayscale + 0.05)
                        simulator.boxEdgeGrayscale = (next * 100).rounded() / 100
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.mini)
                }
                
                // 2. 邊框粗細
                HStack(spacing: 8) {
                    Text("邊框粗細")
                        .font(.caption.weight(.medium))
                        .frame(width: 56, alignment: .leading)
                    
                    Slider(value: $bindableSimulator.boxEdgeThickness, in: 0.002...0.050, step: 0.001)
                        .tint(.cyan)
                        .controlSize(.small)
                    
                    Text(String(format: "%.3f", simulator.boxEdgeThickness))
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundStyle(.cyan)
                        .frame(width: 52, alignment: .trailing)
                    
                    Button {
                        let next = max(0.002, simulator.boxEdgeThickness - 0.002)
                        simulator.boxEdgeThickness = (next * 1000).rounded() / 1000
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.mini)
                    
                    Button {
                        let next = min(0.050, simulator.boxEdgeThickness + 0.002)
                        simulator.boxEdgeThickness = (next * 1000).rounded() / 1000
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.mini)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 14))
        }
        .onAppear {
            particleCount = Double(simulator.particleCount)
            numTypes = Double(simulator.numTypes)
        }
        .onChange(of: simulator.numTypes) { _, newTypes in
            numTypes = Double(newTypes)
        }
    }
    
    private var edgeColorLabel: String {
        let pct = Int((simulator.boxEdgeGrayscale * 100).rounded())
        return "\(pct)%"
    }
}
