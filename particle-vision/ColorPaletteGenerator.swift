import SwiftUI

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
    
    // MARK: - 數學與色彩轉換輔助函式
    private static func clamp(_ val: Double, _ minVal: Double = 0.0, _ maxVal: Double = 1.0) -> Double {
        return min(maxVal, max(minVal, val))
    }
    
    private static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + (b - a) * t
    }
    
    private static func randRange(_ a: Double, _ b: Double) -> Double {
        return Double.random(in: min(a, b)...max(a, b))
    }
    
    /// Box–Muller 常態分佈亂數
    private static func randN(_ mu: Double = 0.0, _ sigma: Double = 1.0) -> Double {
        var u = 0.0
        var v = 0.0
        while u == 0.0 { u = Double.random(in: 0..<1) }
        while v == 0.0 { v = Double.random(in: 0..<1) }
        return mu + sigma * sqrt(-2.0 * log(u)) * cos(2.0 * .pi * v)
    }
    
    private static func posMod(_ x: Double, _ m: Double) -> Double {
        let r = x.truncatingRemainder(dividingBy: m)
        return r < 0 ? r + m : r
    }
    
    /// HSV (H: 0~360, S: 0~1, V: 0~1) 轉 SwiftUI Color
    private static func hsvColor(_ h: Double, _ s: Double, _ v: Double, scale: Double = 1.0) -> Color {
        let hueNorm = posMod(h, 360.0) / 360.0
        let sat = clamp(s)
        let val = clamp(v)
        
        let c = val * sat
        let x = c * (1.0 - abs((hueNorm * 6.0).truncatingRemainder(dividingBy: 2.0) - 1.0))
        let m = val - c
        
        var r = 0.0, g = 0.0, b = 0.0
        let seg = Int(hueNorm * 6.0) % 6
        switch seg {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        
        return Color(
            red: clamp((r + m) * scale),
            green: clamp((g + m) * scale),
            blue: clamp((b + m) * scale)
        )
    }
    
    private static func gradientPalette(_ numTypes: Int, _ keyColors: [KeyColor]) -> [Color] {
        guard numTypes > 0 else { return [] }
        let sorted = keyColors.sorted { $0.t < $1.t }
        var out: [Color] = []
        var k = 0
        
        for i in 0..<numTypes {
            let u = numTypes <= 1 ? 0.0 : Double(i) / Double(numTypes - 1)
            while k < sorted.count - 2 && u > sorted[k + 1].t {
                k += 1
            }
            let a = sorted[k]
            let b = sorted[k + 1]
            let span = max(1e-6, b.t - a.t)
            let v = (u - a.t) / span
            
            let r = clamp(lerp(a.r, b.r, v))
            let g = clamp(lerp(a.g, b.g, v))
            let bl = clamp(lerp(a.b, b.b, v))
            out.append(Color(red: r, green: g, blue: bl))
        }
        return out
    }
    
    private static func jitterPair(_ pair: (Double, Double), _ jStart: Double, _ jEnd: Double) -> (Double, Double) {
        var x = clamp(pair.0 + (Double.random(in: -1...1)) * jStart)
        var y = clamp(pair.1 + (Double.random(in: -1...1)) * jEnd)
        if y < x { swap(&x, &y) }
        return (x, y)
    }
    
    private static func fillSegment(
        count: Int,
        hMin: Double, hMax: Double,
        sMin: Double, sMax: Double,
        vMin: Double, vMax: Double,
        vCurveExp: Double? = nil
    ) -> [Color] {
        guard count > 0 else { return [] }
        let last = Double(max(1, count - 1))
        var segment: [Color] = []
        
        for i in 0..<count {
            let u = count == 1 ? 0.5 : Double(i) / last
            let h = hMin + (hMax - hMin) * u
            let s = clamp(sMin + (sMax - sMin) * u)
            let v: Double
            if let exp = vCurveExp {
                v = clamp(vMax - (vMax - vMin) * pow(u, exp))
            } else {
                v = clamp(vMin + (vMax - vMin) * u)
            }
            segment.append(hsvColor(h, s, v))
        }
        return segment
    }
    
    // MARK: - 主生成入口
    static func generateColors(optionID: Int, numTypes: Int) -> [Color] {
        guard numTypes > 0 else { return [] }
        
        switch optionID {
        case 0: // Random
            return (0..<numTypes).map { _ in
                Color(red: .random(in: 0...1), green: .random(in: 0...1), blue: .random(in: 0...1))
            }
        case 1: // Rainbow
            return (0..<numTypes).map { i in
                hsvColor((Double(i) / Double(numTypes)) * 360.0, 1.0, 1.0)
            }
        case 2: // Neon Warm
            return (0..<numTypes).map { i in
                let t = numTypes <= 1 ? 0.0 : Double(i) / Double(numTypes - 1)
                return hsvColor(lerp(20, 300, t), lerp(1.0, 0.7, t), lerp(1.0, 0.8, t))
            }
        case 3: // Heatmap Classic
            return gradientPalette(numTypes, [
                KeyColor(t: 0.00, r: 0.00, g: 0.00, b: 0.25),
                KeyColor(t: 0.25, r: 0.00, g: 0.80, b: 1.00),
                KeyColor(t: 0.50, r: 1.00, g: 1.00, b: 1.00),
                KeyColor(t: 0.75, r: 1.00, g: 1.00, b: 0.00),
                KeyColor(t: 1.00, r: 0.80, g: 0.00, b: 0.00)
            ])
        case 4: // Heatmap Cool
            return gradientPalette(numTypes, [
                KeyColor(t: 0.00, r: 0.05, g: 0.10, b: 0.35),
                KeyColor(t: 0.25, r: 0.10, g: 0.25, b: 0.85),
                KeyColor(t: 0.50, r: 0.00, g: 0.80, b: 0.80),
                KeyColor(t: 0.75, r: 1.00, g: 0.90, b: 0.10),
                KeyColor(t: 1.00, r: 1.00, g: 1.00, b: 1.00)
            ])
        case 5: // Heatmap Warm
            return gradientPalette(numTypes, [
                KeyColor(t: 0.00, r: 0.45, g: 0.00, b: 0.00),
                KeyColor(t: 0.25, r: 0.90, g: 0.20, b: 0.00),
                KeyColor(t: 0.55, r: 1.00, g: 0.65, b: 0.00),
                KeyColor(t: 0.80, r: 1.00, g: 0.90, b: 0.40),
                KeyColor(t: 1.00, r: 1.00, g: 1.00, b: 1.00)
            ])
        case 6: // Pastel
            return (0..<numTypes).map { i in
                hsvColor((Double(i) / Double(numTypes)) * 360.0, 0.5, 1.0)
            }
        case 7: // Cold Blue
            return gradientPalette(numTypes, [
                KeyColor(t: 0.00, r: 0.05, g: 0.10, b: 0.35),
                KeyColor(t: 0.25, r: 0.10, g: 0.25, b: 0.70),
                KeyColor(t: 0.50, r: 0.20, g: 0.55, b: 0.95),
                KeyColor(t: 0.75, r: 0.55, g: 0.80, b: 1.00),
                KeyColor(t: 1.00, r: 0.85, g: 0.95, b: 1.00)
            ])
        case 8: // Sci-Fi Spectrum
            return gradientPalette(numTypes, [
                KeyColor(t: 0.00, r: 0.00, g: 0.00, b: 0.30),
                KeyColor(t: 0.25, r: 0.00, g: 0.20, b: 1.00),
                KeyColor(t: 0.50, r: 0.00, g: 1.00, b: 0.40),
                KeyColor(t: 0.75, r: 1.00, g: 1.00, b: 0.40),
                KeyColor(t: 1.00, r: 1.00, g: 0.40, b: 1.00)
            ])
        case 9: // Thermal Glow
            return gradientPalette(numTypes, [
                KeyColor(t: 0.00, r: 0.00, g: 0.00, b: 0.25),
                KeyColor(t: 0.20, r: 0.00, g: 0.25, b: 0.80),
                KeyColor(t: 0.40, r: 0.00, g: 0.85, b: 0.40),
                KeyColor(t: 0.60, r: 0.95, g: 0.85, b: 0.00),
                KeyColor(t: 0.80, r: 1.00, g: 0.40, b: 0.00),
                KeyColor(t: 1.00, r: 0.90, g: 0.00, b: 0.65)
            ])
        case 10: // Crimson Flame
            return (0..<numTypes).map { i in
                let t = numTypes <= 1 ? 0.0 : Double(i) / Double(numTypes - 1)
                let h = posMod(2.0 - (2.0 - (-30.0)) * t, 360.0)
                return hsvColor(h, lerp(1.0, 0.7, t), lerp(0.95, 0.45, t))
            }
        case 11: // Fire
            return (0..<numTypes).map { i in
                let t = numTypes <= 1 ? 0.0 : Double(i) / Double(numTypes - 1)
                return hsvColor(lerp(5, 45, t), lerp(1.0, 0.9, t), lerp(0.9, 1.0, t))
            }
        case 12: // Violet Fade
            return (0..<numTypes).map { i in
                let t = numTypes <= 1 ? 0.0 : Double(i) / Double(numTypes - 1)
                return hsvColor(lerp(345, 260, t), lerp(0.9, 0.55, t), lerp(0.95, 0.35, t))
            }
        case 13: // Grayscale
            return gradientPalette(numTypes, [
                KeyColor(t: 0.00, r: 0.05, g: 0.05, b: 0.05),
                KeyColor(t: 0.75, r: 0.65, g: 0.65, b: 0.65),
                KeyColor(t: 1.00, r: 1.00, g: 1.00, b: 1.00)
            ])
        case 14: // Desert Warm
            return gradientPalette(numTypes, [
                KeyColor(t: 0.00, r: 0.9647, g: 0.8863, b: 0.7020),
                KeyColor(t: 0.25, r: 0.9098, g: 0.7529, b: 0.4471),
                KeyColor(t: 0.50, r: 0.8471, g: 0.5373, b: 0.2275),
                KeyColor(t: 0.75, r: 0.7216, g: 0.3608, b: 0.1843),
                KeyColor(t: 1.00, r: 0.3686, g: 0.2275, b: 0.1804)
            ])
        case 15: // Dual Gradient
            let startH = Double.random(in: 0...360)
            var endH = Double.random(in: 0...360)
            let startS = Double.random(in: 0.70...1.00)
            var endS = Double.random(in: 0.70...1.00)
            let startV = Double.random(in: 0.80...1.00)
            var endV = Double.random(in: 0.70...1.00)
            
            let hueDelta = posMod(endH - startH + 540, 360) - 180
            if abs(hueDelta) < 70 {
                let sign = hueDelta >= 0 ? 1.0 : -1.0
                endH = posMod(startH + sign * 70, 360)
            }
            if abs(endS - startS) < 0.15 {
                endS = clamp(endS + (endS >= startS ? 0.15 : -0.15))
            }
            if abs(endV - startV) < 0.12 {
                endV = clamp(endV + (endV >= startV ? 0.12 : -0.12))
            }
            let dH = posMod(endH - startH + 540, 360) - 180
            return (0..<numTypes).map { i in
                let t = numTypes <= 1 ? 0.0 : Double(i) / Double(numTypes - 1)
                return hsvColor(startH + dH * t, lerp(startS, endS, t), lerp(startV, endV, t))
            }
        case 16: // Candy
            let phi = 137.50776405003785
            let baseH = randRange(0, 360)
            return (0..<numTypes).map { i in
                let h = baseH + Double(i) * phi + randN(0, 8)
                return hsvColor(h, clamp(0.8 + randN(0, 0.08)), clamp(0.9 + randN(0, 0.06)))
            }
        case 17: // Organic Flow
            let baseH = randRange(0, 15)
            return (0..<numTypes).map { i in
                let extra = (i % 4 == 0) ? randRange(15, 30) : 0.0
                let h = baseH + randN(0, 8) + extra
                return hsvColor(h, clamp(0.7 + randN(0, 0.1)), clamp(0.45 + abs(randN(0, 0.2))))
            }
        case 18: // Earth Flow
            let hA = randRange(10, 30)
            let hB = posMod(hA + randRange(140, 220), 360)
            let phase = Double.random(in: 0...Double.pi)
            return (0..<numTypes).map { i in
                let u = numTypes <= 1 ? 0.0 : Double(i) / Double(numTypes - 1)
                let a = 2.0 * .pi * u + phase
                let mix = 0.5 + 0.5 * sin(a)
                let hue = hA * (1.0 - mix) + hB * mix + randN(0, 3)
                let s = clamp(0.75 + randN(0, 0.07))
                let v = clamp(0.60 + 0.35 * sin(a + 1.1) + randN(0, 0.06))
                return hsvColor(hue, s, v)
            }
        case 19: // Game Boy DMG
            let steps = [0.2, 0.35, 0.55, 0.78]
            let hue = randRange(90, 110)
            return (0..<numTypes).map { i in
                let v = clamp(steps[i % steps.count] + randN(0, 0.03))
                let s = clamp(0.25 + randN(0, 0.05))
                return hsvColor(hue, s, v)
            }
        case 20: // Paper & Ink
            let inks = [210.0, 30.0, 220.0]
            return (0..<numTypes).map { i in
                if i % 4 == 0 {
                    let v = clamp(0.92 + randN(0, 0.03))
                    let tint = randRange(-6, 6)
                    return hsvColor(45 + tint, 0.18 + randN(0, 0.05), v)
                } else {
                    let hue = inks.randomElement()!
                    return hsvColor(hue + randN(0, 6), 0.6 + randN(0, 0.1), 0.35 + randN(0, 0.08))
                }
            }
        case 21: // Fluoro Sport
            let accents = [95.0, 175.0, 310.0]
            return (0..<numTypes).map { i in
                let isAccent = (i % 4 == 0)
                let h = isAccent ? accents.randomElement()! + randN(0, 6) : randRange(210, 260) + randN(0, 8)
                let s = isAccent ? clamp(0.95 + randN(0, 0.03)) : clamp(0.25 + randN(0, 0.08))
                let v = isAccent ? clamp(0.98 + randN(0, 0.02)) : clamp(0.18 + randN(0, 0.06))
                return hsvColor(h, s, v)
            }
        case 22: // Midnight Circuit
            let ambS = jitterPair((0.90, 1.00), 0.08, 0.08)
            let ambV = jitterPair((0.90, 1.00), 0.08, 0.08)
            let vioS = jitterPair((0.65, 0.92), 0.08, 0.08)
            let vioV = jitterPair((0.28, 0.52), 0.08, 0.08)
            let teaS = jitterPair((0.65, 0.85), 0.08, 0.08)
            let teaV = jitterPair((0.20, 0.50), 0.08, 0.08)
            
            var a = 0
            if Double.random(in: 0...1) < 0.80 {
                let maxAmber = min(2, max(0, numTypes - 1))
                a = maxAmber > 0 ? Int.random(in: 1...maxAmber) : 0
            }
            var rest = numTypes - a
            var v = min(1, rest)
            rest -= v
            let tealExtra = rest > 0 ? Int.random(in: 0...rest) : 0
            let t = tealExtra
            v += (rest - tealExtra)
            
            var out: [Color] = []
            out += fillSegment(count: a, hMin: 25, hMax: 40, sMin: ambS.0, sMax: ambS.1, vMin: ambV.0, vMax: ambV.1)
            out += fillSegment(count: v, hMin: 270, hMax: 285, sMin: vioS.0, sMax: vioS.1, vMin: vioV.0, vMax: vioV.1)
            out += fillSegment(count: t, hMin: 175, hMax: 200, sMin: teaS.0, sMax: teaS.1, vMin: teaV.0, vMax: teaV.1)
            return out
        case 23: // BioLuminescent Abyss
            let accS = jitterPair((0.9, 1.0), 0.05, 0.05)
            let accV = jitterPair((0.85, 1.0), 0.06, 0.06)
            let deepS = jitterPair((0.8, 0.95), 0.05, 0.05)
            let deepV = jitterPair((0.12, 0.20), 0.06, 0.06)
            
            let accentCount = min(2, max(1, Int.random(in: 0...2)))
            let deepCount = max(0, numTypes - accentCount)
            
            var out: [Color] = []
            out += fillSegment(count: accentCount, hMin: 185, hMax: 200, sMin: accS.0, sMax: accS.1, vMin: accV.0, vMax: accV.1)
            out += fillSegment(count: deepCount, hMin: 200, hMax: 225, sMin: deepS.0, sMax: deepS.1, vMin: deepV.0, vMax: deepV.1, vCurveExp: 1.8)
            return out
        case 24: // Blueprint
            let sBlue = jitterPair((0.60, 0.75), 0.05, 0.05)
            let vBlue = jitterPair((0.30, 0.50), 0.05, 0.05)
            let vAccent = jitterPair((0.90, 0.98), 0.01, 0.01)
            
            let accentCount = min(2, max(1, Int.random(in: 0...2)))
            let blueCount = max(0, numTypes - accentCount)
            
            var out: [Color] = []
            out += fillSegment(count: accentCount, hMin: 0, hMax: 0, sMin: 0, sMax: 0, vMin: vAccent.0, vMax: vAccent.1)
            out += fillSegment(count: blueCount, hMin: 215, hMax: 235, sMin: sBlue.0, sMax: sBlue.1, vMin: vBlue.0, vMax: vBlue.1)
            return out
        case 25: // Cyber Dark
            let accentH = randRange(10, 350)
            let accentPeriod = max(3, Int(round(Double(numTypes) / 3.0)))
            return (0..<numTypes).map { i in
                if i % accentPeriod == 0 {
                    return hsvColor(accentH + randN(0, 8), 0.9, 0.95)
                } else {
                    let v = pow(clamp(0.25 + Double.random(in: 0...0.55)), 1.1)
                    return Color(red: v, green: v, blue: v)
                }
            }
        case 26: // Holographic Foil
            let k1 = randRange(0.8, 1.4), k2 = randRange(2.2, 3.6)
            return (0..<numTypes).map { i in
                let t = Double(i) / Double(max(1, numTypes - 1))
                let h = 360.0 * (t + 0.05 * sin(2 * .pi * k1 * t) + 0.03 * sin(2 * .pi * k2 * t)) + randN(0, 4)
                let s = clamp(0.5 + 0.4 * sin(2 * .pi * (k1 + k2) * t) + randN(0, 0.05))
                let v = clamp(0.85 + 0.1 * cos(2 * .pi * k2 * t) + randN(0, 0.03))
                return hsvColor(h, s, v)
            }
        case 36: // Holographic Foil 2
            let phaseH = Double.random(in: 0...(2 * .pi))
            let phaseS = Double.random(in: 0...(2 * .pi))
            let phaseV = Double.random(in: 0...(2 * .pi))
            return (0..<numTypes).map { i in
                let t = numTypes <= 1 ? 0.0 : Double(i) / Double(numTypes - 1)
                let hue = 360.0 * t + 360.0 * 0.06 * sin(2.5 * 2 * .pi * t + phaseH)
                let s = clamp(0.70 + 0.25 * (0.5 + 0.5 * sin(2 * .pi * t + phaseS)))
                let v = clamp(0.92 + 0.08 * (0.5 + 0.5 * cos(2 * .pi * t + phaseV)))
                return hsvColor(hue, s, v)
            }
        case 27: // Mineral Gemstones
            let hues = [140.0, 350.0, 220.0, 45.0, 200.0, 300.0]
            return (0..<numTypes).map { i in
                let h = hues[i % hues.count] + randN(0, 5)
                return hsvColor(h, clamp(0.75 + randN(0, 0.08)), clamp(0.7 + randN(0, 0.1)))
            }
        case 28: // Vaporwave Pastel
            let anchors = [320.0, 260.0, 170.0]
            return (0..<numTypes).map { i in
                let h = anchors[i % anchors.count] + randN(0, 10)
                return hsvColor(h, clamp(0.35 + randN(0, 0.08)), clamp(0.95 + randN(0, 0.04)))
            }
        case 29: // Solarized Drift
            let anchors: [(h: Double, s: Double, v: Double)] = [
                (44, 0.55, 0.92), (44, 0.25, 0.60), (192, 0.55, 0.85), (220, 0.55, 0.80),
                (64, 0.55, 0.85), (18, 0.65, 0.90), (350, 0.55, 0.85), (300, 0.40, 0.85)
            ]
            return (0..<numTypes).map { i in
                let a = anchors[i % anchors.count]
                return hsvColor(a.h + randN(0, 5), clamp(a.s + randN(0, 0.06)), clamp(a.v + randN(0, 0.05)))
            }
        case 30: // Aurora
            let center = randRange(120, 220)
            return (0..<numTypes).map { _ in
                let spread = randRange(20, 60)
                return hsvColor(center + randN(0, spread), clamp(0.6 + randN(0, 0.15)), clamp(0.75 + randN(0, 0.12)))
            }
        case 31: // Cyber Neon
            let baseH = randRange(280, 340)
            return (0..<numTypes).map { i in
                let h = baseH + Double(i) * (360.0 / Double(numTypes)) * randRange(0.6, 1.1) + randN(0, 6)
                return hsvColor(h, clamp(0.9 + randN(0, 0.05)), clamp(0.9 + randN(0, 0.07)))
            }
        case 32: // Golden Angle Jitter
            let phi = 137.50776405003785
            let baseH = randRange(0, 360)
            let sBase = randRange(0.6, 0.95)
            let vBase = randRange(0.8, 1.0)
            let jitterH = randRange(2, 10)
            return (0..<numTypes).map { i in
                let h = baseH + Double(i) * phi + randN(0, jitterH)
                return hsvColor(h, clamp(sBase + randN(0, 0.07)), clamp(vBase + randN(0, 0.05)))
            }
        case 33: // CMYK Misregister
            let inks = [200.0, 300.0, 55.0, 220.0]
            return (0..<numTypes).map { i in
                let h = inks[i % inks.count] + randN(0, 5)
                let s = clamp((i % 4 == 3 ? 0.1 : 0.9) + randN(0, 0.05))
                let v = clamp((i % 4 == 3 ? 0.35 : 0.95) + randN(0, 0.05))
                return hsvColor(h, s, v)
            }
        case 34: // Anodized Metal
            let hue0 = randRange(180, 320)
            return (0..<numTypes).map { i in
                let t = Double(i) / Double(max(1, numTypes - 1))
                let h = hue0 + 40.0 * sin(2 * .pi * t) + randN(0, 3)
                let s = clamp(0.6 + 0.25 * sin(4 * .pi * t + 1.2) + randN(0, 0.03))
                let v = clamp(0.65 + 0.3 * cos(4 * .pi * t) + randN(0, 0.03))
                return hsvColor(h, s, v, scale: 0.96)
            }
        case 35: // Ink Bleed Watercolor
            let center = randRange(190, 260)
            return (0..<numTypes).map { i in
                let h = center + randN(0, 18)
                let s = clamp(0.2 + abs(randN(0, 0.12)))
                let v = clamp(0.7 + 0.25 * sin(Double(i) * 0.9 + randRange(0, .pi)) + randN(0, 0.06))
                return hsvColor(h, s, v)
            }
        default:
            return (0..<numTypes).map { i in
                hsvColor((Double(i) / Double(numTypes)) * 360.0, 1.0, 1.0)
            }
        }
    }
}
