import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(ParticleSimulator.self) private var simulator
    
    // 控制左右兩側獨立毛玻璃視窗的顯隱（預設為 false 不顯示）
    @State private var showColorWindow: Bool = false
    @State private var showMatrixWindow: Bool = false
    
    var body: some View {
        HStack(alignment: .center, spacing: 30) {
            
            // 1. 左側獨立毛玻璃視窗：Color Scheme 選擇器
            ColorSchemeView()
                .frame(width: 380, height: 740)
                .glassBackgroundEffect(
                    in: RoundedRectangle(cornerRadius: 32, style: .continuous),
                    displayMode: showColorWindow ? .always : .never
                )
                .opacity(showColorWindow ? 1.0 : 0.0)
                .allowsHitTesting(showColorWindow)
                .animation(.easeInOut(duration: 0.25), value: showColorWindow)
            
            // 2. 中間主視窗：Particle Life 控制台
            VStack(alignment: .leading, spacing: 18) {
                
                // MARK: - 頂部標題列 + FPS 狀態膠囊
                HStack(alignment: .center) {
                    Image(systemName: "sparkles")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                    
                    Text("Particle Life 控制台")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    // FPS 即時監控膠囊標籤
                    HStack(spacing: 6) {
                        Circle()
                            .fill(fpsStatusColor)
                            .frame(width: 8, height: 8)
                        Text("FPS \(simulator.currentFPS)")
                            .font(.system(.caption, design: .monospaced).bold())
                            .foregroundStyle(.primary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.3), in: Capsule())
                    .overlay(
                        Capsule().stroke(fpsStatusColor.opacity(0.5), lineWidth: 1)
                    )
                }
                
                // MARK: - 左右面板展開切換按鈕
                HStack(spacing: 12) {
                    Toggle(isOn: $showColorWindow) {
                        Label("Color Scheme", systemImage: "paintpalette.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .toggleStyle(.button)
                    .tint(.cyan)
                    
                    Toggle(isOn: $showMatrixWindow) {
                        Label("Matrix Settings", systemImage: "grid")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .toggleStyle(.button)
                    .tint(.cyan)
                }
                
                // MARK: - 核心參數控制面板
                ControlPanelView()
                
                Spacer(minLength: 0)
                
                // MARK: - 底部 3D 空間啟動鈕（置中）
                HStack {
                    Spacer()
                    ToggleImmersiveSpaceButton()
                    Spacer()
                }
            }
            .padding(35)
            .frame(width: 500, height: 740)
            .glassBackgroundEffect()
            
            // 3. 右側獨立毛玻璃視窗：Matrix Settings 編輯器
            RuleMatrixView()
                .frame(width: 480, height: 740)
                .glassBackgroundEffect(
                    in: RoundedRectangle(cornerRadius: 32, style: .continuous),
                    displayMode: showMatrixWindow ? .always : .never
                )
                .opacity(showMatrixWindow ? 1.0 : 0.0)
                .allowsHitTesting(showMatrixWindow)
                .animation(.easeInOut(duration: 0.25), value: showMatrixWindow)
        }
        .padding(20)
        .frame(width: 1480, height: 780)
    }
    
    /// 根據當前 FPS 自動切換指示燈顏色
    private var fpsStatusColor: Color {
        if simulator.currentFPS >= 75 {
            return .green
        } else if simulator.currentFPS >= 50 {
            return .yellow
        } else if simulator.currentFPS > 0 {
            return .orange
        } else {
            return .secondary
        }
    }
}
