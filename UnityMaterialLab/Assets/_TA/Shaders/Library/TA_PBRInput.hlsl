//UNITY_SHADER_NO_UPGRADE
#ifndef TA_PBR_INPUT_INCLUDED
#define TA_PBR_INPUT_INCLUDED

#include "TA_ShaderTypes.hlsl"
#include "TA_Common.hlsl"
#include "TA_Vector.hlsl"
#include "TA_Sampling.hlsl"

struct TA_PBRInputConfig
{
    half4 baseColorTint;
    half normalScale;
    half ambientOcclusionStrength;
    half roughnessScale;
    half metallicScale;
};

struct TA_PBRInputData
{
    half3 baseColor;
    half alpha;
    half3 normalTS;
    half ambientOcclusion;
    half roughness;
    half metallic;
};

TA_PBRInputData TA_SamplePBRInput(
    TEXTURE2D_PARAM(baseMap, baseSampler),
    TEXTURE2D_PARAM(normalMap, normalSampler),
    TEXTURE2D_PARAM(ormMap, ormSampler),
    float2 uv,
    TA_PBRInputConfig config)
{
    half4 baseSample = TA_SampleTexture2D(
        TEXTURE2D_ARGS(baseMap, baseSampler),
        uv
    );
    half3 orm = TA_SampleORM(
        TEXTURE2D_ARGS(ormMap, ormSampler),
        uv
    );

    TA_PBRInputData result;
    result.baseColor = saturate(baseSample.rgb * config.baseColorTint.rgb);
    result.alpha = baseSample.a * config.baseColorTint.a;
    result.normalTS = TA_SampleNormalTS(
        TEXTURE2D_ARGS(normalMap, normalSampler),
        uv,
        config.normalScale
    );
    result.ambientOcclusion = lerp(
        1.0h,
        orm.r,
        saturate(config.ambientOcclusionStrength)
    );
    result.roughness = TA_SanitizePerceptualRoughness(orm.g * config.roughnessScale);
    result.metallic = saturate(orm.b * config.metallicScale);
    return result;
}

TA_SurfaceData TA_BuildSurfaceData(
    TA_PBRInputData inputData,
    half3 normalWS)
{
    TA_SurfaceData surface;
    surface.baseColor = inputData.baseColor;
    surface.normalWS = TA_SafeNormalize(normalWS);
    surface.ambientOcclusion = inputData.ambientOcclusion;
    surface.roughness = inputData.roughness;
    surface.metallic = inputData.metallic;
    return surface;
}

#endif
