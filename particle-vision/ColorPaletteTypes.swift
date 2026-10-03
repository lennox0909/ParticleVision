import Foundation

struct PaletteOption: Identifiable, Equatable {
    let id: Int
    let name: String
    let category: String
}

struct KeyColor {
    let t: Double
    let r: Double
    let g: Double
    let b: Double
}
