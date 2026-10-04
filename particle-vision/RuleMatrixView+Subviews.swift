import SwiftUI

extension RuleMatrixView {
    
    // MARK: - 1. 標題列與「隨機引力規則」、「全部歸零 / 重置半徑」按鈕
    var headerSection: some View {
        HStack(spacing: 10) {
            Image(systemName: "grid")
                .font(.title2)
                .foregroundStyle(.cyan)
            Text("Matrix Settings")
                .font(.title2)
                .fontWeight(.bold)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            
            Spacer()
            
            Button("隨機引力規則") {
                simulator.randomizeRules()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button(selectedTab == .forces ? "全部歸零" : "重置半徑") {
                resetCurrentTabValues()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
    
    // MARK: - 2. 頂部模式切換器 + Popover 說明氣泡
    var tabPickerSection: some View {
        HStack(spacing: 6) {
            ForEach(MatrixTab.allCases, id: \.self) { tab in
                HStack(spacing: 4) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedTab == tab ? .bold : .medium)
                            .padding(.leading, 8)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        activeHelpTab = tab
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.caption)
                            .foregroundStyle(selectedTab == tab ? .primary : .secondary)
                            .padding(.trailing, 8)
                            .padding(.vertical, 8)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: Binding(
                        get: { activeHelpTab == tab },
                        set: { if !$0 { activeHelpTab = nil } }
                    ), arrowEdge: .top) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundStyle(.cyan)
                                Text(tab.helpTitle)
                                    .font(.headline)
                            }
                            Text(tab.helpText)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(18)
                        .frame(width: 280)
                    }
                }
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(selectedTab == tab ? Color.white.opacity(0.18) : Color.clear)
                )
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.25), in: RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - 3. 2D 互動式矩陣網格 (Heat Map Grid)
    func matrixGridSection(count: Int, cellSize: CGFloat) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Button {
                    selection = .all
                } label: {
                    Circle()
                        .fill(Color.black.opacity(0.85))
                        .frame(width: cellSize * 0.82, height: cellSize * 0.82)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: selection == .all ? 2.5 : 0.5)
                        )
                }
                .buttonStyle(.plain)
                .frame(width: cellSize, height: cellSize)
                
                ForEach(0..<count, id: \.self) { col in
                    Button {
                        selection = .col(col)
                    } label: {
                        Circle()
                            .fill(simulator.colorForType(col))
                            .frame(width: cellSize * 0.82, height: cellSize * 0.82)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selection == .col(col) ? 3 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(width: cellSize, height: cellSize)
                }
            }
            
            ForEach(0..<count, id: \.self) { row in
                HStack(spacing: 4) {
                    Button {
                        selection = .row(row)
                    } label: {
                        Circle()
                            .fill(simulator.colorForType(row))
                            .frame(width: cellSize * 0.82, height: cellSize * 0.82)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: selection == .row(row) ? 3 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                    .frame(width: cellSize, height: cellSize)
                    
                    ForEach(0..<count, id: \.self) { col in
                        let isSelected = isCellHighlighted(row: row, col: col)
                        
                        Button {
                            selection = .cell(row: row, col: col)
                        } label: {
                            Rectangle()
                                .fill(cellColor(row: row, col: col))
                                .frame(width: cellSize, height: cellSize)
                                .overlay(
                                    Rectangle()
                                        .stroke(
                                            isSelected ? Color.white : Color.black.opacity(0.4),
                                            lineWidth: isSelected ? 2.0 : 0.5
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - 4. ✨ 即時物理環境：空間摩擦力控制卡片（位於矩陣熱力圖網格正下方）
    var frictionControlSection: some View {
        @Bindable var bindableSimulator = simulator
        
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("即時物理環境", systemImage: "wind")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("即時生效")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("空間摩擦力")
                        .font(.subheadline.weight(.medium))
                    Spacer()
                    Text(String(format: "%.2f", simulator.friction))
                        .font(.system(.subheadline, design: .monospaced).bold())
                        .foregroundStyle(.cyan)
                }
                
                HStack(spacing: 10) {
                    Slider(value: $bindableSimulator.friction, in: 0.01...0.99, step: 0.01)
                        .tint(.cyan)
                    
                    Button {
                        let next = max(0.01, simulator.friction - 0.01)
                        simulator.friction = (next * 100).rounded() / 100
                    } label: {
                        Image(systemName: "minus")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    
                    Button {
                        let next = min(0.99, simulator.friction + 0.01)
                        simulator.friction = (next * 100).rounded() / 100
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                }
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.22), in: RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - 5. 底部控制列 (包含滑桿與 － / ＋ 精準微調按鈕)
    var bottomControlSection: some View {
        HStack(spacing: 10) {
            Button {
                selection = .all
            } label: {
                Text(selectionTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(width: 90)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selection == .all ? Color.cyan.opacity(0.25) : Color.black.opacity(0.35))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selection == .all ? Color.cyan : Color.white.opacity(0.25), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            
            Slider(
                value: activeSliderBinding,
                in: sliderRange,
                step: sliderStep
            )
            .tint(sliderTintColor)
            
            Button {
                adjustSliderValue(by: -sliderStep)
            } label: {
                Image(systemName: "minus")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.small)
            
            Button {
                adjustSliderValue(by: sliderStep)
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.circle)
            .controlSize(.small)
            
            Text(formattedSliderValue)
                .font(.system(.subheadline, design: .monospaced).bold())
                .foregroundStyle(.black)
                .frame(width: 60)
                .padding(.vertical, 6)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
        }
    }
}
