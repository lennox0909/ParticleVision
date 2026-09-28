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
        
        parent.addChild(massiveParticleEntity)
        self.particleEntities = [massiveParticleEntity]
        
        // 初始套用材質
        updateParticleMaterials()
    }
    
    func updateParticleMaterials() {
            guard let entity = self.particleEntities.first as? ModelEntity else { return }
            
            let numTypes = simulator.numTypes
            let colors: [UIColor] = [.systemRed, .systemGreen, .systemBlue, .systemYellow, .systemPurple, .systemOrange]
            
            var materials: [RealityKit.Material] = []
            
            for i in 0..<numTypes {
                let color = colors[i % colors.count]
                
                // ✨ 判斷強度大於 0 才開啟螢光材質
                if simulator.glowIntensity > 0 {
                    var pbrMat = PhysicallyBasedMaterial()
                    pbrMat.baseColor = PhysicallyBasedMaterial.BaseColor(tint: color)
                    pbrMat.metallic = PhysicallyBasedMaterial.Metallic(floatLiteral: 0.8)
                    pbrMat.roughness = PhysicallyBasedMaterial.Roughness(floatLiteral: 0.2)
                    pbrMat.emissiveColor = PhysicallyBasedMaterial.EmissiveColor(color: color)
                    
                    // ✨ 將寫死的數值改為讀取 slider 的強度
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
