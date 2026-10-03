import SwiftUI

struct RuleMatrixView: View {
    @Environment(ParticleSimulator.self) private var simulator
    
    enum MatrixTab: String, CaseIterable {
        case forces = "Forces"
        case minRadius = "Min. Radius"
        case maxRadius = "Max. Radius"
        
        var helpTitle: String {
            switch self {
            case .forces: return "作用力矩陣 (Forces)"
            case .minRadius: return "最小排斥半徑 (Min. Radius)"
            case .maxRadius: return "最大感知半徑 (Max. Radius)"
            }
        }
        
        var helpText: String {
            switch self {
            case .forces:
                return "設定特定粒子間的吸引力（正值青色）與排斥力（負值紅色）。可點選單一格、整列、整欄或全選進行微調。"
            case .minRadius:
                return "設定特定粒子配對的核心排斥距離（rMin）。當兩顆粒子距離小於此數值時會產生無條件排斥，可針對單一配對（如 T1 → T1）獨立調整。"
            case .maxRadius:
                return "設定特定粒子配對的引力感知距離（rMax）。上限鎖定為 125（對應單一網格寬度 0.125），可針對不同顏色配對獨立調整視力範圍。"
            }
        }
    }
    
    enum MatrixSelection: Equatable {
        case all
        case row(Int)
        case col(Int)
        case cell(row: Int, col: Int)
    }
    
    @State private var selectedTab: MatrixTab = .forces
    @State private var selection: MatrixSelection = .cell(row: 0, col: 0)
    @State private var activeHelpTab: MatrixTab? = nil
    
