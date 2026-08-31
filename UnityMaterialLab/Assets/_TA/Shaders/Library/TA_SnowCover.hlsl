//UNITY_SHADER_NO_UPGRADE
#ifndef TA_SNOW_COVER_INCLUDED
#define TA_SNOW_COVER_INCLUDED

#include "TA_Common.hlsl"
#include "TA_Vector.hlsl"

struct TA_SnowCoverConfig
{
    half3 snowColor;
    half coverage;
    half normalThreshold;
    half normalSoftness;
    half snowRoughness;
    half heightBlend;
    float heightStart;
    float heightFade;
};

half TA_EvaluateSnowCover(
    half3 normalWS,
    float3 positionWS,
    TA_SnowCoverConfig config
)
{
    half3 safeNormal = TA_SafeNormalize(normalWS);
    half upwardness = saturate(dot(safeNormal, half3(0.0h, 1.0h, 0.0h)));
    half threshold = saturate(config.normalThreshold);
    half softness = max(config.normalSoftness, TA_MIN_DENOMINATOR);
    half slopeMask = smoothstep(
        threshold - softness,
        threshold + softness,
        upwardness
    );
    float heightFade = max(abs(config.heightFade), (float)TA_MIN_DENOMINATOR);
    half heightMask = saturate((positionWS.y - config.heightStart) / heightFade);
    half combinedMask = lerp(1.0h, heightMask, saturate(config.heightBlend));
    return saturate(slopeMask * combinedMask * saturate(config.coverage));
}

half3 TA_ApplySnowCoverColor(
    half3 baseColor,
    half3 snowColor,
    half snowMask
)
{
    return saturate(lerp(baseColor, saturate(snowColor), saturate(snowMask)));
}

half TA_ApplySnowCoverRoughness(
    half roughness,
    half snowRoughness,
    half snowMask
)
{
    half baseRoughness = TA_SanitizePerceptualRoughness(roughness);
    half targetRoughness = TA_SanitizePerceptualRoughness(snowRoughness);
    return TA_SanitizePerceptualRoughness(
        lerp(baseRoughness, targetRoughness, saturate(snowMask))
    );
}

half TA_ApplySnowCoverMetallic(half metallic, half snowMask)
{
    return saturate(lerp(saturate(metallic), 0.0h, saturate(snowMask)));
}

#endif
