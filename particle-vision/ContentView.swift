import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(ParticleSimulator.self) private var simulator
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        @Bindable var bindableSim = simulator
        
        VStack(alignment: .leading, spacing: 14) {
            
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
            
            // MARK: - 獨立視窗開啟 / 關閉切換按鈕
            HStack(spacing: 12) {
                Toggle(isOn: $bindableSim.showColorWindow) {
                    Label("Color Scheme", systemImage: "paintpalette.fill")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .toggleStyle(.button)
                .tint(.cyan)
                .onChange(of: simulator.showColorWindow) { _, shouldOpen in
                    if shouldOpen {
                        openWindow(id: "ColorSchemeWindow")
                    } else {
                        dismissWindow(id: "ColorSchemeWindow")
                    }
                }
                
                Toggle(isOn: $bindableSim.showMatrixWindow) {
                    Label("Matrix Settings", systemImage: "grid")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                }
                .toggleStyle(.button)
                .tint(.cyan)
                .onChange(of: simulator.showMatrixWindow) { _, shouldOpen in
                    if shouldOpen {
                        openWindow(id: "MatrixSettingsWindow")
                    } else {
                        dismissWindow(id: "MatrixSettingsWindow")
                    }
                }
            }
            
            // MARK: - 透明盒子手部操作防誤觸開關
            Toggle(isOn: $bindableSim.isBoxInteractionEnabled) {
                HStack(spacing: 8) {
                    Image(systemName: simulator.isBoxInteractionEnabled ? "hand.draw.fill" : "lock.fill")
                        .font(.subheadline)
                    Text(simulator.isBoxInteractionEnabled ? "允許手部操作透明盒子" : "已鎖定透明盒子 (防誤觸觀察模式)")
                        .font(.subheadline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
            }
            .toggleStyle(.button)
            .tint(simulator.isBoxInteractionEnabled ? .cyan : .orange)
            
            // MARK: - 核心參數控制面板（宇宙規模設定）
            ControlPanelView()
            
            Spacer(minLength: 0)
            
            // MARK: - 底部 3D 空間啟動鈕（置中）
            HStack {
                Spacer()
                ToggleImmersiveSpaceButton()
                Spacer()
            }
            .padding(.top, 2)
        }
        .padding(28)
        // ✨ 配合移除下半部卡片，將 minHeight 由 780 下調至 460，消除底部多餘空白
        .frame(minWidth: 460, maxWidth: .infinity, minHeight: 640, maxHeight: .infinity)
        .onDisappear {
            if simulator.showColorWindow {
                dismissWindow(id: "ColorSchemeWindow")
                simulator.showColorWindow = false
            }
            if simulator.showMatrixWindow {
                dismissWindow(id: "MatrixSettingsWindow")
                simulator.showMatrixWindow = false
            }
        }
    }
    
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
