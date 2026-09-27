#include <metal_stdlib>
#include "ParticleTypes.h"
using namespace metal;

kernel void clearGrid(device Cell* grid [[buffer(0)]],
                      uint id [[thread_position_in_grid]]) {
    if (id < 4096) {
        atomic_store_explicit(&grid[id].count, 0, memory_order_relaxed);
        atomic_store_explicit(&grid[id].currentOffset, 0, memory_order_relaxed);
    }
}

kernel void countGrid(device const Particle* particles [[buffer(0)]],
                      device Cell* grid [[buffer(1)]],
                      constant SimParams& params [[buffer(2)]],
                      uint id [[thread_position_in_grid]]) {
    if (id >= params.particleCount) return;
    uint cellIndex = getCellIndex(getCellCoords(particles[id].position));
    atomic_fetch_add_explicit(&grid[cellIndex].count, 1, memory_order_relaxed);
}

kernel void prefixSumGrid(device Cell* grid [[buffer(0)]],
                          uint id [[thread_position_in_grid]]) {
    if (id == 0) {
        uint sum = 0;
        for (uint i = 0; i < 4096; i++) {
            grid[i].startIndex = sum;
            sum += atomic_load_explicit(&grid[i].count, memory_order_relaxed);
        }
    }
}

kernel void reorderParticles(device const Particle* particlesIn [[buffer(0)]],
                             device Particle* particlesOut [[buffer(1)]],
                             device Cell* grid [[buffer(2)]],
                             constant SimParams& params [[buffer(3)]],
                             uint id [[thread_position_in_grid]]) {
    if (id >= params.particleCount) return;
    
    Particle p = particlesIn[id];
    uint cellIndex = getCellIndex(getCellCoords(p.position));
    
    uint offset = atomic_fetch_add_explicit(&grid[cellIndex].currentOffset, 1, memory_order_relaxed);
    uint destIndex = grid[cellIndex].startIndex + offset;
    
    particlesOut[destIndex] = p;
}