    var body: some View {
        let count = simulator.numTypes
        let cellSize: CGFloat = count <= 6 ? 46 : 36
        
        VStack(alignment: .leading, spacing: 18) {
            
            // MARK: - 1. 標題列與「隨機引力規則」、「全部歸零」按鈕
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
                
                // ✨ 移過來的「隨機引力規則」按鈕（位於全部歸零左邊）
                Button("隨機引力規則") {
                    simulator.randomizeRules()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Button(selectedTab == .forces ? "全部歸零" : "重置半徑") {
                    switch selectedTab {
                    case .forces:
                        simulator.setAllRules(value: 0.0)
                    case .minRadius:
                        simulator.setAllMinRadius(value: 0.035)
                    case .maxRadius:
                        simulator.setAllMaxRadius(value: 0.120)
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // MARK: - 2. 頂部模式切換器 + Popover 說明氣泡
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
            
            // MARK: - 3. 2D 互動式矩陣網格 (Heat Map Grid)
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
            
            Spacer(minLength: 0)
            
            // MARK: - 4. 底部控制列
            HStack(spacing: 14) {
                Button {
                    selection = .all
                } label: {
                    Text(selectionTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(width: 105)
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
                
                Text(formattedSliderValue)
                    .font(.system(.subheadline, design: .monospaced).bold())
                    .foregroundStyle(.black)
                    .frame(width: 64)
                    .padding(.vertical, 6)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(35)
        .onChange(of: count) { _, newCount in
            switch selection {
            case .row(let r) where r >= newCount:
                selection = .all
            case .col(let c) where c >= newCount:
                selection = .all
            case .cell(let r, let c) where r >= newCount || c >= newCount:
                selection = .cell(row: 0, col: 0)
            default:
                break
            }
        }
    }
    
    // MARK: - 視覺與邏輯輔助計算
    
    private func isCellHighlighted(row: Int, col: Int) -> Bool {
        switch selection {
        case .all: return true
        case .row(let r): return r == row
        case .col(let c): return c == col
        case .cell(let r, let c): return r == row && c == col
        }
    }
    
    private func cellColor(row: Int, col: Int) -> Color {
        switch selectedTab {
        case .forces:
            let val = Double(simulator.getRule(from: row, to: col))
            let intensity = min(1.0, abs(val))
            if val > 0.01 {
                return Color(red: 0.02, green: 0.12 + 0.58 * intensity, blue: 0.16 + 0.68 * intensity)
            } else if val < -0.01 {
                return Color(red: 0.15 + 0.72 * intensity, green: 0.04, blue: 0.08)
            } else {
                return Color(red: 0.06, green: 0.08, blue: 0.10)
            }
            
        case .minRadius:
            let val = Double(simulator.getMinRadius(from: row, to: col))
            let intensity = max(0.0, min(1.0, (val - 0.005) / (0.080 - 0.005)))
            return Color(red: 0.02, green: 0.08 + 0.65 * intensity, blue: 0.12 + 0.75 * intensity)
            
        case .maxRadius:
            let val = Double(simulator.getMaxRadius(from: row, to: col))
            let intensity = max(0.0, min(1.0, (val - 0.040) / (0.125 - 0.040)))
            return Color(red: 0.12 + 0.75 * intensity, green: 0.04, blue: 0.08)
        }
    }
    
    private var selectionTitle: String {
        switch selection {
        case .all: return "All Types"
        case .row(let r): return "Row \(r + 1)"
        case .col(let c): return "Col \(c + 1)"
        case .cell(let r, let c): return "T\(r + 1) → T\(c + 1)"
        }
    }
    
    private var activeSliderBinding: Binding<Double> {
        Binding<Double>(
            get: {
                let (r, c): (Int, Int) = {
                    switch selection {
                    case .cell(let row, let col): return (row, col)
                    case .row(let row): return (row, 0)
                    case .col(let col): return (0, col)
                    case .all: return (0, 0)
                    }
                }()
                
                switch selectedTab {
                case .forces:
                    return Double(simulator.getRule(from: r, to: c))
                case .minRadius:
                    return Double(simulator.getMinRadius(from: r, to: c) * 1000.0)
                case .maxRadius:
                    return Double(simulator.getMaxRadius(from: r, to: c) * 1000.0)
                }
            },
            set: { newVal in
                switch selectedTab {
                case .forces:
                    let fVal = Float(newVal)
                    switch selection {
                    case .cell(let r, let c): simulator.setRule(from: r, to: c, value: fVal)
                    case .row(let r): simulator.setRowRules(row: r, value: fVal)
                    case .col(let c): simulator.setColRules(col: c, value: fVal)
                    case .all: simulator.setAllRules(value: fVal)
                    }
                case .minRadius:
                    let fVal = Float(newVal) / 1000.0
                    switch selection {
                    case .cell(let r, let c): simulator.setMinRadius(from: r, to: c, value: fVal)
                    case .row(let r): simulator.setRowMinRadius(row: r, value: fVal)
                    case .col(let c): simulator.setColMinRadius(col: c, value: fVal)
                    case .all: simulator.setAllMinRadius(value: fVal)
                    }
                case .maxRadius:
                    let fVal = Float(newVal) / 1000.0
                    switch selection {
                    case .cell(let r, let c): simulator.setMaxRadius(from: r, to: c, value: fVal)
                    case .row(let r): simulator.setRowMaxRadius(row: r, value: fVal)
                    case .col(let c): simulator.setColMaxRadius(col: c, value: fVal)
                    case .all: simulator.setAllMaxRadius(value: fVal)
                    }
                }
            }
        )
    }
    
    private var sliderRange: ClosedRange<Double> {
        switch selectedTab {
        case .forces: return -1.0...1.0
        case .minRadius: return 5.0...80.0
        case .maxRadius: return 40.0...125.0
        }
    }
    
    private var sliderStep: Double {
        switch selectedTab {
        case .forces: return 0.05
        case .minRadius, .maxRadius: return 1.0
        }
    }
    
    private var sliderTintColor: Color {
        switch selectedTab {
        case .forces:
            return activeSliderBinding.wrappedValue >= 0 ? .cyan : .red
        case .minRadius:
            return .cyan
        case .maxRadius:
            return .red
        }
    }
    
    private var formattedSliderValue: String {
        switch selectedTab {
        case .forces:
            return String(format: "%+.2f", activeSliderBinding.wrappedValue)
        case .minRadius, .maxRadius:
            return String(format: "%.0f", activeSliderBinding.wrappedValue)
        }
    }
}
