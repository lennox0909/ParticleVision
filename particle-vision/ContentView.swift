import SwiftUI
import RealityKit

struct ContentView: View {
    @Environment(ParticleSimulator.self) private var simulator
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    
    var body: some View {
        @Bindable var bindableSim = simulator
        
        VStack(alignment: .leading, spacing: 8) {
            
            // MARK: - 1. 頂部標題列 + FPS 狀態膠囊
            HStack(alignment: .center) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.cyan)
                
                Text("Particle Life 控制台")
                    .font(.title3.weight(.bold))
                
                Spacer()
                
                // FPS 即時監控膠囊標籤
                HStack(spacing: 6) {
                    Circle()
                        .fill(fpsStatusColor)
                        .frame(width: 7, height: 7)
                    Text("FPS \(simulator.currentFPS)")
                        .font(.system(.caption2, design: .monospaced).bold())
                        .foregroundStyle(.primary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.35), in: Capsule())
                .overlay(
                    Capsule().stroke(fpsStatusColor.opacity(0.5), lineWidth: 1)
                )
            }
            .padding(.top, 2)
            
            // MARK: - 2. 獨立視窗開啟 / 關閉 + 手部互動模式控制列
            HStack(spacing: 8) {
                Toggle(isOn: $bindableSim.showColorWindow) {
                    Label("Color Scheme", systemImage: "paintpalette.fill")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                }
                .toggleStyle(.button)
                .tint(.cyan)
                .controlSize(.small)
                .onChange(of: simulator.showColorWindow) { _, shouldOpen in
                    if shouldOpen {
                        openWindow(id: "ColorSchemeWindow")
                    } else {
                        dismissWindow(id: "ColorSchemeWindow")
                    }
                }
                
                Toggle(isOn: $bindableSim.showMatrixWindow) {
                    Label("Matrix Settings", systemImage: "grid")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 3)
                }
                .toggleStyle(.button)
                .tint(.cyan)
                .controlSize(.small)
                .onChange(of: simulator.showMatrixWindow) { _, shouldOpen in
                    if shouldOpen {
                        openWindow(id: "MatrixSettingsWindow")
                    } else {
                        dismissWindow(id: "MatrixSettingsWindow")
                    }
                }
            }
            
            // MARK: - 3. 透明盒子手部操作 vs 神之手力場切換橫幅（告別刺眼全白按鈕）
            Button {
                simulator.isBoxInteractionEnabled.toggle()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: simulator.isBoxInteractionEnabled ? "hand.draw.fill" : "wand.and.stars")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(simulator.isBoxInteractionEnabled ? .cyan : .orange)
                    
                    Text(simulator.isBoxInteractionEnabled ? "手勢模式：允許搬移與縮放透明盒子" : "手勢模式：已鎖定盒子 (雙手神之手力場啟用中)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Text(simulator.isBoxInteractionEnabled ? "點擊鎖定 🔒" : "點擊解鎖 🖐️")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            (simulator.isBoxInteractionEnabled ? Color.cyan : Color.orange).opacity(0.22),
                            in: Capsule()
                        )
                        .foregroundStyle(simulator.isBoxInteractionEnabled ? .cyan : .orange)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.28))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke((simulator.isBoxInteractionEnabled ? Color.cyan : Color.orange).opacity(0.45), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
            
            // MARK: - 4. 核心參數控制面板（宇宙規模 / 時空邊界 / 透明盒子外觀）
            ControlPanelView()
            
            Spacer(minLength: 0)
            
            // MARK: - 5. 底部 3D 空間啟動鈕（置中並保留底部呼吸空間）
            HStack {
                Spacer()
                ToggleImmersiveSpaceButton()
                    .controlSize(.regular)
                Spacer()
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
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
