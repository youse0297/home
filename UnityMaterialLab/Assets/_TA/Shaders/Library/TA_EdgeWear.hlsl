//UNITY_SHADER_NO_UPGRADE
#ifndef TA_EDGE_WEAR_INCLUDED
#define TA_EDGE_WEAR_INCLUDED

#include "TA_Common.hlsl"
#include "TA_Vector.hlsl"

struct TA_EdgeWearConfig
{
    half threshold;
    half softness;
    half strength;
    half roughnessBoost;
    half3 wearColor;
};

half TA_EvaluateEdgeWear(
    half3 normalWS,
    half3 viewDirectionWS,
    TA_EdgeWearConfig config
)
{
    half3 safeNormal = TA_SafeNormalize(normalWS);
    half3 safeViewDirection = TA_SafeNormalize(viewDirectionWS);
    half grazing = 1.0h - saturate(dot(safeNormal, safeViewDirection));
    half threshold = saturate(config.threshold);
    half softness = max(config.softness, TA_MIN_DENOMINATOR);
    half progress = saturate((grazing - threshold) / softness);
    half edgeMask = progress * progress * (3.0h - 2.0h * progress);
    return saturate(edgeMask * saturate(config.strength));
}

half3 TA_ApplyEdgeWearColor(
    half3 baseColor,
    TA_EdgeWearConfig config,
    half wearMask
)
{
    return saturate(lerp(baseColor, saturate(config.wearColor), saturate(wearMask)));
}

half TA_ApplyEdgeWearRoughness(
    half roughness,
    TA_EdgeWearConfig config,
    half wearMask
)
{
    half sanitizedRoughness = TA_SanitizePerceptualRoughness(roughness);
    half wearTarget = lerp(
        sanitizedRoughness,
        1.0h,
        saturate(config.roughnessBoost)
    );
    return TA_SanitizePerceptualRoughness(
        lerp(sanitizedRoughness, wearTarget, saturate(wearMask))
    );
}

#endif
