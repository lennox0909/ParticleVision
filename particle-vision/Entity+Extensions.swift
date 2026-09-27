import RealityKit
import SwiftUI

extension Entity {
    // 尋找模型元件的遞迴工具
    func findModelEntity() -> Entity? {
        if self.components[ModelComponent.self] != nil { return self }
        for child in self.children {
            if let found = child.findModelEntity() { return found }
        }
        return nil
    }
    
    // 產生外框線條的工具
    func addBoxEdges(size: Float) {
        let thickness: Float = 0.008
        let half = size / 2.0
        let edgeMaterial = UnlitMaterial(color: UIColor.white.withAlphaComponent(0.8))
        
        for y in [-half, half] {
            for z in [-half, half] {
                let edge = ModelEntity(mesh: .generateBox(size: [size, thickness, thickness]), materials: [edgeMaterial])
                edge.position = SIMD3<Float>(0, y, z)
                self.addChild(edge)
            }
        }
        for x in [-half, half] {
            for z in [-half, half] {
                let edge = ModelEntity(mesh: .generateBox(size: [thickness, size, thickness]), materials: [edgeMaterial])
                edge.position = SIMD3<Float>(x, 0, z)
                self.addChild(edge)
            }
        }
        for x in [-half, half] {
            for y in [-half, half] {
                let edge = ModelEntity(mesh: .generateBox(size: [thickness, thickness, size]), materials: [edgeMaterial])
                edge.position = SIMD3<Float>(x, y, 0)
                self.addChild(edge)
            }
        }
    }
}
