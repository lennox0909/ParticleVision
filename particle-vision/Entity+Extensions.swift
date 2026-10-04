import SwiftUI
import RealityKit

extension Entity {
    
    /// 遞迴尋找第一個 ModelEntity（供載入 Sphere.usda 使用）
    func findModelEntity() -> ModelEntity? {
        if let model = self as? ModelEntity {
            return model
        }
        for child in children {
            if let found = child.findModelEntity() {
                return found
            }
        }
        return nil
    }
    
    /// 建立透明盒子的 12 根邊框，並支援即時調整灰階顏色 (0=全黑 ~ 1=全白) 與粗細
    func addBoxEdges(size: Float, grayscale: Float = 0.85, thickness: Float = 0.012) {
        // 先清除舊有的邊框子實體（避免重複疊加）
        let oldEdges = children.filter { $0.name.hasPrefix("BoxEdge_") }
        for edge in oldEdges {
            edge.removeFromParent()
        }
        
        let half = size / 2.0
        let gray = CGFloat(min(1.0, max(0.0, grayscale)))
        let material = UnlitMaterial(color: UIColor(white: gray, alpha: 0.9))
        
        // 基準粗細設為 1.0，後續透過 scale 直接控制實際粗細，拉動滑桿零卡頓！
        let xMesh = MeshResource.generateBox(size: [size, 1.0, 1.0])
        let yMesh = MeshResource.generateBox(size: [1.0, size, 1.0])
        let zMesh = MeshResource.generateBox(size: [1.0, 1.0, size])
        
        let offsets: [Float] = [-half, half]
        
        for a in offsets {
            for b in offsets {
                // 1. X 軸向四根邊框
                let xEdge = ModelEntity(mesh: xMesh, materials: [material])
                xEdge.name = "BoxEdge_X"
                xEdge.position = [0, a, b]
                xEdge.scale = [1.0, thickness, thickness]
                self.addChild(xEdge)
                
                // 2. Y 軸向四根邊框
                let yEdge = ModelEntity(mesh: yMesh, materials: [material])
                yEdge.name = "BoxEdge_Y"
                yEdge.position = [a, 0, b]
                yEdge.scale = [thickness, 1.0, thickness]
                self.addChild(yEdge)
                
                // 3. Z 軸向四根邊框
                let zEdge = ModelEntity(mesh: zMesh, materials: [material])
                zEdge.name = "BoxEdge_Z"
                zEdge.position = [a, b, 0]
                zEdge.scale = [thickness, thickness, 1.0]
                self.addChild(zEdge)
            }
        }
    }
    
    /// ✨ 即時更新 12 根邊框的灰階顏色與粗細
    func updateBoxEdgesAppearance(grayscale: Float, thickness: Float) {
        let gray = CGFloat(min(1.0, max(0.0, grayscale)))
        let material = UnlitMaterial(color: UIColor(white: gray, alpha: 0.9))
        
        for child in children {
            guard let model = child as? ModelEntity, child.name.hasPrefix("BoxEdge_") else { continue }
            model.model?.materials = [material]
            
            switch child.name {
            case "BoxEdge_X":
                model.scale = [1.0, thickness, thickness]
            case "BoxEdge_Y":
                model.scale = [thickness, 1.0, thickness]
            case "BoxEdge_Z":
                model.scale = [thickness, thickness, 1.0]
            default:
                break
            }
        }
    }
}
