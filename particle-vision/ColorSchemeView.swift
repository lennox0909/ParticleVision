import SwiftUI

struct ColorSchemeView: View {
    @Environment(ParticleSimulator.self) private var simulator
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismissWindow) private var dismissWindow
    @State private var showHelpPopover: Bool = false
    
    var body: some View {
        let count = simulator.numTypes
        
        VStack(alignment: .leading, spacing: 18) {
            
            // MARK: - 1. 標題列與 ⓘ 說明氣泡 + 重新骰色按鈕
            HStack(spacing: 8) {
                Image(systemName: "paintpalette.fill")
                    .font(.title2)
                    .foregroundStyle(.cyan)
                
                Text("Color Scheme")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Button {
                    showHelpPopover.toggle()
                } label: {
                    Image(systemName: "info.circle")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(4)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showHelpPopover, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Choose from static or generative color palette generators.")
                            .font(.callout)
                        Text("**Static** palettes are fixed, while **generative** ones produce new themed variations each time.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .padding(18)
                    .frame(width: 290)
                }
                
                Spacer()
                
                Button {
                    simulator.applyPalette(id: simulator.selectedPaletteID)
                } label: {
                    Image(systemName: "dice.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("重新生成當前色票變化")
            }
            
            // MARK: - 2. 當前啟用的粒子色票預覽列
            VStack(alignment: .leading, spacing: 8) {
                Text("目前套用色票 (\(currentPaletteName)):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 10) {
                    ForEach(0..<count, id: \.self) { typeIdx in
                        Circle()
                            .fill(simulator.colorForType(typeIdx))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Circle().stroke(Color.white.opacity(0.4), lineWidth: 1)
                            )
                    }
                    Spacer()
                }
                .padding(12)
                .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
            }
            
            Divider()
            
            // MARK: - 3. 分類捲動色票選單
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(ColorPaletteGenerator.categories, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Text(category.uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.secondary)
                                
                                if category != "Static" {
                                    Text("✨ 隨機變體")
                                        .font(.caption2)
                                        .foregroundStyle(.cyan.opacity(0.8))
                                }
                            }
                            .padding(.horizontal, 4)
                            
                            let options = ColorPaletteGenerator.palettes.filter { $0.category == category }
                            
                            ForEach(options) { option in
                                let isSelected = (simulator.selectedPaletteID == option.id)
                                
                                Button {
                                    simulator.applyPalette(id: option.id)
                                } label: {
                                    HStack {
                                        Text(option.name)
                                            .font(.subheadline)
                                            .fontWeight(isSelected ? .bold : .regular)
                                            .foregroundStyle(isSelected ? .white : .primary)
                                        
                                        Spacer()
                                        
                                        if isSelected {
                                            Image(systemName: option.category == "Static" ? "checkmark.circle.fill" : "sparkles")
                                                .foregroundStyle(.cyan)
                                                .font(.subheadline)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(isSelected ? Color.cyan.opacity(0.28) : Color.black.opacity(0.20))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isSelected ? Color.cyan : Color.clear, lineWidth: 1.5)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.trailing, 6)
            }
        }
        .padding(35)
        // ✨ 當使用者按視窗底部的系統「✕」關閉時，自動將主控制台的按鈕跳回未選取狀態
        .onAppear {
            // ✨ 防呆機制：如果是系統重開 App 時誤把子視窗叫出來（此時按鈕狀態為 false），
            // 則立即關閉自己，並強制喚醒主控制台視窗！
            if !simulator.showColorWindow {
                openWindow(id: "MainControlWindow")
                dismissWindow(id: "ColorSchemeWindow")
            }
        }
        .onDisappear {
            simulator.showColorWindow = false
        }
    }
    
    private var currentPaletteName: String {
        ColorPaletteGenerator.palettes.first(where: { $0.id == simulator.selectedPaletteID })?.name ?? "Rainbow"
    }
}
