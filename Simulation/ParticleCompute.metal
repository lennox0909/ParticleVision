#include <metal_stdlib>
#include "SharedTypes.h"
using namespace metal;

kernel void computeParticles(
    device Particle* particles [[buffer(0)]],
    constant float* ruleMatrix [[buffer(1)]],
    constant SimParams& params [[buffer(2)]],
    uint id [[thread_position_in_grid]]
) {
    if (id >= params.particleCount) { return; }

    Particle p1 = particles[id];
    float3 totalForce = float3(0.0);

    for (uint i = 0; i < params.particleCount; i++) {
        if (i == id) continue;

        Particle p2 = particles[i];
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
                
                float numerator = abs(dist - 0.5 * (params.rMax + params.rMin));
                float denominator = 0.5 * (params.rMax - params.rMin);
                force = ruleValue * (1.0 - (numerator / denominator));
            }
            totalForce += dir * force;
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
