import SwiftUI

enum ColorPaletteGenerator {
    
    // MARK: - 完整註冊表 (對應 colorsGenerator.ts 的 37 種色票)
    static let palettes: [PaletteOption] = [
        // Default
        PaletteOption(id: 0, name: "Random", category: "Default"),
        
        // Static (固定漸層與色相)
        PaletteOption(id: 1, name: "Rainbow", category: "Static"),
        PaletteOption(id: 2, name: "Neon Warm", category: "Static"),
        PaletteOption(id: 3, name: "Heatmap Classic", category: "Static"),
        PaletteOption(id: 4, name: "Heatmap Cool", category: "Static"),
        PaletteOption(id: 5, name: "Heatmap Warm", category: "Static"),
        PaletteOption(id: 6, name: "Pastel", category: "Static"),
        PaletteOption(id: 7, name: "Cold Blue", category: "Static"),
        PaletteOption(id: 8, name: "Sci-Fi Spectrum", category: "Static"),
        PaletteOption(id: 9, name: "Thermal Glow", category: "Static"),
        PaletteOption(id: 10, name: "Crimson Flame", category: "Static"),
        PaletteOption(id: 11, name: "Fire", category: "Static"),
        PaletteOption(id: 12, name: "Violet Fade", category: "Static"),
        PaletteOption(id: 13, name: "Grayscale", category: "Static"),
        PaletteOption(id: 14, name: "Desert Warm", category: "Static"),
        
        // Generative (每次點擊都會產生新的主題變化)
        PaletteOption(id: 15, name: "Dual Gradient", category: "Generative"),
        PaletteOption(id: 16, name: "Candy", category: "Generative"),
        PaletteOption(id: 17, name: "Organic Flow", category: "Generative"),
        PaletteOption(id: 18, name: "Earth Flow", category: "Generative"),
        PaletteOption(id: 19, name: "Game Boy DMG", category: "Generative"),
        PaletteOption(id: 20, name: "Paper & Ink", category: "Generative"),
        PaletteOption(id: 21, name: "Fluoro Sport", category: "Generative"),
        PaletteOption(id: 22, name: "Midnight Circuit", category: "Generative"),
        PaletteOption(id: 23, name: "BioLuminescent Abyss", category: "Generative"),
        PaletteOption(id: 24, name: "Blueprint", category: "Generative"),
        PaletteOption(id: 25, name: "Cyber Dark", category: "Generative"),
        
        // Experimental (實驗性生成式色票)
        PaletteOption(id: 26, name: "Holographic Foil", category: "Experimental"),
        PaletteOption(id: 36, name: "Holographic Foil 2", category: "Experimental"),
        PaletteOption(id: 27, name: "Mineral Gemstones", category: "Experimental"),
        PaletteOption(id: 28, name: "Vaporwave Pastel", category: "Experimental"),
        PaletteOption(id: 29, name: "Solarized Drift", category: "Experimental"),
        PaletteOption(id: 30, name: "Aurora", category: "Experimental"),
        PaletteOption(id: 31, name: "Cyber Neon", category: "Experimental"),
        PaletteOption(id: 32, name: "Golden Angle Jitter", category: "Experimental"),
        PaletteOption(id: 33, name: "CMYK Misregister", category: "Experimental"),
        PaletteOption(id: 34, name: "Anodized Metal", category: "Experimental"),
        PaletteOption(id: 35, name: "Ink Bleed Watercolor", category: "Experimental")
    ]
    
    static let categories = ["Default", "Static", "Generative", "Experimental"]
    
    // MARK: - 主生成路由入口
    static func generateColors(optionID: Int, numTypes: Int) -> [Color] {
        guard numTypes > 0 else { return [] }
        
        if optionID <= 14 {
            return generateStaticPalette(optionID: optionID, numTypes: numTypes)
        } else {
            return generateDynamicPalette(optionID: optionID, numTypes: numTypes)
        }
    }
}
