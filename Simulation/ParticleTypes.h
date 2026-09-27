#ifndef ParticleTypes_h
#define ParticleTypes_h

#include <metal_stdlib>
using namespace metal;

// 【修改】加入 originalIndex 來記憶原本在陣列中的位址
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

// 強制對齊 16 bytes，防止 GPU 記憶體溢位
struct Cell {
    atomic_uint count;
    uint startIndex;
    atomic_uint currentOffset;
    uint padding;
};

inline uint3 getCellCoords(float3 pos) {
    float3 p = clamp(pos + 2.0, 0.0f, 3.9999f);
    return uint3(p * 4.0f);
}

inline uint getCellIndex(uint3 coords) {
    return coords.x + coords.y * 16 + coords.z * 256;
}

#endif /* ParticleTypes_h */
