#include <metal_stdlib>
#include "ParticleTypes.h"
using namespace metal;

kernel void computeGridParticles(device Particle* particlesOut [[buffer(0)]],
                                 device const Particle* particlesIn [[buffer(1)]],
                                 constant float* ruleMatrix [[buffer(2)]],
                                 constant SimParams& params [[buffer(3)]],
                                 device const Cell* grid [[buffer(4)]],
                                 constant float4* handForces [[buffer(5)]],
                                 uint id [[thread_position_in_grid]]) {
    if (id >= params.particleCount) return;

    Particle p = particlesIn[id];
    float3 force = float3(0.0);
    uint3 cellCoords = getCellCoords(p.position);
    
    // ✨ 計算單一矩陣的大小 (N x N)，用於偏移讀取 rMin 與 rMax 矩陣
    uint matrixSize = params.numTypes * params.numTypes;

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

                    // ✨ 根據 (主動粒子 p.type -> 目標粒子 other.type) 查表取得專屬的引力、最小半徑與最大半徑
                    uint ruleIdx = p.type * params.numTypes + other.type;
                    float rule = ruleMatrix[ruleIdx];
                    float pairRMin = ruleMatrix[matrixSize + ruleIdx];
                    float pairRMax = max(pairRMin + 0.001f, ruleMatrix[matrixSize * 2 + ruleIdx]);

                    if (r > 0.0 && r < pairRMax) {
                        d /= r;

                        if (r < pairRMin) {
                            force += d * (1.0f - r / pairRMin) * 2.0f;
                        } else {
                            float f = rule * (1.0f - abs(2.0f * r - pairRMax - pairRMin) / (pairRMax - pairRMin));
                            force += d * f;
                        }
                    }
                }
            }
        }
    }

    // 1. 動態種子：利用 id 與「當前速度」混合，確保擾動方向每幀切換，打破靜態風場
    uint seed = id ^ as_type<uint>(p.velocity.x) ^ as_type<uint>(p.velocity.y) ^ as_type<uint>(p.velocity.z);
    
    // 2. 高品質整數雜湊 (PCG Hash 變體)：確保分佈絕對均勻，消除特定方向的引力偏差
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
    
    // 4. 套用微小擾動打破網格對稱性
    force += jitter * 0.1f;

    // 5. ✨ 雙手「神之手」粒子力場互動 (0: 左手, 1: 右手)
    for (int h = 0; h < 2; h++) {
        float mode = handForces[h].w;
        if (abs(mode) > 0.01f) {
            float3 handPos = handForces[h].xyz;
            float3 toHand = handPos - p.position;
            float dist = fast::length(toHand);
            
            // 作用範圍：局部座標半徑 1.25 內（涵蓋約三分之一個盒子的廣域力場）
            float influenceRadius = 1.25f;
            if (dist > 0.001f && dist < influenceRadius) {
                float3 dir = toHand / dist;
                float falloff = 1.0f - (dist / influenceRadius);
                
                if (mode > 0.0f) {
                    // ✋ 張開手模式 (+1.0)：星雲漩渦引力場
                    // 距離 < 0.12 時產生微排斥核心，避免所有粒子重疊縮成單一亮點；外圍則強力吸引並加上水平切線旋轉力
                    if (dist < 0.12f) {
                        force -= dir * (1.0f - dist / 0.12f) * 8.0f;
                    } else {
                        force += dir * (falloff * falloff) * 14.0f;
                        // 切線軌道旋力：讓聚集過來的粒子繞著指尖優雅公轉
                        float3 swirlDir = normalize(cross(dir, float3(0.0f, 1.0f, 0.0f)) + float3(0.001f));
                        force += swirlDir * falloff * 5.5f;
                    }
                } else {
                    // 🤏 捏合手指模式 (-1.0)：超新星斥力衝擊波
                    force -= dir * (falloff * falloff) * 32.0f;
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

    // 寫回原始身分證的記憶體位址
    particlesOut[p.originalIndex] = p;
}

// 包含位置與法線的頂點結構
struct ParticleVertex {
    float3 position;
    float3 normal;
};

// 四面體的 4 個正規化頂點
constant float3 tetraVerts[4] = {
    float3( 1.0,  1.0,  1.0) * 0.57735f,
    float3( 1.0, -1.0, -1.0) * 0.57735f,
    float3(-1.0,  1.0, -1.0) * 0.57735f,
    float3(-1.0, -1.0,  1.0) * 0.57735f
};

// ✨ 接收 buffer(3) 傳入的 particleScale，讓粒子外觀大小滑桿獨立生效
kernel void updateMeshVertices(device const Particle* particles [[buffer(0)]],
                               device ParticleVertex* vertices [[buffer(1)]],
                               constant SimParams& params [[buffer(2)]],
                               constant float& particleScale [[buffer(3)]],
                               uint id [[thread_position_in_grid]]) {
    if (id >= params.particleCount) return;
    
    Particle p = particles[id];
    uint vIndex = p.originalIndex * 4;
    float size = particleScale;

    for (int i = 0; i < 4; i++) {
        vertices[vIndex + i].position = p.position + tetraVerts[i] * size;
        vertices[vIndex + i].normal = tetraVerts[i];
    }
}
