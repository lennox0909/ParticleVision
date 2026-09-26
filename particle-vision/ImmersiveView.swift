import SwiftUI
import RealityKit

struct ImmersiveView: View {
    @Environment(ParticleSimulator.self) private var simulator
    @State private var particleEntities: [Entity] = []
    @State private var frameSubscription: EventSubscription?

    var body: some View {
        RealityView { content in
            let rootEntity = Entity()
            rootEntity.position = SIMD3<Float>(0, 1.2, -1.5)
            content.add(rootEntity)
            
            let subscription = content.subscribe(to: SceneEvents.Update.self) { _ in
                guard !self.particleEntities.isEmpty else { return }
                simulator.updateSimulation()
                syncParticlesToVisuals()
            }
            
            Task { @MainActor in
                self.frameSubscription = subscription
                
                do {
                    let usdaTemplate = try await Entity(named: "Sphere")
                    setupParticleVisuals(in: rootEntity, template: usdaTemplate)
                } catch {
                    print("無法載入 USDA 模型：\(error)")
                }
            }
        }
        .onChange(of: simulator.particleScale) { _, newScale in
            let newScaleVector = SIMD3<Float>(repeating: newScale)
            for entity in particleEntities {
                entity.scale = newScaleVector
            }
        }
        .onDisappear {
            frameSubscription?.cancel()
            frameSubscription = nil
        }
    }
    
    private func findModelEntity(in entity: Entity) -> Entity? {
        if entity.components[ModelComponent.self] != nil { return entity }
        for child in entity.children {
            if let found = findModelEntity(in: child) { return found }
        }
        return nil
    }
    
    private func setupParticleVisuals(in root: Entity, template: Entity) {
        let count = simulator.particleCount
        let numTypes = simulator.numTypes
        let pointer = simulator.particleBuffer.contents().bindMemory(to: Particle.self, capacity: count)
        
        let colors: [UIColor] = [.systemRed, .systemGreen, .systemBlue, .systemYellow, .systemPurple, .systemOrange]
        var materials: [SimpleMaterial] = []
        for i in 0..<numTypes {
            let color = colors[i % colors.count]
            materials.append(SimpleMaterial(color: color, isMetallic: false))
        }
        
        guard let coreTemplate = findModelEntity(in: template) else {
            print("錯誤：USDA 內找不到幾何模型。")
            return
        }
        
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
            
            root.addChild(clone)
            newEntities.append(clone)
        }
        
        self.particleEntities = newEntities
    }
    
    private func syncParticlesToVisuals() {
        let count = simulator.particleCount
        let pointer = simulator.particleBuffer.contents().bindMemory(to: Particle.self, capacity: count)
        
        for i in 0..<count {
            particleEntities[i].position = pointer[i].position
        }
    }
}
