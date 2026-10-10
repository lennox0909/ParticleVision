import SwiftUI
import RealityKit

extension ImmersiveView {
    
    /// ✨ 建立 visionOS 專屬的「黑洞引力透鏡」深色透明玻璃材質
    private func createDarkGlassMaterial() -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        
        // 1. 基底設為黑色，營造黑洞的深邃感，但透過透明度讓光線穿透
        material.baseColor = PhysicallyBasedMaterial.BaseColor(tint: .black)
        
        // 2. 透明混合：設為 0.1 (90% 透明)，保有極佳的觀察視野，但帶有一層黯淡的薄膜感
        material.blending = .transparent(opacity: 0.10)
        
        // 3. 非金屬、全光滑，確保純粹的折射特性
        material.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: 0.0)
        material.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.0)
        
        // 4. 最大化高光，捕捉周圍發光粒子的銳利反射
        material.specular = PhysicallyBasedMaterial.Specular(floatLiteral: 1.0)
        
        // 5. 強烈透明塗層，勾勒出黑洞外圍銳利的光圈邊緣（Photon Sphere）
        material.clearcoat = PhysicallyBasedMaterial.Clearcoat(floatLiteral: 1.0)
        material.clearcoatRoughness = PhysicallyBasedMaterial.ClearcoatRoughness(floatLiteral: 0.0)
        
        return material
    }
    
    /// ✨ 初始化 3D 黑洞（內層深淵核心 + 外層透明引力透鏡）
    func setupSingularityOrb(in box: Entity) {
        // 1. 外層：透明深色玻璃殼 (引力透鏡 / 邊界)
        let glassMesh = MeshResource.generateSphere(radius: 0.18)
        let glassMaterial = createDarkGlassMaterial()
        singularityOrb = ModelEntity(mesh: glassMesh, materials: [glassMaterial])
        
        // 2. 內核：極小、吞噬一切光線的「事件視界」純黑核心
        let coreMesh = MeshResource.generateSphere(radius: 0.04)
        let coreMaterial = UnlitMaterial(color: .black)
        let coreEntity = ModelEntity(mesh: coreMesh, materials: [coreMaterial])
        
        // 組合雙層結構
        singularityOrb.addChild(coreEntity)
        singularityOrb.position = SIMD3<Float>(0, 0, 0)
        
        box.addChild(singularityOrb)
        updateSingularityVisual()
    }
    
    /// ✨ 根據奇點模式與強度動態更新外觀
    func updateSingularityVisual() {
        guard simulator.singularityMode > 0 else {
            singularityOrb.isEnabled = false
            return
        }
        
        singularityOrb.isEnabled = true
        // 讓整顆黑洞（含內核與玻璃殼）隨著引力強度縮放
        let scale = 0.75 + simulator.singularityStrength * 0.25
        singularityOrb.scale = SIMD3<Float>(repeating: scale)
    }
}
