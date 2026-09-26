#include <metal_stdlib>
using namespace metal;

struct Particle {
    float3 position;
    float3 velocity;
    uint type;
    uint pad1;
    uint pad2;
    uint pad3;
};

struct SimParams {
    float dt;
    float friction;
    float rMax;
    float rMin;
    uint numTypes;
    uint particleCount;
};

struct Cell {
    atomic_uint count;
    uint indices[64];
};

inline uint3 getCellCoords(float3 pos) {
    float3 p = clamp(pos + 2.0, 0.0f, 3.9999f);
    return uint3(p * 4.0f);
}

inline uint getCellIndex(uint3 coords) {
    return coords.x + coords.y * 16 + coords.z * 256;
}

kernel void clearGrid(device Cell* grid [[buffer(0)]],
                      uint id [[thread_position_in_grid]]) {
    if (id < 4096) {
        atomic_store_explicit(&grid[id].count, 0, memory_order_relaxed);
    }
}

kernel void buildGrid(device Particle* particles [[buffer(0)]],
                      device Cell* grid [[buffer(1)]],
                      constant SimParams& params [[buffer(2)]],
                      uint id [[thread_position_in_grid]]) {
    if (id >= params.particleCount) return;

    float3 pos = particles[id].position;
    uint cellIndex = getCellIndex(getCellCoords(pos));

    uint count = atomic_fetch_add_explicit(&grid[cellIndex].count, 1, memory_order_relaxed);
    if (count < 64) {
        grid[cellIndex].indices[count] = id;
    }
}

kernel void computeGridParticles(device Particle* particles [[buffer(0)]],
                                 constant float* ruleMatrix [[buffer(1)]],
                                 constant SimParams& params [[buffer(2)]],
                                 device const Cell* grid [[buffer(3)]],
                                 uint id [[thread_position_in_grid]]) {
    if (id >= params.particleCount) return;

    Particle p = particles[id];
    float3 force = float3(0.0);
    uint3 cellCoords = getCellCoords(p.position);

    for (int z = -1; z <= 1; z++) {
        for (int y = -1; y <= 1; y++) {
            for (int x = -1; x <= 1; x++) {
                int3 neighborCoords = int3(cellCoords) + int3(x, y, z);

                if (neighborCoords.x < 0 || neighborCoords.x > 15 ||
                    neighborCoords.y < 0 || neighborCoords.y > 15 ||
                    neighborCoords.z < 0 || neighborCoords.z > 15) {
                    continue;
                }

                uint neighborCellIndex = getCellIndex(uint3(neighborCoords));
                uint count = atomic_load_explicit(&grid[neighborCellIndex].count, memory_order_relaxed);
                uint limit = min(count, 64u);

                for (uint i = 0; i < limit; i++) {
                    uint otherId = grid[neighborCellIndex].indices[i];
                    if (otherId == id) continue;

                    Particle other = particles[otherId];
                    float3 d = p.position - other.position;
                    float r = length(d);

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

    // ==========================================
    // 撈魚網物理：邊界穿透與推擠力 (Penetration Impulse)
    // ==========================================
    float bounds = 2.0;
    float bounce = 0.4;     // 基本反彈力
    float scoopForce = 0.8; // 網子掃過時賦予粒子的推擠力 (越大彈得越遠)

    // X 軸
    if (p.position.x > bounds) {
        float penetration = p.position.x - bounds; // 計算被網子吃進去多深
        p.position.x = bounds;
        if (p.velocity.x > 0) p.velocity.x *= -bounce;
        p.velocity.x -= (penetration / params.dt) * scoopForce; // 賦予反向推擠速度
    } else if (p.position.x < -bounds) {
        float penetration = -bounds - p.position.x;
        p.position.x = -bounds;
        if (p.velocity.x < 0) p.velocity.x *= -bounce;
        p.velocity.x += (penetration / params.dt) * scoopForce;
    }

    // Y 軸
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

    // Z 軸
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

    particles[id] = p;
}
