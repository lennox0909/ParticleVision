import SwiftUI

extension ColorPaletteGenerator {
    
    // MARK: - 數學與色彩轉換輔助函式 (移除 private 供其他 Extension 呼叫)
    
    static func clamp(_ val: Double, _ minVal: Double = 0.0, _ maxVal: Double = 1.0) -> Double {
        return min(maxVal, max(minVal, val))
    }
    
    static func lerp(_ a: Double, _ b: Double, _ t: Double) -> Double {
        return a + (b - a) * t
    }
    
    static func randRange(_ a: Double, _ b: Double) -> Double {
        return Double.random(in: min(a, b)...max(a, b))
    }
    
    /// Box–Muller 常態分佈亂數
    static func randN(_ mu: Double = 0.0, _ sigma: Double = 1.0) -> Double {
        var u = 0.0
        var v = 0.0
        while u == 0.0 { u = Double.random(in: 0..<1) }
        while v == 0.0 { v = Double.random(in: 0..<1) }
        return mu + sigma * sqrt(-2.0 * log(u)) * cos(2.0 * .pi * v)
    }
    
    static func posMod(_ x: Double, _ m: Double) -> Double {
        let r = x.truncatingRemainder(dividingBy: m)
        return r < 0 ? r + m : r
    }
    
    /// HSV (H: 0~360, S: 0~1, V: 0~1) 轉 SwiftUI Color
    static func hsvColor(_ h: Double, _ s: Double, _ v: Double, scale: Double = 1.0) -> Color {
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
    
    static func gradientPalette(_ numTypes: Int, _ keyColors: [KeyColor]) -> [Color] {
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
    
    static func jitterPair(_ pair: (Double, Double), _ jStart: Double, _ jEnd: Double) -> (Double, Double) {
        var x = clamp(pair.0 + (Double.random(in: -1...1)) * jStart)
        var y = clamp(pair.1 + (Double.random(in: -1...1)) * jEnd)
        if y < x { swap(&x, &y) }
        return (x, y)
    }
    
    static func fillSegment(
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
}
