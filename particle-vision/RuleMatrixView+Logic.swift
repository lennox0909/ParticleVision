import SwiftUI

extension RuleMatrixView {
    
    // MARK: - 動作與狀態驗證輔助
    
    func resetCurrentTabValues() {
        switch selectedTab {
        case .forces:
            simulator.setAllRules(value: 0.0)
        case .minRadius:
            simulator.setAllMinRadius(value: 0.035)
        case .maxRadius:
            simulator.setAllMaxRadius(value: 0.120)
        }
    }
    
    func validateSelection(for newCount: Int) {
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
    
    /// 處理 － / ＋ 按鈕點擊時的數值增減與邊界限制，並消除浮點數誤差
    func adjustSliderValue(by delta: Double) {
        let current = activeSliderBinding.wrappedValue
        let next = min(sliderRange.upperBound, max(sliderRange.lowerBound, current + delta))
        
        if selectedTab == .forces {
            activeSliderBinding.wrappedValue = (next * 100.0).rounded() / 100.0
        } else {
            activeSliderBinding.wrappedValue = next.rounded()
        }
    }
    
    // MARK: - 矩陣視覺輔助計算
    
    func isCellHighlighted(row: Int, col: Int) -> Bool {
        switch selection {
        case .all: return true
        case .row(let r): return r == row
        case .col(let c): return c == col
        case .cell(let r, let c): return r == row && c == col
        }
    }
    
    func cellColor(row: Int, col: Int) -> Color {
        switch selectedTab {
        case .forces:
            let val = Double(simulator.getRule(from: row, to: col))
            let intensity = min(1.0, abs(val))
            if val > 0.005 {
                return Color(red: 0.02, green: 0.12 + 0.58 * intensity, blue: 0.16 + 0.68 * intensity)
            } else if val < -0.005 {
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
    
    var selectionTitle: String {
        switch selection {
        case .all: return "All Types"
        case .row(let r): return "Row \(r + 1)"
        case .col(let c): return "Col \(c + 1)"
        case .cell(let r, let c): return "T\(r + 1) → T\(c + 1)"
        }
    }
    
    // MARK: - 滑桿資料雙向綁定與參數設定
    
    var activeSliderBinding: Binding<Double> {
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
    
    var sliderRange: ClosedRange<Double> {
        switch selectedTab {
        case .forces: return -1.0...1.0
        case .minRadius: return 5.0...80.0
        case .maxRadius: return 40.0...125.0
        }
    }
    
    /// Forces 每步 0.01；Min. Radius 與 Max. Radius 每步 1.0
    var sliderStep: Double {
        switch selectedTab {
        case .forces: return 0.01
        case .minRadius, .maxRadius: return 1.0
        }
    }
    
    var sliderTintColor: Color {
        switch selectedTab {
        case .forces:
            return activeSliderBinding.wrappedValue >= 0 ? .cyan : .red
        case .minRadius:
            return .cyan
        case .maxRadius:
            return .red
        }
    }
    
    var formattedSliderValue: String {
        switch selectedTab {
        case .forces:
            return String(format: "%+.2f", activeSliderBinding.wrappedValue)
        case .minRadius, .maxRadius:
            return String(format: "%.0f", activeSliderBinding.wrappedValue)
        }
    }
}
