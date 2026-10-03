import Foundation

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
