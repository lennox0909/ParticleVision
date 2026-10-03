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
    
    func updateParticleMaterials() {
        guard let entity = self.particleEntities.first as? ModelEntity else { return }
        
        let numTypes = simulator.numTypes
        var materials: [RealityKit.Material] = []
        
        for i in 0..<numTypes {
            // ✨ 直接從 simulator 讀取代表色並轉為 UIColor，確保 3D 粒子與 2D 矩陣面板顏色 100% 一致（支援完整 8 色）
            let color = UIColor(simulator.colorForType(i))
            
            // 判斷強度大於 0 才開啟螢光材質
            if simulator.glowIntensity > 0 {
                var pbrMat = PhysicallyBasedMaterial()
                pbrMat.baseColor = PhysicallyBasedMaterial.BaseColor(tint: color)
                pbrMat.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: 0.8)
                pbrMat.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.2)
                pbrMat.emissiveColor = PhysicallyBasedMaterial.EmissiveColor(color: color)
                pbrMat.emissiveIntensity = simulator.glowIntensity
                materials.append(pbrMat)
            } else {
                materials.append(SimpleMaterial(color: color, isMetallic: true))
            }
        }
        
        entity.model?.materials = materials
    }
    
    func syncParticlesToVisuals() {}
}
