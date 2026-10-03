import SwiftUI

struct RuleMatrixView: View {
    // 移除 private 以便讓拆分至其他檔案的 Extension 存取
    @Environment(ParticleSimulator.self) var simulator
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    
    @State var selectedTab: MatrixTab = .forces
    @State var selection: MatrixSelection = .cell(row: 0, col: 0)
    @State var activeHelpTab: MatrixTab? = nil
    
    var body: some View {
        let count = simulator.numTypes
        let cellSize: CGFloat = count <= 6 ? 46 : 36
        
        VStack(alignment: .leading, spacing: 18) {
            // 1. 頂部標題與重置按鈕列
            headerSection
            
            // 2. 模式切換器與 Popover 氣泡說明
            tabPickerSection
            
            // 3. 2D 互動式矩陣熱力圖網格
            matrixGridSection(count: count, cellSize: cellSize)
            
            Spacer(minLength: 0)
            
            // 4. 底部滑桿與 － / ＋ 精準微調控制列
            bottomControlSection
        }
        .padding(35)
        .onChange(of: count) { _, newCount in
            validateSelection(for: newCount)
        }
        .onAppear {
            if !simulator.showMatrixWindow {
                openWindow(id: "MainControlWindow")
                dismissWindow(id: "MatrixSettingsWindow")
            }
        }
        .onDisappear {
            simulator.showMatrixWindow = false
        }
    }
}
