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

    // --- 替換原本的 Jitter 程式碼 ---
        
    // 1. 動態種子：利用 id 與「當前速度」混合。速度每幀都在變化，確保擾動方向不斷切換，打破靜態風場
    uint seed = id ^ as_type<uint>(p.velocity.x) ^ as_type<uint>(p.velocity.y) ^ as_type<uint>(p.velocity.z);
    
    // 2. 高品質整數雜湊 (PCG Hash 變體)：確保分佈絕對均勻，徹底消除特定方向的引力偏差
    seed ^= seed >> 16;
    seed *= 0x85ebca6b;
    seed ^= seed >> 13;
    seed *= 0xc2b2ae35;
    seed ^= seed >> 16;
    
    // 3. 提取三個均勻分佈的浮點數，將範圍精確映射至 -1.0 ~ 1.0
    float rx = float(seed & 0x3FF) / 1023.0 * 2.0 - 1.0;
    float ry = float((seed >> 10) & 0x3FF) / 1023.0 * 2.0 - 1.0;
    float rz = float((seed >> 20) & 0x3FF) / 1023.0 * 2.0 - 1.0;
    
    float3 jitter = float3(rx, ry, rz);
    
    // 4. 套用擾動 (因為現在的隨機性非常強且活躍，只需 0.1f 就足以打破網格對稱性)
    force += jitter * 0.1f;
    
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

// 新增：包含位置與法線的頂點結構
struct ParticleVertex {
    float3 position;
    float3 normal;
};

// ✨ 修改：新增四面體的 4 個頂點 (已正規化處理，長度皆為 1，剛好可作為法線)
constant float3 tetraVerts[4] = {
    float3( 1.0,  1.0,  1.0) * 0.57735f,
    float3( 1.0, -1.0, -1.0) * 0.57735f,
    float3(-1.0,  1.0, -1.0) * 0.57735f,
    float3(-1.0, -1.0,  1.0) * 0.57735f
};

// 替換原有的 kernel，改為輸出 ParticleVertex
kernel void updateMeshVertices(device const Particle* particles [[buffer(0)]],
                               device ParticleVertex* vertices [[buffer(1)]],
                               constant SimParams& params [[buffer(2)]],
                               uint id [[thread_position_in_grid]]) {
    if (id >= params.particleCount) return;
    
    Particle p = particles[id];
    
    // ✨ 修改：每個粒子只佔用 4 個頂點的陣列空間
    uint vIndex = p.originalIndex * 4;
    float size = 0.015;

    // ✨ 修改：迴圈降至 4 次
    for(int i=0; i<4; i++) {
        vertices[vIndex + i].position = p.position + tetraVerts[i] * size;
        vertices[vIndex + i].normal = tetraVerts[i];
    }
}
