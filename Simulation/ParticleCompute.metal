#include <metal_stdlib>
#include "SharedTypes.h"
using namespace metal;

#define GRID_DIM 16
#define MAX_PER_CELL 64
#define SPACE_SIZE 4.0

struct GridCell {
    atomic_uint count;
    uint indices[MAX_PER_CELL];
};

kernel void clearGrid(device GridCell* grid [[buffer(0)]], uint id [[thread_position_in_grid]]) {
    if (id < (GRID_DIM * GRID_DIM * GRID_DIM)) {
        atomic_store_explicit(&grid[id].count, 0, memory_order_relaxed);
    }
}

kernel void buildGrid(device Particle* particles [[buffer(0)]],
                      device GridCell* grid [[buffer(1)]],
                      constant SimParams& params [[buffer(2)]],
                      uint id [[thread_position_in_grid]]) {
    if (id >= params.particleCount) return;
    
    float3 pos = particles[id].position;
    int3 cellIndex = int3((pos + 2.0) / SPACE_SIZE * GRID_DIM);
    cellIndex = clamp(cellIndex, 0, GRID_DIM - 1);
    uint flatIndex = cellIndex.x + cellIndex.y * GRID_DIM + cellIndex.z * GRID_DIM * GRID_DIM;
    
    uint currentCount = atomic_fetch_add_explicit(&grid[flatIndex].count, 1, memory_order_relaxed);
    if (currentCount < MAX_PER_CELL) {
        grid[flatIndex].indices[currentCount] = id;
    }
}

kernel void computeGridParticles(device Particle* particles [[buffer(0)]],
                                 constant float* ruleMatrix [[buffer(1)]],
                                 constant SimParams& params [[buffer(2)]],
                                 device GridCell* grid [[buffer(3)]],
                                 uint id [[thread_position_in_grid]]) {
    if (id >= params.particleCount) return;

    Particle p1 = particles[id];
    float3 totalForce = float3(0.0);
    int3 cellIndex = int3((p1.position + 2.0) / SPACE_SIZE * GRID_DIM);
    cellIndex = clamp(cellIndex, 0, GRID_DIM - 1);

    for (int z = -1; z <= 1; z++) {
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                int3 neighborIdx = cellIndex + int3(x, y, z);
                if (neighborIdx.x < 0 || neighborIdx.x > 15 || neighborIdx.y < 0 || neighborIdx.y > 15 || neighborIdx.z < 0 || neighborIdx.z > 15) continue;

                uint flatIndex = neighborIdx.x + neighborIdx.y * GRID_DIM + neighborIdx.z * GRID_DIM * GRID_DIM;
                uint count = atomic_load_explicit(&grid[flatIndex].count, memory_order_relaxed);
                uint limit = min(count, (uint)MAX_PER_CELL);

                for (uint i = 0; i < limit; i++) {
                    uint otherId = grid[flatIndex].indices[i];
                    if (otherId == id) continue;

                    Particle p2 = particles[otherId];
                    float3 dir = p2.position - p1.position;
                    float dist = length(dir);

                    if (dist > 0.0 && dist < params.rMax) {
                        dir = normalize(dir);
                        float force = 0.0;
                        if (dist < params.rMin) {
                            force = (dist / params.rMin) - 1.0;
                        } else {
                            uint matrixIndex = p1.type * params.numTypes + p2.type;
                            float ruleValue = ruleMatrix[matrixIndex];
                            float num = abs(dist - 0.5 * (params.rMax + params.rMin));
                            float den = 0.5 * (params.rMax - params.rMin);
                            force = ruleValue * (1.0 - (num / den));
                        }
                        totalForce += dir * force;
                    }
                }
            }
        }
    }

    p1.velocity = (p1.velocity + totalForce * params.dt) * params.friction;
    p1.position += p1.velocity * params.dt;

    float boundary = 2.0;
    if (p1.position.x > boundary || p1.position.x < -boundary) { p1.velocity.x *= -1.0; }
    if (p1.position.y > boundary || p1.position.y < -boundary) { p1.velocity.y *= -1.0; }
    if (p1.position.z > boundary || p1.position.z < -boundary) { p1.velocity.z *= -1.0; }

    particles[id] = p1;
}
