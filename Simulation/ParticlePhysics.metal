#include <metal_stdlib>
#include "ParticleTypes.h"
using namespace metal;

kernel void computeGridParticles(device Particle* particlesOut [[buffer(0)]],
                                 device const Particle* particlesIn [[buffer(1)]],
                                 constant float* ruleMatrix [[buffer(2)]],
                                 constant SimParams& params [[buffer(3)]],
                                 device const Cell* grid [[buffer(4)]],
                                 uint id [[thread_position_in_grid]]) {
    if (id >= params.particleCount) return;

    Particle p = particlesIn[id];
    float3 force = float3(0.0);
    uint3 cellCoords = getCellCoords(p.position);

    for (int z = -1; z <= 1; z++) {
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                int3 neighborCoords = int3(cellCoords) + int3(x, y, z);

                if (neighborCoords.x < 0 || neighborCoords.x > 31 ||
                    neighborCoords.y < 0 || neighborCoords.y > 31 ||
                    neighborCoords.z < 0 || neighborCoords.z > 31) {
                    continue;
                }

                uint neighborCellIndex = getCellIndex(uint3(neighborCoords));
                uint startIndex = grid[neighborCellIndex].startIndex;
                uint count = atomic_load_explicit(&grid[neighborCellIndex].count, memory_order_relaxed);

                for (uint i = 0; i < count; i++) {
                    uint otherId = startIndex + i;
                    if (otherId == id) continue;

                    Particle other = particlesIn[otherId];
                    float3 d = p.position - other.position;
                    float r = fast::length(d);

                    if (r > 0.0 && r < params.rMax) {
                        d /= r;

                        if (r < params.rMin) {
                            force += d * (1.0f - r / params.rMin) * 2.0f;
                        } else {
                            float rule = ruleMatrix[p.type * params.numTypes + other.type];
                            float f = rule * (1.0f - abs(2.0f * r - params.rMax - params.rMin) / (params.rMax - params.rMin));
                            force += d * f;
                        }
                    }
                }
            }
        }
    }

    p.velocity += force * params.dt;
    p.velocity *= params.friction;
    p.position += p.velocity * params.dt;

    // 撈魚網物理邊界
    float bounds = 2.0;
    float bounce = 0.4;
    float scoopForce = 0.8;

    if (p.position.x > bounds) {
        float penetration = p.position.x - bounds;
        p.position.x = bounds;
        if (p.velocity.x > 0) p.velocity.x *= -bounce;
        p.velocity.x -= (penetration / params.dt) * scoopForce;
    } else if (p.position.x < -bounds) {
        float penetration = -bounds - p.position.x;
        p.position.x = -bounds;
        if (p.velocity.x < 0) p.velocity.x *= -bounce;
        p.velocity.x += (penetration / params.dt) * scoopForce;
    }

    if (p.position.y > bounds) {
        float penetration = p.position.y - bounds;
        p.position.y = bounds;
        if (p.velocity.y > 0) p.velocity.y *= -bounce;
        p.velocity.y -= (penetration / params.dt) * scoopForce;
    } else if (p.position.y < -bounds) {
        float penetration = -bounds - p.position.y;
        p.position.y = -bounds;
        if (p.velocity.y < 0) p.velocity.y *= -bounce;
        p.velocity.y += (penetration / params.dt) * scoopForce;
    }

    if (p.position.z > bounds) {
        float penetration = p.position.z - bounds;
        p.position.z = bounds;
        if (p.velocity.z > 0) p.velocity.z *= -bounce;
        p.velocity.z -= (penetration / params.dt) * scoopForce;
    } else if (p.position.z < -bounds) {
        float penetration = -bounds - p.position.z;
        p.position.z = -bounds;
        if (p.velocity.z < 0) p.velocity.z *= -bounce;
        p.velocity.z += (penetration / params.dt) * scoopForce;
    }

    // 【核心修正】寫回原始身分證的記憶體位址，而非排序後的位址
    particlesOut[p.originalIndex] = p;
}
// 👆 上面這個大括號非常重要，代表 computeGridParticles 函式結束。

// 👇 下方的常數與新的 kernel 必須完全獨立在外面！

// 新增：包含位置與法線的頂點結構
struct ParticleVertex {
    float3 position;
    float3 normal;
};

// 定義二十面體 (Icosahedron) 的 12 個標準頂點
constant float a = 0.525731f;
constant float b = 0.850651f;
constant float3 sphereVerts[12] = {
    float3(-a,  b,  0), float3( a,  b,  0), float3(-a, -b,  0), float3( a, -b,  0),
    float3( 0, -a,  b), float3( 0,  a,  b), float3( 0, -a, -b), float3( 0,  a, -b),
    float3( b,  0, -a), float3( b,  0,  a), float3(-b,  0, -a), float3(-b,  0,  a)
};

// 替換原有的 kernel，改為輸出 ParticleVertex
kernel void updateMeshVertices(device const Particle* particles [[buffer(0)]],
                               device ParticleVertex* vertices [[buffer(1)]],
                               constant SimParams& params [[buffer(2)]],
                               uint id [[thread_position_in_grid]]) {
    if (id >= params.particleCount) return;
    
    Particle p = particles[id];
    uint vIndex = p.originalIndex * 12;
    float size = 0.015;

    for(int i=0; i<12; i++) {
        vertices[vIndex + i].position = p.position + sphereVerts[i] * size;
        // 由於我們是以圓球為基底，頂點的標準化相對座標，剛好就是指向外側的法線向量！
        vertices[vIndex + i].normal = sphereVerts[i];
    }
}
