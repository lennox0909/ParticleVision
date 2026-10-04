import SwiftUI
import RealityKit

extension ImmersiveView {
    
    func setupParticleVisuals(in parent: Entity) {
        guard let meshResource = simulator.meshResource else { return }
        
        let massiveParticleEntity = ModelEntity()
        massiveParticleEntity.components.set(ModelComponent(
            mesh: meshResource,
            materials: [] // 先留空，交給下方的函式統一生成
        ))
        
        // 確保粒子網格與透明盒子保持 1:1 座標對齊，自動隨盒子等比例縮放
        massiveParticleEntity.scale = SIMD3<Float>(repeating: 1.0)
        
        parent.addChild(massiveParticleEntity)
        self.particleEntities = [massiveParticleEntity]
        
        // 初始套用材質
        updateParticleMaterials()
    }
    
    /// ✨ 根據「種類色票模式」或「🔥 即時真實動能熱力模式」建立 PBR 自發光材質
    func updateParticleMaterials() {
        guard let entity = self.particleEntities.first as? ModelEntity else { return }
        
        let numTypes = simulator.numTypes
        var materials: [RealityKit.Material] = []
        
        for i in 0..<numTypes {
            let color: UIColor
            let glowMultiplier: Float
            
            if simulator.isKineticColorMode {
                // 🔥 讀取該種類粒子在 3D 空間中的「即時真實平均速度能階 (0.0 靜止冷藍 -> 1.0 高速白熱紅)」
                let liveEnergy = i < simulator.typeKineticEnergies.count ? simulator.typeKineticEnergies[i] : 0.0
                color = thermalHeatmapColor(for: liveEnergy)
                // 靜止時發光微弱呈現冷冽感 (0.35x)，高速衝刺時綻放強烈高能熱光 (1.75x)
                glowMultiplier = 0.35 + liveEnergy * 1.40
            } else {
                // 🎨 一般種類色票模式
                color = UIColor(simulator.colorForType(i))
                glowMultiplier = 1.0
            }
            
            if simulator.glowIntensity > 0 {
                var pbrMat = PhysicallyBasedMaterial()
                pbrMat.baseColor = PhysicallyBasedMaterial.BaseColor(tint: color)
                pbrMat.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: 0.8)
                pbrMat.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.2)
                pbrMat.emissiveColor = PhysicallyBasedMaterial.EmissiveColor(color: color)
                pbrMat.emissiveIntensity = simulator.glowIntensity * glowMultiplier
                materials.append(pbrMat)
            } else {
                materials.append(SimpleMaterial(color: color, isMetallic: true))
            }
        }
        
        entity.model?.materials = materials
    }
    
    /// 將 0.0 (靜止) ~ 1.0 (高速) 的真實動能映射為物理熱力圖色譜（極地深藍 -> 電光青 -> 翡翠綠 -> 亮黃 -> 烈焰橘紅）
    private func thermalHeatmapColor(for t: Float) -> UIColor {
        let clamped = max(0.0, min(1.0, t))
        switch clamped {
        case 0.0..<0.20:
            // 0.0 ~ 0.20 (靜止 ~ 微動)：深海極地藍 -> 冰河藍
            let p = CGFloat(clamped / 0.20)
            return UIColor(red: 0.04, green: 0.12 + 0.38 * p, blue: 0.48 + 0.42 * p, alpha: 1.0)
        case 0.20..<0.45:
            // 0.20 ~ 0.45 (中低速)：冰河藍 -> 電光青綠
            let p = CGFloat((clamped - 0.20) / 0.25)
            return UIColor(red: 0.04, green: 0.50 + 0.45 * p, blue: 0.90 - 0.40 * p, alpha: 1.0)
        case 0.45..<0.70:
            // 0.45 ~ 0.70 (中高速追擊)：電光青綠 -> 耀眼金黃
            let p = CGFloat((clamped - 0.45) / 0.25)
            return UIColor(red: 0.04 + 0.96 * p, green: 0.95, blue: 0.50 * (1.0 - p), alpha: 1.0)
        default:
            // 0.70 ~ 1.00 (極速衝刺 / 神之手加速)：耀眼金黃 -> 烈焰橘紅 -> 白熱紫紅
            let p = CGFloat((clamped - 0.70) / 0.30)
            return UIColor(red: 1.0, green: 0.95 - 0.70 * p, blue: 0.45 * p, alpha: 1.0)
        }
    }
    
    /// ✨ 每幀在 GPU 物理運算完成後，若開啟「🔥 熱力能階模式」，即時抽樣真實速度並動態更新材質能階！
    func syncParticlesToVisuals() {
        guard simulator.isKineticColorMode else { return }
        simulator.updateLiveKineticEnergies()
        updateParticleMaterials()
    }
}
