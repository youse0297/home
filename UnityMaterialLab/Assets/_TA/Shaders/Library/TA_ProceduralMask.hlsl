//UNITY_SHADER_NO_UPGRADE
#ifndef TA_PROCEDURAL_MASK_INCLUDED
#define TA_PROCEDURAL_MASK_INCLUDED

#include "TA_Common.hlsl"

struct TA_ProceduralMaskConfig
{
    float2 uvScale;
    float2 uvOffset;
    float rotationRadians;
    float timeScale;
    float phase;
    half contrast;
    half strength;
};

half TA_EvaluateProceduralMask(
    float2 uv,
    float timeSeconds,
    TA_ProceduralMaskConfig config
)
{
    float2 scale = min(abs(config.uvScale), 64.0);
    float2 transformed = uv * scale + config.uvOffset;
    float angle = clamp(config.rotationRadians, -TA_PI, TA_PI);
    float sine = sin(angle);
    float cosine = cos(angle);
    float2 rotated = float2(
        cosine * transformed.x - sine * transformed.y,
        sine * transformed.x + cosine * transformed.y
    );
    float animatedPhase = dot(rotated, float2(1.61803399, 2.41421356)) +
        timeSeconds * clamp(config.timeScale, -16.0, 16.0) +
        clamp(config.phase, -2.0 * TA_PI, 2.0 * TA_PI);
    half raw = 0.5h + 0.5h * sin(animatedPhase);
    half shaped = saturate((raw - 0.5h) * max(config.contrast, 0.0h) + 0.5h);
    return lerp(1.0h, shaped, saturate(config.strength));
}

half TA_ApplyProceduralMask(half layerWeight, half proceduralMask)
{
    return saturate(layerWeight * saturate(proceduralMask));
}

#endif
