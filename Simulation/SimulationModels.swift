import Foundation
import simd

struct Particle {
    var position: SIMD3<Float>
    var velocity: SIMD3<Float>
    var type: UInt32
    var originalIndex: UInt32
    var pad2: UInt32
    var pad3: UInt32
}

struct SimParams {
    var dt: Float
    var friction: Float
    var rMax: Float
    var rMin: Float
    var numTypes: UInt32
    var particleCount: UInt32
}
