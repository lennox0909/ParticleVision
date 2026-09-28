#ifndef ParticleTypes_h
#define ParticleTypes_h

#include <metal_stdlib>
using namespace metal;

struct Particle {
    float3 position;
    float3 velocity;
    uint type;
    uint originalIndex;
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
    uint startIndex;
    atomic_uint currentOffset;
    uint padding;
};

// ✨ 修正 1：乘數從 4.0f 改為 8.0f (32格 / 4.0空間寬度 = 8.0)
inline uint3 getCellCoords(float3 pos) {
    float3 p = clamp(pos + 2.0, 0.0f, 3.9999f);
    return uint3(p * 8.0f);
}

// ✨ 修正 2：乘數改為 32 與 1024 (32 * 32)
inline uint getCellIndex(uint3 coords) {
    return coords.x + coords.y * 32 + coords.z * 1024;
}

#endif /* ParticleTypes_h */
