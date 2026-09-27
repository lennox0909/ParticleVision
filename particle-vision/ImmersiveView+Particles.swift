import SwiftUI
import RealityKit

extension ImmersiveView {
    
    func setupParticleVisuals(in parent: Entity) {
        guard let coreTemplate = self.coreTemplate else { return }
        
        let count = simulator.particleCount
        let numTypes = simulator.numTypes
        let pointer = simulator.particleBuffer.contents().bindMemory(to: Particle.self, capacity: count)
        let colors: [UIColor] = [.systemRed, .systemGreen, .systemBlue, .systemYellow, .systemPurple, .systemOrange]
        
        var materials: [UnlitMaterial] = []
        for i in 0..<numTypes { materials.append(UnlitMaterial(color: colors[i % colors.count])) }
        
        var newEntities: [Entity] = []
        newEntities.reserveCapacity(count)
        let initialScale = SIMD3<Float>(repeating: simulator.particleScale)
        
        for i in 0..<count {
            let particle = pointer[i]
            let typeIndex = Int(particle.type) % materials.count
            let clone = coreTemplate.clone(recursive: true)
            
            if var modelComp = clone.components[ModelComponent.self] {
                modelComp.materials = [materials[typeIndex]]
                clone.components.set(modelComp)
            }
            
            clone.scale = initialScale
            clone.position = particle.position
            parent.addChild(clone)
            newEntities.append(clone)
        }
        self.particleEntities = newEntities
    }
    
    func syncParticlesToVisuals() {
        let count = simulator.particleCount
        let pointer = simulator.particleBuffer.contents().bindMemory(to: Particle.self, capacity: count)
        for i in 0..<count {
            particleEntities[i].position = pointer[i].position
        }
    }
}
